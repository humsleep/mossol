# 06. 개인정보·데이터 처리 감사 (App Store 제출 전)

- 대상: `모쏠 탈출기` 1.0.0+3 (`main` c799c52), iOS 빌드 기준
- 방법: 저장소 정적 검토(코드는 수정하지 않음) + 빌드 산출물의 SDK 매니페스트 대조(`build/ios/Debug-iphonesimulator/*`) + 방침·지원 페이지 curl(2026-09-26). 기기에서 실제 패킷을 잡지는 않았다 — 그 한계는 해당 항목에 적어 두었다.
- 결론 먼저: **FAIL 0 · RISK 7 · OK 12.** 심사 거절이나 실제 유출로 이어질 결함은 없다. 개인정보처리방침이 자유 입력(플레이어가 친 문장)의 로컬 저장·구조 지표 전송을 아직 안 적고 있어 문안 수정이 필요하고(§3), `저장 데이터 초기화`가 Firebase 쪽 사용자 속성은 못 지운다.

---

## 1. 데이터 흐름 표

### 1.1 기기 밖으로 나가는 것

| # | 무엇 | 어디로 | 동의 게이트 | 보유 | 사용자 통제 | 근거 |
|---|---|---|---|---|---|---|
| O1 | Firebase Analytics 이벤트 15종 + 사용자 속성 3종 + 앱 인스턴스 ID, 기기·OS 정보 | Google (Firebase/GA4) | `analytics_storage` 기본 **거부**(Info.plist:87) → UMP 결과가 `notRequired`(한국 등)일 때만 허용(ad_manager.dart:135-138). EEA 등 동의 대상 지역은 영구 거부 | GA4 콘솔 보관 기간(방침 표기 2개월) | 없음(앱 안 옵트아웃 없음). 사용자 속성은 초기화로도 안 지워짐 → R2 | analytics.dart:43-56, 59-78 |
| O2 | AdMob 광고 요청: IDFA(ATT 허용 시), IP 기반 대략 위치, 기기 정보, 노출·클릭, 진단 | Google (AdMob) | UMP `canRequestAds()` true 일 때만 `MobileAds.initialize()`(ad_manager.dart:204-220) | Google 방침 | ATT(iOS 설정), 설정 › 개인정보 설정(동의 지역만 표시, settings_screen.dart:130-146) | ad_manager.dart:96-229 |
| O3 | UMP 동의 정보 조회(기기 지역·앱 ID) | Google (fundingchoices) | 없음 — 동의 프레임워크 자체. 앱 시작 직후 1회 | — | — | ad_manager.dart:123 |
| O4 | ATT 프롬프트 응답 | Apple 시스템(외부 전송 없음) | UMP 콜백 안에서만(ad_manager.dart:142, 169-172) | — | iOS 설정 › 추적 | ad_manager.dart:185-197 |
| O5 | Firebase Installations ID 등록 요청(추정) | Google (firebaseinstallations) | `Firebase.initializeApp()`이 UMP보다 먼저(main.dart:44) | — | — | R4 참고, 미검증 |
| O6 | 개인정보처리방침·지원 페이지 열기 | GitHub Pages(외부 브라우저) | 사용자 탭 | — | — | app_meta.dart:15-18, settings_screen.dart:301-307 |

이름·MBTI·성별·자유 입력 원문은 **어느 경로로도 나가지 않는다** (§2 OK-1, OK-2 에 추적 근거).

### 1.2 기기에 저장되는 것 (전부 `SharedPreferences` = iOS `NSUserDefaults`)

| 키 | 내용 | 개인정보 성격 | 지워지는 때 | 근거 |
|---|---|---|---|---|
| `mossol_save_v1` | 회차 세이브 JSON. `mbti`(models.dart:1309), `freeInputs[]`(models.dart:1328 — 이벤트 id·선택 index·**친 문장 ≤80자**·일차·자동 여부) 포함. 이름은 **미포함** | 자유 입력 원문 = 이용자 작성 텍스트 | 엔딩 도달 시(game_controller.dart:1496), 새 게임, 초기화 | save_service.dart:9-15 |
| `mossol_endings_v1` | 본 엔딩 id 목록 | 없음 | 초기화만 | save_service.dart:10, 36-50 |
| `mossol_meta_v1` | `playerName`, `playerGender`, `mbti`, 출석·회차 수·`freeInputSends` 등 | 이름·성별·MBTI | 초기화 | meta_service.dart:84-103, 142-165 |
| (Google SDK 자체 키) | UMP 동의 상태, Firebase 앱 인스턴스 ID, AdMob SDK 내부 값 | 식별자 | 앱 삭제. 초기화로는 **안 지워짐** | R2, OK-8 |

- 내보내기·공유·클립보드 경로 없음: `grep -rn "Clipboard\|share_plus\|Share\." lib` → 0건. 방침 링크 실패 시 URL 만 `SelectableText`(settings_screen.dart:316).
- iCloud 백업: `NSUserDefaults` 는 기본적으로 iCloud/컴퓨터 백업에 포함된다(`NSFileProtection`·백업 제외 설정 없음). 즉 이름·MBTI·최근 30문장은 Apple 백업(종단 암호화 여부는 사용자의 고급 데이터 보호 설정에 따름)에 복사된다. 앱을 지워도 기존 백업본은 다음 백업으로 덮어써질 때까지 남는다 → 방침 문안 §3-③.

---

## 2. 발견 사항 (FAIL → RISK → OK)

### FAIL — 없음

### RISK

**R1. 개인정보처리방침이 자유 입력 기능을 반영하지 않는다** — https://humsleep.github.io/apps/mossol/privacy/ (200, 6,358B, 시행일 2026-09-22)
- §1 "게임 진행 정보(플레이어 이름, 성별·MBTI 선택, 스탯, 호감도, 엔딩 기록 등)" — 이용자가 **직접 쓴 문장**이 기기에 저장된다는 사실이 없다. 이건 '진행 정보'가 아니라 이용자 작성 콘텐츠라 명시가 필요하다(개인정보보호법 §30 수집 항목, Apple 5.1.1(i)).
- §2 Firebase 이벤트 열거에 `free_input_*` 5종이 빠져 있다. 원문은 안 가지만 **길이 구간·존댓말 여부·질문 여부·감정 비트·매핑 신뢰도·결과**(analytics.dart:171-197)는 간다. "게임 내 진행 이벤트"로 뭉뚱그리기엔 방침이 이미 항목을 열거하고 있어, 빠진 항목은 허위 열거가 된다.
- §1 오타: "(이용 통계로 보내는 항목은 2항 참고)다." — 문장 끝 "다" 잔재.
- 고침: §3 문안 그대로 반영. 코드 변경 없음.

**R2. `저장 데이터 초기화`가 Firebase 사용자 속성·앱 인스턴스 ID 를 남긴다** — game_controller.dart:691-711
- 지우는 것: `mossol_save_v1`·`mossol_endings_v1`·`mossol_meta_v1` 세 키 전부, 메모리 상태, `TextTemplate.currentName/Mbti`. 로컬은 **완전 초기화 맞다.**
- 안 지우는 것: 사용자 속성 `pref`·`mbti_known`·`free_input_use`(analytics.dart:148, 164, 234)와 Firebase 앱 인스턴스 ID. 초기화 뒤 새 플레이어의 이벤트가 이전 사람의 `mbti_known=1` 에 붙는다. UMP 동의 상태도 남는데 이건 **의도된 동작**(동의는 기기 단위, 설정 행으로 바꿀 수 있음)이라 문제 없음.
- 고침(한 줄): `resetAllData()` 안에서 `FirebaseAnalytics.instance.resetAnalyticsData()` 를 호출한다(백엔드가 `FirebaseAnalyticsBackend` 일 때만, `Analytics` 에 `static Future<void> resetData()` 도우미를 두고 `_guard` 로 감싼다). 앱 인스턴스 ID 가 새로 나며 사용자 속성이 비워진다. 방침 §4 문구도 §3-④ 로 맞춘다.

**R3. `docs/RELEASE_CHECKLIST.md` §3.1 이벤트 표가 코드와 어긋난다** — RELEASE_CHECKLIST.md "보내는 이벤트" 표
- 코드(analytics.dart:71-78)에 있는 `free_input_sent`·`free_input_picked`·`free_input_undo`·`free_input_blocked`·`free_input_locked` 와 사용자 속성 `free_input_use` 가 표에 없다. App Store Connect 라벨 자체는 "사용 데이터 › 제품 상호작용/기타 사용 데이터"로 이미 덮여 있어 라벨 수정은 불필요하지만, 심사 노트·방침을 이 표에서 베끼면 R1 이 재발한다.
- 고침: `docs/overhaul/07_free_input.md` §5 표를 §3.1 아래에 옮겨 붙인다.

**R4. EEA 에서 동의 전에 Google 로 나가는 요청이 0건인지 미검증** — main.dart:44 vs ad_manager.dart:100
- `Firebase.initializeApp()` 이 UMP 보다 먼저 돈다. Info.plist 동의 모드 기본값이 전부 거부(87-92행)라 **Analytics 이벤트는 안 나간다**(Google 문서: 앱에서 `analytics_storage` 거부 시 수집 안 함). 다만 링크된 `FirebaseInstallations`(빌드 산출물에 존재)가 초기화 시 설치 ID 를 등록하러 `firebaseinstallations.googleapis.com` 에 접속할 수 있다. 실린 것은 설치 ID·앱 ID 뿐이라 개인정보 위험은 낮지만, "동의 전 전송 없음"을 방침에 쓰려면 확인이 필요하다. 신뢰도: 중간(정적 분석 한계).
- 고침: 시뮬레이터에서 UMP `debugGeography=EEA` 로 두고 Proxyman/Charles 로 첫 30초 트래픽을 캡처해 `docs/review/evidence/` 에 남긴다. 접속이 보이면 `FirebaseApp.configure` 를 UMP 콜백 뒤로 미루는 대신 `Analytics.init()` 호출을 `_startConsentFlow` 성공 콜백 뒤로 옮기는 편이 간단하다(측정 이벤트는 어차피 동의 뒤에만 유효).

**R5. GoogleService-Info.plist 의 API 키가 GCP 에서 제한돼 있는지 미확인** — ios/Runner/GoogleService-Info.plist:5-6
- Firebase iOS API 키는 앱 번들에 실리도록 설계된 값이라 저장소·바이너리에 있는 것 자체는 정상이다(비밀 아님). git 히스토리 전체에서 이 파일은 cbd2c4b 한 번만 추가됐고 다른 프로젝트 키가 섞인 적 없다(`git log --all -S AIza` 고유 키 1개). `.env`·`google-services.json` 없음, `_debugTestDeviceIds` 비어 있음(ad_manager.dart:59).
- 남는 위험: 이 키가 무제한이면 누군가 다른 앱에서 이 Firebase 프로젝트의 Identity Toolkit 등 API 를 호출할 수 있다.
- 고침: Google Cloud Console › API 및 서비스 › 사용자 인증 정보 › 해당 키 › 애플리케이션 제한 "iOS 앱", 번들 ID `com.hyukahn.mossol`; API 제한을 Firebase Installations·Analytics 로 좁힌다. 코드 변경 없음, 키 교체 불필요.

**R6. 방침 §1 "앱을 삭제하면 함께 지워집니다" 가 백업본을 빠뜨린다** — §1.2 iCloud 항목
- 고침: §3-③ 문안. 코드로 막으려면 `shared_preferences` 대신 백업 제외 파일 저장소가 필요해 범위 밖 — 문안으로 충분하다.

**R7. 방침 영어 요약 "With your consent, … Firebase Analytics" 가 실제 동작보다 넓다** — ad_manager.dart:136-138
- EEA/UK/CH 사용자는 UMP 에서 동의해도 Analytics 는 켜지지 않는다(`status == notRequired` 일 때만 허용). 보수적이라 위험은 없지만 문장이 사실과 다르다.
- 고침: §3-⑤ 문안.

### OK (검증 완료)

**OK-1. 이름·MBTI·자유 입력 원문은 Analytics 로 가지 않는다.**
- 이벤트·파라미터 전수(analytics.dart:59-78, 131-241):
  `onboarding_step{step}` · `onboarding_done{pref,has_name 0/1,has_mbti 0/1,mbti_source}` · `run_started{run,pref,n}` · `day_reached{day}` · `run_ended{ending,tier,run,day}` · `ad_hint_used{}` · `ad_rewarded_shown{placement}` · `heart_empty{day}` · `album_opened{}` · `next_run_suggestion_tapped{kind}` · `free_input_sent{layer,ev,n_ch,len_b,polite,q,emo,conf_b,margin_b,top_i,top_kind,result}` · `free_input_picked{ev,top_i,pick_i,rank,via}` · `free_input_undo{ev,top_i,re_i,conf_b}` · `free_input_blocked{reason}` · `free_input_locked{ev,top_i}`. 사용자 속성 `pref`·`mbti_known`·`free_input_use`.
- 문자열 파라미터의 출처는 전부 코드 상수·이벤트 id(≤40자 절단, analytics.dart:244)·엔딩 id·placement 이름. 이용자가 친 값이 들어갈 자리가 없다. `log()` 는 디버그에서 값 형식을 assert 한다(98-106).
- 추적: `chooseFree`(game_controller.dart:406-470) → `freeInputSend(...)` 인자는 `lenBucket`·`polite`·`question`·`_emoBits`·점수×10 정수·index·enum 뿐. `confirmFree`(490-530) → `freeInputPick` 은 index·rank·via. `undoFree`(546-556) → 정수. 금칙어 걸림 → `freeInputBlock('profanity')` 상수. `cacheKey` 에 `playerName` 이 들어가지만(416) 로컬 캐시 키일 뿐 전송 안 됨.
- 테스트가 지킨다: test/analytics_test.dart:111(이름 '민석' 이 어느 파라미터에도 없음), test/widget/free_input_test.dart:120(원문 '싫어' 없음).

**OK-2. 자유 입력 저장은 상한이 있다.** 80자 절단이 매처(free_input.dart:572-574)·컨트롤러(game_controller.dart:503-505)·모델 생성자(models.dart:1176) 세 겹. 링 30건(models.dart:1392-1399, `removeRange`). 이벤트당 전송 횟수 `maxFreeSendsPerEvent`, 금칙어 연속 3회 차단(game_controller.dart:369-376). 되돌리기는 기록도 지운다(1407-1413). 엔딩 시 세이브 삭제(1496)로 회차를 넘어 남지 않는다.

**OK-3. 금칙어 목록은 순수 로컬.** free_input_lexicon.dart:164-170 상수. 걸리면 매핑·저장·기록 없음, Analytics 엔 `reason=profanity` 카운트만(game_controller.dart:424-426). 걸린 문장은 어디에도 안 남는다.

**OK-4. 동의 순서: UMP → (폼) → Analytics 동의 → ATT → `MobileAds.initialize()`.** ad_manager.dart:123-143. ATT 는 UMP 성공 콜백 안에서만(169-172). `_initializeSdkIfAllowed` 는 항상 `canRequestAds()` 로 문을 잠근다(204-212) — 앱 복귀(262), 설정 폼 뒤(241), 리워드 버튼(395)도 같은 문을 지난다.

**OK-5. 10초 타임아웃·오류 경로는 동의 없이 광고를 켜지 않는다.** 타임아웃(160-164)은 `_initializeSdkIfAllowed` 만 부르고, 첫 실행이면 `canRequestAds()` 가 false 라 아무 일도 안 한다. 지난 세션 동의가 있으면 초기화하되 ATT 는 이번 세션엔 묻지 않는다(설계 의도, 111-114행 주석). 오류 콜백(144-149)은 ATT 를 묻지만 초기화는 여전히 게이트 뒤. 두 경로 모두 `setAnalyticsConsent` 를 안 불러 Analytics 는 **거부 상태 유지** — 측정만 잃고 개인정보는 안전.

**OK-6. Analytics 동의 기본값은 거부.** Info.plist:81-92 `GOOGLE_ANALYTICS_DEFAULT_ALLOW_*` 4종 false, `ADID_COLLECTION_ENABLED` false, `GADDelayAppMeasurementInit` true(96-97). `setAnalyticsConsent` 는 광고 관련 3종을 항상 false 로 고정(analytics.dart:47-52). 부수 효과: 동의 콜백 전에 찍힌 `first_open`·첫 `onboarding_step` 은 버려질 수 있다 — 측정 공백일 뿐.

**OK-7. `PrivacyInfo.xcprivacy` 는 AdMob SDK 매니페스트와 일치한다.** 빌드 산출물 `GoogleMobileAds.framework/PrivacyInfo.xcprivacy`(SDK 13.9.0) 의 수집 항목 7종(DeviceID linked+tracking, CoarseLocation, AdvertisingData, ProductInteraction, PerformanceData, CrashData, OtherDiagnosticData)과 용도가 앱 매니페스트(ios/Runner/PrivacyInfo.xcprivacy:27-137)와 항목·linked·tracking·purposes 까지 동일하고, Firebase 몫으로 `OtherUsageData`(85-96) 하나를 더했다. RELEASE_CHECKLIST §3 표 10행과도 1:1. "사용자 콘텐츠" 미수집 답변은 자유 입력이 기기에만 남으므로 맞다.

**OK-8. 필수 사유 API 선언 — ITMS-91053 위험 없음.** 각 바이너리가 자기 매니페스트를 갖고 있다(빌드 산출물 기준): Flutter.framework(FileTimestamp 0A2A.1·C617.1, SystemBootTime 35F9.1) · GoogleMobileAds(SystemBootTime 35F9.1, UserDefaults CA92.1, DiskSpace E174.1) · UserMessagingPlatform(UserDefaults CA92.1) · FirebaseCore(CA92.1) · FirebaseCoreInternal(1C8F.1) · shared_preferences_foundation(1C8F.1) · url_launcher_ios·app_tracking_transparency(빈 매니페스트). 앱 자체 선언 UserDefaults CA92.1·FileTimestamp C617.1(138-156)은 앱 코드가 직접 부르지 않으니 여분이지만 무해. `audioplayers_darwin` 6.5.0 은 매니페스트가 없으나 소스에 UserDefaults·stat·systemUptime·디스크 용량 호출이 없어(grep 0건) 선언 의무도 없다.

**OK-9. `NSPrivacyTracking=true` + 빈 `NSPrivacyTrackingDomains`.** ATT 를 띄우고 IDFA 로 맞춤 광고를 하니 true 가 맞다(PrivacyInfo:23-24, Info.plist:98-99). 도메인을 비운 것은 Google 안내(GMA SDK 가 ATT 상태로 자체 게이트)와 같고 GMA SDK 매니페스트도 도메인을 선언하지 않는다.

**OK-10. 방침·지원 URL 은 살아 있고 App Store 값과 같다.** `AppLinks.privacyPolicy`·`support`(app_meta.dart:15-18) 모두 200. 방침은 AdMob/UMP/Firebase 를 처리자로, ATT·UMP 철회 경로·14세 미만·책임자 연락처·국외 이전·EEA 영어 요약까지 갖췄다(RELEASE_CHECKLIST §8 1~8 충족). 지원 페이지는 저장 위치·추적 끄기·문의 이메일 안내.

**OK-11. 비밀값·광고 ID.** 실제 광고 단위 ID(ad_manager.dart:43-49)·앱 ID(Info.plist:94)는 바이너리에 실리는 공개 값. 릴리스에서만 실제 ID, 디버그는 Google 테스트 ID(52-55) — test/ad_ids_test.dart 가 고정. Android 매니페스트는 Google 샘플 앱 ID(AndroidManifest.xml:38) — iOS 제출과 무관하나 Android 출시 전 교체 필요.

**OK-12. SDK 버전(pubspec.lock / 빌드 산출물).** google_mobile_ads 9.1.0 → GMA iOS 13.9.0, UMP 3.1.0 · firebase_core 4.15.0 / firebase_analytics 12.6.0 → Firebase iOS 12.19.0 · shared_preferences 2.5.5(foundation 2.5.7) · audioplayers 6.8.1(darwin 6.5.0) · url_launcher 6.3.2(ios 6.4.2) · app_tracking_transparency 2.0.7 · Flutter 3.47.4. 전부 2026-09 시점 현행 메이저이며 Apple 의 Xcode 16/iOS 18 SDK 최소 요건을 넘는다. 이 감사는 오프라인 정적 검토라 CVE 데이터베이스 대조는 하지 않았다 — 제출 직전 `flutter pub outdated` 와 Google 릴리스 노트로 한 번 더 본다.

---

## 3. 개인정보처리방침 수정 문안 (그대로 붙여 넣기)

시행일을 갱신하고 §9 에 따라 "2026-09-2x 개정: 자유 입력 항목 추가" 를 남긴다.

① §1 둘째 문단 교체
> 게임 진행 정보(플레이어 이름, 성별·MBTI 선택, 스탯, 호감도, 엔딩 기록, 그리고 **대화 중 이용자가 직접 입력한 문장(이벤트당 80자 이내, 최근 30개까지)**)는 이용자 기기 안에만 저장됩니다. 이름·MBTI·성별 값과 직접 입력한 문장은 외부로 전송되지 않습니다(이용 통계로 보내는 항목은 2항 참고).

② §2 Firebase Analytics 행 "수집 항목" 교체
> 앱 인스턴스 ID, 기기·OS 정보, 게임 내 진행 이벤트: 온보딩 단계, 도달한 날짜(일차), 도달한 엔딩 종류, 회차 번호, 광고 보상을 받은 위치, 고른 상대 캐릭터 쪽(남성/여성/전체), 이름·MBTI를 입력했는지 여부(값은 보내지 않음), **자유 입력 사용 통계(사용 횟수 구간, 입력 길이 구간, 존댓말·질문 여부, 감정 표현 유무, 선택지에 얼마나 확실하게 연결됐는지, 금칙어에 걸린 횟수 — 입력한 문장 자체는 보내지 않음)**. 이름·MBTI 값·자유 입력 내용은 보내지 않습니다.

③ §4 첫 문장 교체
> 기기에 저장된 게임 정보는 앱을 삭제하거나 앱 설정의 초기화 기능을 쓰면 즉시 지워집니다. **다만 iOS 백업(iCloud 또는 컴퓨터)을 켜 두었다면 백업본에 복사되어 있을 수 있으며, 이는 다음 백업 때 함께 갱신·삭제됩니다.**

④ §4 둘째 문장 뒤 추가 (R2 를 고친 뒤에만)
> 앱 설정의 초기화 기능은 Firebase Analytics 의 앱 인스턴스 ID 와 사용자 속성도 함께 재설정합니다.

⑤ English summary "What we process" 교체
> The game stores your progress, including sentences you type during conversations (up to 80 characters each, latest 30), only on your device. Google AdMob (ads) processes device identifiers, approximate location (IP-based), device information and ad interaction data, subject to your consent where required. Firebase Analytics (usage statistics) is enabled only in regions where consent is not legally required; in the EEA, UK and Switzerland it stays off. Your name, MBTI, own gender and typed sentences are never sent.

⑥ 오타: §1 "…2항 참고)다." → "…2항 참고)."

---

## 4. 판정

**조건부 통과.** 코드 쪽 개인정보 처리는 설계대로다 — 원문은 기기 밖으로 나가지 않고, 광고·측정은 동의 뒤에만 켜지며, 매니페스트는 SDK 와 일치한다. 제출 전에 ① 방침 §3 문안 6곳 반영(R1·R6·R7), ② `resetAllData()` 에 `resetAnalyticsData()` 한 줄(R2), ③ RELEASE_CHECKLIST §3.1 표 동기화(R3), ④ EEA 동의 전 트래픽 캡처 1회(R4), ⑤ GCP API 키 앱 제한(R5)을 끝내면 남는 지적은 없다.
