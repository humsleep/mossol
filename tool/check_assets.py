#!/usr/bin/env python3
"""장면 그림 에셋 점검기 — docs/SCENE_PROMPTS.md 가 기대하는 파일 vs assets/ 에 있는 파일.

그림은 외부 도구로 만들어 `assets/scenes|photos|stickers|endings/` 에 떨어뜨린다
(docs/SCENE_PROMPTS.md §0.3·§0.4). 이 스크립트는 그 뒤에 한 번 돌려 본다.

  python3 tool/check_assets.py            # 요약
  python3 tool/check_assets.py -v         # 없는 파일 전부 나열
  python3 tool/check_assets.py --json     # 기계용

기대 목록은 SCENE_PROMPTS 본문에 적힌 `assets/<폴더>/<이름>.webp` 를 그대로 긁는다
(§0.3 규약표의 `<event id>` 같은 자리표시자 줄은 뺀다). 여기에 두 가지를 더한다:
- 2차 그림 세트(docs/image_prompts/*.md, 엔딩·표정·키 아트·도장·행동 배경·위기 컷).
  위기 컷(`assets/events/<id>`)은 장면 자리 `scenes/` 로 들어간다(tool/import_generated_art.py).
- 대본이 `image`·`photo.image` 로 가리키는 파일 전부(전용 사진 `<이벤트 id>_<n>` 이 여기서 잡힌다).
표준 라이브러리만 쓴다.

나가는 값: 없는 파일이 있으면 1, 규약을 어긴(이름이 틀린·형식이 다른) 파일이 있어도 1,
전부 맞으면 0. "남는 파일(extra)" 은 경고일 뿐 실패가 아니다 — 작가가 변형을 더 넣고
JSON `image` 필드로 가리킬 수 있다(06_scene_plan §4).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(ROOT, 'docs', 'SCENE_PROMPTS.md')
ASSETS = os.path.join(ROOT, 'assets')

DIRS = ('scenes', 'photos', 'stickers', 'endings', 'expressions', 'keyart', 'stamps')
PROMPTS2 = os.path.join(ROOT, 'docs', 'image_prompts')
STORY = os.path.join(ASSETS, 'story')

# lib/ui/scene_registry.dart 의 extensions 와 같은 순서.
EXTENSIONS = ('png', 'jpg', 'jpeg', 'webp')

# 본문에 적힌 에셋 경로. 자리표시자(`<event id>`)가 든 줄은 정규식이 알아서 거른다.
PATH_RE = re.compile(r'assets/(%s)/([a-z0-9_]+)\.webp' % '|'.join(DIRS))

# 크기 기준(§0.4). 파일 크기(바이트)가 이 선을 크게 넘으면 변환을 건너뛴 것이다.
# 한 장당 상한(webp q90 기준). 이 크기를 넘으면 해상도나 품질이 과한 것이다 —
# 가장 큰 아이폰이 쓰는 픽셀은 장면·엔딩 1176px, 사진 792px 뿐이다(tool/convert_art.py).
#
# 2차 세트(docs/image_prompts)는 소유자 결정으로 원본 해상도(1024~1536px)를 유지한다 —
# WebP q90 에서 한 장 150~300KB. 그래서 그 폴더들의 상한은 이 크기에 맞춘다.
SIZE_BUDGET = {
    'scenes': 320 * 1024,
    'endings': 360 * 1024,
    'photos': 320 * 1024,
    'stickers': 60 * 1024,
    'expressions': 360 * 1024,
    'keyart': 360 * 1024,
    'stamps': 420 * 1024,
}


def expected(doc_path: str) -> dict[str, set[str]]:
    """문서가 기대하는 파일. 폴더 → {파일 이름(.webp 포함)}."""
    try:
        with open(doc_path, encoding='utf-8') as f:
            text = f.read()
    except OSError as e:
        sys.exit(f'문서를 읽지 못함: {e}')
    out: dict[str, set[str]] = {d: set() for d in DIRS}
    for folder, name in PATH_RE.findall(text):
        out[folder].add(f'{name}.webp')
    # 2차 세트: 문서 제목의 `<이름>.png`(사진은 아래 대본 참조로 잡는다).
    if os.path.isdir(PROMPTS2):
        prefix = {'01_endings.md': 'endings'}
        for md in sorted(os.listdir(PROMPTS2)):
            if not md.endswith('.md') or md.startswith('02_photos'):
                continue
            with open(os.path.join(PROMPTS2, md), encoding='utf-8') as f:
                for m in re.finditer(r'^#{3,4} .*?`([^`]+)\.png`', f.read(), re.M):
                    name = m.group(1)
                    if name.startswith('assets/'):
                        folder, name = name.split('/')[1], name.split('/')[2]
                        folder = 'scenes' if folder == 'events' else folder
                    else:
                        folder = prefix.get(md)
                    if folder in out:
                        out[folder].add(f'{name}.webp')
    # 대본이 가리키는 그림.
    ref = re.compile(r'"image":\s*"assets/(%s)/([a-z0-9_]+)(?:\.\w+)?"' % '|'.join(DIRS))
    for name in sorted(os.listdir(STORY)) if os.path.isdir(STORY) else []:
        if name.endswith('.json'):
            with open(os.path.join(STORY, name), encoding='utf-8') as f:
                for folder, key in ref.findall(f.read()):
                    out[folder].add(f'{key}.webp')
    return out


def present(assets_dir: str) -> dict[str, dict[str, int]]:
    """실제로 있는 파일. 폴더 → {파일 이름: 바이트}. 숨김 파일(.gitkeep)은 뺀다."""
    out: dict[str, dict[str, int]] = {d: {} for d in DIRS}
    for d in DIRS:
        path = os.path.join(assets_dir, d)
        if not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            if name.startswith('.'):
                continue
            full = os.path.join(path, name)
            if os.path.isfile(full):
                out[d][name] = os.path.getsize(full)
    return out


def stem(name: str) -> str:
    return name.rsplit('.', 1)[0] if '.' in name else name


def ext(name: str) -> str:
    return name.rsplit('.', 1)[1].lower() if '.' in name else ''


def check(want: dict[str, set[str]], have: dict[str, dict[str, int]]) -> dict:
    """없는 것 · 남는 것 · 이름이 틀린 것 · 규약 밖 형식 · 용량 초과."""
    report: dict[str, dict] = {}
    for d in DIRS:
        files = have[d]
        stems = {stem(n): n for n in files}
        missing, wrong_ext = [], []
        for w in sorted(want[d]):
            if w in files:
                continue
            found = stems.get(stem(w))
            if found is None:
                missing.append(w)
            elif ext(found) in EXTENSIONS:
                # 이름은 맞고 형식만 다르다. 레지스트리가 EXTENSIONS 를 다 읽으므로
                # 이것은 오류가 아니다 — 이 맥에 webp 인코더가 없어 장면·사진·엔딩은
                # jpg 로 넣었다(초상화와 같은 형식). 투명도가 필요한 스티커만 png 여야 한다.
                if d == 'stickers' and ext(found) not in ('webp', 'png'):
                    # 스티커는 배경이 투명해야 한다. jpg 는 알파를 담지 못한다.
                    wrong_ext.append(f'{found} (스티커는 알파가 있는 webp·png 여야 한다)')
            else:
                missing.append(w)
        extra = sorted(
            n for n in files
            if n not in want[d] and stem(n) not in {stem(w) for w in want[d]}
        )
        bad_name = sorted(
            n for n in files if not re.fullmatch(r'[a-z0-9_]+\.[A-Za-z0-9]+', n)
        )
        unknown_ext = sorted(n for n in files if ext(n) not in EXTENSIONS)
        heavy = sorted(
            f'{n} ({files[n] // 1024}KB)'
            for n in files
            if files[n] > SIZE_BUDGET[d]
        )
        report[d] = {
            'expected': len(want[d]),
            'present': len(files),
            'bytes': sum(files.values()),
            'missing': missing,
            'extra': extra,
            'wrong_ext': wrong_ext,
            'bad_name': bad_name,
            'unknown_ext': unknown_ext,
            'heavy': heavy,
        }
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description='장면 그림 에셋 점검')
    ap.add_argument('-v', '--verbose', action='store_true', help='목록을 전부 출력')
    ap.add_argument('--json', action='store_true', help='JSON 으로 출력')
    ap.add_argument('--doc', default=DOC, help='기대 목록을 읽을 문서')
    ap.add_argument('--assets', default=ASSETS, help='에셋 폴더')
    args = ap.parse_args()

    want = expected(args.doc)
    have = present(args.assets)
    report = check(want, have)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        total_want = sum(r['expected'] for r in report.values())
        total_have = sum(r['present'] for r in report.values())
        total_bytes = sum(r['bytes'] for r in report.values())
        print(f'기대 {total_want}장 · 있음 {total_have}장 · '
              f'{total_bytes / 1024 / 1024:.2f}MB')
        for d in DIRS:
            r = report[d]
            print(f'  {d:<9} 기대 {r["expected"]:>3} · 있음 {r["present"]:>3} · '
                  f'없음 {len(r["missing"]):>3} · 남음 {len(r["extra"]):>3} · '
                  f'{r["bytes"] / 1024:.0f}KB')
            rows = [
                ('없음', r['missing']),
                ('이름은 맞고 형식이 다름', r['wrong_ext']),
                ('규약 밖 이름', r['bad_name']),
                ('규약 밖 형식', r['unknown_ext']),
                ('용량 초과', r['heavy']),
                ('문서에 없는 파일', r['extra']),
            ]
            for label, items in rows:
                if not items:
                    continue
                shown = items if args.verbose else items[:5]
                more = '' if len(shown) == len(items) else \
                    f' … 외 {len(items) - len(shown)}개 (-v 로 전부)'
                print(f'      {label}: {", ".join(shown)}{more}')

    problems = sum(
        len(r['missing']) + len(r['wrong_ext']) + len(r['bad_name'])
        + len(r['unknown_ext'])
        for r in report.values()
    )
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
