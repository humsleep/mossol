# 장면·사진·스티커 프롬프트 (외부 이미지 생성 도구용)

`docs/overhaul/06_scene_plan.md` 의 샷 리스트 57건과 스티커 52장을 **그대로 생성 도구에 붙여 넣는 문서**다.
초상화 12장을 만든 `docs/PORTRAIT_PROMPTS.md` 와 같은 방식이며, 화풍 문장·캐릭터 앵커는 그 문서에서 가져왔다.
프롬프트 본문은 영어(도구가 영어를 더 정확히 따른다), 설명과 QA 는 한국어다. 이 문서는 코드·JSON 을 고치지 않는다.

## 0. 쓰는 법

> **코드 쪽 준비 완료 (2026-09-24, 개편 4단계 D).**
> 그림을 받을 **자리는 이미 다 비어 있다.** §0.3 이름 그대로 `assets/scenes|photos|stickers|endings/`
> 에 파일을 넣고 다시 빌드하면 그대로 뜬다 — JSON 도 코드도 더 고칠 필요가 없다.
> 자동 인식이 안 되는 전용 사진(`P`)과 공유하는 삽화만 JSON 의 선택 필드(`image` · `photo.image` · `sticker`)로 가리킨다.
> 파일이 하나도 없는 지금은 화면이 예전과 **1px 도 다르지 않다**(카드도 여백도 안 생긴다).
>
> 확인: `python3 tool/check_assets.py` — 이 문서가 기대하는 파일(현재 **114장**)과 `assets/` 를 대조해
> 없는 것 · 남는 것 · 이름·형식이 틀린 것 · 용량 초과를 찍는다(`-v` 로 전부, `--json` 으로 기계용).
> 코드 쪽 규격은 `docs/DESIGN_SYSTEM.md` §2.3.2, 계약은 `docs/overhaul/06_scene_plan.md` §4.

### 0.1 도구 무관 규칙

- **어느 도구든 같은 프롬프트.** Midjourney 는 본문 뒤에 `--ar 3:2 --style raw`(사진 `--ar 4:3`, 스티커 `--ar 1:1`), Stable Diffusion 은 §1.2 의 Avoid 블록을 Negative prompt 칸에 옮기고, DALL-E·Nano-Banana 류 대화형 도구는 본문을 그대로 붙인다. 본문에 이미 비율·크기·금지 항목이 들어 있으니 도구 파라미터는 **중복 지정**일 뿐이다.
- **한 대화 = 한 종류.** 삽화(3:2)·사진(4:3)·엔딩(3:2)은 새 대화 하나에서 연속 생성해도 된다(얼굴이 없어 번짐 위험이 없다). 스티커는 **캐릭터마다 새 대화 + 그 캐릭터의 `assets/portraits/<id>.jpg` 첨부**(§3.0).
- **글자가 하나라도 보이면 재생성.** 이 게임의 소품(간판·노트·달력·영수증·게임 UI)은 거의 글자인데, 생성 글자는 반드시 깨진다. 모든 프롬프트가 "unreadable strokes / blank cells / circles" 로 대체해 두었다. 흐릿한 가짜 글자도 불합격이다(§4).
- **얼굴 금지.** 삽화·사진·엔딩에 얼굴이 나오면 불합격. 손·뒷모습·실루엣·소품만. 얼굴은 스티커에서만, 스티커는 초상화에서 파생한다.

### 0.2 생성 순서 (배치)

| 배치 | 내용 | 파일 수 |
|---|---|---|
| **1 (P0)** | S01 · S03 · S09 · S11 · S13 · P01 · P02 · P05 · P06 · P11 · Pi01 · Pi02 · Pi03 · Pi04 · E04 · E07 · E08 | 17 |
| **2 (P0 스티커)** | 배치 1 에 등장한 캐릭터부터: 서연 · 지우 · 민재 · 예은 · 하늘 · 정우 · 다은 (각 4장, 5번째 있는 사람은 5장) | 30 |
| 3 (P1) | S02 · S04~S08 · S14 · S15 · P03 · P04 · P07 · P09 · P10 · P12 · P14 · P15 · Pi05~Pi09 · E01 · E02 · E03 · E05 · E06 · E09~E12 | 32 |
| 4 (P1 스티커) | 나머지 5명: 소희 · 유나 · 승현 · 건우 · 도윤 | 22 |
| 5 (P2) | S10 · S12 · S16 · S17 · P08 · P13 · Pi10(5장) · E13 · E14 · E15 | 14 |

배치 1 이 들어가면 테스터가 첫 이틀과 첫 모먼트에서 그림을 본다. 배치 1 없이 배치 3 을 먼저 만들지 않는다.

### 0.3 파일 이름 (06_scene_plan §4 데이터 계약 그대로)

| 종류 | 경로 | 비고 |
|---|---|---|
| 삽화 `S` | `assets/scenes/<event id>.webp` | 필드 없이 자동 인식. S01 은 `m01`, S02 는 `m02`, 나머지는 모먼트 id |
| 사진 전용 `P` | `assets/photos/<event id>_0.webp` | **자동 인식 안 됨.** 작가가 그 사진 줄에 `"image": "assets/photos/<event id>_0.webp"` 를 넣는다 (`_0` = 그 이벤트의 첫 `them` 사진) |
| 사진 공용 `Pi` | `assets/photos/<icon>.webp` | 필드 없이 자동. `sky` 의 달 변형만 `assets/photos/sky_moon.webp` 로 두고 `image` 필드로 지정 |
| 엔딩 `E` | `assets/endings/<character id>.webp` / 공용 `assets/endings/common_<tier>.webp` | 캐릭터당 1장을 엔딩 4~5개가 공유. 공용은 `common_solo` · `common_bad` · `common_hidden` |
| 스티커 | `assets/stickers/<char>_<emotion>.webp` | `emotion` = `joy` `sulk` `shy` `surprise`. 5번째는 계약의 화이트리스트 id 그대로 `daeun_blank` `sohee_call` `jeongwoo_haha` `seunghyun_sure` (파일도 이 이름) |

모두 **영문 소문자·언더스코어**, 하위 폴더 없음. 원본 PNG 는 저장소 밖(`~/Pictures/mossol_scenes/<종류>/`)에 같은 이름으로 보관한다.

### 0.4 내보내기 크기와 webp 변환

| 종류 | 생성 크기 | 번들 크기 | 목표 용량 | 알파 |
|---|---|---|---|---|
| 삽화 · 엔딩 | 1536×1024 (3:2) | **1200×800** | ~120KB | 없음 |
| 사진 | 1024×768 (4:3) | **800×600** | ~60KB | 없음 |
| 스티커 | 1024×1024 (1:1) | **384×384** | ~25KB | **있음** |

```sh
brew install webp imagemagick          # cwebp, magick

SRC=~/Pictures/mossol_scenes; DST=~/workspace/mossol/assets
# 삽화·엔딩 3:2 → 1200×800
for f in $SRC/scenes/*.png;   do cwebp -q 82 -resize 1200 800 "$f" -o $DST/scenes/$(basename "${f%.png}").webp; done
for f in $SRC/endings/*.png;  do cwebp -q 82 -resize 1200 800 "$f" -o $DST/endings/$(basename "${f%.png}").webp; done
# 사진 4:3 → 800×600
for f in $SRC/photos/*.png;   do cwebp -q 80 -resize 800 600 "$f" -o $DST/photos/$(basename "${f%.png}").webp; done
# 스티커 1:1 알파 → 384×384 (투명 PNG 가 입력이어야 한다. §3.0)
for f in $SRC/stickers/*.png; do cwebp -q 85 -alpha_q 90 -exact -resize 384 384 "$f" -o $DST/stickers/$(basename "${f%.png}").webp; done

# 확인: 크기·용량
magick identify -format "%f %wx%h %[channels]\n" $DST/scenes/*.webp $DST/photos/*.webp $DST/stickers/*.webp $DST/endings/*.webp
du -ch $DST/scenes $DST/photos $DST/stickers $DST/endings | tail -1     # 1차 113장 ≈ 11MB 이내
```

생성 도구가 3:2 를 정확히 안 주면(예: 1536×1024 대신 1536×1152) `magick in.png -gravity center -crop 3:2 +repage out.png` 로 **중앙 크롭** 후 변환한다. 4:3, 1:1 도 같다.

---

## 1. 전역 블록

아래 블록은 §2·§3 의 모든 프롬프트에 **이미 들어가 있다**. 프롬프트를 고칠 때 이 블록의 문장은 지우지 않는다.

### 1.1 화풍 문장 (잠금 — PORTRAIT_PROMPTS §5 의 영어판, 모든 프롬프트 맨 끝)

```
Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting.
```

- 사진 메시지도 이 화풍이다. **포토리얼로 가지 않는다.** 폰카 느낌은 구도(기울기·흔들림·역광·플레어)로만 낸다. 초상화(웹툰풍)와 사진(실사)이 한 화면에 섞이면 세계가 둘로 갈라진다.
- 한국어 원문(초상화 문서): "깔끔한 반실사 디지털 일러스트, 가는 외곽선, 부드러운 셀 채색, 따뜻하고 부드러운 조명".

### 1.2 금지 블록 (Avoid — 모든 프롬프트 끝 문장. SD 계열은 Negative prompt 칸에)

```
No text, letters, numbers, logos, watermark, visible faces, alcohol.
```

Negative prompt 칸이 따로 있는 도구용 확장판:

```
text, letters, numbers, signage, logo, brand, watermark, signature, caption, UI, face, portrait, eyes, mouth,
alcohol, beer, soju, wine, cigarette, photorealistic, photograph, 3D render, extra fingers, deformed hands,
large white background, blown-out highlights, school uniform, child, nudity, tight clothing, muscle emphasis
```

스티커에서는 `face, portrait, eyes, mouth` 를 **빼고** `floor shadow, background, border, speech bubble` 을 넣는다.

### 1.3 종류별 프레이밍 블록

| 종류 | 블록 (프롬프트 본문에 포함) |
|---|---|
| **scene** 3:2 | `3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas.` |
| **photo** 4:3 | `Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette.` |
| **ending** 3:2 | `3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas.` |
| **sticker** 1:1 | `One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background to be keyed out, no floor shadow, no border, no speech bubble.` |

- 삽화·엔딩은 넓은 화면에서 위아래 10% 가 잘릴 수 있어 "central 80%" 를 넣었다. 통화 배경으로 쓰일 때는 코드가 30% 어둡게 얹는다.
- 엔딩은 tier 를 코드가 색으로 바꾼다(bad = 채도 낮춤, hidden = 세피아). 그림 한 장이 4~5개 엔딩을 견뎌야 하므로 **정물·중간 명도**로 잡았다.
- 다크 모드는 코드가 12% 어둡게 얹는다. 흰 배경 큰 면적 금지.

### 1.4 주인공 블록 (삽화·사진에 "나" 가 나올 때)

```
The protagonist appears only as hands, back view or silhouette: medium-length hair covering the ears, plain neutral grey hoodie or shirt, no nail polish, no jewelry, no gender cues.
```

### 1.5 캐릭터 앵커 블록 12개 (스티커용 — PORTRAIT_PROMPTS §1.1~1.4 의 영어판)

스티커 프롬프트는 이 블록을 **그대로** 포함한다. 초상화 문서의 교훈: 액세서리만 바꾸면 인물이 서로 바뀌므로 **얼굴상·눈·코·입·얼굴형(정체성 속성)을 매번 실어야** 한다. 소품은 표에 있는 것만 쓴다(06_scene_plan §3-4).

| id | 강조색 base(라이트) | 앵커 블록 |
|---|---|---|
| `seoyeon` | 연보라 `#6B4BA8` | `Korean woman, 25, fox-like face: small narrow hidden-crease eyes sharply upturned, thin lips, long slim oval face with pointed chin, cool pale ivory skin, small mole under left eye, burgundy matte lips. Waist-length jet-black straight hair, center part, no bangs, one side tucked behind ear. Charcoal oversized knit cardigan over white tee, thin silver necklace.` |
| `daeun` | 자두 `#8B3C78` | `Korean woman, 23, soft flat squarish face, small monolid eyes with no crease set horizontal, low short nose, small mouth with full lower lip, pale clear bare skin, small mole above right mouth corner, no makeup. Ash-grey-brown blunt bob above the jawline, top section messily pinned up with a black ballpoint pen, long side-swept bangs. White shirt with rolled sleeves, plain beige canvas apron, pencil behind ear.` |
| `jiwoo` | 산호 `#B5442A` | `Korean woman, 29, cat-like face: large upturned almond eyes with thin outer crease, amber-brown irises, black winged eyeliner, high nose bridge, defined cheekbones, inverted-triangle face, nude beige lips. Dark chestnut hair in a neat low bun at the nape, deep side part, one loose strand. Navy tailored jacket over ivory blouse buttoned high, pearl earrings.` |
| `sohee` | 오션 블루 `#005A82` | `Korean woman, 24, heart-shaped face, very large round eyes with wide deep double eyelids, short upturned nose, big mouth with two slightly prominent front teeth, freckles on the nose, rosy cheeks, red tinted lips. Shoulder-length layered wolf cut with straight bangs above the brows, milk-brown with teal inner color. Light-grey oversized hoodie, plain white headset around the neck.` |
| `yeeun` | 연두 `#3F6B3A` | `Korean woman, 26, round face with full chubby cheeks, medium round eyes with inline crease and puffy under-eye, slightly downturned, warm brown irises, short round nose, small plump lips, wide coral blush, two small moles on left cheekbone. Chest-length copper-auburn waves in one loose braid over the shoulder, curtain bangs. Sage-green V-neck cardigan over a high-neck cream tee, small gold earrings.` |
| `yuna` | 비취 `#1D6A53` | `Korean woman, 28, diamond face with high cheekbones and angular jaw, monolid horizontally long eyes clearly downturned, very wide mouth, sun-tanned bronze skin with freckles on nose and cheekbones, no makeup. High ponytail at the crown, full forehead shown, dark brown hair with lighter brown ombre ends. Plain jade-green track jacket zipped to the neck, stopwatch on a black cord.` |
| `jeongwoo` | 모카 `#7F553C` | `Korean man, 25, deer-like face: large moist eyes with thin outer crease and puffy under-eye, clearly downturned, big dark-brown irises, long narrow nose, thin wide lips, long oval face and long neck, fair skin, ears that blush easily. Ear-covering slightly wavy black hair with neat brow-covering bangs. Thin round metal glasses, crisp light-blue oxford shirt buttoned to the collar.` |
| `haneul` | 청록 `#0F6F73` | `Korean man, 24, long strong-jawed face with wide cheekbones, monolid horizontally long eyes slightly upturned, thick straight dark brows, big broad nose, very large mouth with thick lips and big even teeth, healthy mid-tone skin with flushed cheeks. Short two-block cut, bleached light brown with dark grown-out roots, bangs pushed up. Black short-sleeve tee, indigo denim apron, red-white checked dish towel on the shoulder.` |
| `seunghyun` | 라벤더 그레이 `#6A5779` | `Korean man, 29, wolf-like face: small narrow sharp monolid eyes in deep sockets, upturned, short thick straight brows set low, straight high nose, thin straight lips, symmetrical oval face with a sharp jawline, cool pale skin. Very neat short black hair, 7:3 side part, bangs combed aside. White doctor's coat over light-grey shirt, silver stethoscope around the neck.` |
| `minjae` | 인디고 `#3A5BC7` | `Korean man, 23, narrow long face with hollow cheeks and pointed chin, medium roundish hidden-crease eyes clearly downturned, faint dark circles, grey-brown irises, thin low nose, small mouth with full lower lip, pale smooth skin. Nape-length naturally messy black curls, bangs down to the eyebrows with eyes visible, no hat. Dark navy zip-up hoodie, hood down.` |
| `geonwoo` | 로즈우드 `#874957` | `Korean man, 26, small round face with plump cheeks and round chin, large round eyes with wide deep double eyelids slightly upturned, light-brown irises, short round nose, wide mouth with a left snaggletooth, deep dimples on both cheeks, warm lightly tanned skin. Voluminous natural-brown center-parted perm pushed up. Beige cardigan over a small-check shirt, chalk dust on the sleeves.` |
| `doyun` | 슬레이트 `#4A6572` | `Korean man, 27, bear-like face: wide thick rounded-square face, thick neck, small round gentle eyes with thin inline crease slightly downturned, thick bushy brows, big thick nose, full lips, bronze olive skin, short neatly trimmed jawline beard, thin old scar under left jaw. Very short black buzz cut with skin fade. Charcoal half-zip training top zipped to the neck, white towel around the neck.` |

삽화·사진·엔딩에서 캐릭터의 **존재만** 남길 때의 소품(얼굴 없이): 서연 허리 흑발·차콜 카디건 / 다은 볼펜·앞치마·연필 / 지우 네이비 재킷·진주·서류 / 소희 흰 헤드셋·연회색 후드 / 예은 땋은 적갈색 머리·세이지 카디건 / 유나 하이 포니·비취 트레이닝·형광 머리끈 / 정우 원형 안경·칼각 셔츠·열쇠 꾸러미 / 하늘 데님 앞치마·체크 행주 / 승현 흰 가운·청진기·강아지 털 / 민재 네이비 후드·헤드셋·모니터 빛 / 건우 베이지 카디건·분필 가루 / 도윤 차콜 트레이닝·흰 수건·버즈컷 뒷모습.

---

## 2. 샷 리스트 프롬프트 (57건)

형식: **id → 파일 → 의도(한 줄) → 영어 프롬프트(완결, ≤90 단어) → QA(이러면 불합격)**.
S = 삽화 3:2, P = 사진 전용 4:3, Pi = 사진 공용 4:3, E = 엔딩 히어로 3:2.

### 2.1 삽화 S01~S17

#### S01 · `assets/scenes/m01.webp` · P0
자취방 책상, 엎어 둔 폰의 알림 불빛, 거울 귀퉁이에 잘린 내 어깨. 게임의 첫 그림.
```
First-person view of a small studio-apartment desk at night: a phone face-down with its notification light glowing, a half-closed laptop, a mug, a desk lamp; in one corner a small mirror reflects only a cropped shoulder in a plain neutral grey hoodie, no face. Faint violet phone glow, neutral warm palette. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 거울에 얼굴·머리 길이 단서가 보이면 불합격. 폰 화면에 UI·글자가 보이면 불합격.

#### S02 · `assets/scenes/m02.webp` · P1
강의실 뒷자리, 폰 두 대, 태현의 손이 내 폰을 가리킴.
```
Back row of a university lecture hall seen from the protagonist's seat: two phones side by side on a long desk, a young man's hand with a rolled sleeve pointing at the left phone whose screen shows only blurred light, notebooks, afternoon window light, rows of empty seats ahead, no faces. Neutral palette. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 폰 화면에 앱 UI 가 그려지면 불합격. 손가락 6개 확인.

#### S03 · `assets/scenes/mo_seoyeon_call_eleven.webp` · P0
밤 11시 동아리방, 불 꺼진 창가에 켜진 폰 화면 하나. 서연의 첫 전화 배경.
```
University club room at 11 p.m., lights off: a dark window with faint city glow, one phone screen lit on the table beside a stack of blank papers, a charcoal oversized knit cardigan draped over a chair back, a mug, dim violet #6B4BA8 tint in the window light, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 사람이 그려지면 불합격. 통화 화면에서 30% 어둡게 얹어도 폰 불빛이 보이는지.

#### S04 · `assets/scenes/mo_seoyeon_call_dawn.webp` · P1
낯선 도시의 호텔 창, 새벽, 차 소리 없는 거리. 거리감이 주제.
```
Hotel-room window in an unfamiliar foreign city before dawn: a silent empty street below with dim street lamps and no cars, curtains half open, a phone glowing on the windowsill, a small suitcase, soft violet-blue #6B4BA8 predawn sky, quiet distant mood, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 거리 간판에 글자가 생기면 불합격. 차·사람이 있으면 불합격(조용함이 주제).

#### S05 · `assets/scenes/mo_seoyeon_seen_you.webp` · P1
도서관 앞 계단, 멀리서 본 두 사람의 뒷모습. 서연의 질투를 관찰자 시점으로.
```
Library steps at dusk, seen from far across the plaza: two people small in frame walking up side by side, backs to the viewer, one in a plain grey hoodie with medium ear-covering hair; in the foreground a blurred charcoal cardigan sleeve and a strand of long black hair, violet #6B4BA8 sky. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 두 사람 중 하나라도 얼굴이 돌아 있으면 불합격. 전경의 관찰자가 얼굴까지 나오면 불합격.

#### S06 · `assets/scenes/mo_haneul_call_night_shift.webp` · P1
새벽 2시 편의점 카운터 안쪽, 폐기 봉투와 폰. 형광등 아래 혼자.
```
Convenience-store counter at 2 a.m. from the clerk's side: a clear bag of expired sandwiches with blank round stickers, a phone screen-up, a red-white checked dish towel, harsh fluorescent light with a teal #0F6F73 tint, empty aisles and a dark glass door beyond, no people, no readable packaging. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 진열대에 브랜드·글자·술병이 보이면 불합격.

#### S07 · `assets/scenes/mo_haneul_preview_manager.webp` · P1
카페 백룸, 앞치마 두 벌 나란히, 점장 사무실 문틈 빛. "우리 사귀냐고 물어봄".
```
Café back room: two aprons hanging side by side on a wall hook, one indigo denim and one plain neutral grey, a strip of warm light from an office door left ajar, shelves of blank cardboard boxes, a mop and bucket, teal #0F6F73 tinted fluorescent shadows, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 앞치마가 두 벌이 아니거나 둘 다 데님이면 불합격. 박스에 글자가 있으면 불합격.

#### S08 · `assets/scenes/mo_jiwoo_call_taxi.webp` · P1
택시 뒷좌석, 창에 흐르는 야간 도심 불빛, 서류 가방. 켄번즈가 가장 잘 어울리는 장면.
```
Taxi back seat at night, passenger's viewpoint: a rain-streaked window with streaming city lights in warm coral and amber #B5442A, a leather briefcase on the seat, a navy tailored jacket folded beside it, a woman's hand holding a phone at the frame edge, the driver's headrest as a dark silhouette, no faces. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 백미러에 얼굴이 비치면 불합격. 창밖 간판 글자 불합격.

#### S09 · `assets/scenes/mo_jiwoo_call_eve.webp` · P0
새벽 사무실, 서류 더미 위 식은 커피, 창밖 여명. 기일 전날의 무게.
```
Empty law office at dawn: a desk buried in stacks of blank documents, a cold half-finished paper coffee cup, a navy jacket over the chair, a desk lamp still on, a small photo frame turned face-down, a wide window with pale coral-grey #B5442A dawn over the city, heavy still mood, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 서류에 읽히는 글줄이 있으면 불합격. 액자가 세워져 얼굴이 보이면 불합격.

#### S10 · `assets/scenes/mo_jiwoo_preview_lookalike.webp` · P2
법원 앞 횡단보도, 인파 속 한 사람의 뒷모습. "그쪽이랑 똑같이 생긴 사람".
```
Crosswalk in front of a courthouse at midday: a crowd crossing away from the viewer, all seen from behind with slight motion blur, one person in a plain neutral grey hoodie with medium ear-covering hair slightly isolated at the center, courthouse steps and columns ahead, soft coral #B5442A warm light, no faces. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 누구든 얼굴이 보이면 불합격. 법원 현판 글자 불합격.

#### S11 · `assets/scenes/mo_minjae_call_offgame.webp` · P0
어두운 방, 모니터 불빛에 비친 헤드셋과 폰. 민재의 세계는 모니터 빛뿐.
```
Dark bedroom lit only by a monitor: the screen shows abstract glowing color shapes with no interface, a black gaming headset resting on the desk, a phone face-up glowing beside the keyboard, an empty cup-ramen container, a navy hoodie sleeve at the frame edge, indigo-blue #3A5BC7 glow on everything, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 모니터에 게임 UI·글자·실존 게임 화면이 있으면 불합격. 헤드셋 로고 불합격.

#### S12 · `assets/scenes/mo_minjae_preview_clip.webp` · P2
게임 길드 채널을 보는 폰(UI 글자 없이 빛과 색만).
```
Close-up of a phone held in a neutral hand, its screen showing an abstract game-guild chat as glowing colored bars and bright shapes with no letters; behind it a dark desk with a gaming headset and an indigo-blue #3A5BC7 monitor glow out of focus, no faces. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 화면에 읽히는 글자·아이콘·실존 앱 UI 가 있으면 불합격. 손톱 장식 불합격.

#### S13 · `assets/scenes/mo_yeeun_call_letter.webp` · P0
열린 서랍, 빛바랜 편지 봉투, 스탠드 불빛. 예은 루트의 핵심 소품.
```
An open wooden desk drawer under a brass lamp: a faded cream envelope, unsealed with its flap slightly lifted and nothing written on it, a pressed flower, a hair tie with a sage-green ribbon, old pencils, sage-green #3F6B3A tint in the shadows, warm nostalgic mood, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 봉투에 주소·이름·우표 글자가 있으면 불합격.

#### S14 · `assets/scenes/mo_yeeun_preview_dream.webp` · P1
빈 초등학교 교실, 어른 크기의 그림자 둘이 작은 책상에. "6학년 3반인데 우리가 지금 나이야".
```
Empty elementary-school classroom at dusk, dreamlike: rows of small wooden desks, two adult-sized long shadows cast onto two neighboring small desks, a chalkboard wiped blank, green #3F6B3A afternoon light through the windows, dust in the air, no people, no writing anywhere. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 칠판에 글자·숫자, 벽에 시간표가 생기면 불합격. 그림자가 사람으로 그려지면 불합격.

#### S15 · `assets/scenes/mo_doyun_call_mirror.webp` · P1
불 꺼진 헬스장, 거울에 비친 비상등, 흰 수건. "트레이너 말고".
```
Gym after closing with the lights off: a large wall mirror reflecting only a red emergency exit lamp and dark equipment silhouettes, a white towel folded on a bench, dumbbells racked, faint slate-blue #4A6572 light from the street window, no people, no brand names on equipment. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 거울에 사람이 비치면 불합격. 비상등에 글자·픽토그램이 뚜렷하면 불합격.

#### S16 · `assets/scenes/mo_doyun_preview_absent.webp` · P2
헬스장 접수대, 빈 칸뿐인 출석판, 러닝머신. "오늘 왜 안 왔어요".
```
Gym reception desk in the morning: an attendance board on the wall as an empty grid with a few round stickers and one row conspicuously blank, a treadmill behind, a white towel on the counter, a stopwatch on a black cord, slate-blue #4A6572 tint, no people, no letters or numbers on the board. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 출석판에 이름·날짜가 생기면 불합격. 러닝머신 화면에 숫자 불합격.

#### S17 · `assets/scenes/mo_daily_taehyun_dawn.webp` · P2
새벽 3시 태현의 방, 라면 냄비, 형광펜 그은 노트(글자 없이). 연애론 개그.
```
A young man's messy room at 3 a.m.: a small ramen pot with chopsticks resting across it, an open notebook covered in neon-highlighter strokes that are unreadable scribbles, a desk lamp, a phone propped against a mug, crumpled paper, warm neutral palette, no people. 3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 노트의 획이 글자로 읽히면 불합격. 캔·병 술이 있으면 불합격.

### 2.2 사진 전용 P01~P15 (4:3, `photo.image` 필드로 지정)

#### P01 · `assets/photos/mo_seoyeon_photo_night_0.webp` · P0
동아리방 창밖 야경, 창틀에 비친 과제 노트 귀퉁이. 서연이 보낸 첫 사진.
```
Night view from a university club-room window: city lights below, the window frame at one edge, the corner of an assignment notebook faintly reflected in the glass with only unreadable pen strokes, violet #6B4BA8 tint on the night, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 유리 반사에 얼굴이 비치면 불합격. 노트 글자 불합격.

#### P02 · `assets/photos/mo_haneul_photo_sandwich_0.webp` · P0
폐기 스티커 붙은 샌드위치 두 개, 편의점 카운터. "하나 너 거".
```
Two triangular sandwiches in clear wrap on a convenience-store counter, each with a blank round discount sticker, a corner of a red-white checked dish towel, cool fluorescent light with teal #0F6F73 tint, top-down angle, no readable packaging, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 샌드위치가 두 개가 아니면 불합격(숫자가 고백이다). 포장 글자 불합격.

#### P03 · `assets/photos/mo_haneul_photo_profile_0.webp` · P1
앞치마 둘, 흔들린 역광, 얼굴은 프레임 밖. 프사 바꿨다는 사진.
```
Backlit, motion-blurred snapshot of two people in aprons standing close, one indigo denim and one plain neutral grey, framed from the shoulders down to the knees so heads are out of frame, bright café window behind, lens flare, teal #0F6F73 tint, no faces. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 턱·입이라도 프레임에 들어오면 불합격.

#### P04 · `assets/photos/mo_jiwoo_photo_dinner_0.webp` · P1
서류 더미 옆 식은 김밥 한 줄, 형광등. 지우의 밤 10시.
```
One roll of kimbap, cold, in a plastic tray on an office desk beside a stack of blank documents, a paper coffee cup, chopsticks, flat fluorescent light with coral #B5442A tinted shadows, top-down angle, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 서류에 글줄이 읽히면 불합격. 김밥이 두 줄 이상이면 불합격(혼자 먹는 밤).

#### P05 · `assets/photos/mo_minjae_photo_ramen_0.webp` · P0
모니터 불빛 옆 컵라면, 프레임 끝에 손. "손 나온 건 실수 아님".
```
Steaming cup ramen on a desk next to the glowing edge of a monitor showing only abstract color, chopsticks, and at the frame edge a young man's hand in a navy hoodie sleeve, slightly cropped, indigo-blue #3A5BC7 glow, no faces. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 손이 없거나 손가락이 이상하면 불합격(손이 첫 노출). 컵라면 브랜드 불합격.

#### P06 · `assets/photos/mo_minjae_photo_shadow_0.webp` · P0
편의점 앞 아스팔트, 나란한 두 그림자. 엔딩 E04 와 짝.
```
Asphalt in front of a convenience store at night, viewed downward: two long shadows side by side cast by the store light, both people's sneakers at the bottom edge, one pair worn black and one plain grey, indigo-blue #3A5BC7 tinted pavement, no faces, no store signage. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 그림자가 나란하지 않고 마주 보면 불합격(그건 E04). 사람 몸이 무릎 위까지 나오면 불합격.

#### P07 · `assets/photos/mo_yeeun_photo_snackbar_0.webp` · P1
학교 앞 분식집 낡은 간판(글자 대신 빛바랜 그림·색), 파란 천막. "이거 아직 있어!!"
```
Old snack bar in front of an elementary school: a weathered sign with faded painted food shapes and peeling color but no letters, a blue tarpaulin awning, a plastic table with red plastic stools, warm afternoon light, sage-green #3F6B3A tint in the shadows, nostalgic, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 간판·메뉴판에 한글·숫자 비슷한 획이라도 있으면 불합격.

#### P08 · `assets/photos/mo_yeeun_photo_picnic_0.webp` · P2
빛바랜 소풍 단체 사진, 사람은 멀리 작게, 앞줄 둘만 어깨가 붙음. 12살 얼굴은 그리지 않는다.
```
A faded, yellowed old group photo lying on a table, itself photographed with a phone: a spring meadow, a class of children far away and tiny with faces as indistinct blurs, two in the front row with shoulders touching, sun flare, worn edges, green #3F6B3A tint. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 아이 얼굴이 하나라도 식별되면 불합격. 사진 속 현수막 글자 불합격.

#### P09 · `assets/photos/mo_doyun_photo_run_0.webp` · P1
해 뜨기 직전 강변, 러닝 트랙, 입김. `sky` 공용의 기준.
```
Riverside running track just before sunrise: a pale orange horizon, mist over the water, a stretch of rubber track, a puff of breath in the cold air at the frame edge with no face, slate-blue #4A6572 predawn shadows, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 러닝하는 사람 실루엣이 얼굴까지 나오면 불합격.

#### P10 · `assets/photos/mo_doyun_photo_journal_0.webp` · P1
운동 일지 마지막 장, 손글씨 획과 밑줄만, 펜. "이건 기록 아니에요".
```
Close-up of the last page of a worn training journal: handwriting rendered as unreadable scribbled strokes with one line underlined, a ballpoint pen across the page, visible paper texture, warm desk light, slate-blue #4A6572 tint, no legible words or numbers. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 획이 글자로 읽히거나 숫자·표가 있으면 불합격.

#### P11 · `assets/photos/mo_daily_mom_banchan_0.webp` · P0
테이프 칭칭 감은 반찬통 택배, 현관.
```
A delivery box wrapped many times in brown packing tape on an apartment entrance floor, lid slightly open showing stacked plastic side-dish containers, a pair of shoes nearby, warm hallway light, neutral palette, no shipping label text, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 송장·택배 라벨에 글자가 있으면 불합격.

#### P12 · `assets/photos/mo_daily_unknown_photo_0.webp` · P1
카페 창가 자리, 뒷모습 한 사람, 살짝 흔들림. "이거 너 맞지?"
```
Café window seat from behind: one person in a plain neutral grey hoodie with medium ear-covering hair, back to the camera, looking out the window, a coffee cup on the table, slight motion blur, afternoon light, neutral palette, no face, no gender cues. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 창 반사에 얼굴이 비치거나 머리 길이·옷이 성별을 암시하면 불합격.

#### P13 · `assets/photos/mo_daily_group_photo_0.webp` · P2
조별과제 단체 사진, 전원 역광 실루엣, 한 명만 고개 숙임. "나만 눈 감음".
```
Group photo of a student project team, five people strongly backlit into flat silhouettes against a bright window, one in the middle with head bowed, slightly blurred, neutral palette, no facial features on anyone. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 실루엣 안에 눈·입이 그려지면 불합격.

#### P14 · `assets/photos/mo_daily_taehyun_story_0.webp` · P1
커피 두 잔, 맞은편 테두리에 걸린 손. 태현의 캡처.
```
Café table from above: two coffee cups, one across the table with a hand resting on its rim just inside the frame edge, wooden table, warm light, framing slightly cropped like a screenshot, neutral palette, no face. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 손이 없으면 불합격(손 하나가 이야기 전체). 손가락 수 확인.

#### P15 · `assets/photos/mo_daily_dad_sky_0.webp` · P1
흔들린 퇴근길 노을, 차창 반사. "아빠의 첫 사진".
```
Blurry, shaky commute sunset shot through a car window: orange-pink sky, faint dashboard reflection, road lights streaking, one overexposed corner, noticeably tilted, neutral warm palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 너무 잘 찍힌 사진이면 불합격(서툰 흔들림이 주제). 표지판 글자 불합격.

### 2.3 사진 공용 Pi01~Pi10 (4:3, `assets/photos/<icon>.webp`, 중립색 — 코드가 강조색 틴트를 얹는다)

#### Pi01 · `assets/photos/book.webp` · P0
빈 노트 펼침, 펜, 스탠드. `me` 답장 8건.
```
An open blank notebook on a desk with a ballpoint pen lying across it, a small desk lamp, faint paper texture, warm neutral palette, no writing at all, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 노트에 줄 외의 획이 있으면 불합격.

#### Pi02 · `assets/photos/food.webp` · P0
야식 한 그릇(라면·떡볶이 어느 쪽으로도 읽히게), 폰 불빛.
```
A single bowl of late-night food that could read as either ramen or tteokbokki: red-orange broth, noodles and rice cakes mixed, chopsticks, a phone glowing beside the bowl on a small table, warm neutral palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 컵라면 포장 브랜드가 보이면 불합격. 그릇이 둘이면 불합격.

#### Pi03 · `assets/photos/street.webp` · P0
밤 골목, 가로등, 운동화 한 켤레 프레임 아래.
```
A quiet night alley with one street lamp, wet asphalt reflecting the light, a pair of plain sneakers at the bottom edge of the frame, neutral cool palette, no signage, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 운동화 로고 불합격. 가게 간판 글자 불합격.

#### Pi04 · `assets/photos/selfie.webp` · P0
흔들린 역광 실루엣 하나, 렌즈 플레어. 얼굴 금지 원칙의 공용 해법.
```
A single motion-blurred backlit silhouette of head and shoulders against a bright window, strong lens flare washing out all features, medium-length hair shape only, neutral palette, no facial features, no gender cues. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 눈·입이 조금이라도 보이면 불합격.

#### Pi05 · `assets/photos/cafe.webp` · P1
창가 커피 한 잔, 창밖 흐림.
```
One coffee cup on a café window table, the street outside soft and out of focus, afternoon light, wooden table, neutral warm palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 컵에 로고, 창밖 간판 글자 불합격.

#### Pi06a · `assets/photos/sky.webp` · P1
옥상 노을 (기본 `sky`).
```
Rooftop sunset over apartment blocks, a railing at the bottom edge, warm orange-pink sky fading to violet, a few clouds, neutral palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 하늘이 화면의 90% 이상이라 다크 모드에서 밋밋하면 난간 비중을 올려 재생성.

#### Pi06b · `assets/photos/sky_moon.webp` · P1
창밖 달 (변형, `image` 필드로 지정).
```
The moon seen through a bedroom window at night, a curtain edge on one side, dark blue sky, faint window frame reflection, neutral cool palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 달이 지나치게 크면(만화적) 불합격.

#### Pi07 · `assets/photos/pet.webp` · P1
담요 속 강아지, 하품.
```
A small fluffy dog wrapped in a knit blanket on a sofa, mid-yawn, warm indoor light, neutral palette, no people, no collar tag. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 목걸이 이름표 글자 불합격.

#### Pi08 · `assets/photos/night.webp` · P1
창밖 야경, 창틀.
```
City night lights seen through a window, window frame on two sides, a faint reflection of a dark room, neutral cool palette, no people, no readable signs. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 반사에 얼굴 불합격.

#### Pi09 · `assets/photos/gym.webp` · P1
불 꺼진 헬스장, 거울.
```
A dark gym after hours: a large mirror reflecting equipment silhouettes and one small emergency light, a folded towel on a bench, neutral cool palette, no people, no brand names. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 거울 속 사람 불합격.

#### Pi10 · 5장 · P2 (규격의 14종을 채우는 용도)

`assets/photos/music.webp`
```
A recording-booth microphone with a pop filter on a stand, a pair of headphones hung beside it, warm booth light, dark acoustic foam behind, neutral palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
`assets/photos/ticket.webp`
```
A paper wall calendar page as an empty grid with no numbers or words, one cell circled in red marker, a pen beside it, warm light, neutral palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
`assets/photos/flower.webp`
```
A faded old photo of a spring meadow with tiny distant figures as indistinct dots, worn white edges, sun flare, soft green and cream tones, no faces. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
`assets/photos/sea.webp`
```
A beach at dusk, gentle waves, a line of footprints leading away toward the water, soft blue-grey and peach sky, neutral palette, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
`assets/photos/game.webp`
```
A generic game controller resting on a desk under colored monitor glow, the screen out of frame, a headset beside it, dark room, neutral cool palette, no logos, no people. Illustrated handheld phone snapshot, 4:3, 1024×768, slightly tilted framing, mid-tone palette. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA(5장 공통): 달력 숫자·컨트롤러 로고·현수막 글자가 있으면 불합격. 실존 콘솔 형태를 그대로 닮으면 불합격.

### 2.4 엔딩 히어로 E01~E15 (3:2, 캐릭터당 1장, tier 는 코드가 색으로)

#### E01 · `assets/endings/seoyeon.webp` · P1
동아리방 책상, 다이어리의 빈 토요일 칸, 창밖 야경.
```
Club-room desk at night: an open weekly diary as an empty grid with one column left conspicuously blank, a fountain pen, a charcoal knit cardigan on the chair, a mug, city night through the window in violet #6B4BA8, no people, no letters or numbers. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 다이어리에 날짜·요일 글자가 있으면 불합격. 채도를 낮췄을 때(bad) 여전히 소품이 읽히는지.

#### E02 · `assets/endings/haneul.webp` · P1
국밥집 테이블, 계산서를 집는 손, 벽의 낙서 가득한 계획표.
```
Gukbap restaurant table after a meal: two empty bowls, a hand in a rolled black sleeve reaching for a small bill slip, a checked towel at the frame edge, a wall covered in scribbled doodles and a hand-drawn plan chart with no readable words, teal #0F6F73 accent, no faces. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 벽 낙서가 글자로 읽히거나 계산서에 숫자가 있으면 불합격. 술병 불합격.

#### E03 · `assets/endings/jiwoo.webp` · P1
캘린더의 첫 빈칸, 명함 한 장, 커피 두 잔.
```
Office desk in morning light: a monthly desk calendar as an empty grid with the first cell left blank, a single business card lying face-down, two coffee cups side by side, a navy jacket sleeve on the chair, coral #B5442A tinted light, no people, no text. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 명함이 앞면(글자)이면 불합격. 커피가 한 잔이면 불합격.

#### E04 · `assets/endings/minjae.webp` · P0
편의점 앞, 두 그림자가 이번엔 마주 봄. P06 의 보상.
```
Night in front of a convenience store, viewed downward: two long shadows on the asphalt now facing each other, both people's sneakers at the bottom edge, store light spilling out, a navy hoodie hem at the frame edge, indigo-blue #3A5BC7 pavement, no faces, no store signage. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 그림자가 나란하면 불합격(그건 P06). 몸이 허리 위까지 나오면 불합격.

#### E05 · `assets/endings/yeeun.webp` · P1
분식집 테이블 두 그릇, 옆자리, 개봉한 편지 봉투.
```
Snack-bar table: two bowls of tteokbokki side by side, two red plastic stools pulled close together, an opened cream envelope with a blank letter half pulled out, a blue tarpaulin awning edge above, sage-green #3F6B3A tint, no people, no writing. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 편지지에 글줄이 있으면 불합격. 의자가 마주 보면 불합격(옆자리가 주제).

#### E06 · `assets/endings/doyun.webp` · P1
PT 계획표 맨 아래 새 칸(빈 칸), 흰 수건, 스톱워치.
```
A PT plan sheet on a clipboard as an empty grid with one new blank cell added at the bottom, a white towel, a stopwatch on a black cord, a gym bench, slate-blue #4A6572 morning light through a window, no people, no words or numbers. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 계획표에 체중·횟수 숫자가 있으면 불합격.

#### E07 · `assets/endings/jeongwoo.webp` · P0
세탁소 셔터 앞 밤, 다리미 김, 우산 두 개 나란히.
```
A small laundry shop at night with its metal shutter half lowered, steam from an iron glowing through the window, two umbrellas leaning side by side by the door, a ring of keys on a hook, mocha #7F553C warm light, no people, no shop sign text. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 간판 글자 불합격. 우산이 하나면 불합격.

#### E08 · `assets/endings/daeun.webp` · P0
갤러리 벽에 영수증 백 장, 전부 같은 막대 인간(앞치마). 가장 그림다운 엔딩.
```
Gallery wall covered with a hundred café receipts pinned in a neat grid, each bearing the same tiny pen-drawn stick figure wearing an apron and nothing else printed on it, wooden floor, plum #8B3C78 tinted evening light from a skylight, no people. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 영수증에 인쇄 글자·숫자·바코드가 있으면 불합격. 흰 영수증이 화면을 덮어 눈부시면 벽·바닥 비중을 올려 재생성.

#### E09 · `assets/endings/seunghyun.webp` · P1
산책길, 산책줄을 나눠 잡은 두 손, 강아지 보리.
```
A tree-lined park path in daylight: two hands sharing one dog leash, one in a white coat sleeve and the other in a plain neutral grey sleeve, a fluffy medium-sized dog at the end of the leash, lavender-grey #6A5779 tint in the shade, framed from the waist down, no faces. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 얼굴이 나오면 불합격. 손가락 수 확인. 강아지 이름표 글자 불합격.

#### E10 · `assets/endings/sohee.webp` · P1
녹음 부스 유리 너머 헤드셋, 콘솔 불빛, 바깥 의자 하나.
```
Recording studio: through the booth glass a plain white headset resting on a microphone stand, mixing-console lights glowing in the foreground, and beside the console one empty chair, ocean-blue #005A82 accent light, no people, no labels on the console. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 콘솔에 글자·브랜드가 있으면 불합격. 의자가 둘이면 불합격.

#### E11 · `assets/endings/geonwoo.webp` · P1
교실 뒤 게시판, 빛바랜 단체 사진 옆 새 사진(둘 다 얼굴 흐림), 분필 가루.
```
Classroom back bulletin board: an old faded class photo pinned next to a new photo, both showing distant figures with faces blurred to nothing, chalk dust on the ledge below, a beige cardigan hanging on a chair, rosewood #874957 warm afternoon light, no people, no text. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 사진 속 얼굴이 식별되면 불합격. 게시판 프린트 글자 불합격.

#### E12 · `assets/endings/yuna.webp` · P1
분식집 떡볶이 2인분, 스티커 가득한 일지, 형광 머리끈. "숫자는 하나도 없다".
```
Snack-bar table: two portions of tteokbokki, a training journal open and packed with colorful round stickers and no numbers or words, a neon-green hair tie beside it, jade-green #1D6A53 accent on the table edge, warm light, no people. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 일지에 숫자·글자가 있으면 불합격(주제가 "숫자 없음").

#### E13 · `assets/endings/common_solo.webp` · P2
거울 앞, 정돈된 책상, 아침 빛. "거울 속 사람이 마음에 든다".
```
A tidy studio desk in the morning: a mirror reflecting a made bed and sunlight but no person, a watered plant, a closed laptop, a neatly folded neutral grey hoodie, warm neutral palette, no people. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 거울에 사람이 비치면 불합격.

#### E14 · `assets/endings/common_bad.webp` · P2
1일차와 같은 책상, 프사 그대로인 폰, 달력만 넘어감. S01 과 같은 구도.
```
The same studio-apartment desk as day one, same viewpoint: a phone face-down with its notification light glowing, a wall calendar with many pages flipped over as blank grids, a small mirror reflecting only a cropped shoulder in a neutral grey hoodie, dim evening light, neutral palette, no faces. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: S01 과 나란히 놓았을 때 같은 방으로 보이지 않으면 불합격(S01 이미지를 첨부해 생성). 달력 숫자 불합격.

#### E15 · `assets/endings/common_hidden.webp` · P2
결혼식장 뒷줄, 다섯 개의 빈 의자에 놓인 폰들. "모두가 당신을 믿는다".
```
Back row of a wedding hall: five empty white chairs in a row, a phone placed on each seat with its screen softly glowing, flower petals on the floor, soft warm light from the front, no people, no text on any screen. 3:2, 1536×1024, key props inside the central 80%, calm still-life composition, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
```
QA: 의자가 다섯이 아니면 불합격. 폰 화면에 UI 불합격. 흰 의자·흰 벽 면적이 크면 세피아·다크에서도 무난하지만, 원본이 눈부시면 조명을 낮춰 재생성.

---

## 3. 스티커 프롬프트 (52장)

### 3.0 방식 (초상화 문서 관찰 로그 #4 의 교훈)

1. **캐릭터마다 새 대화**를 열고 `assets/portraits/<id>.jpg` 를 첨부한다. 다른 캐릭터의 초상화·스티커는 첨부하지 않는다.
2. 먼저 **시트(2×2) 프롬프트**를 붙여 4감정을 한 장에 뽑는다. 한 장 안에서는 모델이 같은 얼굴을 유지하므로 얼굴이 흔들리지 않는다. 시트가 초상화와 같은 사람으로 보이면 확정, 아니면 PORTRAIT_PROMPTS §6.8 문장("라인업의 그 인물과 얼굴이 달라졌습니다…")으로 고친다.
3. 시트를 자른다(아래 명령). 잘라서 손·소품이 잘렸거나 한 칸이 이상하면 **그 칸만** 단독 프롬프트(3.1~3.12 의 감정 줄)로 다시 뽑는다. 5번째 스티커는 시트 확정 뒤 단독으로 1장.
4. 배경은 **마젠타 `#FF00FF` 단색**으로 생성해 키잉한다(도구가 투명 PNG 를 직접 주면 그걸 쓰고 이 단계는 생략). 캐릭터에 마젠타 계열이 없어 안전하다.

```sh
# 시트 자르기 (2×2, 좌상 joy · 우상 sulk · 좌하 shy · 우하 surprise)
magick sheet_seoyeon.png -crop 2x2@ +repage seoyeon_%d.png
mv seoyeon_0.png seoyeon_joy.png; mv seoyeon_1.png seoyeon_sulk.png
mv seoyeon_2.png seoyeon_shy.png; mv seoyeon_3.png seoyeon_surprise.png
# 마젠타 키잉 → 투명 PNG (가장자리 잔색은 -fuzz 를 6~12% 사이에서 조절)
for f in seoyeon_*.png; do magick "$f" -fuzz 8% -transparent '#FF00FF' -trim +repage \
  -gravity center -background none -extent 1024x1024 "$f"; done
# 이후 §0.4 의 스티커 cwebp 로 384×384 알파 webp
```

키잉 뒤 반드시 **다크 배경(#161014) 위에 얹어** 가장자리 마젠타 테두리가 없는지 본다(§4).

### 3.1 스티커 공통 블록

모든 스티커 프롬프트 = `[앞머리] + [앵커 블록 §1.5] + [감정 줄] + [프레이밍] + [화풍] + [금지]`. 아래 두 줄이 앞머리와 뒷부분이다.

앞머리(첨부 초상화를 기준으로 삼게 한다):
```
Redraw the exact same character as the attached portrait as a chat sticker — identical face, eye shape, hair, outfit and accessories; change only the expression, pose and hands.
```
뒷부분(프레이밍 + 화풍 + 금지):
```
One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

시트 프롬프트는 앞머리 대신 이 문장으로 시작한다:
```
Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: [joy]. Top-right: [sulk]. Bottom-left: [shy]. Bottom-right: [surprise]. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```
`[joy]` 등 자리에는 아래 각 캐릭터의 감정 줄을 그대로 넣는다.

감정 4종 정의(전원 공통, 06_scene_plan §2.2): **joy** = 입이 먼저 웃음 · **sulk** = 시선을 돌리고 입을 다묾 · **shy** = 볼이 붉고 시선이 아래 · **surprise** = 눈이 커지고 입이 벌어짐. 각 캐릭터의 감정 줄은 그 캐릭터의 **대표 표정을 어느 쪽으로 굴리는가**다. 초상화의 눈 모양(무쌍·작은 눈)을 감정 때문에 바꾸지 않는다.

### 3.2 서연 `seoyeon` — 첨부 `assets/portraits/seoyeon.jpg`

앵커: §1.5 `seoyeon` 블록. 공통 QA: 눈이 커지거나 쌍꺼풀 선이 생기면 불합격(놀람도 "조금" 커질 뿐). 카디건 단추 잠금.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/seoyeon_joy.webp` | `Joy, restrained: only one corner of the mouth lifts, eyes still half-lidded and narrow, chin slightly raised, one hand loosely in the cardigan pocket.` | 활짝 웃으면 불합격 |
| sulk | `assets/stickers/seoyeon_sulk.webp` | `Sulk, her signature: mouth closed, eyelids half lowered, pupils sliding sideways in a cool side-glance, arms crossed over the charcoal cardigan.` | 정면 응시면 불합격 |
| shy | `assets/stickers/seoyeon_shy.webp` | `Shy: gaze dropped to the lower corner, faint pink on the pale cheeks, one hand tucking a strand of long black hair behind her ear, lips pressed together.` | 볼 홍조가 없으면 불합격 |
| surprise | `assets/stickers/seoyeon_surprise.webp` | `Surprise: the narrow eyes open just a little wider than usual so it shows, lips parted slightly, one eyebrow raised, hand paused mid-gesture.` | 눈이 둥글게 커지면 불합격 |

시트: 위 시트 문장의 `[joy]`~`[surprise]` 에 네 줄을 넣고, 앞에 §1.5 `seoyeon` 앵커 블록을 붙인다.

### 3.3 다은 `daeun` — 첨부 `assets/portraits/daeun.jpg` (5장)

앵커: §1.5 `daeun` 블록. 공통 QA: 무쌍에 쌍꺼풀 선, 눈이 커짐, 화장 → 불합격. 앞치마·볼펜 반묶음 유지.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/daeun_joy.webp` | `Joy, barely there: one corner of the small mouth lifts a millimeter, sleepy half-lidded eyes unchanged, pencil still behind the ear, hands resting on the apron.` | 눈웃음까지 가면 불합격 |
| sulk | `assets/stickers/daeun_sulk.webp` | `Sulk: face stays blank and sleepy, but she has pulled the black ballpoint pen out of her hair and holds it up between two fingers, gaze turned aside, hair half fallen.` | 볼펜이 머리에 그대로면 불합격 |
| shy | `assets/stickers/daeun_shy.webp` | `Shy: gaze down, faint pink on the pale cheeks, both hands fiddling with the beige apron strings at her waist, lips slightly parted.` | 시선이 정면이면 불합격 |
| surprise | `assets/stickers/daeun_surprise.webp` | `Surprise: the small monolid eyes go round and fully open with no crease line, mouth a small "o", shoulders lifted, pencil slipping from behind the ear.` | 쌍꺼풀 선이 생기면 불합격 |
| daeun_blank | `assets/stickers/daeun_blank.webp` | `Her default deadpan "…": sleepy half-lidded eyes looking straight at the viewer, mouth slightly open with no expression, holding a pencil upright in one hand as if mid-thought.` | 웃거나 찡그리면 불합격 |

### 3.4 지우 `jiwoo` — 첨부 `assets/portraits/jiwoo.jpg`

앵커: §1.5 `jiwoo` 블록. 공통 QA: 윙 아이라인·진주 귀걸이·쪽머리가 빠지면 불합격.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/jiwoo_joy.webp` | `Joy: the skeptical half-smile finally becomes a real smile, both corners up, eyes softening but still sharp almond shape, one hand lightly on her chest.` | 한쪽 눈썹이 여전히 올라가 있으면 불합격 |
| sulk | `assets/stickers/jiwoo_sulk.webp` | `Sulk, her signature: one eyebrow raised, mouth closed and flat, arms crossed over the navy jacket, leaning back slightly, gaze cool and sideways.` | 팔짱이 없으면 불합격 |
| shy | `assets/stickers/jiwoo_shy.webp` | `Shy: the winged-eyeliner eyes slide sideways and down, faint blush, one hand touching a pearl earring, lips pressed in a small line.` | 귀걸이를 만지는 손이 없으면 불합격 |
| surprise | `assets/stickers/jiwoo_surprise.webp` | `Surprise: both eyebrows shoot up, almond eyes wide, lips parted, one hand raised palm-out as if stopping something.` | 눈썹 한쪽만 올라가면 불합격 |

### 3.5 소희 `sohee` — 첨부 `assets/portraits/sohee.jpg` (5장)

앵커: §1.5 `sohee` 블록. 공통 QA: 헤드셋(로고 없음)·청록 이너컬러·앞니가 빠지면 불합격.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/sohee_joy.webp` | `Joy, her signature: huge round eyes wide, mouth open in an excited cheer showing the two front teeth, both fists raised beside her face, leaning toward the viewer.` | 입을 다물면 불합격 |
| sulk | `assets/stickers/sohee_sulk.webp` | `Sulk: headset pulled off and hanging around her neck, cheeks puffed out, mouth closed, big eyes glancing sideways, arms crossed over the grey hoodie.` | 볼 부풀림이 없으면 불합격 |
| shy | `assets/stickers/sohee_shy.webp` | `Shy: both hands pulling the hoodie drawstrings so the hood hides half her face, only the big eyes peeking down, bright blush over the freckles.` | 얼굴이 다 보이면 불합격 |
| surprise | `assets/stickers/sohee_surprise.webp` | `Surprise: one hand lifting one side of the headset off her ear, mouth wide open, round eyes even wider, eyebrows up.` | 헤드셋을 안 만지면 불합격 |
| sohee_call | `assets/stickers/sohee_call.webp` | `Shot-caller focus "go go": headset on both ears, facing straight ahead with narrowed determined eyes and a small confident grin, one hand pointing forward at the viewer.` | 신난 외침과 같으면 불합격(집중이지 흥분이 아님) |

### 3.6 예은 `yeeun` — 첨부 `assets/portraits/yeeun.jpg`

앵커: §1.5 `yeeun` 블록. 공통 QA: 땋은 머리·커튼뱅·코랄 블러셔가 빠지면 불합격. 볼살 유지.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/yeeun_joy.webp` | `Joy: cheeks even rounder in a full soft smile, eyes curved warmly, both hands holding the copper braid in front of her shoulder, head tilted.` | 땋은 머리를 잡지 않으면 불합격 |
| sulk | `assets/stickers/yeeun_sulk.webp` | `Sulk, her signature: lips pushed out in a pout, one cheek puffed, eyes looking up from under the curtain bangs, arms hanging with fists clenched lightly.` | 삐죽이 없으면 불합격 |
| shy | `assets/stickers/yeeun_shy.webp` | `Shy: both palms pressed to her round cheeks, blush spreading past the coral blusher, eyes looking down, small pouty smile.` | 손이 볼에 없으면 불합격 |
| surprise | `assets/stickers/yeeun_surprise.webp` | `Surprise: one hand covering her mouth, round eyes wide, eyebrows up, shoulders raised, braid swinging.` | 입을 안 가리면 불합격 |

### 3.7 유나 `yuna` — 첨부 `assets/portraits/yuna.jpg`

앵커: §1.5 `yuna` 블록. 공통 QA: 재킷 지퍼 내림·노출·근육 강조 → 불합격. 포니테일·스톱워치 유지, 무쌍 유지.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/yuna_joy.webp` | `Joy, her signature: mouth wide open in a loud laugh, downturned monolid eyes squeezed into crescents, one hand raised high for a high-five.` | 눈이 열려 있으면 불합격 |
| sulk | `assets/stickers/yuna_sulk.webp` | `Sulk: head turned sharply away so the high ponytail swings, mouth closed, eyes glancing back sideways, arms crossed over the jade track jacket.` | 포니테일이 움직이지 않으면 불합격 |
| shy | `assets/stickers/yuna_shy.webp` | `Shy: fiddling with the stopwatch on its cord with both hands, gaze down, blush rising over the freckles on her nose and cheekbones, small closed-mouth smile.` | 스톱워치가 없으면 불합격 |
| surprise | `assets/stickers/yuna_surprise.webp` | `Surprise: the downturned eyes open wide while keeping their downturned shape, mouth open, eyebrows up, one hand out.` | 눈꼬리가 올라가면 불합격 |

### 3.8 정우 `jeongwoo` — 첨부 `assets/portraits/jeongwoo.jpg` (5장)

앵커: §1.5 `jeongwoo` 블록. 공통 QA: 안경테 끊김·안경 없음 → 불합격(sulk 는 손에 든다). 귀 홍조 유지.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/jeongwoo_joy.webp` | `Joy: eyes crease first into a gentle smile, then the mouth follows, one finger pushing the round glasses up his nose, ears slightly pink.` | 안경을 밀어 올리는 손이 없으면 불합격 |
| sulk | `assets/stickers/jeongwoo_sulk.webp` | `Sulk: glasses taken off and held in one hand, brows drawn together, mouth closed in a firm line, downturned eyes looking aside.` | 안경을 쓰고 있으면 불합격 |
| shy | `assets/stickers/jeongwoo_shy.webp` | `Shy, his signature: eyes wide and darting sideways in fluster, lips pressed tight, ears bright red, one hand rubbing the back of his neck.` | 붉은 귀가 없으면 불합격 |
| surprise | `assets/stickers/jeongwoo_surprise.webp` | `Surprise: the round glasses slipping down to the tip of his nose, big eyes wide above the frames, mouth open, both hands half raised.` | 안경이 제자리면 불합격 |
| jeongwoo_haha | `assets/stickers/jeongwoo_haha.webp` | `Awkward "haha" as he deletes a message: a stiff sheepish smile, eyes squeezed half shut, one hand holding a phone with the thumb pressing the screen, the other hand raised in a small apologetic wave.` | 폰 화면에 글자·UI 가 있으면 불합격 |

### 3.9 하늘 `haneul` — 첨부 `assets/portraits/haneul.jpg`

앵커: §1.5 `haneul` 블록. 공통 QA: 체크 행주·데님 앞치마·큰 입이 빠지면 불합격. 무쌍 유지.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/haneul_joy.webp` | `Joy, his signature: one eye winked shut, a huge grin showing all his big even teeth, the checked dish towel snapped up in one hand.` | 윙크가 없으면 불합격 |
| sulk | `assets/stickers/haneul_sulk.webp` | `Sulk: towel slung over one shoulder, thick lips pushed out in a pout, monolid eyes looking off to the side, one hand on his hip.` | 삐죽 입이 없으면 불합격 |
| shy | `assets/stickers/haneul_shy.webp` | `Shy: one hand scratching the back of his neck, cheeks flushed deeper than usual, eyes looking down and away, a crooked small smile.` | 뒷목 손이 없으면 불합격 |
| surprise | `assets/stickers/haneul_surprise.webp` | `Surprise: the already large mouth opens even wider, eyes wide, eyebrows up, both hands spread.` | 입이 작으면 불합격 |

### 3.10 승현 `seunghyun` — 첨부 `assets/portraits/seunghyun.jpg` (5장)

앵커: §1.5 `seunghyun` 블록. 공통 QA: 눈이 커지거나 활짝 웃으면 불합격. 청진기·가운 유지, 가운에 글자 없음.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/seunghyun_joy.webp` | `Joy, minimal: the corners of the thin lips lift only slightly, the sharp eyes soften a fraction, hands in the coat pockets, posture straight.` | 이가 보이면 불합격 |
| sulk | `assets/stickers/seunghyun_sulk.webp` | `Sulk: face completely blank, only the eyes shifted to the side, mouth a flat line, one hand adjusting the stethoscope.` | 미간을 찡그리면 불합격 |
| shy | `assets/stickers/seunghyun_shy.webp` | `Shy, delayed: gaze just turned away after a beat, a faint blush on the cool pale skin, one hand raised showing small fresh scratch marks on its back, mouth closed.` | 손등 발톱 자국이 없으면 불합격 |
| surprise | `assets/stickers/seunghyun_surprise.webp` | `Surprise: the small narrow eyes stay small, but both short thick brows rise high, lips part slightly, head pulled back a little.` | 눈이 커지면 불합격 |
| seunghyun_sure | `assets/stickers/seunghyun_sure.webp` | `Unwavering direct gaze: looking straight into the viewer's eyes, calm and certain, mouth closed and set, stethoscope around the neck, both hands relaxed at his sides.` | 시선이 조금이라도 비껴가면 불합격 |

### 3.11 민재 `minjae` — 첨부 `assets/portraits/minjae.jpg`

앵커: §1.5 `minjae` 블록. 공통 QA: 다크서클이 사라지거나 눈꼬리가 올라가면 불합격. 후드는 sulk 에서만 쓴다.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/minjae_joy.webp` | `Joy: the hesitant smile opens halfway, showing a bit of teeth, downturned eyes brightening, head still slightly lowered, one hand holding the hoodie hem.` | 활짝 웃으면 불합격 |
| sulk | `assets/stickers/minjae_sulk.webp` | `Sulk: hood pulled up over the messy curls, face turned half away, mouth closed, eyes glancing out from under the hood.` | 후드를 안 쓰면 불합격 |
| shy | `assets/stickers/minjae_shy.webp` | `Shy, his signature turned up: head lowered, both hands gripping the hoodie drawstrings, eyes peeking up through the bangs, cheeks pink against the pale skin.` | 올려다보는 눈이 없으면 불합격 |
| surprise | `assets/stickers/minjae_surprise.webp` | `Surprise: the tired dark-circled eyes go round and wide, mouth open, shoulders jump, one hand flat on his chest.` | 다크서클이 없어지면 불합격 |

### 3.12 건우 `geonwoo` — 첨부 `assets/portraits/geonwoo.jpg`

앵커: §1.5 `geonwoo` 블록. 공통 QA: 보조개·왼쪽 덧니·분필 가루가 빠지면 불합격.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/geonwoo_joy.webp` | `Joy, his signature bursting: the held-back laugh finally breaks out, wide grin with the left snaggletooth showing, deep dimples, eyes sparkling, one hand slapping his knee.` | 덧니가 없으면 불합격 |
| sulk | `assets/stickers/geonwoo_sulk.webp` | `Sulk: chin propped on one hand, lips pushed out in a pout, round eyes glancing sideways, dimples still faintly visible.` | 턱 괸 손이 없으면 불합격 |
| shy | `assets/stickers/geonwoo_shy.webp` | `Shy: one hand scratching the back of his permed hair, eyes rolled up and away, cheeks warm, a sheepish closed-mouth smile with dimples.` | 시선이 아래면 불합격(건우는 위) |
| surprise | `assets/stickers/geonwoo_surprise.webp` | `Surprise: a piece of chalk dropping from his open hand, round eyes wide, mouth open, eyebrows up, a puff of chalk dust.` | 분필이 없으면 불합격 |

### 3.13 도윤 `doyun` — 첨부 `assets/portraits/doyun.jpg`

앵커: §1.5 `doyun` 블록. 공통 QA: 지퍼 내림·근육 강조 → 불합격. 흰 수건·버즈컷·턱수염 유지, 걱정 눈썹이 기본.

| id | 파일 | 감정 줄 (영어) | QA |
|---|---|---|---|
| joy | `assets/stickers/doyun_joy.webp` | `Joy: the small gentle eyes fold into a warm smile, full lips relaxed, one hand wiping his brow with the white towel.` | 수건이 없으면 불합격 |
| sulk | `assets/stickers/doyun_sulk.webp` | `Sulk: arms crossed over the charcoal training top, brows still worried with inner ends raised, mouth closed, gaze aside.` | 팔짱이 없으면 불합격 |
| shy | `assets/stickers/doyun_shy.webp` | `Shy: one big hand on the back of his neck, eyes down, a faint flush on the bronze skin, small awkward smile under the trimmed beard.` | 시선이 정면이면 불합격 |
| surprise | `assets/stickers/doyun_surprise.webp` | `Surprise: the inner ends of the thick brows shoot up sharply, small eyes open as wide as they go, mouth open, hand half raised.` | 눈썹이 그대로면 불합격 |

---

## 4. 넣기 전 확인 체크리스트

`assets/` 에 넣기 전에 파일마다 본다. 하나라도 걸리면 그 파일만 재생성한다(대화는 유지).

**화풍 (초상화 12장과 나란히 놓고)**
- [ ] 선 굵기·채색 방식·조명 방향이 `assets/portraits/*.jpg` 와 같은 세계로 보이는가. 사진(P·Pi)이 실사처럼 보이면 불합격.
- [ ] 채도·명도가 초상화와 비슷한가(사진만 유난히 어둡거나 쨍하지 않은가).

**글자 0**
- [ ] 간판·노트·달력·영수증·박스·폰 화면·옷에 글자·숫자·로고가 없는가. **흐릿한 가짜 글자, 한글 비슷한 획도 불합격.** 400% 확대해서 본다.
- [ ] 워터마크·서명·테두리 없음.

**얼굴·인물**
- [ ] 삽화·사진·엔딩: 얼굴이 하나도 없는가(유리·거울·백미러 반사 포함). 실루엣 안에 눈·입이 없는가.
- [ ] 주인공: 머리 귀 덮는 중간 길이, 무채색 옷, 손톱·액세서리 없음. 성별이 읽히면 불합격.
- [ ] 캐릭터 소품이 §1.5 표의 것인가(새 소품을 만들지 않았는가).
- [ ] 스티커: 초상화와 **같은 사람**인가(눈 모양·쌍꺼풀·눈 크기·코·입·얼굴형). 12명 스티커를 한 줄에 놓고 머리·옷을 가려도 구분되는가. 무쌍 4명(다은·유나·하늘·승현)에 쌍꺼풀 선이 안 생겼는가.
- [ ] 손: 손가락 5개, 관절 방향. 안경(정우)·헤드셋(소희)·청진기(승현) 끊김 없음.

**12+ 등급**
- [ ] 술잔·병·캔·담배 없음. 노출·몸매 강조·지퍼 내림 없음(유나·도윤). 어린이 얼굴 없음(P08·E11). 실존 브랜드·게임 UI 없음.

**안전 영역·비율**
- [ ] 삽화·엔딩 3:2: 핵심 소품이 위아래 10% 를 잘라도 살아 있는가. 정확히 1200×800 인가.
- [ ] 사진 4:3: 800×600. 폴라로이드 안에서 기울기가 어색하지 않은가(약간의 기울기는 의도).
- [ ] 스티커 1:1: 384×384, **알파 채널 있음**(`magick identify` 의 channels 에 `a`), 캐릭터가 캔버스 85%, 바닥 그림자·테두리·마젠타 잔색 없음.

**다크 모드**
- [ ] 각 파일을 `#161014` 배경 위에 놓고 본다: 흰 면적이 눈부시지 않은가(E08 영수증·E15 의자·Pi01 노트 주의). 12% 어둡게 얹어도 소품이 읽히는가.
- [ ] 통화 배경(S03·S04·S06·S08·S09·S11·S13·S15): 30% 어둡게 얹고 그 위에 아바타·이름이 올라가도 그림이 읽히는가.
- [ ] 엔딩: 채도 낮춤(bad)·세피아(hidden)를 흉내 내어(`magick in.webp -modulate 80,40 out.png` / `-sepia-tone 80%`) 봐도 장면이 성립하는가.
- [ ] 스티커를 라이트 말풍선(`#FFFAF9`)·다크 말풍선(`#262027`) 둘 다 위에 올려 가장자리가 깨끗한가.

**파일**
- [ ] 이름이 §0.3 규약과 정확히 같은가(소문자·언더스코어·`_0` 접미사·`common_<tier>`).
- [ ] 용량: 삽화·엔딩 ≤150KB, 사진 ≤80KB, 스티커 ≤35KB. 전체 ≤12MB.
- [ ] 원본 PNG 와 시트 이미지는 저장소 밖에 보관했는가. `.gitkeep` 을 지우지 않았는가.
- [ ] 생성 도구의 이용 약관에서 상업적 이용(앱 내 사용·스토어 스크린샷)이 허용되는지 날짜와 링크를 기록했는가(PORTRAIT_PROMPTS §7 과 같은 항목).

넣은 뒤: 앱을 **완전히 다시 실행**(핫 리로드로는 새 에셋이 안 보인다) → 디버그 갤러리에서 삽화 카드·통화 배경·사진 폴라로이드·스티커 줄·엔딩 카드를 라이트/다크로 한 번씩 본다.
