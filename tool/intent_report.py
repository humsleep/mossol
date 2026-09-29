#!/usr/bin/env python3
"""자유 입력 분리도 보고서 (docs/overhaul/07_free_input.md §2-3). 표준 라이브러리만.

lib/engine/free_input.dart 의 점수 함수를 그대로 옮겼다(사전은 free_input_lexicon.dart 를 파싱해 읽는다 —
두 벌을 따로 관리하지 않는다). 이벤트마다:
  - 자기 회수: 선택지 문구를 입력으로 넣었을 때 1위가 자기 자신인가 → 아니면 FAIL
  - 쌍 유사도: 보이는 선택지 두 개의 서명 유사도 jaccard(tags)+dice(grams) > 0.55 → LOW
  - 빈 서명: 본문 2-gram ≤ 2 이고 태그 0 → EMPTY
출력: tool/sim_out/intent_report.md.

  python3 tool/intent_report.py            # 보고서
  python3 tool/intent_report.py --fixture  # 픽스처 정확도(Dart 테스트와 같은 숫자가 나와야 한다)
  python3 tool/intent_report.py --debug m17 "그냥 바로 답장할래"   # 후보별 점수 분해
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / 'assets/story'
LEXICON = ROOT / 'lib/engine/free_input_lexicon.dart'
OUT = ROOT / 'tool/sim_out/intent_report.md'

EVENT_FILES = [
    'events_main.json', 'events_route_a.json', 'events_route_b.json', 'events_daily.json',
    'events_special.json', 'route_jeongwoo.json', 'route_daeun.json', 'route_seunghyun.json',
    'route_sohee.json', 'route_geonwoo.json', 'route_yuna.json', 'events_moments.json',
]

# 임계값 — FreeInputThresholds 와 같아야 한다.
AUTO_MIN, AUTO_MARGIN, WEAK, TIE, PENALTY, MAX_CHARS = 0.38, 0.12, 0.18, 0.02, 0.25, 80
LOW_PAIR = 0.55

# ---------------------------------------------------------------------------
# 사전: Dart 상수를 파싱한다.
# ---------------------------------------------------------------------------

def _dart_list(src, name):
    m = re.search(r'static const %s = \[(.*?)\];' % re.escape(name), src, re.S)
    return re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(1)) if m else []


def _dart_tag_map(src):
    body = re.search(r'static const Map<String, List<String>> tags = \{(.*?)\n  \};', src, re.S).group(1)
    out = {}
    for tag, items in re.findall(r'Intent\.(\w+): \[(.*?)\],', body, re.S):
        out[tag.rstrip('_')] = re.findall(r"'((?:[^'\\]|\\.)*)'", items)
    return out


def _dart_emo(src):
    body = re.search(r'static const emo = \{(.*?)\n  \};', src, re.S).group(1)
    return {k: re.findall(r"'([^']*)'", v) for k, v in re.findall(r"'(\w+)': \[(.*?)\]", body, re.S)}


_src = LEXICON.read_text(encoding='utf-8')
TAGS = _dart_tag_map(_src)
POLITE_END = _dart_list(_src, 'politeEndings')
POLITE_TOK = _dart_list(_src, 'politeTokens')
CASUAL_END = _dart_list(_src, 'casualEndings')
QUESTION_END = _dart_list(_src, 'questionEndings')
EMO = _dart_emo(_src)
OPPOSITES = [('refuse', 'agree'), ('honest', 'passive'), ('assert', 'passive')]

# ---------------------------------------------------------------------------
# 정규화 (norm)
# ---------------------------------------------------------------------------

REPEATS = [(re.compile('ㅋ{3,}'), 'ㅋㅋ'), (re.compile('ㅎ{3,}'), 'ㅎㅎ'), (re.compile('[ㅠㅜ]{3,}'), 'ㅠㅠ'),
           (re.compile('!{2,}'), '!!'), (re.compile(r'\?{2,}'), '??'), (re.compile('[.…]{2,}'), '…')]
BODY = re.compile('[가-힣a-z0-9]')
COMPACT = re.compile('[가-힣ㄱ-ㅎㅏ-ㅣa-z0-9♥❤💕]')
PUNCT = re.compile('[^\\s가-힣ㄱ-ㅎㅏ-ㅣa-z0-9♥❤💕]')


def norm(s):
    import unicodedata
    t = unicodedata.normalize('NFC', s).strip().lower()
    for re_, to in REPEATS:
        t = re_.sub(to, t)
    compact = ''.join(BODY_C for BODY_C in COMPACT.findall(t))
    body = ''.join(BODY.findall(t))
    tokens = [PUNCT.sub('', w) for w in re.split(r'\s+', t) if PUNCT.sub('', w)]
    return {'raw': t, 'compact': compact, 'body': body, 'tokens': tokens}


def bigrams(body):
    return {body[i:i + 2] for i in range(len(body) - 1)}


def dice(a, b):
    return 0.0 if not a or not b else 2 * len(a & b) / (len(a) + len(b))


def jaccard(a, b):
    return 0.0 if not a or not b else len(a & b) / len(a | b)


def jong(ch):
    o = ord(ch)
    return (o - 0xAC00) % 28 if 0xAC00 <= o <= 0xD7A3 else -1


def politeness(body):
    if not body:
        return 0
    if any(body.endswith(e) for e in POLITE_END) or any(p in body for p in POLITE_TOK):
        return 1
    if any(body.endswith(e) for e in CASUAL_END):
        return -1
    return 0


def question(n):
    return '?' in n['raw'] or (bool(n['body']) and any(n['body'].endswith(e) for e in QUESTION_END))


def degenerate(raw):
    syl = sum(1 for ch in raw if 0xAC00 <= ord(ch) <= 0xD7A3)
    jamo = sum(1 for ch in raw if 0x3131 <= ord(ch) <= 0x318E)
    latin = sum(1 for ch in raw if 'a' <= ch <= 'z')
    if syl < 2 and latin < 3:
        return True
    return syl <= 2 and jamo > syl


def len_bucket(body):
    return 0 if len(body) <= 4 else 1 if len(body) <= 15 else 2


def action(n):
    if n['raw'].startswith('('):
        return True
    b = n['body']
    if len(b) < 2:
        return False
    if b.endswith('다') and (jong(b[-2]) == 4 or b.endswith('했다')):
        return True
    return jong(b[-1]) == 16 and len(b) >= 3


def emo(raw):
    return {k for k, v in EMO.items() if any(x in raw for x in v)}


def tags_of(n, q):
    out = set()
    for tag, pats in TAGS.items():
        for p in pats:
            need_q, need_not_q = p.endswith('?'), p.endswith('!')
            if need_q or need_not_q:
                p = p[:-1]
            if (need_q and not q) or (need_not_q and q):
                continue
            if p.startswith('^'):
                if p[1:] in n['tokens']:
                    out.add(tag)
                    break
            elif p in n['compact']:
                out.add(tag)
                break
    if q:
        out.add('ask')
    return out


def features(s):
    n = norm(s)
    deg = degenerate(n['raw'])
    q = (bool(n['body']) and any(n['body'].endswith(e) for e in QUESTION_END)) if deg else question(n)
    return {'n': n, 'grams': bigrams(n['body']), 'polite': politeness(n['body']), 'question': q,
            'len': len_bucket(n['body']), 'emo': emo(n['raw']), 'action': action(n), 'tags': tags_of(n, q),
            'degenerate': deg}


def last_sentence(s):
    parts = re.split(r'(?<=[.!?])\s+', s)
    if len(parts) < 2:
        return s
    last = parts[-1].strip()
    return last if len(norm(last)['body']) >= 4 else s


# ---------------------------------------------------------------------------
# 선택지 서명
# ---------------------------------------------------------------------------

QUOTES = re.compile('["\'“”‘’()（）\\[\\]]')
TOKEN = re.compile(r'\{[^{}]*\}')


def fill(s):
    """TextTemplate.fill 의 이름 없음 기본값 근사: 호격은 지우고, 나머지 자리표시자는 대체어/빈칸."""
    def rep(m):
        inner = m.group(0)[1:-1]
        parts = inner.split('|')
        if parts[0] == 'mbti':
            return parts[1] if len(parts) > 1 else ''
        if len(parts) == 3:
            return parts[2]
        if len(parts) == 2 and parts[1] == '아야':
            return ''
        if len(parts) == 2 and parts[1].startswith('씨'):
            return '그쪽'
        return '너'
    return TOKEN.sub(rep, s)


def effect_tags(e, decline=False):
    out = set()
    st = e.get('stats', {}) or {}
    if any(v < 0 for v in (e.get('affection', {}) or {}).values()):
        out |= {'refuse', 'passive'}
    if st.get('sincerity', 0) > 0:
        out.add('honest')
    if st.get('sincerity', 0) < 0:
        out.add('passive')
    if st.get('esteem', 0) > 0:
        out.add('assert')
    if st.get('stress', 0) < 0:
        out |= {'passive', 'delay'}
    if st.get('money', 0) < 0:
        out.add('love')
    if st.get('reputation', 0) > 0:
        out.add('joke')
    if st.get('reputation', 0) < 0:
        out.add('passive')
    if decline:
        out.add('refuse')
    if any(f.endswith('_dm_first') or '_confess' in f for f in e.get('setFlags', []) or []):
        out.add('love')
    return out


def reply_lines(c):
    out = []
    for key in ('reply', 'critReply'):
        r = c.get(key) or []
        if isinstance(r, str):
            r = [r]
        for l in r:
            if isinstance(l, str):
                out.append(l)
            elif l.get('who', 'them') in ('them', 'narr'):
                out.append(l.get('text', ''))
    return out


def signature(c):
    t = QUOTES.sub('', fill(c['text']))
    n = norm(t)
    q = question(n)
    tags = tags_of(n, q)
    reply_grams = set()  # 반응 줄은 2-gram 만(태그 없음 — Dart 와 같은 규칙)
    for l in reply_lines(c):
        reply_grams |= bigrams(norm(fill(l))['body'])
    text_grams = bigrams(n['body'])
    for s in c.get('intent') or []:
        inn = norm(s)
        ig = bigrams(inn['body'])
        text_grams |= ig
        reply_grams |= ig or {inn['body']}
        tags |= tags_of(inn, question(inn))
    text_tags = set(tags)
    tags |= effect_tags(c.get('effects') or {}, c.get('decline', False))
    return {'text': text_grams, 'reply': reply_grams, 'tags': tags, 'ttags': text_tags, 'polite': politeness(n['body']),
            'question': q, 'len': len_bucket(n['body']), 'action': action(n), 'body': n['body']}


def style(i, c):
    s = 0.0
    if not c['action'] and i['polite'] == c['polite']:
        s += 0.5
    if i['question'] == c['question']:
        s += 0.3
    if abs(i['len'] - c['len']) <= 1:
        s += 0.2
    return s


def score(i, c, parts=False):
    tw = 0.50 if i['action'] and c['action'] else 0.40
    a = tw * dice(i['grams'], c['text'])
    b = 0.15 * dice(i['grams'], c['reply'])
    d = 0.35 * jaccard(i['tags'], c['tags'])
    e = 0.10 * style(i, c)
    pen = 0.0
    ct = c['ttags']  # 극성 벌점은 문구 태그만
    for x, y in OPPOSITES:
        if x in i['tags'] and y in i['tags']:
            continue
        if (x in i['tags'] and y in ct and x not in ct) or (y in i['tags'] and x in ct and y not in ct):
            pen -= PENALTY
    s = a + b + d + e + pen
    return (s, a, b, d, e, pen) if parts else s


def visible(ev):
    """MBTI 없음 기준 보이는 선택지. 통화면 decline 제외."""
    out = []
    for i, c in enumerate(ev.get('choices', [])):
        if c.get('mbti') or c.get('compat'):
            continue
        if ev.get('format') == 'call' and c.get('decline'):
            continue
        out.append((i, c))
    return out


def match(text, cands, sigs, in_call=False):
    t = text.strip()[:MAX_CHARS]
    i = features(last_sentence(t))
    if not i['n']['compact']:
        return None, i
    full_body = norm(t)['body']
    scored = []
    for idx, c in cands:
        sig = sigs[idx]
        exact = bool(sig['body']) and sig['body'] in (i['n']['body'], full_body)
        scored.append((idx, score(i, sig), exact, c))
    scored.sort(key=lambda x: (0 if x[2] else 1, -x[1], x[0]))
    return scored, i


def decide(i, ranked):
    if not ranked:
        return 'empty'
    idx, s1, exact, c = ranked[0]
    if i['degenerate']:
        return 'pick'
    if not i['grams'] and not exact:
        return 'pick'
    s2 = ranked[1][1] if len(ranked) > 1 else 0.0
    if not (exact or (s1 >= AUTO_MIN and s1 - s2 >= AUTO_MARGIN and s1 - s2 >= TIE)):
        return 'pick'
    if c.get('require'):
        return 'locked'  # 초기 상태 기준(요구치는 여기서 안 본다) — Dart 는 실제 잠금을 본다
    if c.get('chance') is not None or c.get('minigame'):
        return 'confirm'
    return 'auto'


def load_events():
    evs = []
    for f in EVENT_FILES:
        p = STORY / f
        if not p.exists():
            continue
        text = p.read_text(encoding='utf-8')
        if not text.strip():
            continue
        raw = json.loads(text)
        evs.extend(raw if isinstance(raw, list) else raw['events'])
    return evs


# ---------------------------------------------------------------------------
# 모드
# ---------------------------------------------------------------------------

def run_fixture():
    fx = json.loads((ROOT / 'test/fixtures/free_input.json').read_text(encoding='utf-8'))
    by_id = {e['id']: e for e in load_events()}
    n = top1 = top2 = auto = wrong = 0
    misses = []
    for e in fx['events']:
        ev = by_id[e['id']]
        cands = visible(ev)
        sigs = {i: signature(c) for i, c in cands}
        for case in e['cases']:
            for s in case['inputs']:
                ranked, i = match(s, cands, sigs, ev.get('format') == 'call')
                n += 1
                order = [r[0] for r in ranked]
                dec = decide(i, ranked)
                ok = order[0] == case['choice']
                top1 += ok
                top2 += case['choice'] in order[:2]
                auto += dec == 'auto'
                wrong += (dec == 'auto' and not ok)
                if not ok:
                    misses.append('%s[%d] "%s" → %s %s s1=%.2f' % (e['id'], case['choice'], s, order[:3], dec, ranked[0][1]))
    print('fixture: n=%d top1=%.1f%% top2=%.1f%% auto=%d wrongAuto=%d' % (n, 100 * top1 / n, 100 * top2 / n, auto, wrong))
    for m in misses:
        print('  miss:', m)


def run_debug(ev_id, text):
    ev = {e['id']: e for e in load_events()}[ev_id]
    cands = visible(ev)
    sigs = {i: signature(c) for i, c in cands}
    i = features(last_sentence(text))
    print('input tags=%s polite=%d q=%s len=%d action=%s grams=%d' % (
        sorted(i['tags']), i['polite'], i['question'], i['len'], i['action'], len(i['grams'])))
    for idx, c in cands:
        sig = sigs[idx]
        s, a, b, d, e, pen = score(i, sig, parts=True)
        print('  [%d] %-28s total=%.3f text=%.3f reply=%.3f tags=%.3f style=%.3f pen=%.2f | tags=%s polite=%d q=%s action=%s' % (
            idx, c['text'][:28], s, a, b, d, e, pen, sorted(sig['tags']), sig['polite'], sig['question'], sig['action']))


def run_report():
    evs = load_events()
    fails, lows, empties = [], [], []
    n_choices = 0
    for ev in evs:
        cands = visible(ev)
        if len(cands) < 2:
            continue
        sigs = {i: signature(c) for i, c in cands}
        n_choices += len(cands)
        for idx, c in cands:
            sig = sigs[idx]
            if len(sig['text']) <= 2 and not sig['tags']:
                empties.append((ev['id'], idx, c['text'], suggest(c)))
            ranked, _ = match(c['text'], cands, sigs, ev.get('format') == 'call')
            if ranked and ranked[0][0] != idx and sigs[ranked[0][0]]['body'] != sig['body']:
                fails.append((ev['id'], idx, c['text'], ranked[0][0]))
        for a in range(len(cands)):
            for b in range(a + 1, len(cands)):
                ia, ib = cands[a][0], cands[b][0]
                sim = jaccard(sigs[ia]['tags'], sigs[ib]['tags']) + dice(sigs[ia]['text'], sigs[ib]['text'])
                if sim > LOW_PAIR:
                    lows.append((ev['id'], ia, ib, sim, cands[a][1]['text'], cands[b][1]['text']))
    low_events = {x[0] for x in lows}
    empty_events = {x[0] for x in empties}
    lines = ['# 자유 입력 분리도 보고서', '',
             '이벤트 %d · 보이는 선택지 %d(MBTI 없음 기준). 기준: docs/overhaul/07_free_input.md §2-3.' % (len(evs), n_choices), '',
             '- 자기 회수 FAIL: %d' % len(fails),
             '- LOW(쌍 유사도 > %.2f): %d쌍 · 이벤트 %d' % (LOW_PAIR, len(lows), len(low_events)),
             '- EMPTY(2-gram ≤ 2 · 태그 0): %d · 이벤트 %d' % (len(empties), len(empty_events)),
             '- `intent` 저작 후보 이벤트(LOW ∪ EMPTY): %d' % len(low_events | empty_events), '']
    if fails:
        lines += ['## 자기 회수 FAIL', '', '| 이벤트 | 선택지 | 문구 | 1위 |', '|---|---|---|---|']
        lines += ['| %s | %d | %s | %d |' % f for f in fails]
        lines.append('')
    lines += ['## EMPTY', '', '| 이벤트 | 선택지 | 문구 | 제안 표현(반응 줄 명사) |', '|---|---|---|---|']
    lines += ['| %s | %d | %s | %s |' % (e, i, t.replace('|', '\\|'), s) for e, i, t, s in empties]
    lines += ['', '## LOW', '', '| 이벤트 | 쌍 | 유사도 | 문구 |', '|---|---|---|---|']
    lines += ['| %s | %d·%d | %.2f | %s / %s |' % (e, a, b, sim, ta.replace('|', '\\|'), tb.replace('|', '\\|'))
              for e, a, b, sim, ta, tb in sorted(lows, key=lambda x: -x[3])]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[:9]))
    print('→', OUT.relative_to(ROOT))


def suggest(c):
    """반응 줄에서 2~4자 한글 덩어리를 뽑아 제안 표현으로."""
    words = []
    for l in reply_lines(c):
        for w in re.findall('[가-힣]{2,4}', fill(l)):
            if w not in words:
                words.append(w)
    return ' '.join(words[:4])


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['--fixture']:
        run_fixture()
    elif args[:1] == ['--debug'] and len(args) >= 3:
        run_debug(args[1], ' '.join(args[2:]))
    else:
        run_report()
