#!/usr/bin/env python3
"""목소리 검사 — "…" 밀도 · 캐릭터별 말버릇 횟수 · 시그니처 누수를 숫자로 낸다.

    python3 tool/check_voice.py          # 숫자표 + 위반 목록
    python3 tool/check_voice.py --quiet  # 위반만 (CI·훅용)

규칙은 `tool/voice_rules.json` 에 있다. 다음 글 작업은 이 숫자에서 시작하면 된다.
위반이 있으면 종료 코드 1.

세는 대상은 **상대 대사(`who: them`)** 다. 말하는 사람은 줄의 `name`,
없으면 그 이벤트의 `character`, 그것도 없으면 `(익명)` 이다.
"""
from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / 'assets' / 'story'
RULES = json.loads((Path(__file__).resolve().parent / 'voice_rules.json').read_text(encoding='utf-8'))

EVENT_FILES = [
    'events_daily.json', 'events_action.json', 'events_main.json', 'events_moments.json',
    'events_route_a.json', 'events_route_b.json', 'events_special.json',
    'route_daeun.json', 'route_geonwoo.json', 'route_jeongwoo.json',
    'route_seunghyun.json', 'route_sohee.json', 'route_yuna.json',
]
REPLY_KEYS = ('reply', 'failReply', 'critReply')
LEAD = '…'

# 공략 캐릭터 12명. 조연(태현·준호·엄마…)과 익명은 따로 센다.
CAST = ['seoyeon', 'haneul', 'jiwoo', 'minjae', 'yeeun', 'doyun',
        'jeongwoo', 'daeun', 'seunghyun', 'sohee', 'geonwoo', 'yuna']


def text_of(l):
    return l if isinstance(l, str) else (l.get('text') or '')


def who_of(l):
    return 'them' if isinstance(l, str) else (l.get('who') or 'them')


def name_of(l):
    return None if isinstance(l, str) else l.get('name')


def is_wait(l):
    return who_of(l) == 'sys' and (0 if isinstance(l, str) else l.get('wait', 0)) > 0


def arrays(ev):
    yield 'lines', ev.get('lines', [])
    for ci, ch in enumerate(ev.get('choices', [])):
        for k in REPLY_KEYS:
            if k in ch:
                v = ch[k]
                yield f'choices[{ci}].{k}', [v] if isinstance(v, str) else v


def load_events():
    out = []
    for f in EVENT_FILES:
        for ev in json.loads((STORY / f).read_text(encoding='utf-8')):
            ev['_file'] = f
            out.append(ev)
    return out


def speaker(ev, l):
    return name_of(l) or ev.get('character') or '(익명)'


def main():
    quiet = '--quiet' in sys.argv
    events = load_events()
    endings = json.loads((STORY / 'endings.json').read_text(encoding='utf-8'))
    bad = []

    # ── 1. 말머리 "…" ────────────────────────────────────────────────
    er = RULES['ellipsis']
    exempt = set(er.get('exempt', []))
    them = Counter()
    dots = Counter()
    total_them = total_dot = 0
    for ev in events:
        lines = ev.get('lines', [])
        tail_wait = bool(lines) and is_wait(lines[-1])
        per_path = defaultdict(int)
        for name, arr in arrays(ev):
            for i, l in enumerate(arr):
                if who_of(l) != 'them':
                    continue
                who = speaker(ev, l)
                them[who] += 1
                t = text_of(l)
                if not t.startswith(LEAD) or t.strip() == LEAD:
                    continue
                if f'{ev["id"]}.{name}[{i}]' in exempt:
                    continue      # 규칙보다 장면이 먼저인 줄 (voice_rules.json)
                dots[who] += 1
                path = 'lines' if name == 'lines' else name
                per_path[path] += 1
                prev_wait = is_wait(arr[i - 1]) if i > 0 else (name != 'lines' and tail_wait)
                if prev_wait and not er['afterWait']:
                    bad.append(f'{ev["id"]}.{name}[{i}]: wait 다음 줄이 "…" 로 시작한다 — {t!r}')
        base = per_path.pop('lines', 0)
        for path, n in list(per_path.items()) or []:
            if base + n > er['perEventMax']:
                bad.append(f'{ev["id"]}: 한 경로(lines+{path})에 말머리 "…" 가 {base + n}번 '
                           f'(상한 {er["perEventMax"]})')
        if not per_path and base > er['perEventMax']:
            bad.append(f'{ev["id"]}.lines: 말머리 "…" 가 {base}번 (상한 {er["perEventMax"]})')
    total_them = sum(them.values())
    total_dot = sum(dots.values())

    if not quiet:
        print('── 말머리 "…" ' + '─' * 46)
        print(f'전체 {total_dot} / {total_them}줄 = {100 * total_dot / max(1, total_them):.1f}% '
              f'(상한 {er["globalMaxRatio"] * 100:.0f}%)')
        for who in CAST + [w for w in them if w not in CAST and them[w] >= 20]:
            n = them.get(who, 0)
            if not n:
                continue
            cap = er['perCharacterMaxRatio'].get(who, er['perCharacterMaxRatio']['_default'])
            flag = ' ←' if dots[who] > n * cap else ''
            print(f'  {who:12s} {dots[who]:4d} / {n:4d} = {100 * dots[who] / n:5.1f}%  '
                  f'(상한 {cap * 100:.0f}%){flag}')
    if total_dot > total_them * er['globalMaxRatio']:
        bad.append(f'전체 "…" 밀도 {100 * total_dot / total_them:.1f}% '
                   f'> 상한 {er["globalMaxRatio"] * 100:.0f}%')
    for who, n in them.items():
        cap = er['perCharacterMaxRatio'].get(who, er['perCharacterMaxRatio']['_default'])
        if n >= 50 and dots[who] > n * cap:
            bad.append(f'{who}: "…" {dots[who]}/{n} = {100 * dots[who] / n:.1f}% > 상한 {cap * 100:.0f}%')

    # ── 2. 시그니처 횟수와 누수 ──────────────────────────────────────
    counts = defaultdict(Counter)   # phrase -> speaker -> n
    where = defaultdict(list)
    for ev in events:
        for name, arr in arrays(ev):
            for i, l in enumerate(arr):
                if who_of(l) != 'them':
                    continue
                t, who = text_of(l), speaker(ev, l)
                for rule in RULES['signatures']:
                    if rule['phrase'] in t:
                        counts[rule['phrase']][who] += 1
                        where[(rule['phrase'], who)].append(f'{ev["id"]}.{name}[{i}]')
    if not quiet:
        print('\n── 시그니처 ' + '─' * 48)
    for rule in RULES['signatures']:
        p, owner = rule['phrase'], rule['owner']
        c = counts[p]
        if not quiet:
            top = ' · '.join(f'{w} {n}' for w, n in c.most_common(6))
            print(f'  {p:6s} 합 {sum(c.values()):3d}  {top}')
        for who, n in c.items():
            limit = rule['ownerMax'] if who == owner else rule['otherMax']
            if n > limit:
                kind = '제 시그니처 과다' if who == owner else '다른 캐릭터에게 누수'
                bad.append(f'"{p}" {kind}: {who} {n}번 (상한 {limit}) — '
                           f'{", ".join(where[(p, who)][:4])}…')

    # ── 3. 캐릭터별 금지어 ───────────────────────────────────────────
    for ev in events:
        for name, arr in arrays(ev):
            for i, l in enumerate(arr):
                if who_of(l) != 'them':
                    continue
                who = speaker(ev, l)
                for w in RULES['banned'].get(who, []) if who in RULES['banned'] else []:
                    if w in text_of(l):
                        bad.append(f'{ev["id"]}.{name}[{i}]: {who} 가 안 쓰는 말 {w!r} — {text_of(l)!r}')

    # ── 4. 서술의 2인칭 ──────────────────────────────────────────────
    for w in RULES['narration']['bannedWords']:
        for e in endings:
            for key in ('epilogue', 'hint'):
                if w in (e.get(key) or ''):
                    bad.append(f'엔딩 {e["id"]}.{key}: 2인칭 {w!r} — {e[key]!r}')
        for ev in events:
            for name, arr in arrays(ev):
                for i, l in enumerate(arr):
                    if who_of(l) == 'narr' and w in text_of(l):
                        bad.append(f'{ev["id"]}.{name}[{i}]: 서술에 2인칭 {w!r} — {text_of(l)!r}')

    if not quiet:
        print('\n── 익명 상대 ' + '─' * 47)
        anon_ev = set()
        anon_lines = 0
        for ev in events:
            for name, arr in arrays(ev):
                for l in arr:
                    if who_of(l) == 'them' and not name_of(l) and not ev.get('character'):
                        anon_ev.add(ev['id'])
                        anon_lines += 1
        print(f'  이름도 character 도 없는 상대 대사 {anon_lines}줄 / {len(anon_ev)} 이벤트')
        print(f'  ({", ".join(sorted(anon_ev))})')

    print('\n' + ('통과 — 위반 0건' if not bad else f'위반 {len(bad)}건'))
    for b in bad:
        print(' -', b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
