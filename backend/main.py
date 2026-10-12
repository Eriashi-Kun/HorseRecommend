from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from scraper import fetch_races_for_upcoming, _fetch_yoso_odds, fetch_race_result
from recommender import recommend, client as anthropic_client
from datetime import datetime, date
import asyncio
import threading
import time
import logging
import json
import re

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
    allow_methods=["GET", "POST"],
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


@app.get("/find_race")
def find_race(date: str, venue: str, race_number: str):
    """日付・場所・レース番号からrace_idを逆引きする"""
    from scraper import fetch_race_ids_for_date, fetch_race_ids_for_date_db, VENUE_NAME_TO_CODE
    venue_code = VENUE_NAME_TO_CODE.get(venue, '')
    if not venue_code:
        raise HTTPException(status_code=400, detail=f"Unknown venue: {venue}")
    try:
        race_num = int(re.sub(r'\D', '', race_number))
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid race number: {race_number}")

    for fetch_fn in [fetch_race_ids_for_date, fetch_race_ids_for_date_db]:
        race_ids = fetch_fn(date)
        for rid in race_ids:
            if rid[4:6] == venue_code and int(rid[10:12]) == race_num:
                return {"race_id": rid}

    raise HTTPException(status_code=404, detail="Race not found")


# MARK: - Ticket Parsing

class ParseTicketRequest(BaseModel):
    ocr_text: str

class ParseTicketVisionRequest(BaseModel):
    image_base64: str
    media_type: str = "image/jpeg"

_TICKET_JSON_SCHEMA = """\
以下のJSON形式で返してください（コードブロックや余計な説明は不要、JSONのみ）:
{
  "raceDate": "YYYYMMDD形式（例: 20260520）",
  "venue": "開催場所（例: 東京, 中山, 阪神）",
  "raceNumber": "NR形式（例: 9R）",
  "kaisaiRound": 開催回の数字（例: 「2回9日」なら2）,
  "kaisaiDay": 開催日の数字（例: 「2回9日」なら9）,
  "raceName": "レース名（不明な場合は空文字）",
  "betType": "単勝/複勝/枠連/馬連/馬単/ワイド/三連複/三連単 のいずれか",
  "betPattern": "通常/ながし/フォーメーション/ボックス のいずれか",
  "isMulti": マルチ（WHEEL）の場合true、それ以外false,
  "bets": [
    {"horses": [馬番リスト（整数）], "amount": 購入金額（整数）}
  ],
  "totalAmount": 合計金額（整数）
}"""

_TICKET_RULES = """\
ルール:
- 【betType判定（最重要・英語コード優先）】馬券左側の英語コードから以下の順で判定（部分一致禁止・完全一致のみ）:
  EXACTA → 馬単（2頭。絶対にワイドでも三連単でもない）
  TRIFECTA → 三連単（3頭、着順あり）
  TRIO → 三連複（3頭、着順なし）
  QUINELLA PLACE → ワイド（QUINELLAのみでなく必ずPLACEも続く場合のみ）
  QUINELLA → 馬連（QUINELLAのみ、PLACEが続かない場合）
  BRACKET QUINELLA → 枠連
  WIDE → ワイド
  WIN → 単勝
  PLACE → 複勝
  英語コードが読み取れない場合は中央縦書き漢字で確認。「馬単」「三連単」「馬連」「三連複」「単勝」「複勝」「ワイド」「枠連」
- 【betPatternの選択肢】必ず「通常」「ながし」「フォーメーション」「ボックス」の4択のみ。「マルチ」はbetPatternに絶対入れない
- 【ながしの判定】タイトル部に「ながし」「WHEEL」「軸○頭ながし」のいずれかが印字されていればbetPattern="ながし"
- 【isMultiの判定】以下のいずれかに該当すればisMulti=true（EXACTA/馬単・TRIFECTA/三連単のみ）: (1)馬券中央下部にカタカナ「マルチ」が黒い長方形・白文字で印字されている、(2)「組合せ数N×2」という×2付きの表記がある。TRIO/三連複・QUINELLA/馬連・WIDE/ワイド・枠連ではいかなる場合もisMulti=false
- 【馬番の絶対ルール】horsesは必ず1〜18の整数のみ。19以上は絶対に含めない
- 【金額整合性（最重要）】均等購入では len(bets) × amount = totalAmount が必ず成立すること
- 【組合せ数の検証】「組合せ数N」「組合せ数N×2」が印字されている場合、betsの総数がN（または N×2）になること
- 「ながし」（2頭券種: 馬連・馬単・ワイド・枠連）: 軸1頭+相手n頭 → n点。各betは[軸,相手]
- 「マルチ（isMulti=true）」: EXACTA/馬単・TRIFECTA/三連単のながしのみ。軸1頭+相手n頭 → 2n点（逆方向も追加）
- 「ながし」（3頭券種: TRIO/三連複・TRIFECTA/三連単）: 軸1頭+相手n頭 → C(n,2)点。各betは[軸,相手A,相手B]
- 「ボックス」: 指定馬番の全組み合わせをbetsに列挙
- 「フォーメーション」: 指定の組み合わせを全てbetsに列挙
- totalAmountは馬券に印字された合計金額をそのまま使用
- betsのamountは1点あたりの金額"""

_PARSE_TICKET_VISION_PROMPT = """この画像はJRA（日本中央競馬会）の馬券（投票票）です。画像から馬券情報を読み取り、構造化JSONに変換してください。

【画像の読み方】
- 【券種の特定】馬券左端に縦書きされた英語コードを読む: EXACTA=馬単, TRIFECTA=三連単, TRIO=三連複, QUINELLA PLACE=ワイド, QUINELLA=馬連, WIN=単勝, PLACE=複勝。英語が不明なら中央の大きな漢字で確認
- 【レース日付（最重要）】raceDateは必ず馬券の左下隅の「JRA ○○ / ○月○○日」から取得。年は上部「2026年」から。月・日は左下のみ。例:「5月23日」→ 月=5, 日=23 → raceDate="20260523"。日付は1〜2桁: 「23日」は2桁(23)、「5日」は1桁(5)。絶対に途中で切り捨てない（「5月23日」を「5月2日」にしない）。上部の「2026年2回9日」は開催回・日であり絶対にraceDateに使わない
- 【開催回・開催日】上部の「○○○○年○回○日」から kaisaiRound（回の数字）と kaisaiDay（日の数字）を読む
- 馬番は長方形の枠（ボックス）の中に印字されている。「（軸）」欄の枠内が軸馬番、「（相手）」欄の枠内が相手馬番
- 相手馬番は枠内にハイフン区切りで複数印字されている（例: 2-12-18 → 馬番2, 12, 18の3頭）
- ☆マーク・星マークは空欄（購入対象外）なので無視する
- 馬券下部のバーコード・QRコード・長い数字列（管理番号）は馬番ではない。絶対に馬番として読まないこと
- 「組合せ数N×2」「各○円」「合計○円」から点数・金額を確認する

""" + _TICKET_JSON_SCHEMA + "\n\n" + _TICKET_RULES


def _build_race_id(result: dict) -> str:
    from scraper import VENUE_NAME_TO_CODE
    race_date = result.get('raceDate', '')
    venue_code = VENUE_NAME_TO_CODE.get(result.get('venue', ''), '')
    race_num_str = re.sub(r'\D', '', result.get('raceNumber', ''))
    kaisai_round = result.get('kaisaiRound', 0)
    kaisai_day = result.get('kaisaiDay', 0)
    if race_date and venue_code and race_num_str and kaisai_round and kaisai_day:
        year = race_date[:4]
        return f"{year}{venue_code}{int(kaisai_round):02d}{int(kaisai_day):02d}{int(race_num_str):02d}"
    return ''


def _parse_ticket_response(text: str) -> dict:
    m = re.search(r'\{.*\}', text, re.DOTALL)
    if not m:
        raise ValueError("No JSON in response")
    result = json.loads(m.group())
    # 馬番1-18フィルタ（モデルがルールを守れなかった場合の保険）
    for bet in result.get('bets', []):
        bet['horses'] = [h for h in bet['horses'] if 1 <= int(h) <= 18]
    result['bets'] = [b for b in result['bets'] if b['horses']]
    result['raceId'] = _build_race_id(result)
    # OCRの日付誤読をキャッシュで補正（kaisaiRound/kaisaiDayは正確に読めているので race_id は正しい）
    if result['raceId'] and _cache.get('races'):
        for race in _cache['races']:
            if race.get('race_id') == result['raceId']:
                result['raceDate'] = race.get('day', result.get('raceDate', ''))
                break
    return result


@app.post("/parse_ticket_vision")
def parse_ticket_vision(body: ParseTicketVisionRequest):
    try:
        response = anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            messages=[{
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": body.media_type,
                            "data": body.image_base64,
                        },
                    },
                    {"type": "text", "text": _PARSE_TICKET_VISION_PROMPT},
                ],
            }],
        )
        result = _parse_ticket_response(response.content[0].text.strip())
        logger.info(f"parse_ticket_vision: {result.get('venue')} {result.get('raceNumber')} {result.get('betType')} {len(result.get('bets', []))}点")
        return result
    except Exception as e:
        logger.error(f"parse_ticket_vision failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/parse_ticket")
def parse_ticket(body: ParseTicketRequest):
    try:
        prompt = f"以下は競馬の馬券OCRテキストです。\n\nOCRテキスト:\n{body.ocr_text}\n\n" + _TICKET_JSON_SCHEMA + "\n\n" + _TICKET_RULES
        response = anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )
        result = _parse_ticket_response(response.content[0].text.strip())
        return result
    except Exception as e:
        logger.error(f"parse_ticket failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class ParseResultHtmlRequest(BaseModel):
    html_base64: str  # EUC-JPバイト列をbase64エンコードしたもの

@app.post("/parse_result_html")
def parse_result_html(body: ParseResultHtmlRequest):
    """iOSが直接取得したnetkeibaのHTML（EUC-JP）をパースして結果・払戻を返す"""
    import base64
    from scraper import _parse_result_soup
    try:
        html_bytes = base64.b64decode(body.html_base64)
        html = html_bytes.decode('EUC-JP', errors='replace')
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        result = _parse_result_soup(soup)
        if not result:
            return {'results': [], 'payouts': {}}
        return result
    except Exception as e:
        logger.error(f"parse_result_html failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/debug/netkeiba/{race_id}")
def debug_netkeiba(race_id: str):
    """Fly.io から netkeiba へのアクセス診断"""
    import requests
    from scraper import HEADERS
    try:
        url = f'https://race.netkeiba.com/race/result.html?race_id={race_id}'
        resp = requests.get(url, headers=HEADERS, timeout=25)
        content = resp.content
        return {
            "status_code": resp.status_code,
            "content_length": len(content),
            "has_race_table": b'RaceTable01' in content,
            "has_payout_table": b'Payout_Detail_Table' in content,
            "payout_table_count": content.count(b'Payout_Detail_Table'),
            "url": url,
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "cached_races": len(_cache["races"]) if _cache["races"] else 0,
        "updated_at": _cache["updated_at"].isoformat() if _cache["updated_at"] else None,
    }
