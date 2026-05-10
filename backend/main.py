from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from scraper import fetch_races_for_upcoming
from datetime import datetime
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_cache: dict = {"races": None, "updated_at": None}
CACHE_TTL_SECONDS = 1800


def _refresh_cache_sync():
    try:
        _cache["races"] = fetch_races_for_upcoming()
        _cache["updated_at"] = datetime.now()
        logger.info(f"Cache loaded: {len(_cache['races'])} races")
    except Exception as e:
        logger.error(f"Cache refresh failed: {e}")


def _is_cache_fresh() -> bool:
    if _cache["races"] is None or _cache["updated_at"] is None:
        return False
    age = (datetime.now() - _cache["updated_at"]).total_seconds()
    return age < CACHE_TTL_SECONDS


@asynccontextmanager
async def lifespan(app: FastAPI):
    loop = asyncio.get_running_loop()
    loop.run_in_executor(None, _refresh_cache_sync)
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
    if not _is_cache_fresh():
        logger.info("Cache miss — fetching from netkeiba")
        _refresh_cache_sync()
    return _cache["races"] or []


@app.get("/races/refresh")
def refresh_races():
    _refresh_cache_sync()
    return {"status": "ok", "count": len(_cache["races"] or [])}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "cached_races": len(_cache["races"]) if _cache["races"] else 0,
        "updated_at": _cache["updated_at"].isoformat() if _cache["updated_at"] else None,
    }
