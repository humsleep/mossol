# 모쏠 탈출기

메신저 채팅 형식으로 100일 안에 연애 고수가 되는 무료 스토리 게임. Flutter + AdMob. iOS 우선 출시.

## 이름

| 칸 | 값 |
|---|---|
| 스토어 앱 이름 (30자 제한) | 모쏠 탈출기 : 100일 연애 시뮬레이션 |
| App Store 부제 (30자 제한) | 톡 한 줄로 썸부터 고백까지 |
| 홈 화면 표시 이름 | 모쏠 탈출기 |
| 번들 ID | com.hyukahn.mossol (변경 불필요, 출시 후 변경 불가) |

- 이름은 "모쏠 탈출기 : 100일 연애 시뮬레이션"(2026-09-22 변경, 이전 "모쏠 키우기"). 목표(모쏠 → 연애)와 게임 첫날의 100일 내기가 이름에 그대로 들어간다.
- Apple 은 이름·부제·키워드 칸을 합쳐 검색에 쓰므로 부제에 이름의 단어를 반복하지 않는다.
- 이름에 설명을 붙인 것으로 반려되면 이름은 "모쏠 탈출기"만 남기고 설명을 부제로 옮긴다.
- 세이브 키(`mossol_save_v1`)와 클래스명은 내부 식별자라 바꾸지 않는다. 바꾸면 기존 저장이 사라진다.

설계서: https://claude.ai/code/artifact/6b8d9eec-1077-4e27-a43d-6dcab584899b

## 콘텐츠 분량

| 항목 | 수 |
|---|---|
| 이벤트 | 262 (메인 40 · 루트 94 · 일상 98 · 위기 16 · 히든 14) |
| 엔딩 | 30 (전부 사람이 쓴 한 줄 `hint` 포함 · 검증기가 누락을 잡는다) |
| 미니게임 | 12 (이벤트 선택지 113곳에 배치) |
| 캐릭터 | 6 + 조연 3 |
| 테스트 | 198 (`flutter test` 기준 · 오프닝·후속 17 포함) |

## 구조

```
assets/story/            스토리 데이터 (코드 수정 없이 콘텐츠 추가)
  config.json            스탯 초기치, 아침 행동, 하트 설정
  characters.json        캐릭터 6명 + 미니게임 취향(replyZone/humor/tags/budget)
  events_main.json       메인 40 (1~100일 고정 배치, 5개 장)
  events_route_a.json    서연·하늘·지우 루트 47 (서연·하늘 r00 첫 접촉 포함)
  events_route_b.json    민재·예은·도윤 루트 47 (민재·예은 r00 첫 접촉 포함)
  events_daily.json      일상 랜덤 98 (12개 상황 카테고리 + 오프닝 d_open_* 12 + 후속 d_fu_* 3 + 내기 정산 d_bet_settle* 3)
  events_special.json    위기 16 + 히든 14
  endings.json           엔딩 30개와 조건, 앨범용 한 줄 힌트(`hint`)
assets/icon/app_icon.png 아이콘 원본 1024px

lib/engine/              순수 Dart 게임 로직 (UI·광고 의존 없음, 단위 테스트 대상)
  models.dart            JSON ↔ Dart 모델
  conditions.dart        trigger / require 판정
  effects.dart           효과 적용과 변화량 계산
  event_engine.dart      하루 계획, 선택 적용(확률·크리티컬·콤보), 럭키 룰렛, 하루 마감
  ending_resolver.dart   엔딩 결정 (우선순위 → 호감도)
  story_repository.dart  에셋 로드와 데이터 검증
  save_service.dart      SharedPreferences 세이브
lib/minigames/           미니게임 12종
  minigame.dart          공용 타입·등록소·껍데기 위젯
  registry.dart          id → 화면 매핑
  timing_games.dart      답장 타이밍 · 결심의 순간 · 5초 삭제
  tap_games.dart         단톡방 대응 · 맞장구 · 프로필 스와이프
  choice_games.dart      표정 읽기 · 짤 고르기 · 옷장 코디 · 코스 짜기
  push_games.dart        주량 관리 · 문장 만들기
lib/ads/ad_manager.dart  AdMob. UMP 동의 → ATT → SDK 초기화 순서, 전면 빈도 캡
lib/game_controller.dart 화면 흐름 (home → action → event → summary → ending)
lib/ui/                  화면 (홈·행동·이벤트·정산·엔딩·앨범·룰렛)
test/                    엔진 단위 테스트 40개
```

## 이벤트 JSON 형식

```json
{
  "id": "seoyeon_r04",
  "layer": "route",
  "character": "seoyeon",
  "trigger": { "affection": { "*": [25, 75] }, "day": [10, 100] },
  "weight": 3,
  "title": "읽씹 사건",
  "lines": [
    { "who": "them", "text": "오늘 발표 잘했더라" },
    { "who": "me",   "text": "감사합니다!!" },
    { "who": "sys",  "wait": 30 },
    { "who": "narr", "text": "지문" }
  ],
  "choices": [
    { "text": "선택지",
      "require": { "stats": { "esteem": 40 } },
      "effects": { "affection": { "*": 4 }, "stats": { "esteem": 2 }, "setFlags": ["x"] },
      "chance": 60,
      "minigame": "reply_timing",
      "fail": { "affection": { "*": -5 }, "album": "흑역사 제목" },
      "next": "다음_이벤트_id" }
  ],
  "hint": 1,
  "cliffhanger": "다음 날 예고 한 줄"
}
```

- `layer`: main(고정 날짜, `day` 필수) · route(캐릭터 루트) · daily(가중치 추첨) · crisis(임계값) · hidden
- `*` 는 이벤트의 캐릭터 자신. `once: false` 면 반복 등장.
- `chance` 가 있으면 확률 판정, `minigame` 이 있으면 실력 판정. 둘은 함께 쓰지 않는다.
- `next` 로만 이어지는 2단 이벤트는 `"trigger": {"day": [0, 0]}` 로 잠가 단독으로 뽑히지 않게 한다 (예: `d_open_bet_2`).
- 미니게임은 `require` 가 없는 선택지에만 붙인다. 스탯 게이트와 겹치면 안 된다.
- 성공 시 5%+눈치/20 % 확률로 크리티컬(호감 2배). 물오름 상태면 두 배.
- 엔딩은 `priority` 내림차순으로 검사하고, 같은 우선순위면 호감도 높은 캐릭터.

이벤트 파일을 추가하면 `lib/engine/story_repository.dart` 의 `eventFiles` 에 이름만 넣으면 된다.
앱 시작 시 id 중복, 없는 캐릭터 참조, 끊긴 next, 없는 미니게임, main 날짜 중복을 자동 검사한다.

## 서체 (Pretendard 서브셋)

`assets/fonts/Pretendard-*.otf` 는 원본(굵기당 1.5MB)이 아니라 서브셋(굵기당 ~340KB, 합계 1.3MB)이다.
KS X 1001 완성형 2350자 + 프로젝트 소스에 실제로 쓰인 한글 음절 + 라틴·구두점·기호·자모만 담는다.
원본은 `tool/fonts_src/` 에 두고 git 에 올리지 않는다(`.gitignore`). 없으면 스크립트가 다운로드 위치를 안내한다.

- **이벤트·엔딩·UI 문구에 새 한글이 들어가면** `python3 tool/subset_fonts.py` 를 다시 돌리고 `assets/fonts/` 를 함께 커밋한다.
  (fonttools 가 없으면 `uv` 로 자동 실행. 2350자 밖의 드문 글자만 새로 추가되므로 대개는 아무것도 바뀌지 않는다.)
- `test/font_subset_test.dart` 가 `assets/fonts/coverage.txt`(서브셋 cmap 목록)와 `assets/story/*.json`, `lib/**/*.dart`,
  `ios/Runner/Info.plist` 의 한글 집합을 비교한다. 빠진 글자가 있으면 `flutter test` 가 실패하며 글자를 알려 준다.
- 코드에서 새 `FontFeature` 를 쓰면 스크립트의 `LAYOUT_FEATURES` 에도 추가한다(현재 kern·tnum·pnum·locl·ccmp·mark·mkmk).

## 디버그 갤러리 (QA)

미니게임 12종과 엔딩 30개를 100일 플레이 없이 연다. 디버그 빌드 전용이며 릴리스 빌드에는 코드가 들어가지 않는다.

```bash
flutter run -d "iPhone 17" --dart-define=MOSSOL_DEBUG_GALLERY=true
```

엔딩 미리보기는 메모리 세이브를 써서 기기의 실제 세이브·엔딩 앨범을 건드리지 않는다. 코드는 `lib/debug/debug_gallery.dart`.

## 밸런스 검증

`test/sim_balance_test.dart` 가 시드 200개 × 전략 14종으로 100일을 돌려
`tool/sim_out/` 에 엔딩 분포, 스탯 추이, 이벤트 노출률을 남긴다.
`flutter test` 를 돌릴 때마다 함께 실행되며, 수치를 바꾸면 여기서 바로 확인한다.

- 도달 가능한 엔딩 30개 중 26개 (봇이 흉내 내기 어려운 절제형 4개 제외)
- 하루 평균 이벤트 2.8개, 회차 60~74분
- 한 캐릭터에 집중해야 호감 80을 넘도록 루트 이벤트에 상호배타 조건이 걸려 있다
- `test/deadlock_test.dart` 가 그 조건 때문에 루트가 전부 닫히는 구간이 없는지 검사한다
- 1~3일차 오프닝: `d_open_*` 일상 10개(day [1,3], once)와 `*_r00` 루트 첫 접촉 4개(호감 0~15, 보상 호감 0~1)로 첫 세션을 채운다. 엔진은 오프닝(`openingDays`=3)에 한해 하루를 4개(`openingMinEventsPerDay`)까지 일상으로 채우고, 루트 캐릭터를 호감과 무관하게 균등 무작위로 고른다(첫날 동전 던지기가 루트를 정하지 않도록). 4일차부터는 원래 규칙(3개 목표, 최고 호감 우선). `test/opening_test.dart` 가 시드 20개로 이를 고정하고, 4일차 이후 후보에 새지 않는지 검사한다
- 오프닝의 실은 후반에 되돌아온다: 태현의 치킨 내기는 `bet_accepted`(어느 갈래든) + `bet_doubled`/`bet_public` 에 따라 90~100일차에 `d_bet_settle` / `d_bet_settle_double` / `d_bet_settle_public` 중 하나(상호배타, weight 40)로 정산된다. `stranger_laugh`(잘못 온 번호) → `d_fu_stranger`, `app_installed`(앱 매칭) → `d_fu_locked`(자물쇠 계정), `lurker`(단톡 눈팅) → `d_fu_lurker` 가 4~20일차에 잇는다
- `require.flags` 는 쓰지 않는다. 잠긴 선택지의 문구(`Requirement.describe`)가 플래그를 설명하지 못해 빈 사유로 잠기기 때문에, 플래그 분기는 `trigger.flags`/`notFlags` 로 이벤트를 나눠서 한다

### 해피 엔딩 난이도 목표

"대충 해도 해피"가 아니라 "노력해야 해피"여야 재도전 동기가 생긴다. 전략별 happy 비율 목표:

| 전략 | 목표 | 2026-09-19 조정 후 (시드 2000) |
|---|---|---|
| first (항상 첫 선택지) | ≤ 6% | 5% |
| random | ≤ 5% | 2% |
| focus (한 명 집중) | 72~80% | 77% |
| focus+hint | 85~92% | 90% |
| statGrow | ≤ 85% | 76% |

- 모먼트(`events_moments.json`) 보상 규칙: 첫 선택지(누르기만 하면 되는 답)는 호감·신뢰를 원래의 40%, 힌트 선택지는 호감 80%(신뢰 유지), 그 밖의 좋은 답은 호감 60%·신뢰 70%, 호감 40 이상에서 뜨는 후반 모먼트는 여기에 ×0.7. 호감만 오르고 신뢰는 안 오르는 "독성" 답과 가장 무심한 답(회피형 봇이 고르는 최소 선택지)은 그대로 둔다(toxic·wallflower 봇 분포 보존).
- `@top` 은 일상의 기본 보상이라 모먼트보다 해피율에 훨씬 크게 작용한다(일상 `@top` 을 전부 0으로 하면 focus 가 86%→50%). 그래서 크기를 줄일 때는 한 칸씩만 줄이고, 회피형·흑역사 봇이 고르는 최소 선택지 구성을 바꾸지 않는 선택지만 건드린다.
- 참고: toxic 봇의 happy 는 대상이 아닌 캐릭터 이벤트에서 첫 선택지를 고르다 생기는 "우연한 해피"라, first 를 낮추면 함께 내려간다(시드 2000 기준 11%→3%).
- 비교 실험: `--dart-define=SEEDS=2000`(표본), `STORY_DIR=<스냅샷 폴더>`(수정 전후 같은 데이터로 비교), `SIM_OUT=<폴더>`(여러 실험을 동시에 돌릴 때 결과 파일이 겹치지 않게), `NO_EARLY=true`(초반 가속 제외). 시드 200 에서는 드문 엔딩(seoyeon_bad 등 1% 안팎)이 우연히 빠질 수 있으니 도달 가능 엔딩 수는 시드 2000 으로 확인한다.

## 하트 경제와 리텐션

하루 = 하트 1개. 현재 하루 45초, 콘텐츠 확장 후 60~90초 예상. 하트가 떨어지면
광고를 "봐야만" 진행되는 구조는 피한다 (광고는 보너스, 통행세가 아님).

후보 비교 (세션 = 은행을 다 비우는 접속, 하루 3세션, 세션 사이에 은행이 다시 차는 기준):

| 안 | 최대/재생 | 가득 차는 시간 | 하루 무료 일수 | 세션 길이 (45초 / 75초·일) | 100일 회차 |
|----|-----------|----------------|----------------|-----------------------------|-----------|
| 이전 | 5개 / 30분 | 150분 | 15일 | 3.8분 / 6.3분 | 약 7일 |
| (a) | 8개 / 20분 | 160분 | 24일 | 6.0분 / 10분 | 약 4일 |
| (b) | 6개 / 20분 | 120분 | 18일 | 4.5분 / 7.5분 | 약 5.5일 |
| **(c) 채택** | **5개 / 15분** | **75분** | 15일 (4세션이면 20일) | 3.8분 / 6.3분 | 약 5~7일 |

(c)를 고른 이유:

- 30분은 "기다릴 시간"이 아니라 "닫을 시간"이었다. 15분은 홈의 카운트다운을 보고
  잠깐 뒤에 다시 여는 게 현실적인 길이다. 은행이 75분이면 차서 하루 4~5회 접속이 자연스럽다.
- 최대치를 5로 두면 출석 하트 +1이 20% 보너스로 체감된다. 8이면 12%.
- (a)는 세션이 길어져 100일이 나흘 만에 끝난다. 콘텐츠 소모가 빠르고 "짧고 자주"에 어긋난다.
- 회차 한 번이 약 일주일이라 7일 연속 출석 보상(재도전권)과 주기가 맞는다.
- 기존 세이브의 hearts 가 5 이하이므로 호환 문제 없음. UI 하트 아이콘 5개도 그대로.

출석 보상 (`lib/engine/attendance.dart`, 7일 주기로 반복):

| 연속 | 하트 | 추가 |
|------|------|------|
| 매일 | +1 | |
| 3일째 (7n+3) | +2 | `extra: streak3` |
| 7일째 (7n) | +3 | `extra: streak7`, 룰렛 재도전권 +1 (최대 3장) |

- 개근 한 주 = 하트 10개 + 재도전권 1장. 출석만으로 하루 두 세션이 나오고 광고 하트는 그 위에 얹힌다.
- 출석 하트는 최대치를 넘겨 쌓이되 최대치 두 배(10)까지. 초과분은 재생 대상이 아니다.
  광고 하트(`grantHeart`)는 여전히 최대치까지만.
- 세이브가 없을 때 받은 하트는 메타(`mossol_meta_v1`)에 보관했다가 다음 `newGame`/`continueGame`에 얹는다.
- 기기 시계가 마지막 출석보다 과거면 보상 없음. 자정은 기기 로컬 날짜 기준.
- 회차 간 보너스: 앨범의 엔딩 1개당 새 회차 초기 매력·화술·자존감 +1, 각 +5 까지.
  루트 잠금은 대부분 60~80 이상이라 +5 로 열리는 문은 없다.
- 메타 기록: 연속·최고 연속·누적 출석·누적 회차·최고 도달 일차·첫 실행 시각.

## 미사용 플래그

이벤트가 `setFlags` 로 세우지만 아직 어떤 trigger·require·엔딩도 읽지 않는 플래그. 후속 이벤트를 붙일 때 여기서 고른다. (엔진이 직접 읽는 `burnout`·`hardcore`·`album_10`·`album_20`·`chose_loop` 는 제외.)

`album_hunter`, `asked_taehyun`, `backtrack`, `chose_one`, `claimed_yeeun`, `contented`, `demanded_setup`, `doubt_taehyun`, `drunk_confess_ok`, `fake_e`, `fake_profile`, `fast_hands`, `focused`, `greedy`, `haneul_next_date`, `legend_path`, `lied_mosol`, `lied_to_mom`, `minjae_meet`, `minjae_meet_asked`, `mystery_pfp`, `night_drill`, `pact`, `pact_passive`, `pickup_confessed`, `played_games`, `prepared_date`, `progress_photo`, `refused_mom`, `rulebook`, `saver_1`, `saver_2`, `self_complete`, `self_focus`, `small_lie`, `stranger_saved`, `they_dm_first`, `unprepared_date`, `yeeun_avoid_2`, `yeeun_avoid_3`

오프닝에서 나온 것 중 `night_drill`(새벽 답장 훈련 합격)과 `stranger_saved`(모르는 번호 저장)는 의도적으로 남겨 뒀다. 다음 콘텐츠 배치에서 서연·하늘 루트의 새벽 톡 이벤트와 잇는다.

## 도파민 설계

- **크리티컬**: 기본 5% + 눈치/20. 호감 2배, 전용 연출.
- **콤보(물오름)**: 좋은 선택 3연속이면 확률 판정 +20%p, 크리티컬 확률 2배. 나쁜 선택 하나로 해제.
- **럭키 룰렛**: 하루 시작 1회. 광고 시청으로 한 번 더. 7일마다 대박 칸이 넓어진다.
- **클리프행어**: 하루 정산 끝에 다음 날 예고 한 줄.
- **흑역사 앨범**: 실패가 카드로 쌓인다. 10개·20개에서 히든 이벤트와 엔딩.

## 실행

```bash
flutter pub get
flutter test
flutter run -d "iPhone 17"
```

## 출시 전 바꿔야 하는 것

- `lib/ads/ad_manager.dart` 의 테스트 광고 단위 ID → AdMob 콘솔 실제 ID
- `ios/Runner/Info.plist` 의 `GADApplicationIdentifier` → 실제 앱 ID
- `android/app/src/main/AndroidManifest.xml` 의 `APPLICATION_ID` → 실제 앱 ID
- 개인정보처리방침 URL 호스팅, App Store 개인정보 라벨, IARC 연령 등급(15세)
- AdMob 콘솔에서 UMP 동의 메시지 생성. **한국어 메시지를 만들지 않으면 한국 유저에게 영어 화면이 그대로 뜬다.**
- 상세 절차는 `docs/RELEASE_CHECKLIST.md` 참고 (개인정보 라벨, 연령 등급 설문 답안, 심사 노트 포함)

## 광고 동의 순서

`lib/ads/ad_manager.dart` 는 UMP 동의 → ATT → SDK 초기화 순서를 콜백으로 강제한다.
타임아웃으로 순서를 재촉하면 "다음 화면에서 허용을 눌러 주세요" 안내가
이미 지나간 ATT 뒤에 뜨는 사고가 난다. 동의가 끝나지 않으면 그 세션에는 ATT 를 묻지 않는다.
