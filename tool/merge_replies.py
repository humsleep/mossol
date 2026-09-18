#!/usr/bin/env python3
"""tool/replies/*.json 의 상대 반응을 assets/story/events_*.json 에 합친다.

반응 파일 형식:
  { "<이벤트 id>": [ {"reply": ..., "failReply": ..., "critReply": ...} | null, ... ] }
배열 순서는 그 이벤트의 choices 순서와 같다. null 이면 그 선택지는 건너뛴다.
각 값은 문자열(상대의 말 한 줄) 또는 문자열·Line 객체의 배열.

사용: python3 tool/merge_replies.py [--check] [--only 파일명.json]
  --check 는 파일을 쓰지 않고 문제만 출력한다.
  --only 는 그 반응 파일만 읽고, 그 파일이 맡은 이벤트의 빈칸·길이 규칙까지 검사한다.
여러 번 실행해도 결과가 같다(덮어쓰기).
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, 'assets', 'story')
KEYS = ('reply', 'failReply', 'critReply')


def lint(eid, i, ch, p, src):
    """test/reply_coverage_test.dart 와 같은 규칙."""
    out = []
    where = f'{src}: {eid}.choices[{i}]'
    can_fail = 'chance' in ch or 'minigame' in ch
    if 'next' not in ch and not p.get('reply'):
        out.append(f'{where} reply 없음')
    if can_fail and 'failNext' not in ch and not p.get('failReply'):
        out.append(f'{where} failReply 없음')
    for k in KEYS:
        v = p.get(k)
        if v in (None, '', []):
            continue
        lines = v if isinstance(v, list) else [v]
        if len(lines) > 3:
            out.append(f'{where}.{k} 3줄 초과')
        for l in lines:
            if isinstance(l, str):
                l = {'who': 'them', 'text': l}
            if l.get('who', 'them') not in ('them', 'narr', 'sys', 'me'):
                out.append(f"{where}.{k} who={l.get('who')}")
            t = l.get('text', '')
            if not t.strip():
                out.append(f'{where}.{k} 빈 줄')
            if len(t) > 60:
                out.append(f'{where}.{k} 60자 초과({len(t)})')
            if l.get('wait'):
                out.append(f'{where}.{k} 대기 줄 금지')
    return out


def main():
    check = '--check' in sys.argv
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    if only:
        check = True
    patches = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'tool', 'replies', '*.json'))):
        if only and os.path.basename(path) != only:
            continue
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        for eid, arr in data.items():
            if eid in patches:
                sys.exit(f'중복 이벤트 id: {eid} ({os.path.basename(path)})')
            patches[eid] = (arr, os.path.basename(path))

    errors = []
    applied = 0
    seen = set()
    for path in sorted(glob.glob(os.path.join(STORY, 'events_*.json'))):
        with open(path, encoding='utf-8') as f:
            events = json.load(f)
        changed = False
        for e in events:
            if e['id'] not in patches:
                continue
            arr, src = patches[e['id']]
            seen.add(e['id'])
            if len(arr) != len(e['choices']):
                errors.append(f"{src}: {e['id']} 선택지 수 {len(arr)} != {len(e['choices'])}")
                continue
            for i, (ch, p) in enumerate(zip(e['choices'], arr)):
                if only:
                    errors.extend(lint(e['id'], i, ch, p or {}, src))
                if p is None:
                    continue
                for k in p:
                    if k not in KEYS:
                        errors.append(f"{src}: {e['id']} 알 수 없는 키 {k}")
                for k in KEYS:
                    if k in p and p[k] not in (None, '', []):
                        ch[k] = p[k]
                        changed = True
                        applied += 1
        if changed and not check:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(events, f, ensure_ascii=False, indent=1)
    for eid, (_, src) in patches.items():
        if eid not in seen:
            errors.append(f'{src}: 없는 이벤트 id {eid}')
    for er in errors:
        print(er)
    print(f"{'확인' if check else '적용'}: 반응 {applied}개, 오류 {len(errors)}건")
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
