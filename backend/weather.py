from __future__ import annotations

import logging
import os
from datetime import datetime

import requests

logger = logging.getLogger(__name__)

OPENWEATHER_API_KEY = os.environ.get('OPENWEATHER_API_KEY', '')

# 各競馬場の緯度・経度
VENUE_COORDS: dict[str, tuple[float, float]] = {
    '札幌': (43.05, 141.40),
    '函館': (41.77, 140.73),
    '福島': (37.77, 140.47),
    '新潟': (37.87, 139.05),
    '中山': (35.77, 139.97),
    '東京': (35.63, 139.49),
    '中京': (35.08, 137.07),
    '京都': (34.90, 135.68),
    '阪神': (34.75, 135.34),
    '小倉': (33.83, 130.84),
}

_cache: dict[tuple, dict | None] = {}


def get_race_weather(venue: str, day: str, time_str: str) -> dict | None:
    """レース開催地・日時の天気情報を返す。取得失敗時は None。"""
    if not OPENWEATHER_API_KEY:
        return None

    coords = VENUE_COORDS.get(venue)
    if not coords:
        return None

    cache_key = (venue, day, time_str[:2])  # 時間単位でキャッシュ
    if cache_key in _cache:
        return _cache[cache_key]

    lat, lon = coords
    today = datetime.now().strftime('%Y%m%d')

    try:
        if day == today:
            result = _fetch_current(lat, lon)
        else:
            result = _fetch_forecast(lat, lon, day, time_str)
    except Exception as e:
        logger.warning(f"Weather fetch failed for {venue} {day}: {e}")
        result = None

    _cache[cache_key] = result
    return result


def _fetch_current(lat: float, lon: float) -> dict | None:
    resp = requests.get(
        'https://api.openweathermap.org/data/2.5/weather',
        params={'lat': lat, 'lon': lon, 'appid': OPENWEATHER_API_KEY,
                'units': 'metric', 'lang': 'ja'},
        timeout=10,
    )
    resp.raise_for_status()
    d = resp.json()
    return {
        'description': d['weather'][0]['description'],
        'temp': round(d['main']['temp']),
        'humidity': d['main']['humidity'],
        'wind_speed': round(d['wind']['speed'], 1),
    }


def _fetch_forecast(lat: float, lon: float, day: str, time_str: str) -> dict | None:
    resp = requests.get(
        'https://api.openweathermap.org/data/2.5/forecast',
        params={'lat': lat, 'lon': lon, 'appid': OPENWEATHER_API_KEY,
                'units': 'metric', 'lang': 'ja'},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()

    # 3時間ごとの予報から最も近い時刻のエントリを選ぶ
    target = datetime.strptime(f"{day} {time_str}", '%Y%m%d %H:%M')
    best, best_diff = None, float('inf')
    for item in data.get('list', []):
        dt = datetime.fromtimestamp(item['dt'])
        diff = abs((dt - target).total_seconds())
        if diff < best_diff:
            best_diff = diff
            best = item

    # 3時間超過離れていたらデータなし
    if not best or best_diff > 10800:
        return None

    return {
        'description': best['weather'][0]['description'],
        'temp': round(best['main']['temp']),
        'humidity': best['main']['humidity'],
        'wind_speed': round(best['wind']['speed'], 1),
    }
