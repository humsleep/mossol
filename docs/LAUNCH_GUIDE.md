# 출시까지 쉬운 순서 (App Store 심사 제출까지)

> 자세한 근거와 정책은 `RELEASE_CHECKLIST.md`, 스토어 문구는 `STORE_LISTING.md`에 있다. 이 문서는 **순서만** 적는다.
> 🙋 = 직접 해야 하는 것(계정·결제·콘솔). 🤖 = 값을 알려 주면 Claude가 코드에 넣는 것.

현재 상태 (2026-09-22): 앱 완성, 아이콘 적용 완료, Apple 개발자 팀 설정됨(68BP5NY48R), Firebase 프로젝트 `mossol` 생성만 됨, AdMob 미생성.

---

## 1단계. AdMob 만들기 (약 20분)

1. 🙋 https://admob.google.com 에서 Google 계정으로 가입. 국가 **대한민국**, 시간대 서울, 결제 통화 KRW.
   - 수익 지급 정보(주소·은행)는 나중에 수익이 쌓이면 입력해도 된다.
2. 🙋 **앱 추가** → 플랫폼 **iOS** → "앱이 지원되는 앱 스토어에 등록되어 있나요?" → **아니요**(아직 출시 전).
   앱 이름 `모쏠 키우기`.
3. 🙋 그 앱에 **광고 단위 3개** 만들기:
   | 형식 | 이름(예) | 쓰는 곳 |
   |---|---|---|
   | 전면(Interstitial) | mossol_ios_interstitial | 3일차 이후 가끔 |
   | 보상형(Rewarded) | mossol_ios_rewarded | 하트 충전·힌트·되돌리기 |
   | 배너(Banner) | mossol_ios_banner | 화면 하단 |
4. 🙋 앱 설정 → **앱 콘텐츠 등급 최대값 T(청소년)**. 아동 대상 아님.
5. 🙋 **개인정보 보호 및 메시지** → GDPR 메시지 만들기 → 언어 **한국어** 추가 → 개인정보처리방침 URL(4단계) 입력 → **게시**.
   (IDFA 메시지 옵션도 켜면 ATT 설명 화면이 함께 뜬다.)
6. 🤖 아래 4개 값을 Claude에게 보낸다:
   - 앱 ID `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (물결표 `~`)
   - 전면·보상형·배너 광고 단위 ID 3개 (`/` 슬래시)

> 안드로이드는 나중에 출시할 때 같은 방법으로 앱을 하나 더 추가한다.

## 2단계. Firebase 연결 (약 10분)

1. 🙋 Firebase 콘솔 → 프로젝트 `mossol` → **앱 추가 → iOS**.
   - Apple 번들 ID: **`com.hyukahn.mossol`** (정확히)
   - 앱 닉네임: 모쏠 키우기 iOS
2. 🙋 `GoogleService-Info.plist` 다운로드 → 프로젝트의 **`ios/Runner/`** 폴더에 넣는다.
   이후 "SDK 추가", "초기화 코드" 단계는 **건너뛴다**(코드는 이미 되어 있다).
3. 🤖 Claude가 Xcode 타깃에 파일을 등록하고, 시뮬레이터에서 이벤트가 들어오는지 확인한다.
4. 🙋 (선택) Firebase 프로젝트 설정 → 통합 → **AdMob 연결**하면 광고 수익과 이용 통계를 한곳에서 본다.

## 3단계. 개인정보처리방침 올리기 (약 10분)

여러 앱이 같이 쓰는 공용 사이트 저장소를 `~/workspace/humsleep.github.io`에 준비해 두었다(앱 목록, 모쏠 안내·FAQ 페이지,
개인정보처리방침, 새 앱 템플릿, 공용 `app-ads.txt`). 사용법은 그 폴더의 `README.md`.

1. 🙋 GitHub에서 **공개(public)** 저장소 `humsleep.github.io`를 **빈 채로** 만든다(README 추가 체크 해제).
2. 🙋 보호책임자 이름과 **앱 문의 전용 메일**을 정한다(공개되므로 개인 메일 대신).
3. 🤖 Claude가 `[연락 이메일]`·`[보호책임자 이름]`을 채우고 푸시한다.
4. 🙋 저장소 Settings → Pages → Branch `main` / `(root)` → Save. 1~2분 뒤 열린다.
   - 개인정보처리방침: `https://humsleep.github.io/mossol/privacy/`
   - 지원 URL: `https://humsleep.github.io/mossol/`
5. 🤖 Claude가 앱 설정 화면 링크(`lib/app_meta.dart`)를 위 주소로 바꾼다.

## 4단계. App Store Connect에 앱 만들기 (약 30분)

1. 🙋 https://appstoreconnect.apple.com → 앱 → **+ 새로운 앱**
   - 플랫폼 iOS, 이름 `모쏠 키우기 : 연애 시뮬레이션 게임`, 기본 언어 **한국어**,
     번들 ID `com.hyukahn.mossol`(목록에 없으면 developer.apple.com → Identifiers 에서 먼저 등록), SKU `mossol001`.
2. 🙋 **앱 정보**: 부제·카테고리(게임 > 시뮬레이션, 보조 엔터테인먼트) — `STORE_LISTING.md` 복사.
3. 🙋 **가격 및 사용 가능 여부**: 무료, 국가는 우선 **대한민국만**(ROADMAP 소규모 출시).
4. 🙋 **앱 개인정보 보호**: 개인정보처리방침 URL(3단계) + 데이터 수집 설문 → `RELEASE_CHECKLIST.md` §3 표 그대로.
5. 🙋 **연령 등급**: `STORE_LISTING.md`의 설문 답변 그대로(예상 12+).
6. 🙋 **1.0 버전 페이지**: 프로모션 텍스트·설명·키워드·지원 URL(개인정보처리방침 주소나 노션 페이지 가능).
7. 🤖 **스크린샷**: Claude가 6.9인치 시뮬레이터로 8장 찍어 `docs/store_screenshots/`에 넣는다. 🙋 업로드만.
8. 🙋 **심사 노트**: `RELEASE_CHECKLIST.md` §6 문구 복사(로그인 없음, 광고 테스트 방법 등).

## 5단계. 빌드 올리기 (약 20분)

1. 🤖 Claude가 1·2·3단계 값을 넣고 테스트·빌드 검증 후 커밋한다.
2. 🙋 Xcode에서 `ios/Runner.xcworkspace` 열기 → 상단 기기를 **Any iOS Device (arm64)** → 메뉴 **Product → Archive**.
   (터미널이 편하면: `flutter build ipa` 후 Transporter 앱으로 업로드.)
3. 🙋 Organizer 창 → **Distribute App → App Store Connect → Upload**. 몇 분~30분 뒤 App Store Connect에 빌드가 뜬다.
4. 🙋 수출 규정(암호화) 질문 → "표준 암호화만 사용 / 면제" (HTTPS만 씀).

## 6단계. TestFlight로 한 번 해 보기 (하루)

1. 🙋 TestFlight → 내부 테스터에 본인 추가 → iPhone에 TestFlight 앱으로 설치.
2. 🙋 확인할 것: 첫 실행 → ATT 팝업 → 온보딩 → 하루 진행 → 광고가 **실제 광고**로 뜨는지(처음 며칠은 광고가 적게 뜰 수 있음, 정상)
   → 설정의 개인정보처리방침 링크가 열리는지.
3. 🙋 **본인 폰에서 실제 광고를 반복해서 누르지 말 것**(AdMob 계정 정지 사유). 확인용으로는 AdMob → 설정 → **테스트 기기**에 본인 폰을 등록한다.

## 7단계. 심사 제출

1. 🙋 1.0 버전 페이지 → 빌드 선택 → **심사에 추가 → 제출**. 보통 1~3일.
2. 반려되면 사유를 Claude에게 붙여 넣으면 된다. 흔한 사유와 대응은 `RELEASE_CHECKLIST.md` §6.

## 8단계. 출시 후 바로 할 것

1. 🙋 AdMob → 앱 설정 → **스토어에 앱 연결**(출시된 App Store 앱 선택). 연결해야 광고 노출이 정상화된다.
2. 🤖 **app-ads.txt**: 공용 사이트에 자리가 이미 있다(`https://humsleep.github.io/app-ads.txt`). AdMob 게시자 ID(`pub-…`)를
   알려 주면 Claude가 채워 푸시한다. 🙋 App Store Connect의 마케팅 URL에 `https://humsleep.github.io/`를 넣어야 AdMob이 찾아간다.
3. 🙋 지인 20~50명에게 공유 → 1~2주 뒤 Firebase에서 `ROADMAP.md` Phase 2 숫자 확인 → Claude와 다음 단계 결정.

---

### 지금 Claude에게 보내 주면 되는 것 (한 번에)

- [ ] AdMob 앱 ID 1개 + 광고 단위 ID 3개
- [ ] `GoogleService-Info.plist`를 `ios/Runner/`에 넣었다는 말
- [ ] `humsleep.github.io` 공개 저장소를 만들었다는 말 + 보호책임자 이름·문의 전용 메일
