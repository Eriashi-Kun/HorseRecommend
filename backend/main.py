from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from scraper import fetch_races_for_upcoming, _fetch_yoso_odds, fetch_race_result
from recommender import recommend
from datetime import datetime, date
import asyncio
import threading
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_cache: dict = {"races": None, "updated_at": None}
CACHE_TTL_SECONDS = 1800
ODDS_REFRESH_INTERVAL = 60


def _refresh_cache_sync():
    try:
        races = fetch_races_for_upcoming()
        _cache["races"] = races
        _cache["updated_at"] = datetime.now()
        logger.info(f"Cache loaded: {len(races)} races")
    except Exception as e:
        logger.error(f"Cache refresh failed: {e}")


def _refresh_odds_for_today():
    """今日のレースのオッズだけを1分ごとに更新するバックグラウンドスレッド"""
    while True:
        time.sleep(ODDS_REFRESH_INTERVAL)
        if not _cache["races"]:
            continue
        today = date.today().strftime("%Y%m%d")
        today_races = [r for r in _cache["races"] if r.get("day") == today]
        if not today_races:
            continue
        updated = 0
        for race in today_races:
            race_id = race.get("race_id")
            if not race_id:
                continue
            odds_map = _fetch_yoso_odds(race_id)
            if odds_map:
                for horse in race.get("horses", []):
                    key = str(horse["number"])
                    if key in odds_map:
                        horse["odds"] = odds_map[key]
                updated += 1
        if updated:
            logger.info(f"Odds refreshed for {updated} races")


def _is_cache_fresh() -> bool:
    if _cache["races"] is None or _cache["updated_at"] is None:
        return False
    age = (datetime.now() - _cache["updated_at"]).total_seconds()
    return age < CACHE_TTL_SECONDS


@asynccontextmanager
async def lifespan(app: FastAPI):
    loop = asyncio.get_running_loop()
    loop.run_in_executor(None, _refresh_cache_sync)
    threading.Thread(target=_refresh_odds_for_today, daemon=True).start()
    yield


app = FastAPI(title="HorseRecommend API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/races")
def get_races():
    if _cache["races"] is not None:
        if not _is_cache_fresh():
            threading.Thread(target=_refresh_cache_sync, daemon=True).start()
        return _cache["races"]
    _refresh_cache_sync()
    return _cache["races"] or []


@app.get("/races/refresh")
def refresh_races():
    _refresh_cache_sync()
    return {"status": "ok", "count": len(_cache["races"] or [])}


# MARK: - Recommendation

class HorseInput(BaseModel):
    number: int
    name: str
    odds: float
    gate: int = 0
    sex: str = ""
    age: int = 0
    jockey: str = ""
    weight: float = 0.0
    horse_id: str = ""

class RaceInput(BaseModel):
    name: str
    venue: str
    race_number: str
    day: str
    time: str = ""
    distance: str
    condition: str
    horses: list[HorseInput]

class WeightsInput(BaseModel):
    jockey: float = 50.0
    history: float = 50.0
    popularity: float = 50.0
    cuteness: float = 0.0
    intuition: float = 0.0

class RecommendRequest(BaseModel):
    race: RaceInput
    type: str  # "safe" | "midRange" | "longShot"
    weights: WeightsInput = WeightsInput()


@app.post("/recommend")
def get_recommendation(body: RecommendRequest):
    try:
        race_dict = body.race.model_dump()
        return recommend(race_dict, body.type, body.weights.model_dump())
    except Exception as e:
        logger.error(f"Recommendation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/race/{race_id}/result")
def get_race_result(race_id: str):
    return fetch_race_result(race_id)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "cached_races": len(_cache["races"]) if _cache["races"] else 0,
        "updated_at": _cache["updated_at"].isoformat() if _cache["updated_at"] else None,
    }
