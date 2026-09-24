#!/usr/bin/env python3
"""전용 사진(assets/photos/<이벤트 id>_<n>)을 대본의 사진 줄에 이어 준다.

공용 사진은 `photo.icon` 으로 저절로 찾아지지만(`assets/photos/food` 등), 한 이벤트만을
위해 그린 사진은 이름이 이벤트 id 라 규약만으로는 찾을 수 없다. 그래서 그 줄에만
`photo.image` 를 적는다. 확장자는 적지 않는다 — 레지스트리가 알아서 찾는다.

멱등이다. 다시 돌려도 이미 적힌 줄은 건드리지 않는다.

    python3 tool/link_photos.py [--check]
"""
import argparse, glob, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PHOTO_DIR = 'assets/photos/'

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true', help='쓰지 않고 확인만')
    a = ap.parse_args()

    # 전용 사진 파일: <이벤트 id>_<번호>.<확장자>
    dedicated = {}
    for f in sorted((ROOT / 'assets' / 'photos').iterdir()):
        m = re.fullmatch(r'(.+)_(\d+)\.\w+', f.name)
        if m:
            dedicated.setdefault(m.group(1), []).append(int(m.group(2)))
    for v in dedicated.values():
        v.sort()

    linked = skipped = 0
    missing = []
    for path in sorted(glob.glob(str(ROOT / 'assets/story/*.json'))):
        data = json.loads(pathlib.Path(path).read_text(encoding='utf-8'))
        if not isinstance(data, list):
            continue
        changed = False
        for ev in data:
            nums = dedicated.get(ev.get('id'))
            if not nums:
                continue
            # 이벤트 안 사진 줄을 등장 순서대로 모은다(lines + 반응 전부).
            shots = []
            def walk(seq):
                for l in seq:
                    if isinstance(l, dict) and isinstance(l.get('photo'), dict):
                        shots.append(l['photo'])
            walk(ev.get('lines', []))
            for ch in ev.get('choices', []):
                for key in ('reply', 'critReply', 'failReply'):
                    r = ch.get(key)
                    walk(r if isinstance(r, list) else [])
            for n in nums:
                if n >= len(shots):
                    missing.append(f"{ev['id']}_{n} (사진 줄 {len(shots)}개뿐)")
                    continue
                want = f"{PHOTO_DIR}{ev['id']}_{n}"
                if shots[n].get('image') == want:
                    skipped += 1
                    continue
                shots[n]['image'] = want
                linked += 1
                changed = True
        if changed and not a.check:
            pathlib.Path(path).write_text(
                json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')

    print(f"전용 사진 {sum(len(v) for v in dedicated.values())}장 · 새로 연결 {linked} · 이미 연결 {skipped}")
    for m in missing:
        print(f"  짝을 못 찾음: {m}")
    if a.check:
        print('--check: 파일은 쓰지 않았다.')
    return 1 if missing else 0

if __name__ == '__main__':
    raise SystemExit(main())
