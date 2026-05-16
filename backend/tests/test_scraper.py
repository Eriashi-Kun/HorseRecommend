from unittest.mock import patch, MagicMock
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from scraper import _fetch_yoso_odds, _parse_horses
from bs4 import BeautifulSoup


# ── 1. オッズAPIキーマッピング ──────────────────────────────────────────────

class TestFetchYosoOdds:
    def _mock_response(self, odds_raw: dict):
        resp = MagicMock()
        resp.json.return_value = {'data': {'odds': {'1': odds_raw}}}
        return resp

    def test_zero_padded_keys_are_normalized(self):
        """APIが"01"形式で返すキーを"1"に正規化する"""
        raw = {'01': ['6.7', '0', '2'], '02': ['8.1', '0', '3']}
        with patch('scraper.requests.get', return_value=self._mock_response(raw)):
            result = _fetch_yoso_odds('202604010508')
        assert '1' in result
        assert '2' in result
        assert '01' not in result
        assert result['1'] == 6.7
        assert result['2'] == 8.1

    def test_placeholder_odds_excluded(self):
        """'---.-' のオッズは除外される"""
        raw = {'01': ['---.-', '0', '0'], '02': ['9.0', '0', '3']}
        with patch('scraper.requests.get', return_value=self._mock_response(raw)):
            result = _fetch_yoso_odds('202604010508')
        assert '1' not in result
        assert '2' in result

    def test_api_error_returns_empty(self):
        """APIエラー時は空辞書を返す"""
        with patch('scraper.requests.get', side_effect=Exception('timeout')):
            result = _fetch_yoso_odds('202604010508')
        assert result == {}


# ── 2. 馬番採番ロジック ───────────────────────────────────────────────────

def _make_shutuba_html(horse_names: list[str], tr_ids: list[int]) -> BeautifulSoup:
    """テスト用の出馬表HTMLを生成する"""
    rows = ''
    for i, (name, tr_id) in enumerate(zip(horse_names, tr_ids)):
        gate = (i // 2) + 1
        rows += f'''
        <tr id="tr_{tr_id}" class="HorseList">
            <td class="Waku Waku{gate}"><span>{gate}</span></td>
            <td class="HorseInfo"><a href="/horse/dummy{i}">{name}</a></td>
            <td class="Txt_R Popular">---.-</td>
            <td class="Barei">牡4</td>
            <td class="Kinryo">57.0</td>
            <td class="Jockey"><a href="/jockey/result/recent/dummy">騎手名</a></td>
        </tr>'''
    html = f'<table class="Shutuba_Table">{rows}</table>'
    return BeautifulSoup(html, 'lxml')


class TestParseHorses:
    def test_sequential_numbering_regardless_of_tr_id(self):
        """tr_N のIDに関係なく行順で1から馬番を採番する"""
        names = ['ウマA', 'ウマB', 'ウマC', 'ウマD']
        tr_ids = [10, 9, 15, 5]  # バラバラなIDでも正しく採番されるはず
        soup = _make_shutuba_html(names, tr_ids)
        horses = _parse_horses(soup)
        assert [h['number'] for h in horses] == [1, 2, 3, 4]
        assert horses[0]['name'] == 'ウマA'
        assert horses[3]['name'] == 'ウマD'

    def test_horse_count_matches_rows(self):
        """パースした馬の数がテーブルの行数と一致する"""
        names = [f'ウマ{i}' for i in range(1, 17)]
        tr_ids = list(range(10, 26))  # 10〜25のズレたID
        soup = _make_shutuba_html(names, tr_ids)
        horses = _parse_horses(soup)
        assert len(horses) == 16
        assert horses[-1]['number'] == 16
