# 몰입 개편 계획 — "게임이지만 실제 같아야 한다"

> 2026-09-23 작성. TestFlight 첫 테스트 피드백에서 출발. 목표는 App Store 게임 랭킹 Top 10 진입이지만,
> 이 문서는 그 전제조건인 **몰입 개편**만 다룬다. ASO·마케팅은 별도(STORE_LISTING.md, LAUNCH_GUIDE.md).
> 진행은 agency-agents 로 한다(§5). 기준 문서: DESIGN_SYSTEM.md, ROADMAP.md, CAST_BIBLE.md.

## 0. 테스트 피드백 원문 → 항목

| # | 피드백 | 항목 | 결정 |
|---|---|---|---|
| A | 카톡처럼 이름 왼쪽에 그 사람 이미지, 상단은 이름만 | 채팅 UI | 한다 |
| B | 날짜가 바뀌면 전체화면으로 "2일째 / Day 2" | 날짜 전환 | 한다 |
| C | 문자·전화가 오면 효과음, 필요하면 실제 진동 | 사운드·햅틱 | 한다 |
| D | 텍스트만 나와서 집중이 안 됨 → 이미지·GIF | 장면 삽화 | 코드 슬롯 + 프롬프트 문서. **그림은 사용자가 생성** |
| E | 배너를 상단에 | 광고 배치 | 한다(채팅 화면 제외, 정책) |
| F | 채팅으로 직접 입력해 스토리 잇기 | 자유 입력 | **제한형**: LLM 없이 입력 → 의도 매핑 → 기존 선택지 |
| G | 벤치마킹: AI 채팅 앱, 프린세스 메이커 | 연구 | 설계 단계에서 |

## 1. 현재 코드 기준 (2026-09-23)

- 채팅: `lib/ui/event_screen.dart`. AppBar 에 `CharacterAvatar` + 이름 + 이벤트 제목. 말풍선은 `_speakerKey` 로 같은 화자를 묶지만 아바타 없음.
- 날짜: `GameController.startDay` → `Phase.event`/`Phase.summary`. 정산(`summary_screen.dart`) → 행동(`action_screen.dart`) 사이에 전환 화면 없음.
- 사운드·햅틱: 코드·패키지 모두 없음. 오디오 관련 import 0.
- 이미지: `assets/portraits/<id>.jpg` 12장, `PortraitRegistry` 로 있으면 쓰고 없으면 이니셜. 장면 삽화 슬롯 없음.
- 배너: `BannerSlot` 이 홈·행동·정산·앨범·설정의 `bottomNavigationBar`. 채팅 화면엔 없음(선택지 옆 배너 = AdMob 우발 클릭 정책 위반, `ad_manager.dart` 주석).
- 선택지: 이벤트당 3개 고정, `require`/`chance`/`minigame`.

## 2. 항목별 설계 방향 (에이전트가 채울 자리)

### A. 채팅 UI (카톡형)
- 상대 말풍선 그룹의 **첫 줄에만** 아바타(40pt) + 이름. 이어지는 줄은 아바타 자리만 비움.
- 내 말풍선은 오른쪽, 아바타 없음. narr/sys 는 가운데 캡슐.
- 상단 AppBar: **이름만**(+ 온라인/통화중 같은 상태 한 줄 가능). 아바타 제거.
- 그룹 대화(둘 이상 등장)는 화자마다 아바타. `Line.who` 가 캐릭터 id 를 이미 담고 있는지 확인.
- DESIGN_SYSTEM.md §2.3 갱신 필요.

### B. 날짜 전환 화면
- 정산 "다음 날" → **풀스크린 "D+N" 카드**(1.2~1.6초, 탭으로 건너뛰기) → 룰렛 시트.
- 요일·날씨·장(章) 이름을 같이. 동작 줄이기 설정이면 페이드만.
- 첫날(D+1)은 새 회차 인트로와 합침.

### C. 사운드·햅틱
- 이벤트: 문자 도착(알림 카드), 전화 벨(반복, 받거나 거절할 때까지), 통화 종료, 선택 확정, 정산 카드, 엔딩.
- 햅틱: `HapticFeedback`(내장). 전화 벨은 반복 진동, 문자는 한 번.
- 에셋: CC0/OFL 급 효과음 6~8개, `assets/sfx/`. 라이선스 파일 동봉.
- 설정: 효과음·진동 각각 토글. iOS 무음 스위치 존중(`audioplayers` 의 AudioContext).
- 패키지 후보: `audioplayers` (진동은 내장으로 충분, `vibration` 패키지는 보류).

### D. 장면 삽화
- 슬롯: 이벤트 JSON 에 `image` 필드(선택) → 채팅 상단 또는 첫 말풍선 위에 삽화 카드. 없으면 지금과 동일.
- 우선 대상 30~50장면: 모먼트 30개 + 전화 + 엔딩 12 + 첫날. 447개 전부는 아니다.
- 스티커: 캐릭터별 감정 4종(기쁨·삐짐·부끄·놀람) × 12 = 48장 → 특정 대사 뒤에 붙임. `Line.sticker` 필드.
- 프롬프트 문서 `docs/SCENE_PROMPTS.md` — PORTRAIT_PROMPTS.md 의 형식·교훈(관찰 로그 #4: 액세서리만 바꾸면 같은 사람이 된다)을 따른다.
- GIF 는 용량(16MB 앱 아님, 스토어 앱이지만 다운로드 크기) 때문에 정적 PNG/WebP 우선, 움직임은 Flutter 애니메이션으로.

### E. 배너 상단
- `BannerSlot` 을 홈·행동·정산·앨범·설정에서 `appBar` 아래(body 첫 줄)로. SafeArea 처리.
- 채팅 화면은 계속 없음. 룰렛·다이얼로그 위에 겹치지 않게.

### F. 자유 입력 (제한형)
- 선택지 패널에 입력창 하나. 보낸 문장을 **로컬에서** 기존 선택지 3개 중 하나로 매핑(키워드·감정어·길이). 매핑 신뢰도 낮으면 "이런 뜻이에요?" 로 3개 중 고르게.
- 내 말풍선에는 **사용자가 친 문장 그대로** 남긴다(선택지 원문 대신). 이게 몰입의 핵심.
- 상대 반응은 기존 outcome. 서버·LLM 없음. 나중에 풀 LLM 으로 갈 때 이 입력창과 매핑 로그가 학습 데이터가 된다.
- 위험: 매핑이 틀리면 "내 말을 못 알아듣는다" 가 더 나쁜 경험. 신뢰도 임계값과 되돌리기(광고 없이 1회) 필요.

### G. 벤치마킹
- AI 채팅 앱(제타·Character.ai 류): 첫 화면 즉시 대화, 캐릭터 프로필, 읽음 표시, 타이핑 인디케이터, 프로필 사진 클릭 시 캐릭터 페이지.
- 프린세스 메이커: 일정표식 하루 계획, 스탯 그래프, 월말 이벤트, 엔딩 갤러리 — 지금 앱과 구조가 비슷. 아침 행동 화면을 "이번 주 계획" 으로 확장 여부 검토.

## 3. 순서

1. **연구·설계** (병렬): 벤치마킹, 게임 루프 진단, 채팅 UI 명세, 오디오·햅틱 명세, 삽화·스티커 프롬프트 세트, 제한형 자유 입력 설계 → 이 문서 §2 를 확정본으로 갱신.
2. **구현 1차** (코드만): A, B, C, E, F. 위젯·통합 테스트, 시뮬레이터 확인, 회귀 0.
3. **구현 2차** (에셋): D 슬롯·JSON 필드 먼저, 프롬프트 문서 전달 → 그림 도착하면 투입.
4. 풀 LLM 자유 입력은 별도 트랙(백엔드·비용·심의).

## 4. 하지 않는 것 / 주의

- 채팅 화면 배너 (정책).
- 447개 이벤트 전부 삽화 (비용). 없는 이벤트는 지금처럼.
- 풀 LLM (이번 개편 밖).
- 진동은 사용자가 끌 수 있어야 하고, 무음 스위치를 무시하면 안 된다.
- 기존 세이브 호환: JSON 에 필드를 **추가만** 한다(`save_migration_test.dart`).

## 5. 에이전트 배정 (agency-agents)

설치됨: Agents Orchestrator, UI Designer, Frontend Developer, Reality Checker, Ad Creative Strategist, Reddit Community Builder, AI Code Security Auditor.

추가(사용자가 agency-agents 앱에서 켬):

| 에이전트 | 맡는 것 |
|---|---|
| `engineering-mobile-app-builder` | Flutter 구현 전체 (A·B·C·E·F) |
| `game-designer` | 하루 루프·프린세스 메이커식 구조 진단, B 연출 |
| `narrative-designer` | 대사 톤, 스티커·삽화가 붙을 장면 선정, F 의 의도 매핑 어휘 |
| `design-whimsy-injector` | 마이크로 인터랙션(타이핑, 읽음, 전화 벨 연출) |
| `design-image-prompt-engineer` | `docs/SCENE_PROMPTS.md` 스티커·삽화 프롬프트 |
| `design-visual-storyteller` | 어떤 장면에 그림이 붙어야 하는지, 그림의 역할 |
| `game-audio-engineer` | 효과음 목록·톤·햅틱 패턴, 에셋 출처 |
| `product-trend-researcher` | G 벤치마킹 |
| `marketing-app-store-optimizer` | Top 10 — 개편 뒤 스토어 자산 |

Reality Checker 는 각 단계 끝에 "실제로 되는가" 를 본다. UI Designer 는 DESIGN_SYSTEM.md 갱신.
