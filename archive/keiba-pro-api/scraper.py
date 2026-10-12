from __future__ import annotations

import re
import time
import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime

logger = logging.getLogger(__name__)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
    'Referer': 'https://race.netkeiba.com/',
}

VENUE_CODES = {
    '01': '札幌', '02': '函館', '03': '福島', '04': '新潟',
    '05': '中山', '06': '東京', '07': '中京', '08': '京都',
    '09': '阪神', '10': '小倉',
}
VENUE_NAME_TO_CODE = {v: k for k, v in VENUE_CODES.items()}
TRACK_TYPE_MAP = {'芝': 'A', 'ダ': 'B', '障': 'C'}

_course_stats_cache: dict[str, dict] = {}
_course_stats_time: dict[str, float] = {}
COURSE_STATS_TTL = 86400


def _get(url: str, encoding: str = 'EUC-JP') -> BeautifulSoup | None:
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        text = resp.content.decode(encoding, errors='replace')
        return BeautifulSoup(text, 'lxml')
    except Exception as e:
        logger.error(f"GET {url} failed: {e}")
        return None


def _search_race_ids_for_course(venue_code: str, track_type: str, dist: int, n: int = 50) -> list[str]:
    year = datetime.now().year
    url = (
        f"https://db.netkeiba.com/race/?pid=race_search_detail"
        f"&track[]={venue_code}"
        f"&type[]={track_type}"
        f"&distance_min={dist}&distance_max={dist}"
        f"&start_year={year - 10}&end_year={year}"
        f"&list=100&sort=date&order=desc"
    )
    soup = _get(url)
    if not soup:
        return []

    seen, ids = set(), []
    for m in re.finditer(r'\b(\d{12})\b', str(soup)):
        rid = m.group(1)
        if rid not in seen and rid[4:6] in VENUE_CODES:
            seen.add(rid)
            ids.append(rid)
        if len(ids) >= n:
            break
    return ids


def _fetch_result_for_stats(race_id: str) -> list[dict]:
    soup = _get(f'https://race.netkeiba.com/race/result.html?race_id={race_id}')
    if not soup:
        return []

    table = None
    for sel in ['.Result_Table', 'table.race_table_01']:
        table = soup.select_one(sel)
        if table:
            break
    if not table:
        return []

    header_row = table.find('tr')
    if not header_row:
        return []
    headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
    col = {h: i for i, h in enumerate(headers)}

    rows = []
    for row in table.find_all('tr')[1:]:
        tds = row.find_all('td')
        if not tds:
            continue

        def cell(name: str) -> str:
            idx = col.get(name, -1)
            return tds[idx].get_text(strip=True) if 0 <= idx < len(tds) else ''

        try:
            finish = int(cell('着順'))
            gate = int(cell('枠番'))
        except ValueError:
            continue

        corner_raw = cell('1角') or cell('通過') or cell('コーナー通過順')
        c1 = 0
        if corner_raw:
            m = re.match(r'\d+', corner_raw.strip())
            if m:
                try:
                    c1 = int(m.group())
                except ValueError:
                    pass

        rows.append({'finish': finish, 'gate': gate, 'corner1': c1})

    return rows


def _running_style(corner1: int, head_count: int) -> str:
    if head_count == 0 or corner1 == 0:
        return ''
    r = corner1 / head_count
    if r <= 0.12:
        return '逃げ'
    if r <= 0.35:
        return '先行'
    if r <= 0.65:
        return '差し'
    return '追込'


def fetch_course_stats(venue: str, distance_str: str) -> dict:
    """
    venue: 例 "東京"
    distance_str: 例 "芝2000m", "ダ1600m"
    """
    cache_key = f"{venue}_{distance_str}"
    if cache_key in _course_stats_cache:
        if time.time() - _course_stats_time.get(cache_key, 0) < COURSE_STATS_TTL:
            logger.info(f"Course stats cache hit: {cache_key}")
            return _course_stats_cache[cache_key]

    venue_code = VENUE_NAME_TO_CODE.get(venue, '')
    if not venue_code:
        return {'error': f'Unknown venue: {venue}'}

    track_char = distance_str[0]
    track_type = TRACK_TYPE_MAP.get(track_char, 'A')
    m = re.search(r'\d+', distance_str)
    if not m:
        return {'error': f'Invalid distance: {distance_str}'}
    dist = int(m.group())

    logger.info(f"Fetching course stats: {venue} {distance_str}")
    race_ids = _search_race_ids_for_course(venue_code, track_type, dist, n=50)
    if not race_ids:
        return {'error': 'No races found', 'venue': venue, 'distance': distance_str, 'sample_races': 0}

    gate_stats: dict[str, dict] = {str(g): {'wins': 0, 'places': 0, 'total': 0} for g in range(1, 9)}
    style_stats: dict[str, dict] = {s: {'wins': 0, 'places': 0, 'total': 0}
                                     for s in ['逃げ', '先行', '差し', '追込']}
    sample_races = 0

    for race_id in race_ids[:40]:
        time.sleep(0.4)
        rows = _fetch_result_for_stats(race_id)
        if not rows:
            continue
        sample_races += 1
        n_horses = len(rows)

        for r in rows:
            gk = str(r['gate'])
            if gk in gate_stats:
                gate_stats[gk]['total'] += 1
                if r['finish'] == 1:
                    gate_stats[gk]['wins'] += 1
                if r['finish'] <= 3:
                    gate_stats[gk]['places'] += 1

            style = _running_style(r['corner1'], n_horses)
            if style and style in style_stats:
                style_stats[style]['total'] += 1
                if r['finish'] == 1:
                    style_stats[style]['wins'] += 1
                if r['finish'] <= 3:
                    style_stats[style]['places'] += 1

    for stats in [gate_stats, style_stats]:
        for v in stats.values():
            t = v['total']
            v['win_rate'] = round(v['wins'] / t, 3) if t else 0.0
            v['place_rate'] = round(v['places'] / t, 3) if t else 0.0

    result = {
        'venue': venue,
        'distance': distance_str,
        'sample_races': sample_races,
        'gate_stats': gate_stats,
        'running_style_stats': style_stats,
    }
    _course_stats_cache[cache_key] = result
    _course_stats_time[cache_key] = time.time()
    logger.info(f"Course stats computed: {venue} {distance_str} ({sample_races} races)")
    return result
