# 출시 전 체크리스트 — 모쏠 키우기 (com.hyukahn.mossol)

작성 기준일: 2026-09-15. AdMob/Apple/Google 정책은 자주 바뀌므로 제출 직전에 각 링크를 다시 확인할 것.

---

## 0. 스토어 등록 이름

| 칸 | 입력값 | 제한 |
|---|---|---|
| App Store 앱 이름 | 모쏠 키우기 : 연애 시뮬레이션 게임 | 30자 |
| App Store 부제 | 100일 안에 썸부터 고백까지 | 30자 |
| Google Play 앱 이름 | 모쏠 키우기 : 연애 시뮬레이션 게임 | 30자 |
| 홈 화면 표시 이름 | 모쏠 키우기 | Info.plist·AndroidManifest 에 반영됨 |

- App Store 키워드 칸(100자)에는 이름·부제에 이미 있는 단어(모쏠, 키우기, 연애, 시뮬레이션, 게임, 썸, 고백)를 넣지 않는다. 합쳐서 검색되므로 반복은 칸 낭비다.
- 키워드 칸에 다른 앱 이름이나 상표(카톡, 인스타, 모태솔로 등)를 넣지 않는다. Apple 가이드라인 2.3.7 위반이다.
- 앱 이름의 설명 부분 때문에 반려되면 이름은 "모쏠 키우기"만 남기고 "연애 시뮬레이션 게임"을 부제로 옮긴다.
- App Store Connect 에서 앱을 만들 때 같은 이름이 이미 쓰이면 등록이 막힌다. Google Play 와 웹 검색에서는 동명 앱이 없었다(2026-09-15 확인).

---

## 1. 출시 전 반드시 교체해야 할 테스트 광고 ID (3곳)

전부 Google 공식 테스트 ID다. 실제 AdMob 콘솔에서 만든 앱/광고 단위 ID로 바꾸지 않으면
정책 위반은 아니지만 수익이 발생하지 않는다.

1. `ios/Runner/Info.plist` → `GADApplicationIdentifier` (현재 `ca-app-pub-3940256099942544~1458002511`)
2. `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID` meta-data
   (현재 `ca-app-pub-3940256099942544~3347511713`)
3. `lib/ads/ad_manager.dart` → `_ids` 맵 (android/ios × interstitial/rewarded/banner, 총 6개 광고 단위 ID)

세 곳 모두 코드에 "출시 전 교체 필수" 주석이 이미 달려 있다. AdMob 콘솔의 앱 ID와 Info.plist/Manifest의
앱 ID가 다르면 `MobileAds.instance.initialize()`가 조용히 실패하거나 광고가 전혀 안 뜨므로, 앱 ID부터
먼저 바꾸고 광고 단위 ID를 바꾼다.

---

## 2. AdMob 콘솔 설정

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
항목(https://developers.google.com/admob/ios/privacy/data-disclosure)이 일치하도록 아래처럼 입력한다.
앱 자체 코드가 서버로 보내는 것은 **Firebase Analytics 게임 진행 이벤트뿐**이다(§3.1, 켰을 때만).
나머지는 "Google Mobile Ads SDK가 수집" 기준이다. App Store Connect 는 같은 데이터 유형에 여러 SDK 의
답을 합쳐 한 줄로 받으므로, 같은 칸이면 더 넓은 쪽(AdMob) 답을 그대로 두고 용도에 "분석"이 들어 있는지만 확인한다.

| App Store Connect 카테고리 | 세부 항목 | 사용자 추적에 사용 | 사용자 계정에 연결 | 용도 |
|---|---|---|---|---|
| 식별자(Identifiers) | 기기 ID(광고 식별자/IDFA) | ATT 허용 시 예 | 예 | 타사 광고, 자사 광고, 분석 |
| 위치(Location) | 대략적 위치(IP 기반) | 아니요 | 예 | 타사 광고, 자사 광고, 분석 |
| 사용 데이터(Usage Data) | 광고 데이터(노출/클릭) | 아니요 | 예 | 타사 광고, 자사 광고, 분석 |
| 사용 데이터(Usage Data) | 제품 상호작용 | 아니요 | 예 | 타사 광고, 자사 광고, 분석 |
| 진단(Diagnostics) | 성능 데이터 | 아니요 | 아니요 | 타사 광고, 자사 광고, 분석 |
| 진단(Diagnostics) | 충돌 데이터 | 아니요 | 아니요 | 분석 |
| 진단(Diagnostics) | 기타 진단 데이터 | 아니요 | 아니요 | 타사 광고, 자사 광고, 분석 |
| 사용 데이터(Usage Data) | 제품 상호작용 — **Firebase Analytics** | 아니요 | 아니요 | 분석 |
| 사용 데이터(Usage Data) | 기타 사용 데이터 — **Firebase Analytics** | 아니요 | 아니요 | 분석 |
| 식별자(Identifiers) | 기기 ID(앱 인스턴스 ID) — **Firebase Analytics** | 아니요 | 아니요 | 분석 |

- Firebase 세 줄은 Firebase 를 켰을 때(§3.1)만 해당한다. 앞의 AdMob 줄과 같은 칸("제품 상호작용",
  "기기 ID")은 App Store Connect 에서 한 번만 답하므로 AdMob 답(연결 예, 용도에 분석 포함)이 이긴다.
  새로 생기는 칸은 **기타 사용 데이터**(연결 안 됨 · 추적 안 함 · 분석) 하나다 — PrivacyInfo 에 이미 넣었다.
- Firebase Analytics 는 `Info.plist` 의 `GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED=false` 로 IDFA 를
  모으지 않는다. 보내는 이벤트에 이름·자유 입력·MBTI 원문 같은 개인 데이터는 없다(`lib/analytics/analytics.dart`).
- "추적에 사용" 전체 여부: **예**(ATT를 허용한 사용자에 한해 IDFA 기반 맞춤 광고를 하므로 앱 전체
  추적 플래그는 켜야 한다 — `NSPrivacyTracking = true`로 이미 선언되어 있음).
- 게임 자체는 로그인·회원가입·서버 통신이 없으므로 연락처, 건강, 금융, 사용자 콘텐츠, 검색/브라우징
  기록 등은 전부 "수집 안 함"으로 둔다.
- 만 14세(국내 기준)/13세(COPPA 기준) 미만 아동 대상이 아니므로 "아동 대상 앱" 태그는 끄고, AdMob
  콘솔의 "아동용 처리(tag for child-directed treatment)"도 **아니요**로 설정한다.

### 3.1 Firebase Analytics 켜기

지금 앱에는 Firebase 코드가 들어 있지만 **꺼져 있다**. `ios/Runner/GoogleService-Info.plist` 가 없으면
`Firebase.initializeApp()` 이 실패하고, 앱은 조용히 "디버그 백엔드"(디버그 빌드에서 콘솔에만 찍고
릴리스에서는 아무것도 안 함)로 돈다. 빌드·실행은 그대로 된다. 켜려면 주인이 아래를 한 번 한다.

1. https://console.firebase.google.com 에서 프로젝트 만들기(이름 예: `mossol`). Google Analytics 사용 **켬**,
   Analytics 계정은 새로 만들거나 기존 것 선택. 데이터 공유 설정은 전부 끄는 쪽을 권장.
2. 프로젝트에 **iOS 앱 추가** → 번들 ID `com.hyukahn.mossol`(Xcode Runner 타깃과 같아야 한다),
   앱 닉네임 `모쏠 키우기`. App Store ID 는 출시 뒤에 넣어도 된다.
3. `GoogleService-Info.plist` 를 내려받아 **`ios/Runner/` 에 넣는다**. 그다음 Xcode 에서
   `ios/Runner.xcworkspace` 를 열고, 왼쪽 Runner 그룹에 이 파일을 끌어다 놓는다 →
   "Copy items if needed" 끄고, **Add to targets: Runner 체크**. (파일만 폴더에 두고 타깃에 안 넣으면
   번들에 안 들어가서 여전히 꺼진 상태다.)
4. 콘솔 안내의 "SDK 추가"·"초기화 코드" 단계는 **건너뛴다** — `firebase_core`/`firebase_analytics` 패키지와
   `main.dart` 의 `Analytics.init()` 이 이미 한다. (`flutterfire configure` 도 안 써도 된다.)
5. 확인: 실기기/시뮬레이터에서 Xcode Scheme → Run → Arguments 에 `-FIRDebugEnabled` 를 넣고 실행 →
   Firebase 콘솔 **DebugView** 에 `run_started` 등이 뜨면 끝. 확인 뒤 인자는 뺀다.
6. 위 §3 표의 Firebase 세 줄을 App Store Connect 개인정보 라벨에 반영하고, §8 개인정보처리방침에
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

게임 내용(연애 시뮬레이션, 실제 음주·도박·성적 묘사 없음, 갈등/스트레스 이벤트 존재)에 맞춘 답변:

- 알코올, 담배, 마약 사용 또는 참조: **Infrequent/Mild**
- 시뮬레이션 도박: **None**
- 성적인 콘텐츠 또는 누드: **None**
- 성숙하거나 부적절한 주제: **Infrequent/Mild**
- 폭력(사실적/만화적), 공포/스릴러 요소: **None**
- 사용자 생성 콘텐츠/소셜 기능: **없음**(1인용, 서버 통신 없음)

주의: Apple이 2025년 7월 연령 등급 체계를 4+/9+에서 4+/9+/13+/16+/18+ 5단계로, 설문에 소셜 기능 관련
문항을 추가하는 방향으로 개편했다
(https://developer.apple.com/news/?id=ks775ehf). 2026-01-31 이후 업데이트부터는 새 설문 응답이
필수이므로, 제출 시점에 App Store Connect에 실제로 표시되는 문항 문구와 등급 구간이 위 표와 다를 수
있다 — **이 표는 추정이며, 제출 화면에서 실제 문항을 한 번 더 확인해야 한다.**

---

## 6. 심사 노트 (App Review Notes)

App Store Connect "App Review Information → Notes"에 아래 내용을 영어로 작성해 제출한다
(데이팅/소셜 앱으로 오분류되어 추가 심사 요구를 받는 것을 예방하기 위함 — 앱 이름과 아이콘,
스토어 설명에 "연애", "썸", "채팅" 같은 단어가 들어가면 리뷰어가 실제 매칭 서비스로 오해하는 사례가
흔하다):

```
This is a single-player narrative/story simulation game. All characters, chats, and
"dating" scenarios are pre-written fictional content — there is no real-time matching,
no user accounts, no messaging between real users, and no server-side communication of
any kind. The app only talks to Google's AdMob/UMP endpoints to serve ads and consent
forms. Please do not classify this as a dating or social-networking app.

Ads are currently wired to Google's official TEST ad unit IDs
(ca-app-pub-3940256099942544/...) for review purposes; production ad unit IDs will be
swapped in before/at release. Test devices are not hard-coded into the release build.
```

- LSApplicationCategoryType은 이미 `public.app-category.games`로 지정돼 있음 — 스토어 카테고리도
  Games로 유지할 것 (Social Networking/Lifestyle로 등록하면 오분류 리스크가 커진다).
- 심사용 빌드에서 테스트 광고가 정상적으로 뜨는지, ATT/UMP 폼이 첫 실행 시 뜨는지 미리 확인해 둘 것.

---

## 7. 스크린샷 규격 (2026년 기준)

앱이 Universal(`TARGETED_DEVICE_FAMILY = "1,2"`, 세로 고정)이므로 iPhone·iPad 스크린샷을 모두 준비한다.
Apple은 각 기기군에서 가장 큰 화면 하나만 있으면 나머지 크기로 자동 축소해준다.

- iPhone 6.9" (예: iPhone 17 Pro Max급): **1320 × 2868px** 세로 (1290×2796, 1260×2736도 허용)
- iPad 13" (M4 iPad Pro급): **2064 × 2752px** 세로 (2048×2732의 12.9" iPad Pro 크기도 허용)
- 모두 세로(portrait) 방향, 알파 채널 없는 PNG/JPEG.

(정확한 최신 크기는 제출 시점에 App Store Connect 업로드 화면에서 다시 확인 — 스크린샷 요구 크기는
Apple이 신모델 출시 때마다 바뀐다.)

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
