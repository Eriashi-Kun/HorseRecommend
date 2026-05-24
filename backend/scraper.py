from __future__ import annotations

import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import re
import time
import logging

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

# コース統計キャッシュ（24時間TTL）
_course_stats_cache: dict[str, dict] = {}
_course_stats_time: dict[str, float] = {}
COURSE_STATS_TTL = 86400


def get_candidate_dates() -> list[str]:
    """今日から14日間の日付リストを返す（YYYYMMDD形式）"""
    today = datetime.now()
    return [(today + timedelta(days=i)).strftime('%Y%m%d') for i in range(14)]


def _get(url: str, encoding: str = 'EUC-JP') -> BeautifulSoup | None:
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        text = resp.content.decode(encoding, errors='replace')
        return BeautifulSoup(text, 'lxml')
    except Exception as e:
        logger.error(f"GET {url} failed: {e}")
        return None


def _valid_race_id(rid: str, year: str) -> bool:
    return (
        rid[:4] == year
        and rid[4:6] in VENUE_CODES
        and '01' <= rid[10:12] <= '12'
    )


def fetch_race_ids_for_date(date_str: str) -> list[str]:
    soup = _get(f'https://race.netkeiba.com/top/race_list_sub.html?kaisai_date={date_str}')
    if not soup:
        return []

    year = date_str[:4]
    text = str(soup)
    seen, ids = set(), []
    for m in re.finditer(r'\b(\d{12})\b', text):
        rid = m.group(1)
        if rid not in seen and _valid_race_id(rid, year):
            seen.add(rid)
            ids.append(rid)
    return ids


def _fetch_yoso_odds(race_id: str) -> dict:
    """予想オッズAPIから馬番→オッズのマップを取得する"""
    try:
        url = f'https://race.netkeiba.com/api/api_get_jra_odds.html?race_id={race_id}&type=1&action=init'
        resp = requests.get(url, headers=HEADERS, timeout=10)
        data = resp.json()
        odds_raw = data.get('data', {}).get('odds', {}).get('1', {})
        return {str(int(k)): float(v[0]) for k, v in odds_raw.items() if v and v[0] and v[0] != '---.-'}
    except Exception:
        return {}


def fetch_race_detail(race_id: str, day: str) -> dict | None:
    soup = _get(f'https://race.netkeiba.com/race/shutuba.html?race_id={race_id}')
    if not soup:
        return None

    # Venue fallback from race_id
    venue = VENUE_CODES.get(race_id[4:6], '不明')
    race_number = f'{int(race_id[10:12])}R'
    grade = 'open'

    # Venue from page title (reliable: includes venue name like "東京競馬場")
    title_el = soup.find('title')
    if title_el:
        t = title_el.get_text()
        for v in ['札幌','函館','福島','新潟','中山','東京','中京','京都','阪神','小倉']:
            if v in t:
                venue = v
                break

    # Grade from specific CSS class name (netkeiba uses image sprites, not text)
    # Do NOT use page title — it contains "G1・G2・G3" site-wide in navigation text
    # Icon_GradeType1=G1, Icon_GradeType2=G2, Icon_GradeType3=G3, Icon_GradeType5=Listed
    if soup.select_one('.Icon_GradeType1'):
        grade = 'g1'
    elif soup.select_one('.Icon_GradeType2'):
        grade = 'g2'
    elif soup.select_one('.Icon_GradeType3'):
        grade = 'g3'

    # Race name
    race_name = ''
    for sel in ['.RaceName', '.race_name', 'h1']:
        el = soup.select_one(sel)
        if el and el.get_text(strip=True):
            race_name = el.get_text(strip=True)
            break

    # Distance, condition, start time
    distance, condition, start_time = '', '良', ''
    for sel in ['.RaceData01', '.race_data01', '.RaceData']:
        el = soup.select_one(sel)
        if el:
            text = el.get_text()
            m = re.search(r'[芝ダ障]\d+m', text)
            if m:
                distance = m.group()
            for cond in ['不良', '稍重', '重', '良']:
                if cond in text:
                    condition = cond
                    break
            m = re.search(r'(\d{1,2}:\d{2})', text)
            if m:
                start_time = m.group(1)
            break

    horses = _parse_horses(soup)

    if not race_name or not horses:
        logger.warning(f"Skipping {race_id}: missing name or horses")
        return None

    # 予想オッズをAPIから取得して上書き
    odds_map = _fetch_yoso_odds(race_id)
    if odds_map:
        for h in horses:
            key = str(h['number'])
            if key in odds_map:
                h['odds'] = odds_map[key]

    return {
        'race_id': race_id,
        'day': day,
        'venue': venue,
        'race_number': race_number,
        'name': race_name,
        'grade': grade,
        'distance': distance,
        'condition': condition,
        'time': start_time,
        'horses': horses,
    }


def _parse_horses(soup: BeautifulSoup) -> list[dict]:
    table = soup.select_one('.Shutuba_Table')
    if not table:
        return []

    horses = []
    horse_num = 0
    for row in table.find_all('tr'):
        # tr_N id を持つ行のみ馬行として扱う（ヘッダー行を除外）
        row_id = row.get('id', '')
        if not re.match(r'tr_\d+', row_id):
            continue

        # 馬名: .HorseInfo セル
        name_cell = row.select_one('.HorseInfo')
        if not name_cell:
            continue
        name = name_cell.get_text(strip=True)
        if not name:
            continue

        # 馬番: tr_N のN値は馬番に対応しないため、テーブル行順で1から採番
        horse_num += 1

        # オッズ: .Txt_R.Popular セル（レース前は数値、過去は "---.-"）
        odds = 99.9
        odds_cell = row.select_one('td.Txt_R.Popular')
        if odds_cell:
            try:
                val = float(odds_cell.get_text(strip=True))
                if 1.0 <= val <= 9999.9:
                    odds = val
            except ValueError:
                pass

        # 枠番: Waku + WakuN クラスを持つ td (N=1〜8)
        gate = 0
        gate_cell = next(
            (td for td in row.find_all('td')
             if any(c.startswith('Waku') and c != 'Waku' for c in td.get('class', []))),
            None
        )
        if gate_cell:
            try:
                gate = int(gate_cell.get_text(strip=True))
            except ValueError:
                pass

        # 性齢: Barei クラスのセル (例: "牡3", "牝4", "セ5")
        sex, age = '', 0
        barei_cell = row.select_one('td.Barei')
        if barei_cell:
            t = barei_cell.get_text(strip=True)
            if t:
                sex = t[0] if t[0] in '牡牝セ' else ''
                m = re.search(r'\d+', t)
                if m:
                    try:
                        age = int(m.group())
                    except ValueError:
                        pass

        # 斤量: Kinryo クラスのセル (例: "57.0")
        weight = 0.0
        kinryo_cell = row.select_one('td.Kinryo') or row.select_one('td.Txt_C.Kinryo')
        if kinryo_cell:
            try:
                weight = float(kinryo_cell.get_text(strip=True))
            except ValueError:
                pass

        # 騎手: Jockey クラスのセル（名前 + jockey_id）
        jockey = ''
        jockey_id = ''
        jockey_cell = row.select_one('td.Jockey')
        if jockey_cell:
            jockey = jockey_cell.get_text(strip=True)
            a_tag = jockey_cell.select_one('a[href]')
            if a_tag:
                m = re.search(r'/jockey/(\w+)', a_tag.get('href', ''))
                if m:
                    jockey_id = m.group(1)

        # 馬ID: HorseInfo の <a href> から抽出（過去成績取得に使用）
        horse_id = ''
        a_tag = name_cell.select_one('a[href]')
        if a_tag:
            m = re.search(r'/horse/(\w+)', a_tag.get('href', ''))
            if m:
                horse_id = m.group(1)

        horses.append({
            'number': horse_num,
            'name': name,
            'odds': odds,
            'running_style': None,
            'gate': gate,
            'sex': sex,
            'age': age,
            'jockey': jockey,
            'jockey_id': jockey_id,
            'weight': weight,
            'horse_id': horse_id,
        })

    return horses


def fetch_horse_past_results(horse_id: str, n: int = 3) -> list[dict]:
    """db.netkeiba.com の馬ページから直近n走の成績を取得する"""
    if not horse_id:
        return []
    soup = _get(f'https://db.netkeiba.com/horse/{horse_id}/', encoding='EUC-JP')
    if not soup:
        return []

    table = soup.select_one('table.db_h_race_results')
    if not table:
        return []

    # ヘッダー行からカラム名→インデックスのマップを作成
    header_row = table.find('tr')
    if not header_row:
        return []
    headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
    col = {h: i for i, h in enumerate(headers)}

    results = []
    for row in table.find_all('tr')[1:n + 1]:
        tds = row.find_all('td')
        if not tds:
            continue

        def _cell(name: str, default: str = '') -> str:
            idx = col.get(name, -1)
            return tds[idx].get_text(strip=True) if 0 <= idx < len(tds) else default

        finish = _cell('着順')
        if not finish:
            continue
        results.append({
            'finish': finish,
            'race_name': _cell('レース名'),
            'distance': _cell('距離'),
            'condition': _cell('馬場'),
            'popularity': _cell('人気'),
            'venue': _cell('開催'),
        })

    return results


def fetch_jockey_stats(jockey_id: str) -> dict:
    """db.netkeiba.com の騎手ページから当年の勝率・複勝率を取得する"""
    if not jockey_id:
        return {}
    soup = _get(f'https://db.netkeiba.com/jockey/result/recent/{jockey_id}/', encoding='EUC-JP')
    if not soup:
        return {}

    table = soup.select_one('table.nk_tb_common')
    if not table:
        return {}

    header_row = table.find('tr')
    if not header_row:
        return {}
    headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
    col = {h: i for i, h in enumerate(headers)}

    # 最新年のデータ行（2行目）を使用
    rows = table.find_all('tr')[1:]
    for row in rows:
        tds = row.find_all('td')
        if not tds:
            continue

        def _val(name: str) -> str:
            idx = col.get(name, -1)
            return tds[idx].get_text(strip=True) if 0 <= idx < len(tds) else ''

        win_rate = _val('勝率')
        place_rate = _val('複勝率')
        wins = _val('1着')
        if win_rate or wins:
            return {
                'win_rate': win_rate,
                'place_rate': place_rate,
                'wins': wins,
            }

    return {}


_result_cache: dict[str, dict] = {}


def fetch_race_result(race_id: str) -> dict:
    """レース結果ページから着順を取得する（結果確定後は永続キャッシュ）"""
    if race_id in _result_cache:
        return _result_cache[race_id]

    soup = _get(f'https://race.netkeiba.com/race/result.html?race_id={race_id}')
    if not soup:
        return {'results': []}

    table = None
    for sel in ['table.RaceTable01', '.Result_Table', '.RaceTable', 'table.race_table_01']:
        table = soup.select_one(sel)
        if table:
            break
    if not table:
        return {'results': []}

    # ヘッダー行からカラム名→インデックスのマップを作成
    header_row = table.find('tr')
    if not header_row:
        return {'results': []}
    headers = [th.get_text(strip=True) for th in header_row.find_all(['th', 'td'])]
    col = {h: i for i, h in enumerate(headers)}

    finish_idx = col.get('着順', 0)
    number_idx = col.get('馬番', col.get('馬 番', 2))

    results = []
    for row in table.find_all('tr')[1:]:
        tds = row.find_all('td')
        if not tds:
            continue
        try:
            finish_text = tds[finish_idx].get_text(strip=True) if finish_idx < len(tds) else ''
            number_text = tds[number_idx].get_text(strip=True) if number_idx < len(tds) else ''
            finish = int(finish_text)
            number = int(number_text)
            results.append({'number': number, 'finish': finish})
        except (ValueError, IndexError):
            continue

    result = {'results': results}
    if results:
        _result_cache[race_id] = result
    return result


# ──────────────────────────────────────────────────────────────────
# コース統計（過去レース結果から枠順別・脚質別の実績を集計）
# ──────────────────────────────────────────────────────────────────

def _search_race_ids_for_course(venue_code: str, track_type: str, dist: int, n: int = 50) -> list[str]:
    """db.netkeiba の検索から特定コース・距離の過去 race_id を取得"""
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
    """結果ページから 枠番・着順・1角通過順 を取得"""
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

        # 通過順位（コーナー）: "1角" or "通過" 列から1番目の数字を取る
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
    特定コース・距離の過去レース結果を集計して枠順別・脚質別の統計を返す。
    distance_str 例: "芝1400m", "ダ1600m"
    結果は24時間キャッシュ。
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


def fetch_races_for_upcoming() -> list[dict]:
    """今日から14日間で実際にレースが開催される日のレースをすべて取得する"""
    all_races = []
    for date_str in get_candidate_dates():
        race_ids = fetch_race_ids_for_date(date_str)
        if not race_ids:
            continue
        logger.info(f"  → {date_str}: {len(race_ids)} races found")
        for race_id in race_ids:
            race = fetch_race_detail(race_id, date_str)
            if race:
                all_races.append(race)
            time.sleep(0.8)
    return all_races
