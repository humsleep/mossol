# 스티커 시트 프롬프트 — 붙여넣기용 (12장 + 5번째 4장)

> `docs/SCENE_PROMPTS.md` §1.5·§3 에서 기계로 조립한 완성본이다. 원본 규칙이 바뀌면
> `tool/gen_sticker_sheets.py` 로 다시 만든다. **이 파일은 손으로 고치지 않는다.**

## 왜 시트인가

52장을 하나씩 뽑으면 52번이고, 무엇보다 **매번 얼굴이 조금씩 달라진다**. 한 장 안에서는
모델이 같은 얼굴을 유지하므로, 2×2 시트로 뽑으면 4감정의 얼굴이 자동으로 일치한다.
**12번 + 5번째 4번 = 16번**이면 끝난다.

## 순서

1. 이미지 도구에서 **`assets/portraits/<id>.jpg` 를 첨부**하고, 아래 그 캐릭터의 프롬프트를 통째로 붙여넣는다.
2. 나온 시트가 초상화와 **같은 사람으로 보이는지**만 본다. 다르면 다시 뽑는다(칸별 디테일은 나중에).
3. 시트를 `art_src/sticker_sheets/<id>.png` 로 저장한다. 파일 이름은 캐릭터 id 그대로.
4. 12장을 다 모았으면 한 번에 자른다:

```bash
python3 tool/split_stickers.py
```

   2×2 분할 → 마젠타 배경 제거 → 여백 정리 → 384×384 → `assets/stickers/<id>_<감정>.webp` 로 저장까지 한다.
   Pillow 가 필요하다: `pip3 install Pillow`

5. 5번째 스티커 4장은 시트가 확정된 뒤 단독으로 뽑아 `art_src/sticker_singles/<파일명>.png` 로 저장하고 같은 명령을 다시 돌린다.
6. 확인:

```bash
python3 tool/check_assets.py
```

## 배경에 대해

배경을 **마젠타 `#FF00FF` 단색**으로 뽑아서 빼내는 방식이다. 캐릭터에 마젠타 계열 색이
없어 안전하다. 쓰는 도구가 **투명 PNG 를 직접 준다면** 그게 더 좋다 — 그 경우에도
`split_stickers.py` 는 그대로 동작한다(이미 투명하면 키잉 단계를 건너뛴다).

결과는 알파를 가진 **WebP** 로 나간다. 같은 그림을 PNG 로 두면 146KB, WebP q90 이면 17KB 다
(실측). 52장이면 7.6MB 대 0.9MB 차이라 WebP 를 쓴다. 투명도는 그대로 보존된다.

---

## 1. 시트 12장 (캐릭터당 1번)

칸 배치는 **왼쪽 위 joy · 오른쪽 위 sulk · 왼쪽 아래 shy · 오른쪽 아래 surprise** 고정이다.
자르는 스크립트가 이 순서를 그대로 쓰므로 바꾸지 말 것.

### 서연 `seoyeon` — 첨부 `assets/portraits/seoyeon.jpg`
```text
Korean woman, 25, fox-like face: small narrow hidden-crease eyes sharply upturned, thin lips, long slim oval face with pointed chin, cool pale ivory skin, small mole under left eye, burgundy matte lips. Waist-length jet-black straight hair, center part, no bangs, one side tucked behind ear. Charcoal oversized knit cardigan over white tee, thin silver necklace. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, restrained: only one corner of the mouth lifts, eyes still half-lidded and narrow, chin slightly raised, one hand loosely in the cardigan pocket. Top-right: Sulk, her signature: mouth closed, eyelids half lowered, pupils sliding sideways in a cool side-glance, arms crossed over the charcoal cardigan. Bottom-left: Shy: gaze dropped to the lower corner, faint pink on the pale cheeks, one hand tucking a strand of long black hair behind her ear, lips pressed together. Bottom-right: Surprise: the narrow eyes open just a little wider than usual so it shows, lips parted slightly, one eyebrow raised, hand paused mid-gesture. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 다은 `daeun` — 첨부 `assets/portraits/daeun.jpg`
```text
Korean woman, 23, soft flat squarish face, small monolid eyes with no crease set horizontal, low short nose, small mouth with full lower lip, pale clear bare skin, small mole above right mouth corner, no makeup. Ash-grey-brown blunt bob above the jawline, top section messily pinned up with a black ballpoint pen, long side-swept bangs. White shirt with rolled sleeves, plain beige canvas apron, pencil behind ear. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, barely there: one corner of the small mouth lifts a millimeter, sleepy half-lidded eyes unchanged, pencil still behind the ear, hands resting on the apron. Top-right: Sulk: face stays blank and sleepy, but she has pulled the black ballpoint pen out of her hair and holds it up between two fingers, gaze turned aside, hair half fallen. Bottom-left: Shy: gaze down, faint pink on the pale cheeks, both hands fiddling with the beige apron strings at her waist, lips slightly parted. Bottom-right: Surprise: the small monolid eyes go round and fully open with no crease line, mouth a small "o", shoulders lifted, pencil slipping from behind the ear. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 지우 `jiwoo` — 첨부 `assets/portraits/jiwoo.jpg`
```text
Korean woman, 29, cat-like face: large upturned almond eyes with thin outer crease, amber-brown irises, black winged eyeliner, high nose bridge, defined cheekbones, inverted-triangle face, nude beige lips. Dark chestnut hair in a neat low bun at the nape, deep side part, one loose strand. Navy tailored jacket over ivory blouse buttoned high, pearl earrings. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy: the skeptical half-smile finally becomes a real smile, both corners up, eyes softening but still sharp almond shape, one hand lightly on her chest. Top-right: Sulk, her signature: one eyebrow raised, mouth closed and flat, arms crossed over the navy jacket, leaning back slightly, gaze cool and sideways. Bottom-left: Shy: the winged-eyeliner eyes slide sideways and down, faint blush, one hand touching a pearl earring, lips pressed in a small line. Bottom-right: Surprise: both eyebrows shoot up, almond eyes wide, lips parted, one hand raised palm-out as if stopping something. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 소희 `sohee` — 첨부 `assets/portraits/sohee.jpg`
```text
Korean woman, 24, heart-shaped face, very large round eyes with wide deep double eyelids, short upturned nose, big mouth with two slightly prominent front teeth, freckles on the nose, rosy cheeks, red tinted lips. Shoulder-length layered wolf cut with straight bangs above the brows, milk-brown with teal inner color. Light-grey oversized hoodie, plain white headset around the neck. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, her signature: huge round eyes wide, mouth open in an excited cheer showing the two front teeth, both fists raised beside her face, leaning toward the viewer. Top-right: Sulk: headset pulled off and hanging around her neck, cheeks puffed out, mouth closed, big eyes glancing sideways, arms crossed over the grey hoodie. Bottom-left: Shy: both hands pulling the hoodie drawstrings so the hood hides half her face, only the big eyes peeking down, bright blush over the freckles. Bottom-right: Surprise: one hand lifting one side of the headset off her ear, mouth wide open, round eyes even wider, eyebrows up. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 예은 `yeeun` — 첨부 `assets/portraits/yeeun.jpg`
```text
Korean woman, 26, round face with full chubby cheeks, medium round eyes with inline crease and puffy under-eye, slightly downturned, warm brown irises, short round nose, small plump lips, wide coral blush, two small moles on left cheekbone. Chest-length copper-auburn waves in one loose braid over the shoulder, curtain bangs. Sage-green V-neck cardigan over a high-neck cream tee, small gold earrings. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy: cheeks even rounder in a full soft smile, eyes curved warmly, both hands holding the copper braid in front of her shoulder, head tilted. Top-right: Sulk, her signature: lips pushed out in a pout, one cheek puffed, eyes looking up from under the curtain bangs, arms hanging with fists clenched lightly. Bottom-left: Shy: both palms pressed to her round cheeks, blush spreading past the coral blusher, eyes looking down, small pouty smile. Bottom-right: Surprise: one hand covering her mouth, round eyes wide, eyebrows up, shoulders raised, braid swinging. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 유나 `yuna` — 첨부 `assets/portraits/yuna.jpg`
```text
Korean woman, 28, diamond face with high cheekbones and angular jaw, monolid horizontally long eyes clearly downturned, very wide mouth, sun-tanned bronze skin with freckles on nose and cheekbones, no makeup. High ponytail at the crown, full forehead shown, dark brown hair with lighter brown ombre ends. Plain jade-green track jacket zipped to the neck, stopwatch on a black cord. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, her signature: mouth wide open in a loud laugh, downturned monolid eyes squeezed into crescents, one hand raised high for a high-five. Top-right: Sulk: head turned sharply away so the high ponytail swings, mouth closed, eyes glancing back sideways, arms crossed over the jade track jacket. Bottom-left: Shy: fiddling with the stopwatch on its cord with both hands, gaze down, blush rising over the freckles on her nose and cheekbones, small closed-mouth smile. Bottom-right: Surprise: the downturned eyes open wide while keeping their downturned shape, mouth open, eyebrows up, one hand out. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 정우 `jeongwoo` — 첨부 `assets/portraits/jeongwoo.jpg`
```text
Korean man, 25, deer-like face: large moist eyes with thin outer crease and puffy under-eye, clearly downturned, big dark-brown irises, long narrow nose, thin wide lips, long oval face and long neck, fair skin, ears that blush easily. Ear-covering slightly wavy black hair with neat brow-covering bangs. Thin round metal glasses, crisp light-blue oxford shirt buttoned to the collar. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy: eyes crease first into a gentle smile, then the mouth follows, one finger pushing the round glasses up his nose, ears slightly pink. Top-right: Sulk: glasses taken off and held in one hand, brows drawn together, mouth closed in a firm line, downturned eyes looking aside. Bottom-left: Shy, his signature: eyes wide and darting sideways in fluster, lips pressed tight, ears bright red, one hand rubbing the back of his neck. Bottom-right: Surprise: the round glasses slipping down to the tip of his nose, big eyes wide above the frames, mouth open, both hands half raised. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 하늘 `haneul` — 첨부 `assets/portraits/haneul.jpg`
```text
Korean man, 24, long strong-jawed face with wide cheekbones, monolid horizontally long eyes slightly upturned, thick straight dark brows, big broad nose, very large mouth with thick lips and big even teeth, healthy mid-tone skin with flushed cheeks. Short two-block cut, bleached light brown with dark grown-out roots, bangs pushed up. Black short-sleeve tee, indigo denim apron, red-white checked dish towel on the shoulder. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, his signature: one eye winked shut, a huge grin showing all his big even teeth, the checked dish towel snapped up in one hand. Top-right: Sulk: towel slung over one shoulder, thick lips pushed out in a pout, monolid eyes looking off to the side, one hand on his hip. Bottom-left: Shy: one hand scratching the back of his neck, cheeks flushed deeper than usual, eyes looking down and away, a crooked small smile. Bottom-right: Surprise: the already large mouth opens even wider, eyes wide, eyebrows up, both hands spread. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 승현 `seunghyun` — 첨부 `assets/portraits/seunghyun.jpg`
```text
Korean man, 29, wolf-like face: small narrow sharp monolid eyes in deep sockets, upturned, short thick straight brows set low, straight high nose, thin straight lips, symmetrical oval face with a sharp jawline, cool pale skin. Very neat short black hair, 7:3 side part, bangs combed aside. White doctor's coat over light-grey shirt, silver stethoscope around the neck. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, minimal: the corners of the thin lips lift only slightly, the sharp eyes soften a fraction, hands in the coat pockets, posture straight. Top-right: Sulk: face completely blank, only the eyes shifted to the side, mouth a flat line, one hand adjusting the stethoscope. Bottom-left: Shy, delayed: gaze just turned away after a beat, a faint blush on the cool pale skin, one hand raised showing small fresh scratch marks on its back, mouth closed. Bottom-right: Surprise: the small narrow eyes stay small, but both short thick brows rise high, lips part slightly, head pulled back a little. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 민재 `minjae` — 첨부 `assets/portraits/minjae.jpg`
```text
Korean man, 23, narrow long face with hollow cheeks and pointed chin, medium roundish hidden-crease eyes clearly downturned, faint dark circles, grey-brown irises, thin low nose, small mouth with full lower lip, pale smooth skin. Nape-length naturally messy black curls, bangs down to the eyebrows with eyes visible, no hat. Dark navy zip-up hoodie, hood down. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy: the hesitant smile opens halfway, showing a bit of teeth, downturned eyes brightening, head still slightly lowered, one hand holding the hoodie hem. Top-right: Sulk: hood pulled up over the messy curls, face turned half away, mouth closed, eyes glancing out from under the hood. Bottom-left: Shy, his signature turned up: head lowered, both hands gripping the hoodie drawstrings, eyes peeking up through the bangs, cheeks pink against the pale skin. Bottom-right: Surprise: the tired dark-circled eyes go round and wide, mouth open, shoulders jump, one hand flat on his chest. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 건우 `geonwoo` — 첨부 `assets/portraits/geonwoo.jpg`
```text
Korean man, 26, small round face with plump cheeks and round chin, large round eyes with wide deep double eyelids slightly upturned, light-brown irises, short round nose, wide mouth with a left snaggletooth, deep dimples on both cheeks, warm lightly tanned skin. Voluminous natural-brown center-parted perm pushed up. Beige cardigan over a small-check shirt, chalk dust on the sleeves. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy, his signature bursting: the held-back laugh finally breaks out, wide grin with the left snaggletooth showing, deep dimples, eyes sparkling, one hand slapping his knee. Top-right: Sulk: chin propped on one hand, lips pushed out in a pout, round eyes glancing sideways, dimples still faintly visible. Bottom-left: Shy: one hand scratching the back of his permed hair, eyes rolled up and away, cheeks warm, a sheepish closed-mouth smile with dimples. Bottom-right: Surprise: a piece of chalk dropping from his open hand, round eyes wide, mouth open, eyebrows up, a puff of chalk dust. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### 도윤 `doyun` — 첨부 `assets/portraits/doyun.jpg`
```text
Korean man, 27, bear-like face: wide thick rounded-square face, thick neck, small round gentle eyes with thin inline crease slightly downturned, thick bushy brows, big thick nose, full lips, bronze olive skin, short neatly trimmed jawline beard, thin old scar under left jaw. Very short black buzz cut with skin fade. Charcoal half-zip training top zipped to the neck, white towel around the neck. Draw the exact same character as the attached portrait four times in a 2×2 grid on one square 1024×1024 image, plain flat magenta #FF00FF background, thin even gaps, no grid lines. Identical face, hair, outfit and accessories in every cell; only expression, pose and hands change. Top-left: Joy: the small gentle eyes fold into a warm smile, full lips relaxed, one hand wiping his brow with the white towel. Top-right: Sulk: arms crossed over the charcoal training top, brows still worried with inner ends raised, mouth closed, gaze aside. Bottom-left: Shy: one big hand on the back of his neck, eyes down, a faint flush on the bronze skin, small awkward smile under the trimmed beard. Bottom-right: Surprise: the inner ends of the thick brows shoot up sharply, small eyes open as wide as they go, mouth open, hand half raised. Each figure bust to waist, facing the viewer, filling its cell. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

---

## 2. 5번째 스티커 4장 (시트 확정 뒤 단독으로)

이 넷은 그 캐릭터의 대표 표정이라 시트에 넣지 않고 따로 뽑는다.
저장 위치는 `art_src/sticker_singles/<파일명>.png`.

### `daeun_blank` — 첨부 `assets/portraits/daeun.jpg` → `daeun_blank.png`
```text
Redraw the exact same character as the attached portrait as a chat sticker — identical face, eye shape, hair, outfit and accessories; change only the expression, pose and hands. Korean woman, 23, soft flat squarish face, small monolid eyes with no crease set horizontal, low short nose, small mouth with full lower lip, pale clear bare skin, small mole above right mouth corner, no makeup. Ash-grey-brown blunt bob above the jawline, top section messily pinned up with a black ballpoint pen, long side-swept bangs. White shirt with rolled sleeves, plain beige canvas apron, pencil behind ear. Her default deadpan "…": sleepy half-lidded eyes looking straight at the viewer, mouth slightly open with no expression, holding a pencil upright in one hand as if mid-thought. One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### `sohee_call` — 첨부 `assets/portraits/sohee.jpg` → `sohee_call.png`
```text
Redraw the exact same character as the attached portrait as a chat sticker — identical face, eye shape, hair, outfit and accessories; change only the expression, pose and hands. Korean woman, 24, heart-shaped face, very large round eyes with wide deep double eyelids, short upturned nose, big mouth with two slightly prominent front teeth, freckles on the nose, rosy cheeks, red tinted lips. Shoulder-length layered wolf cut with straight bangs above the brows, milk-brown with teal inner color. Light-grey oversized hoodie, plain white headset around the neck. Shot-caller focus "go go": headset on both ears, facing straight ahead with narrowed determined eyes and a small confident grin, one hand pointing forward at the viewer. One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### `jeongwoo_haha` — 첨부 `assets/portraits/jeongwoo.jpg` → `jeongwoo_haha.png`
```text
Redraw the exact same character as the attached portrait as a chat sticker — identical face, eye shape, hair, outfit and accessories; change only the expression, pose and hands. Korean man, 25, deer-like face: large moist eyes with thin outer crease and puffy under-eye, clearly downturned, big dark-brown irises, long narrow nose, thin wide lips, long oval face and long neck, fair skin, ears that blush easily. Ear-covering slightly wavy black hair with neat brow-covering bangs. Thin round metal glasses, crisp light-blue oxford shirt buttoned to the collar. Awkward "haha" as he deletes a message: a stiff sheepish smile, eyes squeezed half shut, one hand holding a phone with the thumb pressing the screen, the other hand raised in a small apologetic wave. One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

### `seunghyun_sure` — 첨부 `assets/portraits/seunghyun.jpg` → `seunghyun_sure.png`
```text
Redraw the exact same character as the attached portrait as a chat sticker — identical face, eye shape, hair, outfit and accessories; change only the expression, pose and hands. Korean man, 29, wolf-like face: small narrow sharp monolid eyes in deep sockets, upturned, short thick straight brows set low, straight high nose, thin straight lips, symmetrical oval face with a sharp jawline, cool pale skin. Very neat short black hair, 7:3 side part, bangs combed aside. White doctor's coat over light-grey shirt, silver stethoscope around the neck. Unwavering direct gaze: looking straight into the viewer's eyes, calm and certain, mouth closed and set, stethoscope around the neck, both hands relaxed at his sides. One character only, bust to waist, facing the viewer, fills 85% of a 1:1 1024×1024 canvas, plain flat magenta #FF00FF background, no floor shadow, no border, no speech bubble. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, alcohol.
```

---

## 3. 뽑은 뒤 확인할 것

- 네 칸이 **같은 사람**인가. 얼굴형·눈 모양·머리·옷이 칸마다 같아야 한다.
- 무쌍인 캐릭터(다은·하늘·승현·유나)에 **쌍꺼풀 선이 생기지 않았는가**. 놀람도 눈이 "조금" 커질 뿐이다.
- 글자·숫자·로고가 없는가. 있으면 다시 뽑는다(스티커에 글자를 넣지 않는다).
- 배경이 **깨끗한 마젠타 단색**인가. 그림자나 그라데이션이 있으면 키잉 후 테두리가 지저분해진다.
- 소품이 맞는가: 서연 카디건 / 다은 볼펜·앞치마 / 지우 진주 귀걸이 / 소희 헤드셋 / 예은 땋은 머리 /
  유나 스톱워치 / 정우 원형 안경 / 하늘 데님 앞치마 / 승현 청진기 / 민재 네이비 후드 /
  건우 덧니·보조개 / 도윤 버즈컷·흰 수건.
