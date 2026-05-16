from __future__ import annotations

import json
import logging
import re
import time
from concurrent.futures import ThreadPoolExecutor

from anthropic import Anthropic
from scraper import fetch_horse_past_results, fetch_jockey_stats

logger = logging.getLogger(__name__)

client = Anthropic()  # reads ANTHROPIC_API_KEY from environment

# Server-side cache keyed by (day, venue, race_number, type) to minimise API costs
_cache: dict[tuple, dict] = {}
_cache_time: dict[tuple, float] = {}
RECOMMEND_CACHE_TTL = 600  # 10分でキャッシュ無効化（オッズ変動に追従）

# 馬ごとの過去成績キャッシュ（horse_id → list[dict]）
_horse_results_cache: dict[str, list] = {}

# 騎手成績キャッシュ（jockey_id → dict）
_jockey_stats_cache: dict[str, dict] = {}


def _get_past_results(horses: list[dict]) -> dict[str, list]:
    """全馬の過去3走を並列取得（キャッシュ済みは再利用）"""
    uncached = [h for h in horses if h.get('horse_id') and h['horse_id'] not in _horse_results_cache]

    def _fetch(h):
        hid = h['horse_id']
        _horse_results_cache[hid] = fetch_horse_past_results(hid, n=3)

    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(_fetch, uncached))

    return {h['horse_id']: _horse_results_cache[h['horse_id']]
            for h in horses if h.get('horse_id') and h['horse_id'] in _horse_results_cache}


def _get_jockey_stats(horses: list[dict]) -> dict[str, dict]:
    """全馬の騎手成績を並列取得（キャッシュ済みは再利用）"""
    uncached = [h for h in horses if h.get('jockey_id') and h['jockey_id'] not in _jockey_stats_cache]

    def _fetch(h):
        jid = h['jockey_id']
        _jockey_stats_cache[jid] = fetch_jockey_stats(jid)

    with ThreadPoolExecutor(max_workers=8) as ex:
        list(ex.map(_fetch, uncached))

    return {h['jockey_id']: _jockey_stats_cache[h['jockey_id']]
            for h in horses if h.get('jockey_id') and h['jockey_id'] in _jockey_stats_cache}

_TYPE_LABELS = {
    "safe":      ("固め",  "オッズ10倍以下の人気上位馬を堅実に狙う。安定感のある馬を最大3頭選んでください。"),
    "midRange":  ("中穴",  "オッズ10〜50倍の中穴ゾーンから配当妙味のある馬を最大3頭選んでください。"),
    "longShot":  ("爆穴",  "オッズ50倍以上の大穴馬を最大3頭選び、一発逆転シナリオを描いてください。"),
}


def prefetch_race_data(races: list[dict]) -> None:
    """全レースの馬過去成績・騎手成績をバックグラウンドでプリフェッチする"""
    all_horses = [h for race in races for h in race.get('horses', [])]
    logger.info(f"Prefetching data for {len(all_horses)} horses across {len(races)} races")
    _get_past_results(all_horses)
    _get_jockey_stats(all_horses)
    logger.info(f"Prefetch done: {len(_horse_results_cache)} horse results, {len(_jockey_stats_cache)} jockey stats cached")


def _filter_horses_by_type(horses: list[dict], pred_type: str) -> list[dict]:
    """予想タイプに応じてオッズでフィルタリング。対象馬が少なければ近い範囲にフォールバック"""
    if pred_type == "safe":
        filtered = [h for h in horses if h['odds'] <= 10.0]
        if len(filtered) >= 2:
            return filtered
        return sorted(horses, key=lambda h: h['odds'])[:6]
    elif pred_type == "midRange":
        filtered = [h for h in horses if 10.0 < h['odds'] <= 50.0]
        if len(filtered) >= 2:
            return filtered
        return sorted(horses, key=lambda h: abs(h['odds'] - 25))[:6]
    elif pred_type == "longShot":
        filtered = [h for h in horses if h['odds'] > 50.0]
        if len(filtered) >= 2:
            return filtered
        return sorted(horses, key=lambda h: -h['odds'])[:6]
    return horses


def recommend(race: dict, pred_type: str, weights: dict = None) -> dict:
    # 全パラメータがデフォルト値の場合のみキャッシュを使用
    is_default = (not weights or (
        weights.get('jockey', 50) == 50.0 and
        weights.get('history', 50) == 50.0 and
        weights.get('popularity', 50) == 50.0 and
        weights.get('cuteness', 0) == 0.0 and
        weights.get('intuition', 0) == 0.0
    ))
    if is_default:
        cache_key = (race["day"], race["venue"], race["race_number"], pred_type)
        cached_at = _cache_time.get(cache_key, 0)
        if cache_key in _cache and time.time() - cached_at < RECOMMEND_CACHE_TTL:
            logger.info(f"Recommendation cache hit: {cache_key}")
            return _cache[cache_key]
        result = _call_claude(race, pred_type, weights or {})
        _cache[cache_key] = result
        _cache_time[cache_key] = time.time()
        return result

    return _call_claude(race, pred_type, weights)


def _weight_instruction(weights: dict) -> str:
    """重みに応じたプロンプト指示文を生成する"""
    if not weights:
        return ''

    lines = []
    jockey_w = weights.get('jockey', 50)
    history_w = weights.get('history', 50)
    popularity_w = weights.get('popularity', 50)

    if jockey_w == 0:
        lines.append('・騎手の実力は無視してください')
    elif jockey_w >= 80:
        lines.append(f'・騎手の実力・勝率を特に重視してください（重視度{int(jockey_w)}/100）')
    elif jockey_w >= 60:
        lines.append(f'・騎手の実力を重視してください（重視度{int(jockey_w)}/100）')

    if history_w == 0:
        lines.append('・過去成績は無視してください')
    elif history_w >= 80:
        lines.append(f'・前走・過去成績を特に重視してください（重視度{int(history_w)}/100）')
    elif history_w >= 60:
        lines.append(f'・過去成績を重視してください（重視度{int(history_w)}/100）')

    if popularity_w == 0:
        lines.append('・人気・オッズは無視してください')
    elif popularity_w <= 20:
        lines.append(f'・人気・オッズはほぼ考慮しないでください（重視度{int(popularity_w)}/100）')
    elif popularity_w >= 80:
        lines.append(f'・人気・オッズを特に重視してください（重視度{int(popularity_w)}/100）')

    cuteness_w = weights.get('cuteness', 0)
    if cuteness_w >= 60:
        lines.append(f'・馬名の響き・可愛さ・ユニークさを重視してください（重視度{int(cuteness_w)}/100）')
    elif cuteness_w >= 30:
        lines.append(f'・馬名の印象も少し考慮してください（重視度{int(cuteness_w)}/100）')

    intuition_w = weights.get('intuition', 0)
    if intuition_w >= 60:
        lines.append(f'・データに表れない直感的な穴馬を1頭加えてください（重視度{int(intuition_w)}/100）')
    elif intuition_w >= 30:
        lines.append(f'・意外性のある馬も少し考慮してください（重視度{int(intuition_w)}/100）')

    if not lines:
        return ''
    return '\n【ユーザー設定の重視度】\n' + '\n'.join(lines)


def _call_claude(race: dict, pred_type: str, weights: dict) -> dict:
    label, instruction = _TYPE_LABELS.get(pred_type, ("予想", "おすすめ馬を選んでください。"))

    target_horses = _filter_horses_by_type(race["horses"], pred_type)
    past_map = _get_past_results(target_horses)
    jockey_map = _get_jockey_stats(target_horses)

    def _horse_line(h: dict) -> str:
        parts = [f"  {h['number']}番"]
        if h.get('gate'):
            parts.append(f"[枠{h['gate']}]")
        parts.append(f" {h['name']}")
        attrs = []
        if h.get('sex') and h.get('age'):
            attrs.append(f"{h['sex']}{h['age']}歳")
        if h.get('weight'):
            attrs.append(f"斤量{h['weight']}kg")
        if h.get('jockey'):
            jockey_str = f"{h['jockey']}騎手"
            jstats = jockey_map.get(h.get('jockey_id', ''), {})
            if jstats.get('win_rate'):
                jockey_str += f"(勝率{jstats['win_rate']} 複勝率{jstats.get('place_rate','')})"
            attrs.append(jockey_str)
        attrs.append(f"オッズ{h['odds']}倍")

        past = past_map.get(h.get('horse_id', ''), [])
        if past:
            past_str = '→'.join(
                f"{r['finish']}着({r.get('distance','')}{r.get('condition','')} {r.get('popularity','')}人気)"
                for r in past
            )
            attrs.append(f"前3走[{past_str}]")

        return "".join(parts) + "　" + "　".join(attrs)

    horses_lines = "\n".join(
        _horse_line(h)
        for h in sorted(target_horses, key=lambda x: x["number"])
    )

    weight_section = _weight_instruction(weights)

    prompt = f"""あなたは競馬予想の専門家です。以下のレース情報を分析し、「{label}」スタイルの予想をしてください。

【レース情報】
レース名: {race['name']}
競馬場: {race['venue']}　{race['distance']}　馬場: {race['condition']}

【出走馬】
{horses_lines}

【予想スタイル：{label}】
{instruction}{weight_section}

各推奨馬について、以下の観点を含む具体的な予想理由を4〜5文で書いてください：
- この馬が今日の条件（距離・馬場・コース形態）に向いている理由
- オッズと人気面での信頼度や妙味の評価
- このレースでの具体的な期待シナリオ

体言止め禁止。数字を使った根拠を含め、読んで楽しく納得感のある文章で。

必ず以下のJSON形式だけを返してください（他のテキスト不要）:
{{"picks": [{{"number": <馬番>, "score": <推奨度1-99>, "reason": "<理由>"}}]}}"""

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        temperature=0,
        messages=[{"role": "user", "content": prompt}],
    )

    text = message.content[0].text
    logger.info(f"Claude raw response: {text[:200]}")

    m = re.search(r'\{.*\}', text, re.DOTALL)
    if not m:
        raise ValueError(f"Could not parse JSON from Claude response: {text}")

    data = json.loads(m.group())
    horse_map = {h["number"]: h for h in race["horses"]}

    picks = []
    for pick in data.get("picks", []):
        h = horse_map.get(pick["number"])
        if h:
            picks.append({
                "number": h["number"],
                "name": h["name"],
                "odds": h["odds"],
                "score": pick["score"],
                "reason": pick["reason"],
            })

    return {"picks": picks}
