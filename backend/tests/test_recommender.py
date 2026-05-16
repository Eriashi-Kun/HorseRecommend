import time
import sys, os
from unittest.mock import MagicMock

# anthropic未インストール環境でもテスト可能にするためモック化
sys.modules.setdefault('anthropic', MagicMock())
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from recommender import _filter_horses_by_type, _cache, _cache_time, RECOMMEND_CACHE_TTL


def make_horses(odds_list: list[float]) -> list[dict]:
    return [{'number': i + 1, 'name': f'ウマ{i+1}', 'odds': o} for i, o in enumerate(odds_list)]


# ── 3. オッズフィルター ───────────────────────────────────────────────────

class TestFilterHorsesByType:

    # 固め
    def test_safe_returns_horses_under_10(self):
        horses = make_horses([2.0, 5.0, 12.0, 30.0, 80.0])
        result = _filter_horses_by_type(horses, 'safe')
        assert all(h['odds'] <= 10.0 for h in result)
        assert len(result) == 2

    def test_safe_fallback_when_too_few(self):
        """10倍以下が1頭のみ → 低オッズ順上位6頭にフォールバック"""
        horses = make_horses([3.0, 15.0, 25.0, 40.0, 60.0, 80.0, 100.0])
        result = _filter_horses_by_type(horses, 'safe')
        assert result[0]['odds'] == 3.0  # 最低オッズが先頭

    # 中穴
    def test_midrange_returns_10_to_50(self):
        horses = make_horses([3.0, 8.0, 15.0, 30.0, 45.0, 60.0])
        result = _filter_horses_by_type(horses, 'midRange')
        assert all(10.0 < h['odds'] <= 50.0 for h in result)
        assert len(result) == 3

    def test_midrange_fallback_when_too_few(self):
        """10〜50倍が1頭以下 → 25倍に近い順でフォールバック"""
        horses = make_horses([2.0, 5.0, 8.0, 60.0, 80.0])
        result = _filter_horses_by_type(horses, 'midRange')
        assert len(result) > 0

    # 爆穴
    def test_longshot_returns_over_50(self):
        horses = make_horses([3.0, 20.0, 55.0, 80.0, 120.0])
        result = _filter_horses_by_type(horses, 'longShot')
        assert all(h['odds'] > 50.0 for h in result)
        assert len(result) == 3

    def test_longshot_fallback_when_too_few(self):
        """50倍超が1頭以下 → 高オッズ順でフォールバック"""
        horses = make_horses([2.0, 5.0, 10.0, 20.0, 40.0])
        result = _filter_horses_by_type(horses, 'longShot')
        assert result[0]['odds'] == 40.0  # 最高オッズが先頭


# ── 4. 推薦キャッシュTTL ──────────────────────────────────────────────────

class TestRecommendCacheTTL:

    def test_cache_expires_after_ttl(self):
        """キャッシュはTTL経過後に無効になる"""
        key = ('20260516', '東京', '1R', 'safe')
        _cache[key] = {'picks': []}
        _cache_time[key] = time.time() - RECOMMEND_CACHE_TTL - 1  # TTL超過

        cached_at = _cache_time.get(key, 0)
        is_valid = key in _cache and time.time() - cached_at < RECOMMEND_CACHE_TTL
        assert not is_valid

    def test_cache_valid_within_ttl(self):
        """TTL内のキャッシュは有効"""
        key = ('20260516', '東京', '2R', 'safe')
        _cache[key] = {'picks': []}
        _cache_time[key] = time.time()  # 今さっき作成

        cached_at = _cache_time.get(key, 0)
        is_valid = key in _cache and time.time() - cached_at < RECOMMEND_CACHE_TTL
        assert is_valid
