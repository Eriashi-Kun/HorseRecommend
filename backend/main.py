from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from scraper import fetch_races_for_weekend
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="HorseRecommend API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

# Simple in-memory cache (30 min TTL)
_cache: dict = {"races": None, "updated_at": None}
CACHE_TTL_SECONDS = 1800


def _is_cache_fresh() -> bool:
    if _cache["races"] is None or _cache["updated_at"] is None:
        return False
    age = (datetime.now() - _cache["updated_at"]).total_seconds()
    return age < CACHE_TTL_SECONDS


@app.get("/races")
def get_races():
    if not _is_cache_fresh():
        logger.info("Cache miss — fetching from netkeiba")
        _cache["races"] = fetch_races_for_weekend()
        _cache["updated_at"] = datetime.now()
    return _cache["races"]


@app.get("/races/refresh")
def refresh_races():
    _cache["races"] = fetch_races_for_weekend()
    _cache["updated_at"] = datetime.now()
    return {"status": "ok", "count": len(_cache["races"])}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "cached_races": len(_cache["races"]) if _cache["races"] else 0,
        "updated_at": _cache["updated_at"].isoformat() if _cache["updated_at"] else None,
    }
