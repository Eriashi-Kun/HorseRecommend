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


def fetch_race_detail(race_id: str, day: str) -> dict | None:
    soup = _get(f'https://race.netkeiba.com/race/shutuba.html?race_id={race_id}')
    if not soup:
        return None

    # Venue fallback from race_id
    venue = VENUE_CODES.get(race_id[4:6], '不明')
    race_number = f'{int(race_id[10:12])}R'
    grade = 'open'

    # Page title is the most reliable source for venue and grade
    # e.g. "NHKマイルカップ(G1) 2026年5月10日 東京競馬場 出馬表"
    title_el = soup.find('title')
    if title_el:
        t = title_el.get_text()
        for v in ['札幌','函館','福島','新潟','中山','東京','中京','京都','阪神','小倉']:
            if v in t:
                venue = v
                break
        if 'G1' in t:
            grade = 'g1'
        elif 'G2' in t:
            grade = 'g2'
        elif 'G3' in t:
            grade = 'g3'

    # Grade from CSS class name — netkeiba uses image sprites so get_text() is empty
    # Icon_GradeType1=G1, Icon_GradeType2=G2, Icon_GradeType3=G3, Icon_GradeType5=Listed
    if grade == 'open':
        for el in soup.select('[class*="GradeType"]'):
            classes = ' '.join(el.get('class', []))
            if 'GradeType1' in classes:
                grade = 'g1'
            elif 'GradeType2' in classes:
                grade = 'g2'
            elif 'GradeType3' in classes:
                grade = 'g3'
            elif 'GradeType5' in classes:
                grade = 'listed'
            break

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

    return {
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
    for row in table.find_all('tr'):
        # 馬番: class名に "Umaban" を含むセル
        num_cell = next(
            (td for td in row.find_all('td')
             if any('Umaban' in c for c in td.get('class', []))),
            None
        )
        if not num_cell:
            continue
        try:
            horse_num = int(num_cell.get_text(strip=True))
        except ValueError:
            continue

        # 馬名: .HorseInfo セル
        name_cell = row.select_one('.HorseInfo')
        if not name_cell:
            continue
        name = name_cell.get_text(strip=True)
        if not name:
            continue

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

        horses.append({
            'number': horse_num,
            'name': name,
            'odds': odds,
            'running_style': None,
        })

    return horses


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
