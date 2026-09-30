# 출시 전 체크리스트 — 모쏠 탈출기 (com.hyukahn.mossol)

작성 기준일: 2026-09-15 (§3·§5·§6·§7 은 2026-09-29 Apple 최신 규칙 기준으로 고침 — `APP_STORE_CONNECT_GUIDE.md` §0-1). AdMob/Apple/Google 정책은 자주 바뀌므로 제출 직전에 각 링크를 다시 확인할 것.

---

## 0. 스토어 등록 이름

| 칸 | 입력값 | 제한 |
|---|---|---|
| App Store 앱 이름 | 모쏠 탈출기 : 100일 연애 시뮬레이션 | 30자 |
| App Store 부제 | 톡 한 줄로 썸부터 고백까지 | 30자 |
| Google Play 앱 이름 | 모쏠 탈출기 : 100일 연애 시뮬레이션 | 30자 |
| 홈 화면 표시 이름 | 모쏠 탈출기 | Info.plist·AndroidManifest 에 반영됨 |

- App Store 키워드 칸(100자)에는 이름·부제에 이미 있는 단어(모쏠, 탈출기, 100일, 연애, 시뮬레이션, 톡, 썸, 고백)를 넣지 않는다. 합쳐서 검색되므로 반복은 칸 낭비다.
- 키워드 칸에 다른 앱 이름이나 상표(카톡, 인스타, 모태솔로 등)를 넣지 않는다. Apple 가이드라인 2.3.7 위반이다.
- 앱 이름의 설명 부분 때문에 반려되면 이름은 "모쏠 탈출기"만 남기고 "100일 연애 시뮬레이션"을 부제로 옮긴다.
- App Store Connect 에서 앱을 만들 때 같은 이름이 이미 쓰이면 등록이 막힌다. Google Play 와 웹 검색에서는 동명 앱이 없었다(2026-09-15 확인).

---

## 1. 광고 ID (iOS 완료 2026-09-22)

AdMob 앱 이름 **Mossol**, 앱 ID `ca-app-pub-4073994600346533~6518695864`.

| 위치 | 값 |
|---|---|
| `ios/Runner/Info.plist` `GADApplicationIdentifier` | 실제 앱 ID ✅ |
| `lib/ads/ad_manager.dart` `_realIds['ios']` | 배너 `…/7646935542`, 전면 `…/8783923243`, 보상 `…/5122687865` ✅ |
| Android (`AndroidManifest.xml`, `_realIds['android']`) | 아직 테스트 ID. Android 출시 때 AdMob 에 Android 앱을 추가하고 교체 |

- **실제 광고 단위는 릴리스 빌드(TestFlight·App Store)에서만** 쓰인다. 디버그 빌드는 Google 테스트 광고가 뜬다(`AdManager.idsFor`, `test/ad_ids_test.dart`).
- TestFlight 에서 본인 폰으로 확인할 때는 AdMob → 설정 → **테스트 기기**에 폰을 먼저 등록한다. 등록 안 된 폰에서 실제 광고를 반복해 누르면 계정 정지 사유다.
- **TestFlight 에서 광고가 안 뜨면** (2026-09-23 "오늘의 운 → 한 번 더" 로 실제 겪음) 앱 코드보다 AdMob 쪽을 먼저 본다.
  같은 코드가 디버그 빌드(테스트 ID)에서는 광고를 띄우므로, 실제 ID 로 광고가 안 오는 이유는 대개 콘솔에 있다.
  - AdMob → 앱 → **앱 승인 상태**: 스토어에 아직 없는 앱은 "검토 중/승인되지 않음" 이고 그동안 실제 광고가 거의 안 온다. 출시 뒤 스토어 URL 을 연결해야 풀린다.
  - 광고 단위를 새로 만든 직후(수 시간~하루)는 "No ad config" / no fill 로 온다. 기다리는 것 말고 방법이 없다.
  - **배너도 안 뜨면** SDK 초기화 자체가 안 된 것(UMP 동의 조회 실패 → `canRequestAds()` false). §2 의 UMP 메시지 게시 여부를 본다.
  - 폰을 맥에 꽂고 Console.app 에서 프로세스 `Runner` 로 걸러 보면 `리워드 광고 로드 실패(N회): …` 에 SDK 가 준 이유가 그대로 찍힌다(릴리스 빌드에서도 `debugPrint` 는 나온다).
- 보상형 광고 단위의 **보상 설정**: 수량 `1`, 항목 `reward`, 서버 측 확인(SSV) 끔. 앱은 AdMob 의 보상 값을 쓰지 않고
  "보상 콜백이 왔는가"만 보고 하트·힌트 등을 앱이 정한 만큼 준다.
- **전면 광고 빈도 정책**(`AdManager`, 상수 3개 · `test/release_gaps_test.dart` 가 고정):
  `interstitialEveryDays = 5` · `interstitialMinInterval = 1분` · `interstitialMaxPerDay = 15`.
  앱을 켠 뒤 게임 속 하루를 5번 마칠 때마다(약 10분에 한 번) 정산 `다음 날로` 에서 한 번(100일째 `엔딩 보기` 는 제외).
  예전 값(D+7 이후 · 6분 간격 · 하루 6회)은 광고가 거의 보이지 않아 2026-09-30 유저 요청으로 바꿨다.
  배너는 채팅·통화·알림 화면에 두지 않고, 다른 화면에서는 AppBar(홈은 제목 줄) 아래에 둔다.

---

## 2. AdMob 콘솔 설정

- [ ] **AdMob 콘솔 → 차단 관리(Blocking controls) → 콘텐츠 등급(최대 광고 콘텐츠 등급) → T(청소년)** 로 저장했다.
  코드도 `lib/ads/ad_manager.dart` 에서 `maxAdContentRating: MaxAdContentRating.t` 로 요청하지만, 콘솔 설정이 계정 쪽 기본값이라 둘 다 맞춘다.
  App Store 연령 등급 13+ 와 짝이다(심사 노트에도 "max ad content rating T" 라고 썼다).
- **최대 광고 콘텐츠 등급(Max Ad Content Rating)**: 앱 설정에서 **T(Teen)** 로 지정한다. 연애 시뮬레이션
  소재이지만 노출·도박·과도한 폭력 묘사가 없으므로 T가 적절하다.
  (Google Ads Policy Center → 앱 → Content ratings.
  참고: https://support.google.com/admob/answer/7562737)
- **UMP(사용자 메시지 플랫폼) 동의 메시지**: Privacy & messaging → 메시지 만들기에서 GDPR(EEA)용,
  그리고 필요하면 US 주(state) 규정용 메시지를 **반드시 게시(publish)** 해야
  `ConsentInformation.instance.requestConsentInfoUpdate()`가 실제 폼을 내려준다. 메시지를 만들어
  두지 않으면 코드는 정상이어도 유럽 사용자에게 동의 폼이 뜨지 않아 GDPR 위반이 될 수 있다.
  (참고: https://developers.google.com/admob/flutter/privacy)
- **ATT 설명 문구 연동**: UMP 메시지 설정에서 "Apple의 앱 추적 투명성 권한 요청 문구 표시" 옵션을 켜면
  UMP가 동의 폼 다음에 iOS ATT 팝업까지 이어서 띄운다. `lib/ads/ad_manager.dart`의 흐름
  (UMP → ATT → `canRequestAds()` → `initialize()`) 과 맞물리므로 콘솔에서 이 옵션을 켜두는 것을 권장.
- 앱 ID 발급 후 Info.plist / AndroidManifest.xml / `ad_manager.dart`의 테스트 ID를 위 1번 항목대로 교체.

---

## 3. App Store Connect — 개인정보 라벨(Privacy Nutrition Label)

`ios/Runner/PrivacyInfo.xcprivacy`에 이미 선언된 내용과 Google이 공식 문서에서 밝힌 AdMob SDK 수집
항목(https://developers.google.com/admob/ios/privacy/data-disclosure)이 일치하도록 입력한다.
앱 자체 코드가 서버로 보내는 것은 **Firebase Analytics 게임 진행 이벤트뿐**이다(§3.1, 켰을 때만).
나머지는 "Google Mobile Ads SDK가 수집" 기준이다. App Store Connect 는 같은 데이터 유형에 여러 SDK 의
답을 합쳐 한 줄로 받으므로, 같은 칸이면 더 넓은 쪽(AdMob) 답을 그대로 두고 용도에 "분석"이 들어 있는지만 확인한다.

**입력할 값은 `APP_STORE_CONNECT_GUIDE.md` §5 가 유일한 기준(single source of truth)이다.** 여기에는 표를 두지 않는다
(두 곳에 두었다가 "기기 ID 추적 여부"가 서로 달라진 적이 있다 — 2026-09-29 정리). 요약만 적으면:

- 수집 유형 8개: 기기 ID · 대략적 위치 · 제품 상호 작용 · 광고 데이터 · 기타 사용 데이터 · 충돌 데이터 · 성능 데이터 · 기타 진단 데이터.
- **추적에 사용: 기기 ID 하나만 "예"**(ATT 허용 시 IDFA 로 맞춤 광고). 나머지는 전부 "아니요".
- 사용자 신원에 연결: 기기 ID · 대략적 위치 · 제품 상호 작용 · 광고 데이터 = 예, 나머지 = 아니요.
- AdMob 과 Firebase 가 같은 유형을 모으면 App Store Connect 는 한 줄로 받으므로 더 넓은 쪽(AdMob) 답이 이긴다.
  근거: AdMob https://developers.google.com/admob/ios/privacy/data-disclosure , Firebase 공식 데이터 공개 문서.

- Firebase Analytics 는 `Info.plist` 의 `GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED=false` 로 IDFA 를
  모으지 않는다. 보내는 이벤트에 이름·자유 입력·MBTI 원문 같은 개인 데이터는 없다(`lib/analytics/analytics.dart`).
- "추적에 사용" 전체 여부: **예**(ATT를 허용한 사용자에 한해 IDFA 기반 맞춤 광고를 하므로 앱 전체
  추적 여부는 "예"로 답한다. 단 `PrivacyInfo.xcprivacy` 의 `NSPrivacyTracking` 은 **false**로 두고
  `NSPrivacyTrackingDomains` 키는 **아예 넣지 않는다**(Google Mobile Ads SDK 매니페스트와 같은 모양).
  추적 신고는 DeviceID 항목의 Tracking=true 와 App Store Connect 라벨("추적에 사용: 기기 ID")로 한다).
  - ITMS-91064 이력: 빌드 8(`true` + 빈 배열) 거절, 빌드 9(`false` + 빈 배열 `<array/>`)도 같은 메시지로
    거절 — Apple 검사기는 배열이 비었는지가 아니라 키가 있는지를 보는 것으로 보인다. 빌드 10부터 키를
    빼고, 파일 안 XML 주석도 없앴다(설명은 여기 둔다).
  - true 로 두려면 도메인을 1개 이상 적어야 하고, 적은 도메인은 ATT 미허용 사용자에게 OS 가 통신을 막는다.
    Google 광고 도메인을 적으면 ATT 거부 사용자는 비맞춤 광고조차 못 받으므로 true 로 두지 않는다.
  - `NSPrivacyAccessedAPITypes` 는 Flutter 엔진·shared_preferences 가 쓰는 UserDefaults(CA92.1)·
    파일 타임스탬프(C617.1) API 를 앱 번들 차원에서도 선언해 둔 것이다.
  - 제출 전 확인: IPA 를 풀어 `plutil -p Payload/Runner.app/PrivacyInfo.xcprivacy` 에
    `NSPrivacyTrackingDomains` 가 없어야 한다.
- 게임 자체는 로그인·회원가입·서버 통신이 없으므로 연락처, 건강, 금융, 사용자 콘텐츠, 검색/브라우징
  기록 등은 전부 "수집 안 함"으로 둔다.
- 만 14세(국내 기준)/13세(COPPA 기준) 미만 아동 대상이 아니므로 "아동 대상 앱" 태그는 끄고, AdMob
  콘솔의 "아동용 처리(tag for child-directed treatment)"도 **아니요**로 설정한다.

### 3.1 Firebase Analytics 켜기

**2026-09-22 켜짐**(iOS, `GoogleService-Info.plist` 커밋·Runner 타깃 등록, 시뮬레이터에서 전송 확인). 아래는 기록과
Android 때를 위한 절차다. plist 가 없으면 `Firebase.initializeApp()` 이 실패하고 앱은 조용히 디버그 백엔드로 돈다.

1. https://console.firebase.google.com 에서 프로젝트 만들기(이름 예: `mossol`). Google Analytics 사용 **켬**,
   Analytics 계정은 새로 만들거나 기존 것 선택. 데이터 공유 설정은 전부 끄는 쪽을 권장.
2. 프로젝트에 **iOS 앱 추가** → 번들 ID `com.hyukahn.mossol`(Xcode Runner 타깃과 같아야 한다),
   앱 닉네임 `모쏠 탈출기`. App Store ID 는 출시 뒤에 넣어도 된다.
3. `GoogleService-Info.plist` 를 내려받아 **`ios/Runner/` 에 넣는다**. 그다음 Xcode 에서
   `ios/Runner.xcworkspace` 를 열고, 왼쪽 Runner 그룹에 이 파일을 끌어다 놓는다 →
   "Copy items if needed" 끄고, **Add to targets: Runner 체크**. (파일만 폴더에 두고 타깃에 안 넣으면
   번들에 안 들어가서 여전히 꺼진 상태다.)
4. 콘솔 안내의 "SDK 추가"·"초기화 코드" 단계는 **건너뛴다** — `firebase_core`/`firebase_analytics` 패키지와
   `main.dart` 의 `Analytics.init()` 이 이미 한다. (`flutterfire configure` 도 안 써도 된다.)
5. 확인: 실기기/시뮬레이터에서 Xcode Scheme → Run → Arguments 에 `-FIRDebugEnabled` 를 넣고 실행 →
   Firebase 콘솔 **DebugView** 에 `run_started` 등이 뜨면 끝. 확인 뒤 인자는 뺀다.
6. `APP_STORE_CONNECT_GUIDE.md` §5 대로 App Store Connect 개인정보 라벨을 입력하고(Firebase 몫은 이미 합쳐져 있다), §8 개인정보처리방침에
   Firebase(Google LLC)를 처리자로 추가한다.
7. **Android 를 낼 때만**: 같은 프로젝트에 Android 앱(패키지 `com.hyukahn.mossol`) 추가 →
   `google-services.json` 을 `android/app/` 에 → `android/settings.gradle.kts` 의 plugins 에
   `id("com.google.gms.google-services") version "4.4.2" apply false`, `android/app/build.gradle.kts` 의
   plugins 에 `id("com.google.gms.google-services")` 추가. Play Data safety(§4)의 "앱 활동"·"기기 ID"
   목적에 분석이 이미 있으므로 칸은 그대로다. 파일이 없으면 Android 도 iOS 와 똑같이 꺼진 채로 돈다.

선택: IDFA 연동 코드를 아예 빼고 싶으면 빌드 때 `FIREBASE_ANALYTICS_WITHOUT_ADID=true flutter build ios`
(firebase_analytics 가 `FirebaseAnalyticsCore` 를 쓴다). Info.plist 플래그로 이미 수집은 꺼져 있어 필수는 아니다.

**보내는 이벤트**(개인 데이터 없음, 값은 작은 정수·짧은 문자열):

| 이벤트 | 파라미터 | 언제 |
|---|---|---|
| `onboarding_step` | `step`: gender · name · mbti · cast | 첫 온보딩(이 기기 첫 판 전)에서 단계 화면이 뜰 때 |
| `onboarding_done` | `pref` f/m, `has_name` 0/1, `has_mbti` 0/1, `mbti_source` toggle · quiz · skip | 첫 온보딩 끝(새 게임 직전) |
| `run_started` | `run`(게임 안 회차), `pref`, `n`(이 기기에서 시작한 판 수) | 새 게임 · 다음 회차 |
| `day_reached` | `day` | 2·3·7·10·20·30·50·70·100일에 닿을 때만 |
| `run_ended` | `ending`(엔딩 id), `tier`, `run`, `day` | 엔딩 |
| `ad_rewarded_shown` | `placement`: heart_action · heart_home · hint · undo · roulette · wait_skip | 리워드 광고가 실제로 떴을 때 |
| `ad_hint_used` | — | 광고로 힌트를 받았을 때 |
| `heart_empty` | `day` | 하트 없이 행동을 눌렀을 때 |
| `album_opened` | — | 앨범 화면을 열 때 |
| `next_run_suggestion_tapped` | `kind`: character · other_side | 엔딩 화면 "다음 판" 카드 |

사용자 속성: `pref`(마지막 판 선호), `mbti_known`(0/1).

---

## 4. Google Play — Data safety 섹션

AdMob 공식 고지(https://developers.google.com/admob/android/privacy/play-data-disclosure) 기준으로
아래 항목을 "수집됨 + 공유됨"으로 표시한다.

| Data safety 카테고리 | 세부 항목 | 수집 | 공유 | 목적 |
|---|---|---|---|---|
| 기기 또는 기타 ID | 광고 ID(Android Advertising ID), 앱 세트 ID | 예 | 예 | 광고, 분석, 부정행위 방지 |
| 앱 활동(App activity) | 앱 상호작용(탭, 영상 시청 등) | 예 | 예 | 광고, 분석, 부정행위 방지 |
| 앱 정보 및 성능 | 충돌 로그, 진단(실행 시간 등) | 예 | 예 | 광고, 분석, 부정행위 방지 |
| 위치 | 대략적 위치(IP 기반 추정) | 예 | 예 | 광고, 분석, 부정행위 방지 |

- 전송 시 TLS 암호화 사용 여부: **예**(AdMob SDK는 전송 구간 암호화).
- "사용자가 데이터 삭제 요청 가능": 앱 내 별도 계정이 없으므로 기기 설정(광고 ID 재설정/제한)으로
  안내.
- 만 13세 미만 대상 여부: **아니요**. Play Console "대상 연령 및 콘텐츠" 설문에서 아동용이 아님을 선택.

---

## 5. App Store 연령 등급 설문 답변

**입력 순서·답은 `APP_STORE_CONNECT_GUIDE.md` §3, 근거와 등급 대응표는 `STORE_LISTING.md` §7** (2026-09-29 현재 설문 기준으로 다시 매김).

- 새 체계: 4+/9+/13+/16+/18+ 5단계, 새 문항(앱 내 제어·기능·의료/웰니스·폭력 테마). 2026-01-31부터 답하지 않으면 제출 불가
  (https://developer.apple.com/news/?id=ks775ehf , 대응표 https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).
- 핵심 답: 선정적 테마·비속어 **드물게**(각 9+), 알코올·담배 언급 **드물게**(**13+**), 광고 **예**(4+),
  사용자 생성 콘텐츠·메시지/채팅·소셜 미디어 **아니요**(자유 입력은 기기 안에서만, 사람 간 대화 없음), 도박·모의 도박·루트 박스 없음.
- **예상 결과: 13+.** AdMob 최대 광고 등급 T 와 맞다(§2).

---

## 6. 심사 노트 (App Review Notes)

App Store Connect "App Review Information → Notes"에 영어로 넣는다
(데이팅/소셜 앱으로 오분류되는 것을 막기 위함 — 이름·설명에 "연애", "썸", "채팅"이 있으면 실제 매칭 서비스로 오해받기 쉽다).

**문구는 `APP_STORE_CONNECT_GUIDE.md` §6-10 의 영어 블록이 유일한 기준이다**(여기 두 벌이 있던 것을 2026-09-29 하나로 합침).
그 블록에 들어 있는 것: 1인용 가상 스토리(데이팅·소셜 앱 아님) · 자유 입력('직접 쓰기')은 기기 안에서 미리 쓴 선택지에 맞춰지고
원문은 전송 안 함(AI/LLM·서버 없음, Analytics 에는 횟수 등 비내용 지표만) · ATT 는 첫 실행 인트로 직후에 뜨며 가는 방법과
"앱의 추적 요청 허용" 설정 조건 · 광고 콘텐츠 최대 등급 T · 인앱 결제 없음 · 로그인 없음.

- LSApplicationCategoryType은 이미 `public.app-category.games`로 지정돼 있음 — 스토어 카테고리도
  Games로 유지할 것 (Social Networking/Lifestyle로 등록하면 오분류 리스크가 커진다).
- 심사용 빌드(릴리스)는 실제 광고 단위를 쓴다. 출시 직후 광고 채움률이 낮을 수 있는데 정상이다. ATT/UMP 폼이 첫 실행 **인트로가 끝난 직후**(캐스트 소개의 "시작하기" 다음) 뜨는지 TestFlight에서 확인해 둘 것.

---

## 7. 스크린샷 규격 (2026-09-29 Apple 문서 재확인)

**iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`, `ios/Runner.xcodeproj`), iPad 스크린샷 불필요.** 세로 고정.

- iPhone 6.9형: **1320 × 2868px** 세로(1290×2796, 1260×2736도 허용) → `docs/store_screenshots/promo/`
- 6.9형이 없으면 6.5형(**1284 × 2778px**, 1242×2688도 허용)이 필수 → `docs/store_screenshots/promo65/` 에 같은 한 벌이 있다.
- 1~10장, PNG/JPEG, 알파 채널 없음. 작은 기종(6.3·6.1형 등)은 자동 축소.
- 올리는 순서(9장): `00a` → `02` → `01` → `04` → `05` → `03` → `06` → `07` → `08` (`00b`·`00c` 는 올리지 않음).
- 출처: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

---

## 8. 개인정보처리방침에 반드시 들어가야 할 조항

앱 스토어/플레이스토어 등록 시 필요한 URL 하나에 아래 내용을 모두 포함해야 한다.

1. **수집 주체**: 앱 개발자가 직접 수집하는 개인정보는 없음(서버 없음) — 광고 서비스를 위해
   Google AdMob(Google LLC)이 광고 식별자·대략적 위치·기기 정보·사용 데이터를 수집한다는 사실 명시.
2. **광고 식별자(IDFA/AAID) 사용**: 맞춤형 광고에 사용되며, iOS는 ATT로, Android는 기기 설정에서
   사용자가 언제든 거부/재설정할 수 있다는 안내.
3. **ATT(App Tracking Transparency)**: 추적 권한 요청 목적과, 거부해도 게임 이용에는 지장이 없다는 문구
   (Info.plist의 `NSUserTrackingUsageDescription`과 같은 취지로 정책에도 명시).
4. **UMP(동의 관리 플랫폼)**: EEA/영국/스위스 등 지역에서 GDPR 동의를 받는다는 사실과, 앱 내 설정에서
   언제든 동의를 철회/재설정할 수 있는 경로(`AdManager.showPrivacyOptions()` 로 연결된 UI, 이미
   `lib/ui/home_screen.dart`에 구현됨) 안내.
5. **로컬 저장 데이터**: `shared_preferences`로 기기 로컬에만 저장되는 게임 진행 상태(스탯, 플래그,
   엔딩 기록 등)가 있으며 서버로 전송되지 않는다는 사실.
6. **만 14세 미만 아동 대상 아님**: 아동을 대상으로 개인정보를 의도적으로 수집하지 않으며, 만 14세
   미만임을 알게 된 경우의 처리 방침(즉시 삭제 등).
7. **제3자 처리자 목록**: Google AdMob / UMP(Firebase 를 켰다면 Firebase Analytics 도)를 데이터 처리자로 명시하고 Google 개인정보처리방침
   링크(https://policies.google.com/privacy)를 함께 건다.
8. **국내법 대응**(한국 스토어 대상이므로): 개인정보보호법상 개인정보처리방침 필수 기재사항(수집 항목,
   목적, 보유기간, 위탁 현황, 이용자 권리 행사 방법, 개인정보 보호책임자 연락처) 형식에 맞춰 작성.

---

## 9. 최종 빌드 검증 결과 (2026-09-15 실행)

```
flutter analyze   → 기존 test/ 폴더의 사전 존재 이슈 2건(미사용 import, avoid_print) 외 0건.
                    lib/, ios/, android/ 관련 이슈 없음.
flutter test      → 130 tests, All tests passed!
flutter build ios --simulator --no-codesign → Build 성공.
                    ios/Runner/PrivacyInfo.xcprivacy 가 Runner.app 루트에 정상 포함됨을 확인.
```

배포용 서명 빌드(`flutter build ipa`)와 실제 기기 테스트, AdMob 콘솔 실제 앱 ID 발급은 이 체크리스트
범위 밖이므로 별도로 진행할 것.
