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
            attrs.append(f"{h['jockey']}騎手")
        attrs.append(f"オッズ{h['odds']}倍")
        return "".join(parts) + "　" + "　".join(attrs)

    horses_lines = "\n".join(
        _horse_line(h)
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

各推奨馬について、以下の観点を含む具体的な予想理由を3〜4文で書いてください：
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
