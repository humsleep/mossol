# 개편 2 — 2차 버그 사냥 결과 (R2)

> 2026-10-07 · 브랜치 `overhaul2-starts`(커밋 안 된 변경 포함) · 기준 문서 `r1_bugs.md`, `r1_meeting.md`
> **직접 돌려서 확인한 것만** 적었다. 재현 스크립트는 `docs/overhaul2/review/r2_scripts/*.dart.txt` 에 있다.
> `test/` 아래 임시 파일(`zz_r2_*`)은 모두 지웠다. 확장자 `.txt` 를 떼고 `test/`(위젯은 `test/widget/`)에 넣으면 돈다.
> `lib/`, `assets/` 는 건드리지 않았다.

## 요약

| 등급 | 건수 | 항목 |
|---|---|---|
| P0 | 0 | 없음 |
| P1 | 1 | R2-1 출시판 기존 사용자(엔딩 보유)가 업데이트하면 회차 간 연결(D7)이 통째로 빠지고, 시작 카드가 클래식을 기본으로 권한다 |
| P2 | 6 | R2-2 처음 보는 내용 앞의 대기도 무료로 건너뜀 · R2-3 `clock` 고정 장면 때문에 하루 안 시계가 거꾸로 감 · R2-4 결과 패널에 "진상 +1" 이 나쁜 색 칩으로 보임 · R2-5 버리는 새 게임 한 판으로 운명을 다시 뽑을 수 있음 · R2-6 메타 `announcedStarts` 형식이 틀리면 메타 전체가 초기화됨 · R2-7 휴식 설명의 소문 문구(클래식 노출, 소문 회차에서 중복) |
| 범위 밖 | 4 | 이번 변경 전부터 있던 문제(아래) |

전체 `flutter test`(임시 테스트 넣기 전): **1146개 중 통과 1145, 건너뜀 1, 실패 0**(13분 15초).

---

## 1. R1 버그 수정 확인

| R1 | 확인 방법 | 결과 |
|---|---|---|
| R1-1 정산 소문 게이지 넘침 | `r1_layout_test` + 내 `zz_r2_ui_test`(320×568, 배율 1.3/2.0, 라이트·다크). 홈·행동·정산의 게이지 | **고쳐짐.** 게이지에서 난 넘침은 0건이다. 정산 화면의 320·1.6 이상 넘침은 게이지가 아니라 `StatBars`(widgets.dart:457)에서 난다. 클래식(소문 0)에서도 같으므로 범위 밖으로 옮겼다 |
| R1-2 운명 다시 뽑기(인트로·홈) | `r1_flow_test` 운명 고정 3건 + 내 테스트: 운명을 누르자마자 뒤로 가기, 시트를 연 채 앱 일시정지·복귀 | **고쳐짐.** 뽑는 즉시 메타에 남는다. 닫기·뒤로 가기·재시작·일시정지 뒤에도 `fateLocked` 가 그대로다. 단 "새 게임을 한 판 시작했다 버리기" 경로는 R2-5 |
| R1-3 가속 캐릭터가 D1~3 에 안 나옴 | `r1_scripts/zz_r1_sim_test`(시드 100) + 내 시뮬(시작 5종 × f/m × D1 갈래 0~3 × 시드 30 = 1,200판) | **고쳐짐.** 가속 캐릭터 장면이 D3 안에 나온 비율이 1,200/1,200 이다. sc_ghost 는 `jiwoo_r00_ghost`/`seunghyun_r00_ghost` 로 100%. sc_swap 은 80% 가 `sc_swap_d2(_m)`, 20% 가 r00 으로 처음 만난다. 옛 스크립트의 sc_ghost "r00 0%" 는 id 를 `<id>_r00` 으로 고정해 센 탓이다 |
| R1-4 main 날짜 키 구멍 | `r1_scripts/zz_r1_validator_test` | **고쳐짐.** 이제 검증기가 `main 날짜 중복: 5일 (m_a, m_b)` 으로 거부한다. 옛 스크립트의 기대값("둘 다 통과")이 실패하는 것이 맞다 |
| R1-5 검증 시간 | 내 측정(실제 데이터, JIT, 5회) | **고쳐짐.** `deep:true` 는 143→92ms, `deep:false`(출시) 는 63→53ms 다. 안정 후 약 40% 줄었다 |
| R1-6 온보딩 퍼널 | `r1_flow_test` | **고쳐짐.** `start`·`name` 단계가 한 흐름에 한 번씩만 남는다 |
| R1-7 카드 명세 | `r1_flow_test` 시작 카드 묶음 | **고쳐짐.** 다만 기존 사용자는 메타가 비어 있어 효과가 없다(R2-1) |
| 범위 밖: `mo_fail_drunk_replay` 하루 두 번 | `r1_scripts/zz_r1_sim_test`(300판) | **고쳐짐.** "twice" 0건 |
| 범위 밖: 홈 320·2.0 넘침 | `zz_r2_ui_test` 홈(소문 90, 라이트·다크, 1.3·2.0) | **고쳐짐** |

R1 스크립트를 그대로 다시 돌린 결과:
- 통과: sim, legacy, resume, template.
- 실패 3건은 모두 **기대값이나 흐름이 바뀐 탓**이다. 앱 버그가 아니다.
  - validator: R1-4 를 고쳐서 이제 거부한다.
  - 인트로 flow: 운명 결과 연출(`start-fate-go`) 단계가 새로 생겼다.
  - 시작 시트 ui: 운명 카드가 맨 위로 올라가서 아래로만 굴리면 못 찾는다.
- 세 경우 모두 정식 테스트(`r1_engine_test`, `r1_flow_test`, `r1_layout_test`)가 새 흐름으로 대신 덮고 있다.

---

## 2. 새로 확인한 문제 없음(통과 항목)

- **메타 저장·복원.** 출시판(HEAD) `PlayerMeta.toJson` 키만 있는 JSON 을 읽으면:
  - 새 필드는 기본값으로 읽힌다(빨리 감기 켬, 목록은 빈 값).
  - 크래시는 없다.
- **메타 크기.** 시작 6종을 한 판씩 100일 끝까지 했을 때:
  - `seenEvents` 505개, `seenRipples` 101개.
  - 메타 JSON 전체가 10.2KB 다. 데이터 기준 상한도 이벤트 638개, 파급 줄 240개라 20KB 를 넘지 않는다. SharedPreferences 한계와는 거리가 멀다.
- **버린 회차 합치기.** 세 경로 모두 본 장면이 쌓인다.
  - 같은 세션에서 새 게임.
  - 앱을 껐다 켠 뒤(`_peek`) 홈에서 새 게임.
  - 엔딩 도달.
- **없어진·바뀐 id.**
  - HEAD 대비 이벤트 id, 엔딩 id, 캐릭터 id, 행동 id, 앨범 id 가 하나도 없어지지 않았다(522 → 533+신규 파일).
  - 기존 이벤트의 선택지 문구·순서·`hint` 도 바뀐 것이 0건이다.
  - 그래도 없는 id 를 담은 세이브·메타를 만들어 확인했다.
    - 세이브: `dayQueue`·`seen`·`dailySeenDay` 에 없는 id, 플래그에 `sc_gone`.
    - 메타: `pendingFate`·`lastStart`·`completedStarts`·`startEndings`·`seenEvents` 에 없는 id.
  - 결과: 이어 하기 → 3일 진행 → 새 게임까지 예외가 없다. 없는 id 는 조용히 건너뛴다(`?engine.byId`, `pendingFate` 게터).
- **출시 검증(`deep:false`).** 실제 데이터는 통과한다. 아래 구조 오류는 `deep:false` 에서도 그대로 예외를 던진다.
  - 없는 `next`, `clock` "1:05"/"24:00", main 날짜 중복.
  - 조건 없는 선택지 1개, 아무도 안 세우는 `ifFlags`, 없는 스탯 키(`vilain`).
  - `castLines` 의 없는 캐릭터.

  `deep:false` 에서 빠지는 것은 자리표시자 형식(`{nmae}`)과 화면 거르기 검사뿐이다. 문서에 적힌 대로의 맞바꿈이다.
- **무료 건너뛰기 기본 조건.**
  - 처음 보는 장면에는 광고 버튼만 있다.
  - 토글을 끄면 즉시 광고로 돌아간다.
  - `seen` 은 선택을 확정할 때만 쌓인다. 그래서 대기 앞에서 회차를 버려도 그 장면은 "본 장면"이 되지 않는다.
  - 무료 버튼을 60ms 간격으로 두 번 눌러도 한 줄만 넘어간다(첫 탭 뒤 다음 프레임에 버튼이 사라진다).
- **사슬 클리프행어(D6).** 세 경우 모두 의도대로다.
  - 여러 단계 사슬: main → 일상 → 일상(클리프) 이면 마지막 갈래가 이긴다.
  - `failNext` 로 이어진 갈래가 이긴다.
  - 사슬 밖 일상은 main 을 못 이긴다.
  - 실제 데이터에서 `next` 대상이 여러 부모를 가진 12곳은 모두 클리프행어가 없는 일상이라 순위 다툼이 없다. 순환 `next` 는 0건이다.
- **오프닝 가속 × `once`/`notFlags`/선호.** 위 1,200판에서 D1 갈래가 무엇이든(`seunghyun_contact` 를 세우는 갈래 포함) 100% 다. 클래식은 `opening_test` 의 균등 불변식을 그대로 통과한다.
- **`villain`.**
  - 진상 선택지 52개는 모두 앨범이나 호감 하락을 함께 가진다. 그래서 콤보("좋은 선택")로 세지 않는다.
  - 악당 봇(시작 6종 × 시드 8 = 48판, 휴식 금지, 진상·소문 선택 우선)을 돌렸다. `infamous` 7판, 진상 최대 3~19, 상한 99 안이다.
- **`castLines`.** 없는 캐릭터는 출시 검증에서도 거부된다. 이번 회차에 없는 성별의 줄은 소개 목록에 오르지 않는다.
- **레이아웃.** 변경된 화면을 320×568, 배율 1.3·2.0, 라이트·다크로 그리고 끝까지 굴렸다.
  - 대상: 시작 시트와 운명 결과, 설정, 캐스트 소개(sc_speech·양쪽), 스탯 안내(소문), 행동(소문 95), 정산(소문 99), 이벤트 화면(대사·내 말·서술·시스템 줄 NEW 점, 선택지 NEW, 무료 건너뛰기), 엔딩, 홈(소문 90), 인트로(시작 단계 → 이름 단계 + "다른 일이었어").
  - 변경분에서 난 넘침은 0건이다. 정산(`StatBars`)과 설정("앱 버전" 줄) 넘침은 예전부터 있던 것이다(범위 밖).
- **위젯 경쟁 상태.** 모두 예외 없이 끝났다.
  - 운명 카드를 크로스페이드 도중(50ms) 다시 눌러도 한 번만 뽑힌다.
  - "이 이야기로 시작"을 80ms 간격으로 두 번 눌러도 두 번 닫히지 않는다.
  - 운명을 누르자마자 뒤로 가기를 해도 메타에 남는다.
  - 시트를 연 채 앱을 일시정지했다가 복귀해도 운명이 그대로 고정돼 있다.

---

## P1

### R2-1. 출시판 기존 사용자가 업데이트하면 회차 간 연결(D7)이 비어 있고, 시작 카드가 클래식을 권한다

- **위치**:
  - `lib/engine/meta_service.dart` 의 `completedStarts`/`startEndings`/`seenEvents` 기본값(빈 목록).
  - `lib/game_controller.dart:703-728` `init`: 옮겨 담는 처리가 없다.
  - `:1196` `newGame`: `done_*`·`veteran` 을 `completedStarts` 로만 세운다.
  - `:1778` `suggestedStart`.
- **원인**: 회차 간 기록은 새 필드로만 쌓인다. 출시판 메타에는 그 필드가 없다. 출시판 사용자가 이미 가진 정보(엔딩 앨범 `mossol_endings_v1`, `lastEndingId`, `totalRuns`)로 채우는 이전 작업이 없다.
- **재현**: `r2_scripts/zz_r2_engine_test.dart.txt` 의 `live-build (HEAD) meta JSON of a veteran …`
  - 출시판 키만 있는 메타(`totalRuns 4`, `lastEndingId coach`)와 엔딩 3개를 넣고 `init` 한다.
  - `suggestedStart == classic` 이다.
  - `completedStarts == []` 이고 `startEndingCount(classic) == 0` 이다.
  - `newGame(start: sc_leak)` 뒤 `veteran`·`done_classic` 플래그가 없다.
- **영향**(대상은 지금 앱스토어 사용자 전부):
  - 시작 카드가 클래식(이미 여러 번 한 것)을 맨 앞 강조 카드로 권한다. R1-7·D7 의 "클래식으로 돌아가는 관성을 끊는다"와 정반대다.
  - 클래식 카드에 "본 적 있음"·엔딩 도장이 없다.
  - `veteran` 파급 줄 16곳(`events_start.json:10821~10956`)이 안 보인다. 새 판을 한 번 끝낼 때까지 그렇다.
  - 이전 회차 본 장면(`seenEvents`)이 비어 있어 첫 회차에는 무료 건너뛰기·NEW 점이 없다. 이것은 기대할 수 있는 한계다.
- **제안**: `init` 에서 한 번만 옮겨 담는다(추가만, 멱등).
  ```dart
  if (m.completedStarts.isEmpty && endingAlbum.isNotEmpty) {
    m.completedStarts.add(StartScenario.classic);
    m.startEndings[StartScenario.classic] = endingAlbum.toSet().toList();
    await metaService.save(m);
  }
  ```
  출시판에는 시작이 클래식뿐이었으므로 정확하다. 회귀 테스트는 위 스크립트의 기대값을 뒤집어 쓴다.

---

## P2

### R2-2. 처음 보는 내용 앞의 대기도 무료로 건너뛴다(변형 대사·파급 줄)

- **위치**:
  - `lib/game_controller.dart:1838` `canFreeSkipWait`(이벤트 **id** 만 본다)
  - `:1850` `_absorbSeen`
  - `lib/ui/event_screen.dart:891`
- **원인**: "본 장면"을 이벤트 id 로 센다. 그런데 같은 id 안에 이전 회차에서 못 본 내용이 있을 수 있다.
  - 변형(`variants`, 회차 시드로 회전).
  - 이번 회차 플래그로만 보이는 파급 줄.
- **재현**: `zz_r2_engine_test` 의 `event seen earlier with variant A; this run shows variant B …`
  - 1회차에 `변형 앞` 묶음을 보고 버린다.
  - 2회차에 `원본 앞` 묶음이 나오는데 `canFreeSkipWait == true` 다.
  - 대기 뒤 줄(처음 보는 줄)까지 광고 없이 넘어간다.
- **실제 데이터 규모**:
  - 대기 줄이 있는 변형 이벤트 7개(`d_kakao_03/07`, `mo_fail_*` 5개).
  - 대기 **뒤에** 파급 줄이 있는 이벤트 9개(`m03`, `m03_m`, `m24`, `m24_f`, `m37`, `sc_leak_d3`, `sc_leak_who`, `sc_leak_drama`, `sc_swap_d3`).
  - `m03` 은 대기 줄 자체가 `ifFlags: [sc_ghost]` 다.
- **영향**: D5 의 "처음 보는 장면의 대기는 광고로만"이 일부 장면에서 새는 것이다. 광고 노출이 설계보다 조금 더 준다.
- **제안**(택1):
  - 남은 줄에 NEW 줄이 있으면 무료 건너뛰기를 끈다. 즉 `newRippleLines` 에 대기 줄 번호보다 큰 번호가 있으면 끈다.
  - 변형까지 막으려면 `seenEvents` 에 `id#variantIndexOf` 도 함께 적는다. 재방송 계측과 같은 규칙이다.

### R2-3. `clock` 을 정한 장면 때문에 하루 안 가짜 시계가 거꾸로 간다

- **위치**: `lib/ui/event_screen.dart:763`(`ev.clockSeconds ?? ChatClock.startSeconds(...)`)과 데이터.
  - `events_start.json:237`(`sc_leak_d1a` 01:20)
  - `:4884/5000/5123`(`sc_clip_d1a/b/c` 09:10)
  - `:5369`(`sc_clip_open_2` 02:00)
  - `:8386`(`sc_swap_back` 23:00)
- **원인**: 고정 시각은 앞 장면이 끝난 시각을 보지 않는다. 뒤 장면의 칸 시각(`_slots`)도 고정 시각을 보지 않는다.
- **재현**: `r2_scripts/zz_r2_clock_test.dart.txt`(시작 6종 × 시드 12, 7,200일). 거꾸로 간 경우는 41번이다.
  - `sc_leak_d1` 이 오전 1:22 에 끝나고 `sc_leak_d1a` 가 1:20 에 시작한다. `sc_clip_d1` 은 9:11 에 끝나고 갈래가 9:10 에 시작한다. `sc_ghost_d1` 도 같다. 1~2분 차이로 D1 갈래마다 일어난다.
  - `a_gym_03` 이 오후 12:56 에 끝나고 `sc_clip_open_2` 가 오전 2:00 에 시작한다. 행동 이벤트 뒤에 새벽 장면이 오는 경우다.
  - `sc_swap_back` 이 23:00 인데, 같은 날 그 뒤의 루트·모먼트 장면은 오후 시각이다.
- **영향**: 표현만의 문제다. 다만 D8 의 목적이 "시각이 맞게"였는데, 첫날 첫 갈래부터 시각이 되감긴다.
- **제안**:
  - 데이터: D1 갈래 시각을 main 마지막 줄 뒤로 미룬다(예: 01:20 → 01:30).
  - 엔진·UI: 하루 안에서 `start = max(정한 시각 또는 칸 시각, 앞 장면 끝 + 1분)` 으로 단조 증가를 보장한다.
  - 새벽(00~05시) 고정 장면은 그날 큐의 맨 뒤로 보내거나 "다음 날 새벽"(24h+)으로 센다. `sc_clip_open_2` 가 이 경우다.

### R2-4. 결과 패널에 "진상 +1" 이 나쁜 쪽 색의 칩으로 보인다

- **위치**: `lib/ui/event_screen.dart:1845`. `o.delta.stats` 전부를 칩으로 만든다. `Stat.isGood(villain, +1) == false` 다.
- **재현**: `r2_scripts/zz_r2_villain_chip_test.dart.txt`. 실제 `a_hustle_reply` 의 진상 선택지를 고르면 결과에 `진상 +1` 칩이 경고색(내려감 톤)으로 뜬다.
- **영향**: `Stat.villain` 주석("스탯 격자·게이지에는 나오지 않는다")과 D4 의 "진상을 판타지로"에 어긋난다.
  - 진상을 고를 때마다 빨간 감점처럼 보여 R1 GD 가 지적한 "평판 세금" 느낌을 다시 만든다.
  - 클래식에서도 열리는 의뢰 4종에서 나온다.
- **제안**: 결과 칩에서 `Stat.villain` 을 뺀다. 또는 중립 톤으로 "흑역사 +1" 같은 보상형 문구로 바꾼다. 대본·기획 결정이 필요하다.

### R2-5. 운명 고정이 "새 게임 한 판"으로 풀린다(버리는 판으로 다시 뽑기)

- **위치**: `lib/game_controller.dart:1212`. `newGame` 은 어떤 시작으로 시작하든 `pendingFate = null` 로 지운다. `:1804` `rememberFate`.
- **재현**: `zz_r2_engine_test` 의 `pendingFate …`
  1. 운명이 잠긴 시작이 아닌 것으로 나온다.
  2. 다른 카드(예: 클래식)로 시작한다.
  3. 홈에서 곧바로 "새 게임"(확인 대화상자 1번)을 누르면 다시 뽑을 수 있다.
- **영향**: 잠긴 시작(sc_swap, sc_ghost)이 나올 때까지 "시작 → 버리기"를 반복할 수 있다. 판마다 탭 5~6번이 든다. R1-2 보다 비용이 크지만 D10 의 "어디서든 재추첨할 수 없다"와 다르다.
- **제안**:
  - 뽑은 운명은 **그 운명으로 시작했을 때만** 지운다. `startId == pendingFate` 일 때만 지운다.
  - 또는 새 게임 이후에도 하루(D2)를 넘겨야 지운다.
  - 의도한 동작이라면 문서(01_design §4.3)에 "다른 카드로 시작하면 운명은 소멸"이라고 적는다.

### R2-6. 메타의 `announcedStarts` 형식이 틀리면 메타 전체(하트·출석·이름·MBTI)가 초기화된다

- **위치**: `lib/engine/meta_service.dart:205-206`(`(j['announcedStarts'] as List?)`). 새 필드 중 이것만 `_strs` 를 쓰지 않는다. `load()` 의 `catch` 는 메타 키를 통째로 지운다.
- **재현**: `zz_r2_engine_test` 의 `a non-list announcedStarts wipes the WHOLE meta …`. `{"totalRuns":7,"playerName":"민지","announcedStarts":"sc_swap"}` 를 읽으면 `totalRuns 0`, `name null` 이 된다.
- **영향**: 지금 코드가 그런 값을 쓰지는 않는다. 손상·향후 형식 변경 때의 방어 문제다. 같은 파일의 다른 새 필드는 모두 안전하게 읽는다.
- **제안**: `announcedStarts: _strs(j['announcedStarts'])`.

### R2-7. 휴식 설명의 소문 문구: 클래식에도 보이고, 소문 회차에서는 두 번 말한다

- **위치**:
  - `assets/story/config.json:115`: `"…자존감을 회복한다. 소문이 식는다"`
  - `lib/ui/action_screen.dart:259` `actionSubtitle`: 소문 회차에 `· 소문 -6` 을 덧붙인다.
- **재현**: `zz_r2_ui_test` 행동 화면. 그리고 `r1_layout_test` 의 기대값도 이 둘을 함께 요구한다.
  - 클래식(소문 0, 게이지·안내 숨김)에서도 휴식 설명이 "소문이 식는다" 다.
  - 소문 회차에서는 "…소문이 식는다 · 소문 -6" 이 된다.
- **영향**: 문구만의 문제다. 클래식 플레이어는 보이지 않는 스탯 이야기를 본다.
- **제안**: `config.json` 설명은 HEAD 문구로 되돌린다. 소문 정보는 `actionSubtitle` 의 덧붙임 하나로만 준다.

---

## 범위 밖(이번 변경 전부터 있던 문제, 참고 — 모두 재현함)

1. **하루 도중 재시작하면 클리프행어가 사라진다.**
   - 재현: `zz_r2_engine_test` 의 `resume mid-day`. main(예고 M) 을 고른 뒤 앱을 껐다 켠다. 이어서 일상(예고 O) 을 마치면 `cliffhanger == O` 가 된다.
   - 원인: `continueGame` 의 `_resetDay()`(`game_controller.dart:1237`)가 `cliffhanger`·`_cliffRank` 를 지운다. 이번에 더한 `_chainRank` 도 메모리 전용이라 같이 사라진다.
   - 결과: 층 순위(S7)·갈래 우선(D6)이 재시작 한 번에 무력해진다.
   - 제안: `GameState` 에 오늘의 `cliffhanger`·rank 를 저장한다(추가만).
2. **되돌리기가 그날 계획돼 있던 이벤트를 지운다.**
   - 재현: `zz_r2_engine_test` 의 `undo after a chained pick`. 선택지 A 의 `next` 가 오늘 이미 계획된 `x` 를 앞으로 당긴 뒤 되돌리기 → B 를 고르면 `x` 가 그날 사라진다.
   - 원인: `game_controller.dart:1617` 은 `next` 로 당긴 것인지 원래 있던 것인지 구분하지 않는다.
   - 제안: 끼워 넣을 때 "원래 큐에 있었는지"를 기억해, 되돌릴 때 제자리로 돌려놓는다.
3. **정산 `StatBars` 가 320pt 에서 넘친다.** 배율 1.6 에서 15px, 2.0 에서 54px 다(`widgets.dart:457` Row). 클래식(소문 0)에서도 똑같다.
4. **설정 "앱 버전" 줄이 320pt 에서 넘친다.** 배율 1.8 에서 21px, 2.0 에서 46px 다(`widgets.dart:1904` `AppListRow`, 트레일링 버전 글자). 새로 넣은 "읽은 장면 빨리 감기" 줄은 넘치지 않는다.

---

## 재현 스크립트(`docs/overhaul2/review/r2_scripts/`)

| 파일(원래 위치) | 내용 | 정식화 제안 |
|---|---|---|
| `test/zz_r2_engine_test.dart` | 출시판 메타 이전(R2-1), 메타 손상(R2-6), 메타 크기, 없는 id 세이브·메타, `deep:false` 구조 오류 9종·시간, 변형 무료 건너뛰기(R2-2), 재시작 합치기, 사슬 클리프행어 3종, 오프닝 가속 1,200판, 악당 봇, 운명 재추첨(R2-5), 재시작 클리프행어(범위 밖 1) | R2-1·R2-6 기대값을 뒤집어 `save_migration_test` 에, 오프닝 시뮬은 시드 5로 `r1_sim_test` 에 |
| `test/zz_r2_clock_test.dart` | 하루 안 시계 단조성(7,200일) | R2-3 고친 뒤 "거꾸로 0건" 으로 |
| `test/widget/zz_r2_ui_test.dart` | 변경 화면 10종 × 320×568 × 1.3/2.0 × 라이트/다크, 운명 카드 연타·"이 이야기로 시작" 연타·즉시 뒤로·일시정지/복귀 | 다크 경우를 `r1_layout_test` 에 |
| `test/widget/zz_r2_detail_test.dart` | 설정·정산 넘침 상세(어느 Row 인지) | 측정용 |
| `test/widget/zz_r2_detail2_test.dart` | 설정 줄별 폭 합계(넘치는 줄 찾기) | 측정용 |
| `test/widget/zz_r2_villain_chip_test.dart` | 진상 선택 결과 칩(R2-4) | R2-4 결정 뒤 기대값으로 |

참고: `r1_scripts/` 를 `zz_r2_r1_*` 로 복사해 다시 돌린 결과는 §1 표에 적었다. 복사본은 지웠다.
