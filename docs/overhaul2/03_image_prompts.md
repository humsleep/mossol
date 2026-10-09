# 개편 2 — 시작 스토리 그림 프롬프트 (ChatGPT 이미지 생성용)

> **쉬운 방법(2026-10-09).** 이 문서를 읽지 않아도 된다. `docs/overhaul2/art_board.html` 을 브라우저로 연다.
> [복사] → ChatGPT 에 붙여 넣기 → 받은 PNG 를 `01.png`~`15.png` 로 `art_inbox/` 에 넣기 → `python3 tool/import_overhaul2_art.py`.
> 복사되는 프롬프트에는 화풍 규칙이 들어 있어서 공통 블록과 2컷 시트·자르기가 필요 없다. 15번 생성(필수 5번)이다.
> 아래 내용은 프롬프트의 원본과 근거다. 프롬프트를 고치면 `python3 tool/image_studio/build_overhaul2.py` 로 작업판을 다시 만든다.

`01_design.md` §6 의 새 그림 12장과 4라운드 회의(`review/r4_meeting.md` G5)가 더한 새 엔딩 3장, 모두 15장을 **가장 적은 손으로** 뽑기 위한 복붙 문서다.
규칙은 `docs/SCENE_PROMPTS.md`(3:2, 얼굴 없음, 글자 없음, 이름 = 이벤트 id)와 `docs/IMAGE_PROMPTS.md`(ChatGPT 크기, PNG 받아서 변환)를
그대로 따른다. 프롬프트 본문은 기존 문서처럼 영어이고, 설명과 검수 기준은 한국어로 적었다. 이 문서는 코드나 JSON 을 고치지 않는다.

> **2026-10-08 갱신.** 시작 스토리 1일차 대본이 바뀌어서 P0 프롬프트 4장을 고쳤다(`sc_speech_d1` 은 축사 중 사고 장면으로, `sc_clip_d1` 은 아침 9시로,
> `sc_leak_d1` 은 카페 알바 단톡으로, `sc_swap_d1` 은 동아리 단톡의 축하 폭주로). `sc_ghost_d1` 은 거의 그대로다.
> P1 장면 가운데 대본과 어긋난 `sc_speech_d2`(밤 → 아침), `sc_swap_d2`(반지 → 펜 한 자루), `sc_leak_d3`(카페), `sc_ghost_d2`(반성문)도 맞췄다.
> 새 엔딩 `villain_legend`·`m36_waiting`·`m36_letgo` 를 §3.8~3.10 에 더하고, 시트를 D·E 두 장 늘렸다(§4). 엔딩 문구는 아직 다듬는 중이다.
> 프롬프트는 이날 `endings.json` 의 에필로그 기준이다. 장면(시간, 장소, 소품)이 바뀌면 프롬프트도 고친다.

## 0. 한눈에

| 단계 | 할 일 | 생성 횟수 | 나오는 그림 |
|---|---|---|---|
| 1 | 새 대화를 열고 §1 공통 블록을 한 번 붙여 넣는다 | 0 | 없음 |
| 2 | §2 의 P0 5장을 한 장씩 만든다(짧은 프롬프트) | 5 | 5 |
| 3 | §3 의 P1 10장(장면 5, 엔딩 5)을 §4 의 "2컷 시트" 5장으로 만든다 | 5 | 10 |
| 4 | §5 명령 두 줄로 webp 변환과 시트 자르기를 한다 | 없음 | 없음 |

**최소 5번 생성하면 시작 카드와 1일차 장면이 다 채워진다. 10번 생성하면 15자리가 모두 채워진다.**
(전에는 `sc_ghost_d2` 를 재사용으로 건너뛰었다. 지금은 `villain_legend` 가 시트 한 칸을 혼자 쓰게 되므로, 빈 칸에 `sc_ghost_d2` 를 함께 넣는다. 추가 생성이 들지 않는다.)
엔딩 5장은 그림이 없어도 대체 그림이 뜨게 할 수 있다(§3 표의 "없을 때"). 그래서 급하면 시트 A·B 까지 7번만 생성해도 된다.

화풍 기준 그림은 `assets/scenes/m01.webp`(밤 책상, 스탠드 불빛, 폰 알림 빛), `mo_minjae_call_offgame.webp`(모니터 빛만 있는 방),
`mo_daily_taehyun_dawn.webp`(구긴 종이와 라면), `assets/endings/common_bad.webp`(정물)이다. 공통점은 다음과 같다.
사람 없는 정물 위주이고, 광원은 하나(스탠드·폰·모니터·창)다. 밤 장면은 따뜻한 갈색이고, 창밖에 도시 불빛이 보인다.
반실사 애니 배경화풍에 가는 외곽선을 쓴다. 아래 블록은 이 느낌을 고정하려고 기존 화풍 문장에 **배경화 한 줄**만 더했다.

### 카드로도 쓰이는 그림이라 지킬 것

- P0 5장은 시작 선택 화면의 카드(`starts.json` 의 `image`)와 1일차 장면을 겸한다. 카드는 **잠기면 흐리게** 보인다(§4.3).
  흐려도 무슨 장면인지 알아보도록 **큰 소품 하나와 지배색 하나**로 잡았다.
- 다섯 장의 색이 서로 겹치지 않게 나눴다. 세로 스크롤에서 카드가 구분되어야 한다.

| 파일 | 지배색 | 큰 소품 |
|---|---|---|
| `sc_leak_d1` | 차가운 청백(폰 빛 하나) | 뒷모습 + 폰 화면의 말풍선 기둥, 화면 위에서 굳은 엄지 |
| `sc_speech_d1` | 따뜻한 금색과 스크린의 흰 섬광 | 단상, 대형 스크린의 알림 배너, 하객석에서 들린 녹화 폰 |
| `sc_clip_d1` | 커튼 친 아침의 회청색에 빨간 점 하나 | 마이크의 빨간 불 |
| `sc_swap_d1` | 어두운 장밋빛 보라 | 머리 위로 든 폰, 커플 프사 원 |
| `sc_ghost_d1` | 아침 노랑, 블라인드 줄무늬 빛 | 식탁, 멈춘 손의 폰 |

---

## 1. 공통 블록 (대화 맨 처음에 한 번만)

ChatGPT **새 대화**를 열고 아래 블록을 통째로 붙여 넣는다. 그다음부터는 §2·§3 의 짧은 프롬프트만 보내면 된다.

```
For this whole conversation you are drawing scene illustrations for one Korean dating-sim game. Every image I ask for must follow ALL of these rules, even when my message is short:
- Format: one landscape 3:2 image, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas.
- Style: Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. Quiet cinematic still-life of everyday Korean spaces, like anime background art, one main light source (lamp, phone, monitor or window).
- The protagonist appears only as hands, back view or silhouette: medium-length hair covering the ears, plain neutral grey hoodie or shirt, no nail polish, no jewelry, no gender cues.
- Nobody's face is ever visible. Other people are backs, hands, or dark backlit silhouettes with no facial features.
- Phone, monitor and screen contents are only soft glowing shapes (blurred bubbles, bars, circles, waveforms), never readable.
- No text, letters, numbers, logos, watermark, visible faces, alcohol. No real brands, no real app or game interfaces.
- Do not ask me questions. Just generate the image.
Reply "OK" and wait for my first scene.
```

- 대화가 길어지면 규칙이 흐려진다. **8장마다 새 대화**를 열고 이 블록부터 다시 붙인다(기존 규칙은 10장마다였다. 짧은 프롬프트는 규칙을 덜 되풀이하므로 조금 더 일찍 바꾼다).
- 결과에 글자나 얼굴이 섞이기 시작하면 블록을 한 번 더 붙여 넣고 같은 프롬프트를 다시 보낸다.
- **다른 도구용 단독 프롬프트**는 짧은 프롬프트 뒤에 아래 세 문장을 붙이면 된다. 이렇게 붙이면 `SCENE_PROMPTS.md` §2 의 형식과 같아지므로,
  나중에 S18~S32 로 옮길 때도 이 형태를 쓴다(엔딩 5장은 첫 문장에 `calm still-life composition,` 을 넣는다).
  ```
  3:2, 1536×1024, key props inside the central 80%, mid-tone palette, no large white areas. Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, warm soft lighting. No text, letters, numbers, logos, watermark, visible faces, alcohol.
  ```

### 자주 쓰는 수정 문장 (IMAGE_PROMPTS §3 과 같은 것, 영어판)

- 얼굴이 보일 때: `Redraw the same scene, but no face may be visible at all: turn the person away or crop above the shoulders.`
- 글자가 생겼을 때: `Remove every letter, number and logo; replace them with soft blurred shapes. Keep everything else.`
- 너무 실사 같을 때: `Less photographic: webtoon illustration with thin outlines and soft cel shading, like m01 (the same style as before).`
- 너무 어두울 때: `One step brighter, mid-tone, keep the single light source.`

---

## 2. 필수 5장 (P0) — 시작 카드 겸 1일차 장면

한 장씩 보낸다. 받은 PNG 는 표의 이름 그대로 `assets/scenes/<이름>.png` 에 저장한다(변환은 §5).

### 2.1 `assets/scenes/sc_leak_d1.webp` — 단톡 박제

새벽 1시 12분. 태현에게 보내려던 고백 문장을 모레 첫 출근할 **카페 알바 단톡(11명)**에 보냈다. 읽음이 1, 4, 6 으로 오르고, 엄지가 화면 위에서 굳는다.
방에서 빛나는 것은 폰 화면 하나뿐이다. 카페라는 단서는 의자에 걸어 둔 새 앞치마 하나로만 준다(앞치마는 `sc_leak_d3` 의 "앞치마 프사"와도 이어진다).
(설계 문서는 "1인칭에 반대 손이 이마를 짚는다"였다. 1인칭으로는 이마 짚은 손이 어색하게 나와서, 어깨 너머 뒷모습으로 바꿨다. 의도는 같다.)

```
Scene sc_leak_d1. 1:12 a.m., dark small bedroom, over-the-shoulder view from behind the protagonist sitting hunched on the edge of the bed, head bowed: one hand holds up a phone whose screen glows cold white-blue with a group chat, a row of many tiny round avatar circles along the top and one freshly sent long bubble shape at the bottom; the thumb hovers frozen just above the screen. The other hand grips the back of the head. On the desk chair beside the bed hangs a brand-new plain café apron, still creased from its packaging. The phone is the only light, cold blue-white glow on the hoodie and sheets, a dark window behind. A frozen second of panic.
```

검수: 옆얼굴, 볼선, 귀가 보이면 불합격. 화면에 글자처럼 읽히는 줄이나 숫자(읽음 표시)가 보이면 불합격. 앞치마에 로고나 이름표가 있으면 불합격. 손가락 개수를 확인한다.

### 2.2 `assets/scenes/sc_speech_d1.webp` — 축사 대참사

1일차는 이제 **사고 순간**으로 시작한다. 축사 원고는 폰에 있고, 그 폰이 단상 옆 대형 스크린에 미러링 중이다. 축사 첫 줄을 읽는 순간 태현의 톡이 스크린에 뜨고,
하객 200명이 같은 속도로 읽는다. 앞줄 신랑 친구 하나가 폰을 들어 녹화한다. 부케 던지기는 축사가 끝난 뒤(`sc_speech_d1a~c`)라서 이 그림에서 뺐다.
부케는 웨딩 단서로만 앞 테이블에 놓아 둔다.
(설계 문서의 "1인칭으로 본 하객석 뒷모습"은 하객이 연사를 향하므로 얼굴이 생긴다. 그래서 카메라를 연사 뒤로 옮기고 하객은 역광 실루엣으로 바꿨다.)

```
Scene sc_speech_d1. Wedding banquet hall seen from behind the protagonist standing at a wooden podium (back view, both hands gripping the podium edge, a phone lying on it with a thin cable running to the screen). Ahead, a huge projection screen on the side wall glares with one bright blank rounded notification-banner shape across its top, mirroring the phone. Round tables with white cloths, flower centerpieces and water glasses only; the guests are small dark featureless backlit silhouettes, every head tilted toward the screen at the same angle. In the front row one silhouette holds a phone up sideways, recording, a tiny red dot glowing on it. A white bouquet rests on the front table. Warm golden chandelier light against the cold white screen glare, a frozen awkward second.
```

검수: 신랑·신부·하객 얼굴이 보이면 불합격(실루엣이라도 코·입 윤곽이 또렷하면 다시 뽑는다). 와인잔이나 술병이 있으면 불합격. 스크린 배너에 글자가 있으면 불합격.
단상에 종이 원고가 있어도 큰 문제는 아니지만 원고는 폰에 있다는 설정이다. 예식장 상표나 이니셜 장식도 불합격. 녹화 폰의 빨간 점이 안 보이면 다시 뽑는다.

### 2.3 `assets/scenes/sc_clip_d1.webp` — 마이크 켜진 새벽

1일차 장면은 이제 **아침 9시**다. 사고는 새벽 2시에 났고, 아침에 알림 99+ 로 폰이 쉬지 않고 울린다. 마이크는 그 밤부터 켜진 채다.
그래서 새벽 창 대신 **커튼을 친 아침 방**으로 바꿨다. 커튼 틈의 가는 햇살 한 줄과 마이크의 빨간 불이 대비된다. 카드 이름("마이크 켜진 새벽")은 빨간 불이 계속 말해 준다.
기존 `mo_minjae_call_offgame`(남색 모니터 책상)과 겹치지 않도록 **마이크를 앞에 크게** 놓았다. `sc_ghost_d1`(밝은 아침 노랑)과 겹치지 않도록 방 전체는 어둡게 둔다.

```
Scene sc_clip_d1. 9 a.m. in a small bedroom with the blackout curtains still drawn, gaming desk seen from a low angle: in the foreground a desktop condenser microphone on a boom arm with its small red "on" light still glowing from the night before, plain over-ear headphones dropped beside the keyboard; behind it a monitor gone to a dim standby glow; a phone face-up on the desk, slightly askew as if buzzing nonstop, its screen stacked with notification glow. A single thin blade of pale morning sunlight cuts through the gap in the curtains across the desk. Dim blue-grey room, the single red light as the accent.
```

검수: 모니터에 게임 UI, 체력 바, 글자가 있으면 불합격. 마이크나 헤드폰에 로고가 있으면 불합격. 빨간 불이 안 보이면 다시 뽑는다(카드의 핵심이다).
알림 빛에 숫자(99+)가 그려지면 불합격. 방이 환하게 밝으면 `sc_ghost_d1` 과 구분이 안 되니 다시 뽑는다.

### 2.4 `assets/scenes/sc_swap_d1.webp` — 환승 목격

1일차는 이제 **동아리 단톡의 축하 폭주**("서진 축하해!!", 새 메시지 23)로 시작한다. 그다음 새벽 2시에 바뀐 서진의 프사를 본다.
그래서 화면에 단톡 말풍선이 빠르게 쌓이는 모양을 더하고, 커플 프사 원은 카드에서 알아보도록 크게 둔다. 침대에 누워 폰을 머리 위로 든 1인칭은 그대로다.

```
Scene sc_swap_d1. 2 a.m., first-person view lying in bed, looking up at a phone held in one hand above: the screen is a group chat flooding with a long column of small bright bubble shapes stacking up fast, and pinned near the top one large round profile-picture circle containing two blurred dark silhouettes leaning their heads together, no features; the other hand clenches a crumpled duvet at the bottom of the frame. Dark room, dim rose-violet phone glow on the sheets and ceiling, a charging cable trailing.
```

검수: 프사 원 속 실루엣에 눈, 코, 입이 보이면 불합격. 하트나 이모지 같은 기호가 화면에 생기면 지운다.

### 2.5 `assets/scenes/sc_ghost_d1.webp` — 새벽 3시의 나

아침 8시 햇살이 드는 식탁. 모르는 사람이 "새벽 3시에 써 주신 시"를 인용한 톡을 보냈다. 폰을 든 손이 멈춰 있고, 화면의 받은 말풍선 안에 시 모양의 문단이 보인다.
다섯 장 가운데 유일하게 밝은 그림이다. 대본이 바뀌었지만 이 장면은 그대로라서, 화면을 "말풍선 안의 시"로만 다듬었다.

```
Scene sc_ghost_d1. Bright 8 a.m. morning at a small kitchen table, first-person view: one hand holds a phone frozen mid-air; the screen shows a chat where one incoming bubble holds a short centered stanza made of soft unreadable grey strokes, shaped like a poem. Beside it a cold mug of coffee with a faint ring, a half-eaten slice of toast on a plate, an empty chair across. Soft yellow sunlight through window blinds casts stripes across the table. Calm, bright, quietly absurd mood.
```

검수: 시 문단이 실제 글자(영어 포함)로 읽히면 불합격. 줄무늬 빛이 없어도 합격이지만, 전체가 어두우면 다시 뽑는다.

---

## 3. 선택 10장 (P1) — 우선순위 순

없어도 게임은 돌아간다. 장면은 그림 없이 지금처럼 나오고, 엔딩은 대체 그림을 쓴다. 순위는 **그 그림을 보는 플레이어 수**를 기준으로 매겼다.
처음부터 열린 시작(단톡·축사·마이크)이 먼저이고, 해금이 필요한 시작(환승: 엔딩 1개, 새벽 3시: 엔딩 2개)이 다음이다.
엔딩은 조건이 좁고 대체 그림도 있어서 뒤에 둔다. `influencer`(소문 35↑·평판 65↑)와 `infamous`(소문 60↑·평판 35↓·진상 3↑)가 먼저다.
그다음이 m36 "마지막 선택"에서 보류(`m36_rejected`)나 정리(`m36_parted`)로 끝난 판의 `m36_waiting`·`m36_letgo`, 맨 뒤가 진상 봇도 열에 한 번꼴인 `villain_legend`(진상 13↑·소문 70↑)다.
`sc_ghost_d2` 는 재사용 그림이 있어서 마지막이지만, `villain_legend` 와 같은 시트에 넣으면 추가 생성 없이 나온다.

| 순위 | 파일 | 추천 생성 방법 | 없을 때 |
|---|---|---|---|
| 1 | `assets/scenes/sc_leak_d3.webp` | 시트 A 위 칸 | 그림 없이 진행 |
| 2 | `assets/scenes/sc_clip_d3.webp` | 시트 A 아래 칸 | 그림 없이 진행 |
| 3 | `assets/scenes/sc_speech_d2.webp` | 시트 B 위 칸 | 그림 없이 진행 |
| 4 | `assets/scenes/sc_swap_d2.webp` | 시트 B 아래 칸 | 그림 없이 진행 |
| 5 | `assets/endings/influencer.webp` | 시트 C 위 칸 | `coach.webp` (엔딩 `image` 필드) |
| 6 | `assets/endings/infamous.webp` | 시트 C 아래 칸 | `common_bad.webp` (엔딩 `image` 필드) |
| 7 | `assets/endings/m36_waiting.webp` | 시트 D 위 칸 | `common_solo.webp` (엔딩 `image` 필드) |
| 8 | `assets/endings/m36_letgo.webp` | 시트 D 아래 칸 | `solo_strong.webp` (엔딩 `image` 필드) |
| 9 | `assets/endings/villain_legend.webp` | 시트 E 위 칸 | `album_master.webp` (엔딩 `image` 필드) |
| 10 | `assets/scenes/sc_ghost_d2.webp` | 시트 E 아래 칸 | 기존 `mo_daily_taehyun_dawn.webp`(구긴 종이, 밤 책상)가 거의 같은 장면이다. 이벤트에 `"image": "assets/scenes/mo_daily_taehyun_dawn.webp"` 를 넣으면 된다 |

시트로 만들면 한 칸이 1024×683 이 된다(§4). D2·D3 장면과 엔딩에는 충분하다. 한 장씩 따로 만들어도 되고, 그때는 아래 프롬프트를 그대로 보낸다.

**엔딩 그림의 크기:** 새 엔딩 5장은 모두 가로 3:2 정물 구도(`calm still-life composition`)로 만든다. 공용 엔딩(`common_solo`·`common_bad`·`common_hidden`)과
캐릭터 공용 엔딩 12장이 이미 1200×800 가로다. `IMAGE_PROMPTS.md` 의 엔딩별 세로 2:3(1024×1536) 장은 캐릭터 초상화를 첨부해 한 장씩 뽑는 그림이다.
이 다섯 장은 캐릭터가 없고 2컷 시트로 묶어야 하므로 가로를 따른다(세로 2:3 두 칸을 묶으면 한 칸 폭이 683px 라 너무 흐리다).

**엔딩 대체 그림에 대해 (엔진 담당에게):**
- 앱은 엔딩 그림을 `image` 필드 → `assets/endings/<엔딩 id>` → 캐릭터 id → 공용 `common_<tier>` 순으로 찾는다(`SceneRegistry.forEnding`).
  공용 그림은 solo·bad·hidden 에만 있다. 그래서 필드가 없으면 `influencer`·`villain_legend` 는 `common_solo`, `infamous` 는 `common_bad` 가 자동으로 뜬다.
  **`m36_waiting`·`m36_letgo` 는 tier good 이라 공용 그림이 없다.** `image` 필드를 넣지 않으면 그림 없이 나온다.
- 대체 그림 다섯 장은 모두 저장소에 있다(2026-10-08 확인): `coach`·`common_bad`·`common_solo`·`solo_strong`·`album_master`.
  m36 두 엔딩은 상대가 열두 명 가운데 누구든 될 수 있으므로, 캐릭터가 나오는 그림(`*_some`·`*_friend` 등)은 대체로 쓰지 않았다.
  `villain_legend` 는 흑역사 액자 전시관(`album_master`)이 "흑역사 앨범을 날짜순으로 정리했다"(SJ 에필로그)와 맞는다. 히든 엔딩 그림(`legend`·`loop`)은 스포일러라서 쓰지 않았다.
  `solo_strong`·`album_master` 는 세로 2:3 이다. 엔딩 히어로 틀(`SceneFrame`)은 세로 그림을 3:4 까지 세워 보여 주므로 그대로 쓸 수 있다.
- `image` 필드는 엔딩 id 파일보다 **먼저** 읽힌다. 진짜 그림(`<엔딩 id>.webp`)을 넣으면 그 엔딩의 `image` 필드를 **지워야** 새 그림이 뜬다.

### 3.1 `sc_leak_d3` — 카페 뒷방, 동시에 켜지는 폰들

단톡 이름이 "카페 알바방 (수사본부)"로 바뀌고 "고백 대상" 투표가 열린 날이다. 휴게실을 카페 뒷방으로 맞췄다.

```
Scene sc_leak_d3. Small café back room behind the counter under fluorescent light: a little table with five phones lying face-up, all lighting up at the same moment with blurred bubble shapes and poll-like horizontal bar shapes; two co-workers in plain café aprons seen only from behind on a bench, leaning toward their phones; lockers, a coat rack, stacked paper cups and a sack of coffee beans with no label. Teal-tinted fluorescent shadows, gossip energy.
```
검수: 동료가 고개를 돌려 얼굴이 보이면 불합격. 투표 막대에 숫자나 글자가 있으면 불합격. 원두 자루나 컵에 로고가 있으면 불합격.

### 3.2 `sc_clip_d3` — 강의실 뒷자리, 같은 영상을 트는 폰들

```
Scene sc_clip_d3. University lecture hall seen from the very last row: in the rows ahead, four students seen strictly from behind each hold a phone playing the same clip, identical blurred glowing sound-waveform shapes on every screen; one student leans to show the next. Afternoon window light, notebooks, the protagonist's own phone face-down on the desk in the foreground.
```
검수: 옆얼굴이 하나라도 보이면 불합격. 파형 대신 사람 얼굴 썸네일이 그려지면 불합격.

### 3.3 `sc_speech_d2` — 아침, 숏폼에 올라간 축사

대본은 이제 다음 날 **아침 8시 10분**("아침. 알림이 멈추지 않는다", 조회수 12만)이다. 밤을 아침으로 바꿨다.
부케는 동창 짝이 받았으므로 내 방에는 없다. 원고는 폰에 있었으므로 종이 원고 대신 결혼식에서 입은 재킷과 벗어 던진 구두를 둔다.

```
Scene sc_speech_d2. Early morning, first-person view still in bed: one hand holds a phone playing a vertical short video shown only as a blurred bright stage-like shape, while a stream of small glowing heart icons floats up the right edge of the screen. A formal dark jacket thrown over a chair, a pair of dress shoes kicked off on the floor. Pale grey-blue morning light through thin curtains, phone glow pink-white on the blanket.
```
검수: 하트 말고 숫자나 글자가 생기면 불합격. 영상 속에 사람 얼굴이 보이면 불합격.

### 3.4 `sc_swap_d2` — 동아리방, 맞은편에 나란히 앉은 두 사람

대본의 눈에 걸리는 소품은 "둘이 번갈아 쓰는 펜 한 자루"와 "책상 밑에서 진동한 폰"이다. 커플 반지는 대본에 없어서 펜으로 바꿨다.

```
Scene sc_swap_d2. University club room during a meeting, long table seen from the protagonist's seat: across the table two people sit side by side, framed from the shoulders down only, their hands close together on one shared notebook, one hand passing a single pen to the other; in the foreground the protagonist's hands rest under the table edge holding a phone that has just lit up with a soft notification glow. Blank whiteboard, posters as plain colour blocks, late-afternoon light.
```
검수: 맞은편 두 사람의 턱 위가 보이면 불합격. 내 손(앞쪽)에 반지가 있으면 불합격(주인공 장신구 금지). 공책에 읽히는 글자가 있으면 불합격.

### 3.5 `influencer` (엔딩, solo) — 무대 옆, 폰 불빛 바다

```
Scene influencer, ending card, calm still-life composition. Backstage wings at night, seen from behind the protagonist standing just off-stage: one hand holds a wireless microphone at their side; a warm spotlight beam falls on the empty stage ahead; beyond it a dark auditorium glittering with a sea of small phone lights held up by an unseen audience. Golden and deep blue light, triumphant but slightly overwhelmed.
```
검수: 객석에 얼굴이 보이면 불합격. 무대 현수막에 글자가 있으면 불합격.

### 3.6 `infamous` (엔딩, bad) — 빈 방 바닥의 엎어진 폰

엔딩 bad 등급은 코드가 채도를 낮춘다. 그래서 원본은 중간 밝기로 둔다.

```
Scene infamous, ending card, calm still-life composition. An empty small room at night, floor-level view: a phone lies face-down on the wooden floor, its notification light spilling around it in soft rings of coloured glow across the floorboards; a dropped grey hoodie, a beanbag, an open snack bag nearby; soft moonlight from the window. Lonely but comic mood.
```
검수: 사람이 있으면 불합격. 너무 어두워 폰 빛이 안 보이면 다시 뽑는다.

### 3.7 `sc_ghost_d2` — 태현의 책상, 시 쓰다 구긴 메모와 반성문

대본에서 태현은 "진짜 A4 세 장"짜리 반성문 사진을 보낸다. 그 반성문을 책상 가운데에 두어 `mo_daily_taehyun_dawn` 과 구분했다. 시트 E 아래 칸이다.

```
Scene sc_ghost_d2. A messy desk in a friend's room at night: in the centre three stapled A4 sheets densely filled with neat unreadable pencil strokes, an apology letter, with a phone held above it by a hand in a striped sleeve, taking a photo of it; around it a pile of crumpled memo papers, one smoothed-out sheet of short poem-like lines heavily crossed out, a laptop glowing with a blurred video-player shape, a small ring light. Warm desk-lamp light, city lights in the window, guilty-comic mood.
```
검수: 반성문이나 메모에 읽히는 글자가 있으면 불합격. 태현의 얼굴이 보이면 불합격(손과 소매만). `mo_daily_taehyun_dawn` 과 너무 비슷하면 이 칸은 버리고 그 그림을 재사용한다.

### 3.8 `m36_waiting` (엔딩, good) — 대답은 101일째에, "입력 중…"인 창가

`endings.json`: 이름 "대답은 101일째에". 에필로그 "100일째 밤에도 대답은 '입력 중…'이었다. 달력 맨 끝에 처음으로 101을 적었다."
상대는 열두 명 가운데 누구든 될 수 있으므로 사람은 그리지 않는다. "입력 중"은 말풍선 속 점 세 개로, "101"은 숫자 대신 달력 마지막 칸 밖에 손으로 그려 넣은 빈 칸 하나로 보여 준다.
같은 시트의 `m36_letgo`(저녁 강변, 바깥)와 대비되게 밤의 실내, 호박색과 남색으로 잡았다.

```
Scene m36_waiting, ending card, calm still-life composition. Night, close view of a windowsill in a small room: a phone stands propped against the window glass, its screen glowing soft warm white with one long sent bubble shape above and, at the bottom, a small bubble holding three glowing dots, as if someone is still typing. Beside it a mug of tea gently steaming, and the protagonist's hand in a grey sleeve rests on the sill, fingertips just short of the phone. On the wall to the side a plain wall calendar whose last row is full, with one extra square freshly hand-drawn in pen just past the grid. Outside, city lights and many lit windows as soft bokeh. Warm amber lamp light from inside against deep blue night, hopeful, held-breath, open-ended mood.
```
검수: 사람이 손 말고 보이면 불합격. 달력이나 화면에 숫자·글자가 있으면 불합격(점 세 개와 빈 칸만). 점 세 개가 안 보이면 다시 뽑는다(이 그림의 핵심이다). 하트 기호는 넣지 않는다(아직 대답 전이다).

### 3.9 `m36_letgo` (엔딩, good) — 내가 정한 끝, 가벼운 발걸음

`endings.json`: 이름 "내가 정한 끝". 에필로그 "정리하자고 한 건 나였다. 고마웠다는 말을 한 번 더 들었다. 100일 전의 나는 끝내는 법도 몰랐다."
SP 문단의 "그날 저녁엔 혼자 멀리 걸었다. 생각보다 발이 가벼웠다"를 장면으로 삼았다. 슬픔보다 홀가분함이 먼저 보여야 한다. 그래서 상자나 눈물 같은 이별 소품은 넣지 않는다.

```
Scene m36_letgo, ending card, calm still-life composition. Early evening on a wide riverside walking path, seen from behind at a little distance: the protagonist walks away alone with an easy, light stride, hands free, a grey jacket, the phone tucked into a back pocket with its screen dark. The path ahead is long and open; a few cyclists far ahead are tiny dark silhouettes; the river reflects a pale peach-and-lavender sunset; a bridge in the distance with its first lights coming on. Soft warm backlight and a long shadow stretching toward the camera. Clean, light, bittersweet but relieved mood.
```
검수: 주인공 옆에 다른 사람이 나란히 있으면 불합격(혼자 걷는 그림이다). 옆얼굴이 보이면 불합격. 너무 어둡고 쓸쓸하면 `One step brighter, keep the sunset.` 로 다시 뽑는다.

### 3.10 `villain_legend` (엔딩, solo) — 동네 전설, 편의점 앞 왕좌

`endings.json`: 이름 "동네 전설". 에필로그 "연인은 없다. 대신 동네 커뮤에 내 이름으로 된 말머리가 생겼다. 다들 쓴다. 나도 쓴다."
SP 문단 "편의점 알바생이 먼저 인사했다"에서 장소를 가져왔다. 벌이 아니라 "이긴 빌런"의 블랙코미디다(r2 회의 E4).
`influencer`(무대, 금색)와 `infamous`(빈 방 바닥, 홀로)와 겹치지 않게 **밤거리 편의점 앞**, 자홍빛 밤과 가게의 흰 불빛으로 잡았다.
"말머리"는 글자를 쓸 수 없으므로, 동네 게시판을 내 뒷모습 실루엣 사진으로 가득 채워 보여 준다.

```
Scene villain_legend, ending card, calm still-life composition. Late night on a narrow neighbourhood street, seen from behind the protagonist sitting sprawled like a king on a white plastic chair outside an unbranded convenience store, one arm resting on the plastic table beside a cup of instant noodles, grey hoodie, a dark cap; the store's bright window light spills across the pavement. On the wall beside them a neighbourhood bulletin board is crowded with blank paper notices and many small pinned photo prints that all show the same dark back-view silhouette in a grey hoodie and cap. Across the street, small phone screens glow from a dark upper window and from two tiny featureless passer-by silhouettes, pointed their way. Magenta-violet night with the cold white store glow, smug black-comedy triumph.
```
검수: 맥주 캔, 술병, 소주잔이 있으면 불합격(음료는 컵라면만). 편의점 간판에 글자나 상표 색 조합이 있으면 불합격. 게시판 종이에 글자가 있으면 불합격.
사진 속 실루엣이나 행인에게 얼굴이 생기면 불합격.

---

## 4. 묶어 뽑기 (2컷 시트)

### 4.1 왜 2컷이고 4컷이 아닌가

ChatGPT 의 캔버스는 1536×1024, 1024×1536, 1024×1024 세 가지뿐이다.

| 시트 | 한 칸 크기 | 앱이 쓰는 폭(가장 큰 아이폰 1176px) 대비 | 판단 |
|---|---|---|---|
| 가로 2×2 (1536×1024) | 768×512 | 65% | **흐려 보인다. 쓰지 않는다** |
| 가로 3×2 | 512×341 | 44% | 쓰지 않는다 |
| **세로 1×2 (1024×1536)** | **1024×683** | **87%** | **D2·D3 장면과 엔딩에 쓴다** |

세로 캔버스에 3:2 그림 두 칸을 위아래로 쌓는 것만 화질이 버틴다. 한 번에 두 장이 나오고, 두 칸이 같은 생성에서 나와 화풍이 맞는다는 장점도 있다.
P0 5장은 카드라서 확대 뷰어에서도 보인다. 그래서 1200×800 을 채우도록 한 장씩 만든다.
(더 빨리 하고 싶으면 P0 도 시트로 만들 수 있다. 대신 확대했을 때 조금 흐리다.)

### 4.2 시트 프롬프트 (공통 블록을 붙인 대화에서)

`<위 칸>` 과 `<아래 칸>` 에는 §3 의 프롬프트에서 `Scene xxx.` 뒤 문장만 넣는다.

```
Make ONE tall 1024×1536 image: a sheet of two separate illustrations stacked vertically. Each illustration is a full-width landscape 3:2 panel (1024×683). Separate them with a plain white horizontal gutter and leave the remaining canvas plain white. Same rules as before for both panels, same style and lighting quality in both.
Top panel: <위 칸>
Bottom panel: <아래 칸>
```

| 시트 | 위 칸 | 아래 칸 | 저장 이름 |
|---|---|---|---|
| A | §3.1 `sc_leak_d3` | §3.2 `sc_clip_d3` | `art_src/scene_sheets/sc_leak_d3+sc_clip_d3.png` |
| B | §3.3 `sc_speech_d2` | §3.4 `sc_swap_d2` | `art_src/scene_sheets/sc_speech_d2+sc_swap_d2.png` |
| C | §3.5 `influencer` | §3.6 `infamous` | `art_src/scene_sheets/influencer+infamous.png` |
| D | §3.8 `m36_waiting` | §3.9 `m36_letgo` | `art_src/scene_sheets/m36_waiting+m36_letgo.png` |
| E | §3.10 `villain_legend` | §3.7 `sc_ghost_d2` | `art_src/scene_sheets/villain_legend+sc_ghost_d2.png` |

시트 C 는 같은 밤, 같은 폰 불빛의 두 결말(성공과 망신)이라 한 장에서 뽑으면 대비가 더 잘 산다.
시트 D 도 같은 92일째 선택의 두 끝(기다림과 정리)이라 짝이 맞는다. 밤의 실내와 저녁의 바깥으로 색을 갈랐다.
시트 E 는 짝이 없는 `villain_legend` 의 빈 칸에 `sc_ghost_d2` 를 넣은 것이다. 둘 다 밤, 따뜻한 인공광, 블랙코미디라 한 생성에서 화풍이 잘 맞는다.
엔딩 문구가 아직 다듬어지는 중이다. 시트 D·E 는 `endings.json` 의 해당 에필로그가 확정된 뒤에 뽑는다. 장면이 바뀌었으면 §3 프롬프트를 먼저 고친다.
검수는 칸마다 §3 의 기준을 그대로 적용한다. **한 칸만 불합격이면** 그 칸만 §3 의 단독 프롬프트로 다시 뽑는다. 장면은 `assets/scenes/<이름>.png`, 엔딩은 `assets/endings/<이름>.png` 로 저장한다.

---

## 5. 변환 (저장소 도구 그대로)

저장소에 이미 있는 도구:
- `tool/convert_art.py`: `assets/scenes|photos|endings/` 의 PNG·JPG 를 **WebP q90, 긴 변 1200(사진 800)** 으로 바꾸고 원본은 `art_src/<폴더>/` 로 옮긴다.
  Pillow 는 처음 실행할 때 `.venv/` 에 자동으로 깔린다.
- `tool/split_stickers.py`: 스티커 전용이다(2×2, 마젠타 키잉, 384px 정사각). 장면 시트에는 맞지 않는다. 그래서 아래에 짧은 분할 명령을 따로 둔다.

### 5.1 한 장짜리(P0, 단독으로 뽑은 P1)

```sh
cd ~/workspace/mossol
# ChatGPT PNG 를 이름만 바꿔 넣는다: assets/scenes/sc_leak_d1.png … / 엔딩은 assets/endings/influencer.png
python3 tool/convert_art.py --dry-run   # 무엇이 바뀌는지 먼저 본다(scenes·photos·endings 의 모든 PNG 가 대상이다)
python3 tool/convert_art.py             # → assets/scenes/sc_leak_d1.webp 1200×800, 원본은 art_src/scenes/
```

### 5.2 시트(2컷) 자르기

시트 PNG 를 `art_src/scene_sheets/<위>+<아래>.png` 로 저장한 뒤 저장소 루트에서 실행한다. 흰 가로 틈을 찾아 칸을 나눈다.
틈을 못 찾으면 위아래 반으로 나눈다. 그다음 칸마다 가운데 기준으로 3:2 를 맞추고 WebP q90 으로 저장한다(확대하지 않는다).
`influencer`·`infamous`·`m36_waiting`·`m36_letgo`·`villain_legend` 는 `assets/endings/`, 나머지는 `assets/scenes/` 로 간다. 다시 돌려도 같은 결과를 덮어쓴다.

```sh
cd ~/workspace/mossol
[ -x .venv/bin/python ] || python3 tool/convert_art.py --dry-run   # .venv 와 Pillow 를 처음 한 번 준비
.venv/bin/python - <<'EOF'
import pathlib
from PIL import Image
ENDINGS = {"influencer", "infamous", "m36_waiting", "m36_letgo", "villain_legend"}
for sheet in sorted(pathlib.Path("art_src/scene_sheets").glob("*.png")):
    names = sheet.stem.split("+")
    im = Image.open(sheet).convert("RGB")
    W, H = im.size
    g = im.convert("L")
    # 가로 전체가 거의 흰색인 줄 = 칸 사이 틈
    white = [sum(1 for x in range(0, W, 4) if g.getpixel((x, y)) > 235) > 0.97 * (W // 4) for y in range(H)]
    bands, start = [], None
    for y, w in enumerate(white + [True]):
        if not w and start is None: start = y
        if w and start is not None:
            if y - start > 200: bands.append((start, y))
            start = None
    if len(bands) != len(names):  # 틈을 못 찾으면 똑같이 나눈다
        step = H // len(names); bands = [(i * step, (i + 1) * step) for i in range(len(names))]
    for name, (y0, y1) in zip(names, bands):
        cell = im.crop((0, y0, W, y1))
        cw, ch = cell.size  # 가운데 기준 3:2
        if cw / ch > 1.5: nw = round(ch * 1.5); cell = cell.crop(((cw - nw) // 2, 0, (cw - nw) // 2 + nw, ch))
        else: nh = round(cw / 1.5); cell = cell.crop((0, (ch - nh) // 2, cw, (ch - nh) // 2 + nh))
        out = pathlib.Path("assets") / ("endings" if name in ENDINGS else "scenes") / f"{name}.webp"
        cell.save(out, "WEBP", quality=90, method=6)
        print(f"{sheet.name} → {out}  {cell.size[0]}×{cell.size[1]}  {out.stat().st_size // 1024}KB")
EOF
```

출력 예: `sc_leak_d3+sc_clip_d3.png → assets/scenes/sc_leak_d3.webp  1024×683  95KB`. 한 칸이 300KB 를 넘으면 `quality=90` 을 `85` 로 낮춘다
(`tool/check_assets.py` 의 상한은 scenes 320KB, endings 360KB 다).

### 5.3 확인

```sh
python3 tool/check_assets.py -v
```

이 15장은 아직 `SCENE_PROMPTS.md` 기대 목록에 없다. 그래서 "남는 파일"로 찍히는데, 이건 경고일 뿐 실패가 아니다.
`01_design.md` §6.2 대로 S18~S29 를 그 문서에 옮기고, 새 엔딩 3장을 S30~S32 로 이어 붙이면 기대 목록이 114장에서 129장으로 늘고 경고가 사라진다(이 작업은 문서 담당이 한다).
15장의 용량은 대략 5×~100KB + 10×~90KB ≈ 1.4MB 다.
진짜 엔딩 그림을 넣은 뒤에는 §3 의 "엔딩 대체 그림에 대해"대로 그 엔딩의 `image` 필드를 지운다. 지우지 않으면 대체 그림이 계속 뜬다.

---

## 6. 움직이는 그림에 대한 의견

**§6.3 에 동의한다. 영상(mp4)은 넣지 않고, 출시 때 움직이는 WebP 도 0장으로 둔다.** 근거는 아래와 같다.

1. **자극은 UI 에서 나온다.** 알림이 쏟아지고, 읽음 숫자가 오르고, 소문 게이지가 터지는 연출은 그림이 아니라 코드다.
   코드로 만들면 한국어 글자를 넣을 수 있고, 동작 줄이기도 따르고, 용량은 0 이다.
2. §6.3 이 후보로 든 두 루프도 **코드로 흉내 낼 수 있다.** 마이크의 빨간 불은 정지 그림 위 고정 좌표에 빨간 원형 그라데이션을 깜빡이게 얹으면 된다.
   축사 장면은 Ken Burns(6초, 1.00→1.04)에 녹화 폰의 빨간 점 깜빡임만 얹어도 "멈춘 순간"이 살아 보인다.
3. **용량.** 정지 그림 한 장이 ~100KB 인데, 2초 루프는 400~600KB 다. 장당 5배다. 지금 에셋이 44MB 라 여유가 크지 않다.
4. **품질 관리.** 영상 생성 도구는 몇 프레임만 지나도 얼굴이 생기거나 글자가 생기거나 화풍이 흔들린다. 이 게임의 두 금지 규칙(얼굴, 글자)을 프레임마다 검수해야 한다.
5. **코드가 어차피 필요하다.** `Image.asset` 은 움직이는 WebP 를 재생하지만, 동작 줄이기를 스스로 따르지 않는다.
   정지 폴백 파일을 따로 두고 분기하는 코드가 필요하다. 그 코드를 짤 거라면 2번의 오버레이를 짜는 쪽이 싸다.

**그래도 해 본다면**: 출시 뒤 `sc_clip_d1` 하나만 실험한다(빨간 불과 알림 빛은 깜빡임이라 루프가 자연스럽다). 아래 프롬프트는 최대 2개다.

### 6.1 만드는 법 (Sora · Runway · Kling 공통)

- **이미지→영상** 모드에 완성된 P0 정지 그림(1536×1024 원본 PNG, `art_src/scenes/`)을 첫 프레임으로 넣는다. 그래야 화풍이 유지된다.
- 카메라 고정, 5초, 720p 이상으로 뽑는다. 앞쪽에서 **1초**만 잘라 **정방향+역방향(핑퐁)** 으로 이어 2초 루프를 만든다. 핑퐁으로 이으면 이음매가 생기지 않는다.
- 결과 규격: **720×480, 12fps, 2초(정방향 12 + 역방향 10 = 22프레임), 무한 반복, 600KB 이하**.
  파일 이름은 정지 그림을 지우지 않도록 따로 둔다: `assets/scenes/sc_clip_d1_loop.webp`(연결 코드는 별도 작업이다).

프롬프트 1 — `sc_clip_d1` (추천):
```
Animate this exact illustration with a locked-off static camera. Only three things move: the small red light on the microphone slowly pulses brighter and dimmer, the phone screen softly flashes with notification glow twice, and the window curtain sways very slightly. Nothing else moves. No new objects, no people, no faces, no text. Keep the illustrated webtoon style, line work and colours identical to the input image. Seamless loop.
```

프롬프트 2 — `sc_speech_d1` (선택. 1일차 그림에서 날아가는 부케를 뺐으므로, 깜빡이는 것만 움직인다. 핑퐁에서도 어색하지 않다):
```
Animate this exact illustration with a locked-off static camera. Only three things move: the bright banner on the big screen flickers softly, the tiny red recording dot on the front-row phone blinks, and the chandelier light shimmers. The podium, the person, the bouquet and the guest silhouettes stay completely still. No new objects, no faces, no text. Keep the illustrated webtoon style and colours identical to the input image. Seamless loop.
```

### 6.2 변환 명령

이 맥의 ffmpeg 에는 WebP 인코더(libwebp)가 없다. 그래서 프레임을 PNG 로 뽑은 뒤 Pillow 로 묶는다. 시험해 보니 24프레임 720×480 이 약 260KB 였다.

```sh
cd ~/workspace/mossol
IN=~/Downloads/clip.mp4; NAME=sc_clip_d1_loop; START=0.5   # 1초를 자를 시작 지점(초)
rm -rf /tmp/mossol_frames && mkdir /tmp/mossol_frames
ffmpeg -loglevel error -ss $START -t 1 -i "$IN" \
  -vf "fps=12,scale=720:480:force_original_aspect_ratio=increase:flags=lanczos,crop=720:480" /tmp/mossol_frames/%03d.png
.venv/bin/python - "$NAME" <<'EOF'
import glob, pathlib, sys
from PIL import Image
f = [Image.open(p).convert("RGB") for p in sorted(glob.glob("/tmp/mossol_frames/*.png"))]
f = f + f[-2:0:-1]  # 핑퐁: 정방향 + 역방향(양 끝 프레임은 중복하지 않는다)
out = pathlib.Path("assets/scenes") / f"{sys.argv[1]}.webp"
f[0].save(out, save_all=True, append_images=f[1:], duration=83, loop=0, quality=70, method=6)
print(out, len(f), "frames", out.stat().st_size // 1024, "KB")
EOF
```

600KB 를 넘으면 하나씩 줄여 본다. `quality=70` → `60`, 그다음 `fps=12` → `10`, 그다음 `720:480` → `600:400`.
