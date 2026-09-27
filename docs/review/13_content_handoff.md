# 13 · 콘텐츠에서 나가는 요청

> 2026-09-27 · narrative. 내가 고친 것은 `docs/review/13_content_fixes.md`.
> **내 파일**: `assets/story/{events_daily,events_special,events_moments,events_route_a,events_route_b,route_*,signals}.json` · `tool/**`
> **내 파일이 아닌 것**: `events_main.json`(★) · `characters.json` · `config.json` · `lib/**` · `test/**`
> 커밋은 안 했다. 아래 요청은 §3 만 빼고 전부 **한 줄~열 줄**이다.

---

## 1. ⚠ 오프닝 10개가 사흘을 두고 경쟁한다 — 설계 판단을 넘긴다 (기획 · `test/opening_test.dart`)

**측정부터.** 100일 완주 30회차(`flutter test tool/unseen_dailies.dart`):

```
d_open_groupchat   후보 30/30 · 읽힘  6/30
d_open_story       후보 30/30 · 읽힘 12/30
d_open_outfit      후보 30/30 · 읽힘 12/30
d_open_late_msg    후보 30/30 · 읽힘 12/30
d_open_meme        후보 30/30 · 읽힘 18/30
```

오프닝 일상 10개가 전부 `day: [1, 3]` 이고, 오프닝 사흘이 뽑는 일상 칸은 예닐곱 개다.
**회차마다 서너 개는 구조적으로 못 나온다.** 이미 다 쓴 글이 회차의 5분의 4에서 안 읽힌다.

창을 넓혀서 실측해 봤다(그리고 **되돌렸다**). 아래는 오프닝 일곱 + `d_fu_*` 셋의 창을
**함께** 넓힌 중간 측정이라 오프닝 단독의 몫은 아니다. 다만 "후보는 됐는데 안 뽑힘" 이
2.8 줄어든 것은 **거의 전부 오프닝이다** — `d_fu_*` 는 창이 아니라 플래그에 막혀 있다(아래).

| | 지금(최종) | 창을 넓힌 중간 측정 |
|---|---|---|
| 회차당 안 읽힌 1회성 일상 | 28.4 / 101 | **25.8 / 101** |
| "후보는 됐는데 안 뽑힘" | 4.5 | **1.7** |
| `id` 기준 재방송(30회차) | 20.7 % | **20.0 %** |

**되돌린 이유**: `test/opening_test.dart` 가 셋으로 막는다.

```
일상 오프닝은 day [1, 3~4]·weight 3~5                  (day.max ∈ [3,4])
일상 오프닝(2단 포함)은 4일차부터 후보에 들지 않는다        (4~100일차 전부에서 후보 0)
4일차 이후 기존 풀 잠식 없음: 10일차 일상 후보 수가 오프닝 추가 전과 같다
```

세 번째 줄 이름이 **"기존 풀 잠식 없음"** 이다. 오프닝은 첫인상 묶음이고 중반 풀을 희석하지
않는다는 게 **결정**이지 누락이 아니라고 읽었다. 내 파일이 아닌 테스트가 그 결정을 지키고 있으니
콘텐츠가 혼자 뒤집을 일이 아니다. **판단만 주면 데이터는 내가 한 번에 넣는다.**

### 넘기는 안 셋

**(A) 아무것도 안 한다.** 오프닝 넷은 회차당 3~4개씩 계속 안 읽힌다. 대신 2회차·3회차에
다른 오프닝이 나와서 **회차를 다시 돌 이유**가 된다고 보면 이게 맞다.

**(B) `day.max` 를 4로 (테스트 한 줄만 바뀐다).** `[1,3]` → `[1,4]` 는 첫 단정문(`3~4`)은
통과하지만 "4일차부터 후보에 들지 않는다"가 깨진다 → 그 테스트의 시작일을 5로 바꾸면 된다.
오프닝이 하루치 칸을 더 얻는다. 실측하지 않았지만 회차당 1개쯤이다.

**(C) 픽션이 안 묶인 것만 중반까지 연다** (내가 이득을 실측한 안). 넷은 대사에 D+1 을 가리키는
말이 없어서 그대로 넓힌다. 셋은 그 말 한 줄만 고치면 된다 — 아래 표의 문장은 내가 써서
한 번 넣어 보고 되돌린 것이라 그대로 쓸 수 있다.

| 이벤트 | 창 | 고칠 줄 |
|---|---|---|
| `d_open_wrong_number` 잘못 온 문자 | `[1,60]` | — |
| `d_open_meme` 위로 짤 타이밍 | `[1,70]` | — |
| `d_open_late_msg` 새벽 1시 14분 | `[1,70]` | — |
| `d_open_groupchat` 단톡 자기소개 | `[1,45]` | — |
| `d_open_story` 첫 스토리 | `[1,60]` | `프사 바꾼 김에 스토리도 하나 올렸다. …` → `스토리를 하나 올렸다. 카페 창가, 커피, 손 살짝.` |
| `d_open_outfit` 옷장 앞 20분 | `[1,60]` | `100일 프로젝트 첫 외출. 옷장 앞에서 20분째.` → `사람을 만나러 나가는 날. 옷장 앞에서 20분째.` |
| `d_open_pfp_who` 누구세요? | `[1,30]` | `프사를 바꾼 지 한 시간. …` → `프사를 바꾼 뒤로 처음. 3년 만에 톡이 온 고등학교 동창.` |
| `d_open_bet` · `d_open_hello` · `d_open_app_match` | **`[1,3]` 유지** | `d_open_bet` 은 100일 내기 전제, `d_open_hello` 는 "100일 프로젝트 첫 실전"(이미 30/30 읽힘), `d_open_app_match` 는 창을 열면 `m09`(D+23, 태현이 앱을 처음 소개한다)와 더 자주 어긋난다 |

(C) 로 가면 `test/opening_test.dart` 의 "4일차 이후 격리" 두 건과 "day [1,3~4]" 한 건을
**오프닝 세 개(`bet`·`hello`·`app_match`)만 보도록** 좁혀야 한다.

### 같이 봐 달라 — `d_fu_*` 셋의 창도 `[4, 20]` 이다

`d_fu_stranger`·`d_fu_locked`·`d_fu_lurker` 는 오프닝의 선택으로만 열리는 후속편인데
창이 17일이다. `opening_test.dart:507` 이 `day.min == 4`·`day.max ≤ 20` 과
`trigger.flags == [flag]` 를 못 박고 있어서 손대지 않았다. 픽션은 셋 다 며칠 뒤여도 몇 주
뒤여도 맞는다("그 번호가 또 연락했다", "자물쇠 계정이 팔로우를 걸었다", "단톡에서 눈팅을
호명한다").

**다만 실측으로는 창이 범인이 아니었다.** `[4, 100]` 으로 열어 놓고 30회차를 돌려도
`d_fu_locked` 는 후보 8/30 에서 안 움직였다 — `app_installed` 가 `d_open_app_match` 의
첫 선택지에서만 서고, 그 선택지가 8회차에서만 골라지기 때문이다. 같은 이유로 `d_fu_lurker` 는
0/30 이다(`lurker` 는 '읽기만 한다'에서만 선다). **선택 갈래의 보상이므로 그 조건은 안 풀었다.**
창을 여는 건 여유일 뿐이고, 셋 중 실제로 막혀 있던 것은 `d_fu_stranger` 하나였다 —
그건 창을 안 건드리고 **플래그가 서는 경로를 늘려서** 0/30 → 24/30 으로 열었다
(13_content_fixes §1.2b).

---

## 2. `test/rerun_share_test.dart` 가 **변형 대사를 못 본다** — 한 줄 (엔진)

목표를 재는 눈금이 목표를 이루는 도구를 못 본다. 이번 라운드에서 제일 중요한 요청이다.

```dart
// test/rerun_share_test.dart, RerunTally.saw
final n = (count[e.id] ?? 0) + 1;   // ← id 로만 센다
count[e.id] = n;
```

`playFullRun` 은 `engine.viewFor(s, ev)` 를 읽는데, `viewFor` → `variantOf` → `withLines` 는
**id 를 그대로 복사한다.** 그래서 `12_engine_fixes §4.1` 이 재방송을 줄이라고 만들어 준
`variants` 가 이 지표에 한 글자도 안 보인다. 그 문서가 "실효 +20" 이라고 쓴 '실효' 가 바로
이 눈금 밖이다.

**실측 차이** (같은 정의, 같은 30회차, 씬 식별자만 `id` → `id#변형번호`):

| | 작업 전 | 최종 |
|---|---|---|
| `id` 기준 | 21.7 % | 21.8 % |
| **변형까지 센 기준** | 21.7 % | **4.8 %** |

계산식은 `EventEngine.variantOf` 와 같고, 내 하네스에 옮겨 놓았다
(`tool/unseen_dailies.dart` 의 `readScenes`):

```dart
final n = base.variants.length + 1;
final vi = n == 1 ? 0
    : (EventEngine.stableSeed(s.seed, 0, 'variant:${base.id}') % n +
       (base.once ? 0 : s.viewsOf(base.id))) % n;
final sceneKey = vi == 0 ? base.id : '${base.id}#$vi';
```

`RerunTally.saw` 가 `e.id` 대신 이 `sceneKey` 를 쓰면 된다(`saw` 에 변형 번호를 넘기거나,
`playFullRun` 이 큐에서 꺼낼 때 계산해서 같이 넘기거나). **문턱값은 그대로 두고** 두 숫자를
같이 찍는 게 제일 좋다 — `id` 기준은 "장면 종류가 부족하다"를, 변형 기준은 "플레이어가 같은
글자를 다시 읽는다"를 재는 서로 다른 지표다.

---

## 3. `events_main.json` — 미니게임 24곳에 `failNext` 가 없다 ★ (작가/메인 담당)

전 코퍼스 미니게임 선택지 191개 중 `failNext` 는 **0 → 46** 이 됐다(내 파일 167곳 중 46).
**남은 24곳이 전부 `events_main.json` 이다.** 내가 쓴 뒷일 장면 10개는 이미 번들에 있으니
**`"failNext": "<id>"` 한 줄만 넣으면 된다** — 장면을 새로 쓸 필요가 없다.

뒷일 장면 목록과 성격:

| id | 무엇이 오는가 | 어떤 실패에 맞는가 |
|---|---|---|
| `mo_fail_capture` | 지웠다고 믿은 화면이 사진으로 돌아온다 | 삭제 실패 |
| `mo_fail_drunk_replay` | 다음 날 오후, 동아리 단톡에 어제 영상 | 술자리에서 선을 넘음 |
| `mo_fail_stranger_saw` | 말 못 건 상대가 먼저 톡을 한다 | 얼어붙음 |
| `mo_fail_intro_capture` | 내 한 줄 캡처가 다른 단톡으로 | 단톡에서 말이 엉킴 |
| `mo_fail_mirror_shot` | 준호에게 결과물 사진을 보낸다 | 머리·옷·거울 |
| `mo_fail_half_sent` | 상대가 먼저 반을 송금한다 | 데이트 코스·계산 |
| `mo_fail_misread` | 설명 없는 사진 한 장이 온다 | 감정을 잘못 읽음 |
| `mo_fail_late_dawn` | 답장을 쓰는 사이 새벽 사진이 온다 | 타이밍을 놓침 |
| `mo_fail_call_cut` | 통화가 끊기고 글로 다시 하자고 한다 | 통화가 꼬임 |
| `mo_fail_meme_missed` | 내 짤 위에 다른 짤이 먼저 | 짤이 늦음 |

**내가 보기에 맞는 자리 (권고)**

| 이벤트 | 선택지 | 미니게임 | `failNext` |
|---|---|---|---|
| `m02` | ch0 `알겠어, 연습해 볼게` | read_emotion | — (준호와의 연습 장면이다. 상대가 사진 보낼 자리가 아니다) |
| `m04` | ch0 `일단 헬스장 등록` | nerve_gauge | — (혼자 거울 앞이다. `mo_fail_mirror_shot` 은 '보냈다'를 전제하니 안 맞는다) |
| `m06` · `m06_m` | ch0 | reply_timing | **`mo_fail_late_dawn`** |
| `m07` | ch0 `자기소개를 한다` | nerve_gauge | **`mo_fail_drunk_replay`** (뒤풀이 자리다) |
| `m08` · `m08_m` | ch0 | group_chat | **`mo_fail_intro_capture`** |
| `m09` · `m09_f` | ch0 | profile_swipe | — (`mo_*` 중 프로필 실패에 맞는 것이 없다. 필요하면 내가 하나 더 쓴다) |
| `m10` | ch0 `코스를 짠다` | date_course | **`mo_fail_half_sent`** |
| `m12` · `m12_m` | ch1 | reply_timing | **`mo_fail_late_dawn`** |
| `m13` | ch1 `준비한 드립을 친다` | word_order | **`mo_fail_drunk_replay`** (정적 뒤 다음 날) |
| `m14` | ch2 `답장하지 않는다` | reply_timing | **`mo_fail_late_dawn`** (failReply 가 이미 '메시지가 삭제되었습니다'다) |
| `m17` | ch1 `규칙을 버린다` | reply_timing | **`mo_fail_late_dawn`** |
| `m18` · `m18_m` | ch0 | date_course | **`mo_fail_half_sent`** |
| `m20` | ch0 | reply_timing | **`mo_fail_late_dawn`** |
| `m21` | ch0 `지금 {top}한테 말한다` | nerve_gauge | — **손대지 마시길.** 55일차 성급한 고백이고 `failReply` 가 이미 그 장면의 결말이다. 여기에 사진 한 장을 더 붙이면 무게가 깎인다 |
| `m23` | ch1 `전부 유지한다` | nerve_gauge | **`mo_fail_misread`** (failReply 가 '엉뚱한 방에 보냈다'다) |
| `m27` | ch0 `부족했다고 먼저 사과한다` | reply_timing | **`mo_fail_late_dawn`** |
| `m35` | ch0 `한다고 한다` | word_order | — (준호 결혼식 축사다. 전용 뒷일이 필요하면 내가 쓴다) |
| `m37` | ch0 `그럼 3개월 동안 뭐였어` | nerve_gauge | — 손대지 마시길. 태현 진실 장면이다 |
| `m39` | ch1 | word_order | — |

권고대로면 **13곳**이 붙고 191 중 59가 된다. `failNext` 가 없는 자리 11곳에는 이유를 적었다 —
**전부 붙이는 게 목표가 아니다.** 클라이맥스(`m21`·`m37`)는 실패 자체가 결말이라 뒤에 장면을
붙이면 오히려 약해진다.

**주의 하나**: `failNext` 대상 id 가 번들에 없으면 검증기가 `없는 next 참조: <id> -> <dest>` 로
앱을 막는다. 위 10개는 이미 `events_moments.json` 에 있으니 그대로 쓸 수 있다.

**새 뒷일 장면이 필요하면 말해 주면 쓴다** — `events_moments.json` 은 내 파일이고, 거기에 두면
`test/event_engine_test.dart:54` 의 `expect(baseEvents().length, 403)` 이 안 움직인다
(`mo_` 접두사를 세지 않는다).

---

## 4. `StoryBundle.repeatableDaily` 가 뽑히지도 않는 장면을 센다 — 한 줄 (엔진)

내 뒷일 장면 10개 때문에 소프트락 방지선 계수가 **24개 → 34개**로 읽힌다.
`flutter test test/rerun_share_test.dart` 출력이 지금 이렇다.

```
반복 가능한 일상(여성 캐릭터) 34개 / 최소 14개
```

**진짜 뽑히는 반복 일상은 여전히 24개다.** 10개는 `trigger: {"day": [0, 0]}` 이라
`_available` 을 절대 통과하지 못하고 `failNext` 로만 열린다.

`once: false` + `layer: "daily"` 는 고른 게 아니라 **테스트 둘이 양쪽에서 막아 남은 한
조합**이다(13_content_fixes §3.1):

- `once: true` → `rerun_share_test` 의 "once 이벤트는 한 번도 재등장하지 않는다" 가 깨진다.
  `next`/`failNext` 로 들어온 이벤트는 `_available` 을 안 지나므로 `once` 가 안 걸린다
  (실측 `mo_fail_late_dawn×3`). **이건 그 자체로 엔진 쪽에서 볼 만한 자리다** —
  `once` 가 층과 무관하게 걸린다는 주석과 실제 동작이 체인 경로에서 갈린다.
- `once: false` + `layer: "route"` → 같은 테스트 `:299` 가 **두 번 읽힌 것은 전부 `daily` 층**
  이어야 한다고 막는다.

요청은 한 줄이다.

```dart
List<StoryEvent> repeatableDaily(String pref) => [
  for (final e in events)
    if (e.layer == EventLayer.daily && !e.once && eventInPreference(e, pref)
        // 창이 닫힌 이벤트(`next`/`failNext` 전용)는 추첨 풀이 아니다.
        && (e.trigger.day?.max ?? 1) >= 1)
      e,
];
```

이게 들어가면 계수가 24로 돌아오고 방지선이 다시 정확해진다.
**그때까지 다음 사람은 34를 믿고 `once: true` 를 더 붙이면 안 된다.**

---

## 5. 참고 — 이번 라운드에 내가 안 건드린 것

- **`characters.json`**: 이번 내 파일 목록에 없다. `13_engine_handoff.md` §1 의 `politeness`
  세 줄은 이미 누군가 넣었다(작업 트리에 `jiwoo`·`seunghyun`·`doyun` 확인).
- **`config.json` 의 `openingScript`**: 아직 `[]` 다. `12_engine_handoff.md` §5 의 재청구가
  그대로 남아 있다. 다만 §1 의 오프닝 문제는 `openingScript` 로는 안 풀린다 —
  대본은 **1회차 D+1 하루**에만 깔리므로 열 개를 적으면 첫날에 열 개가 다 나온다.
- **`signals.json`**: 이번 지시에 항목이 없었다.
- **`tool/transcripts/second_door_transcript.dart` 의 중복 제거**(`12_engine_handoff.md` §6):
  `tool/**` 는 내 파일인데 **못 했다.** 이번 라운드 세 과제에 밀렸다. 고칠 자리와 붙일 코드는
  그 문서 §6 에 그대로 있다(`queue.removeWhere` 한 줄). 다음 사람 몫으로 남긴다.
