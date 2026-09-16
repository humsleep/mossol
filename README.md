# 모쏠 키우기

메신저 채팅 형식으로 100일 안에 연애 고수가 되는 무료 스토리 게임. Flutter + AdMob. iOS 우선 출시.

## 이름

| 칸 | 값 |
|---|---|
| 스토어 앱 이름 (30자 제한) | 모쏠 키우기 : 연애 시뮬레이션 게임 |
| App Store 부제 (30자 제한) | 100일 안에 썸부터 고백까지 |
| 홈 화면 표시 이름 | 모쏠 키우기 |
| 번들 ID | com.hyukahn.mossol (변경 불필요, 출시 후 변경 불가) |

- 이름 형식은 수험생 키우기, 취준생 키우기와 같은 "시작 상태 + 키우기 : 장르" 관례를 따른다.
- Apple 은 이름·부제·키워드 칸을 합쳐 검색에 쓰므로 부제에 이름의 단어를 반복하지 않는다.
- 이름에 설명을 붙인 것으로 반려되면 이름은 "모쏠 키우기"만 남기고 설명을 부제로 옮긴다.
- 세이브 키(`mossol_save_v1`)와 클래스명은 내부 식별자라 바꾸지 않는다. 바꾸면 기존 저장이 사라진다.

설계서: https://claude.ai/code/artifact/6b8d9eec-1077-4e27-a43d-6dcab584899b

## 콘텐츠 분량

| 항목 | 수 |
|---|---|
| 이벤트 | 240 (메인 40 · 루트 90 · 일상 80 · 위기 16 · 히든 14) |
| 엔딩 | 30 |
| 미니게임 | 12 (이벤트 선택지 101곳에 배치) |
| 캐릭터 | 6 + 조연 3 |
| 테스트 | 134 (엔진 107 · 위젯 19 · 교착 4 · 밸런스 시뮬 1 · 기타) |

## 구조

```
assets/story/            스토리 데이터 (코드 수정 없이 콘텐츠 추가)
  config.json            스탯 초기치, 아침 행동, 하트 설정
  characters.json        캐릭터 6명 + 미니게임 취향(replyZone/humor/tags/budget)
  events_main.json       메인 40 (1~100일 고정 배치, 5개 장)
  events_route_a.json    서연·하늘·지우 루트 45
  events_route_b.json    민재·예은·도윤 루트 45
  events_daily.json      일상 랜덤 80 (12개 상황 카테고리)
  events_special.json    위기 16 + 히든 14
  endings.json           엔딩 30개와 조건
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
- 미니게임은 `require` 가 없는 선택지에만 붙인다. 스탯 게이트와 겹치면 안 된다.
- 성공 시 5%+눈치/20 % 확률로 크리티컬(호감 2배). 물오름 상태면 두 배.
- 엔딩은 `priority` 내림차순으로 검사하고, 같은 우선순위면 호감도 높은 캐릭터.

이벤트 파일을 추가하면 `lib/engine/story_repository.dart` 의 `eventFiles` 에 이름만 넣으면 된다.
앱 시작 시 id 중복, 없는 캐릭터 참조, 끊긴 next, 없는 미니게임, main 날짜 중복을 자동 검사한다.

## 밸런스 검증

`test/sim_balance_test.dart` 가 시드 200개 × 전략 14종으로 100일을 돌려
`tool/sim_out/` 에 엔딩 분포, 스탯 추이, 이벤트 노출률을 남긴다.
`flutter test` 를 돌릴 때마다 함께 실행되며, 수치를 바꾸면 여기서 바로 확인한다.

- 도달 가능한 엔딩 30개 중 26개 (봇이 흉내 내기 어려운 절제형 4개 제외)
- 하루 평균 이벤트 2.8개, 회차 60~74분
- 한 캐릭터에 집중해야 호감 80을 넘도록 루트 이벤트에 상호배타 조건이 걸려 있다
- `test/deadlock_test.dart` 가 그 조건 때문에 루트가 전부 닫히는 구간이 없는지 검사한다

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
