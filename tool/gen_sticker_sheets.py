import re, pathlib
doc = pathlib.Path('docs/SCENE_PROMPTS.md').read_text(encoding='utf-8')

# §1.5 앵커 표
anchors = {}
for m in re.finditer(r'^\| `(\w+)` \| [^|]*\| `([^`]+)` \|$', doc, re.M):
    anchors[m.group(1)] = m.group(2)

# §3.x 감정 줄: | id | `assets/stickers/<key>.webp` | `line` | QA |
lines = {}
for m in re.finditer(r'^\| (\w+) \| `assets/stickers/(\w+)\.webp` \| `([^`]+)` \|', doc, re.M):
    emo, key, line = m.group(1), m.group(2), m.group(3)
    char = key.rsplit('_', 1)[0] if emo in ('joy','sulk','shy','surprise') else None
    lines.setdefault(char or key, {})[emo] = (key, line)

SHEET = ("Draw the exact same character as the attached portrait four times in a 2×2 grid on one "
 "square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. "
 "Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. "
 "Top-left: {joy} Top-right: {sulk} Bottom-left: {shy} Bottom-right: {surprise} "
 "Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean "
 "romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. "
 "No text, letters, numbers, logos, watermark, alcohol.")

SOLO_TAIL = ("One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, "
 "plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean "
 "semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm "
 "soft lighting. No text, letters, numbers, logos, watermark, alcohol.")
SOLO_HEAD = ("Redraw the exact same character as the attached portrait as a chat sticker — identical face, "
 "eye shape, hair, outfit and accessories; change only the expression, pose and hands.")

names = {'seoyeon':'서연','daeun':'다은','jiwoo':'지우','sohee':'소희','yeeun':'예은','yuna':'유나',
         'jeongwoo':'정우','haneul':'하늘','seunghyun':'승현','minjae':'민재','geonwoo':'건우','doyun':'도윤'}
order = ['seoyeon','daeun','jiwoo','sohee','yeeun','yuna','jeongwoo','haneul','seunghyun','minjae','geonwoo','doyun']

out = []
fifth = []
for c in order:
    d = lines.get(c, {})
    if not all(e in d for e in ('joy','sulk','shy','surprise')):
        print('MISSING', c, sorted(d)); continue
    body = SHEET.format(**{e: d[e][1] for e in ('joy','sulk','shy','surprise')})
    out.append((c, names[c], anchors[c] + ' ' + body))
    for key, ln in lines.items():
        pass
# 5번째 스티커: 감정 이름이 4종이 아닌 항목
for key, d in lines.items():
    for emo, (fkey, ln) in d.items():
        if emo not in ('joy','sulk','shy','surprise'):
            char = key if key in anchors else fkey.rsplit('_',1)[0]
            fifth.append((fkey, char, SOLO_HEAD + ' ' + anchors[char] + ' ' + ln + ' ' + SOLO_TAIL))

print(f'시트 {len(out)}개, 5번째 {len(fifth)}개')
pathlib.Path('/tmp/sheets.json').write_text(
    __import__('json').dumps({'sheets': out, 'fifth': fifth}, ensure_ascii=False), encoding='utf-8')
