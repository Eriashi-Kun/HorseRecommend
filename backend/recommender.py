from __future__ import annotations

import json
import logging
import re

from anthropic import Anthropic

logger = logging.getLogger(__name__)

client = Anthropic()  # reads ANTHROPIC_API_KEY from environment

# Server-side cache keyed by (day, venue, race_number, type) to minimise API costs
_cache: dict[tuple, dict] = {}

_TYPE_LABELS = {
    "safe":      ("固め",  "人気上位馬を堅実に狙う。オッズが低く安定感のある馬を最大3頭選んでください。"),
    "midRange":  ("中穴",  "オッズ5〜20倍の中穴ゾーンから配当妙味のある馬を最大3頭選んでください。"),
    "longShot":  ("爆穴",  "オッズ15倍以上の大穴馬を最大3頭選び、一発逆転シナリオを描いてください。"),
}


def recommend(race: dict, pred_type: str) -> dict:
    cache_key = (race["day"], race["venue"], race["race_number"], pred_type)
    if cache_key in _cache:
        logger.info(f"Recommendation cache hit: {cache_key}")
        return _cache[cache_key]

    result = _call_claude(race, pred_type)
    _cache[cache_key] = result
    return result


def _call_claude(race: dict, pred_type: str) -> dict:
    label, instruction = _TYPE_LABELS.get(pred_type, ("予想", "おすすめ馬を選んでください。"))

    horses_lines = "\n".join(
        f"  {h['number']}番 {h['name']}　オッズ {h['odds']}倍"
        for h in sorted(race["horses"], key=lambda x: x["number"])
    )

    prompt = f"""あなたは競馬予想の専門家です。以下のレース情報を分析し、「{label}」スタイルの予想をしてください。

【レース情報】
レース名: {race['name']}
競馬場: {race['venue']}　{race['distance']}　馬場: {race['condition']}

【出走馬】
{horses_lines}

【予想スタイル：{label}】
{instruction}

各推奨馬について、オッズ・馬場・距離を踏まえた具体的で読んで楽しい予想理由を1〜2文で書いてください。
体言止め禁止。ポジティブかつ核心をついた表現で。

必ず以下のJSON形式だけを返してください（他のテキスト不要）:
{{"picks": [{{"number": <馬番>, "score": <推奨度1-99>, "reason": "<理由>"}}]}}"""

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
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
