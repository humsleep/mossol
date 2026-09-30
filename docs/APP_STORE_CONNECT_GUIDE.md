# App Store Connect 입력 가이드 — 모쏠 탈출기 1.0.0

> 화면 순서대로, **칸마다 무엇을 넣는지** 적었다. `복사` 표시가 있는 블록은 그대로 붙여 넣는다.
> App Store Connect 화면 문구는 Apple이 가끔 바꾼다. 칸 이름이 조금 달라도 같은 뜻의 칸에 넣으면 된다.
> 영어 화면이면 괄호 안 영어 이름을 보면 된다.

---

## 0. 시작 전 확인 (1분)

- https://appstoreconnect.apple.com 에 Apple 개발자 계정으로 로그인된다.
- 첫 화면 **계약·세금 및 금융(Agreements, Tax, and Banking)** 에 빨간 경고가 없는지 본다.
  무료 앱은 "무료 앱 계약(Free Apps Agreement)"만 있으면 되고, 이건 개발자 등록 때 자동으로 동의돼 있다.
  **유료 앱 계약·은행 정보는 필요 없다**(광고 수익은 Apple이 아니라 AdMob이 지급).
- **2026-06-08 개정 약관(Apple Developer Program License Agreement) 동의**: developer.apple.com/account 에 들어가 새 약관 동의 배너가 있으면 먼저 동의한다.
  동의하지 않으면 제출이 막힌다. 같은 개정에서 개발자 신원 확인 요청이 오면 답해야 한다(https://developer.apple.com/news/?id=a233fmpw).

---

### 0-1. 2026-09-29 기준 Apple 규칙 (이 가이드에 반영됨)

| 규칙 | 내용 | 이 앱 | 출처 |
|---|---|---|---|
| SDK 최소 요건 (2026-04-28부터) | Xcode 26 이상 + iOS 26 SDK 로 빌드해야 업로드 가능 | 맥의 Xcode 26.6 으로 빌드하면 충족 | https://developer.apple.com/news/upcoming-requirements/ |
| 최소 지원 OS (2026-09-09부터) | iOS 13 이상을 대상으로 해야 함 | 배포 대상 iOS 15.0 — 충족 | 같은 곳 |
| 새 연령 등급 (2026-01-31부터 필수) | 4+/9+/13+/16+/18+, 새 문항(앱 내 제어·기능·의료/웰니스·폭력 테마 등) | §3 — 결과 13+ | https://developer.apple.com/news/?id=ks775ehf |
| 스크린샷 | iPhone 6.9형(1320×2868 등) 또는 6.5형(1284×2778 등) 한 벌, 1~10장. iPhone 전용이면 iPad 불필요 | §6-2 | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ |
| 심사 지침 개정 (2026-02-06, 2026-06-08) | 무작위·익명 채팅 앱은 1.2(UGC) 적용, 아동·청소년 안전 지침 보강 등 | 사람 간 채팅 없음 — 심사 노트에 명시 | https://developer.apple.com/news/?id=d75yllv4 , https://developer.apple.com/news/?id=a233fmpw |
| 개인정보 매니페스트·서드파티 SDK 서명 | 목록의 SDK(Google Mobile Ads, Firebase 등)는 매니페스트·서명 필요, required reason API 선언 | SDK 최신 버전 사용, `PrivacyInfo.xcprivacy` 있음 | https://developer.apple.com/support/third-party-SDK-requirements/ |

## 1. 새 앱 만들기 (앱 → 왼쪽 위 파란 **+** → **신규 앱**)

| 칸 | 넣을 값 | 설명 |
|---|---|---|
| 플랫폼 (Platforms) | **iOS** 만 체크 | |
| 이름 (Name) | `모쏠 탈출기 : 100일 연애 시뮬레이션` | 스토어에 보이는 이름. 30자 이내(22자) |
| 기본 언어 (Primary Language) | **한국어** | |
| 번들 ID (Bundle ID) | **com.hyukahn.mossol** 선택 | 목록에 없으면 아래 "번들 ID가 목록에 없을 때" |
| SKU | `mossol001` | 내부 관리용 아무 문자열. 사용자에게 안 보임 |
| 사용자 액세스 (User Access) | **전체 액세스 (Full Access)** | 혼자 쓰면 이걸로 |

→ **생성(Create)**.

**"이 이름은 이미 사용 중" 이 뜨면:** 이름을 `모쏠 탈출기 - 100일 연애 시뮬레이션` 처럼 기호만 바꿔 다시 넣고 알려 주세요.

### 번들 ID가 목록에 없을 때
1. https://developer.apple.com/account/resources/identifiers/list 로 간다.
2. **+** → **App IDs** → 계속 → **App** → 계속.
3. Description: `Mossol`, Bundle ID: **Explicit** 선택 후 `com.hyukahn.mossol`.
4. Capabilities는 아무것도 체크하지 않는다 → 계속 → **Register**.
5. App Store Connect로 돌아가 새로고침 후 다시 1번.

---

## 2. 앱 정보 (왼쪽 메뉴 **일반 → 앱 정보 / App Information**)

| 칸 | 넣을 값 |
|---|---|
| 이름 | (1에서 넣은 값 그대로) |
| 부제 (Subtitle) | `톡 한 줄로 썸부터 고백까지` |
| 카테고리 — 기본 (Primary) | **게임 (Games)** |
| └ 하위 카테고리 1 | **시뮬레이션 (Simulation)** |
| └ 하위 카테고리 2 | **어드벤처 (Adventure)** |
| 카테고리 — 보조 (Secondary) | **엔터테인먼트 (Entertainment)** |
| 콘텐츠 권한 (Content Rights) | **"아니요, 제3자 콘텐츠를 포함하거나 표시하거나 접근하지 않습니다"** (캐릭터 그림·대본은 직접 만든 것, 폰트는 오픈 라이선스) |
| 연령 등급 (Age Rating) | **편집** → §3 대로 답한다 |

오른쪽 위 **저장**.

---

## 3. 연령 등급 설문 (앱 정보 → 연령 등급 → 편집)

화면에 나오는 순서대로 답한다. Apple 현재 설문(4+/9+/13+/16+/18+, 2026-01-31부터 필수 — https://developer.apple.com/news/?id=ks775ehf) 기준, 2026-09-29 확인.
문항이 조금 달라도 같은 뜻이면 같은 답. 근거·등급 대응표는 `STORE_LISTING.md` §7.

**앱 내 제어 기능 (In-App Controls)**
| 문항 | 답 |
|---|---|
| 보호자 통제 (Parental Controls) | **아니요** |
| 연령 확인 (Age Assurance) | **아니요** |

**기능 (Capabilities)**
| 문항 | 답 | 이유 |
|---|---|---|
| 제한 없는 웹 접근 (Unrestricted Web Access) | **아니요** | 방침 링크 하나만 외부 브라우저로 연다 |
| 사용자 생성 콘텐츠 (User-Generated Content) | **아니요** | 이름·자유 입력('직접 쓰기')은 기기 안에서만 쓰이고 다른 사용자에게 보이지 않는다. 자유 입력 원문은 저장·전송하지 않는다 |
| 메시지·채팅 (Messaging and Chat) | **아니요** | 실제 사람끼리 대화 없음(미리 쓴 가상 캐릭터 대사) |
| 광고 (Advertising) | **예** | AdMob 광고 |
| 소셜 미디어 (Social Media) | **아니요** | 피드·팔로우·공유·댓글 없음. 사용자가 만든 글을 남에게 퍼뜨리는 기능이 없다 |
| 13세 미만 사용자의 소셜 미디어 비활성화 | **아니요**(회색이면 그대로) | 앞 문항이 "아니요"라 해당 없음. "예"로 답하면 Declared Age Range API 를 실제로 불러야 한다 |

**성인 테마 (Mature Themes)**
| 문항 | 답 |
|---|---|
| 비속어 또는 저속한 유머 (Profanity or Crude Humor) | **드물게/경미 (Infrequent)** |
| 공포/무서운 테마 (Horror/Fear Themes) | **없음 (None)** |
| 알코올·담배·약물 (Alcohol, Tobacco, or Drug Use or References) | **드물게/경미 (Infrequent)** |

**의료 또는 웰니스 (Medical or Wellness)**
| 문항 | 답 |
|---|---|
| 의료 또는 치료 정보 (Medical or Treatment Information) | **없음 (None)** |
| 건강 또는 웰니스 주제 (Health or Wellness Topics) | **아니요** |

**성적 내용·노출 (Sexuality or Nudity)**
| 문항 | 답 |
|---|---|
| 성인 또는 선정적 테마 (Mature or Suggestive Themes) | **드물게 (Infrequent)** — 연애·썸·고백이 주제 (화면에 따라 "성인 테마" 묶음에 나올 수도 있다) |
| 성적 내용 또는 노출 (Sexual Content or Nudity) | **없음** |
| 노골적인 성적 내용 및 노출 (Graphic Sexual Content and Nudity) | **없음** |

**폭력 (Violence)** — 전부 **없음** (만화·판타지 폭력, 사실적 폭력, 장시간·잔인한 사실적 폭력, 총기·무기)

**확률 기반 활동 (Chance-Based Activities)**
| 문항 | 답 |
|---|---|
| 도박 (Gambling) | **아니요** |
| 모의 도박 (Simulated Gambling) | **없음** (럭키 룰렛은 거는 것 없는 무료 운세 뽑기 — 근거는 `STORE_LISTING.md` §7) |
| 콘테스트 (Contests) | **없음** |
| 루트 박스 (Loot Boxes) | **아니요** (인앱 결제 없음) |

→ 결과는 **13+** 여야 한다. 가장 높은 항목이 "알코올·담배·약물 언급: 드물게" = 13+ 이고, 비속어·선정적 테마 "드물게"는 9+,
광고 "예"는 4+ 다(Apple 대응표: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).
**다른 등급이 나오면 제출하지 말고 답을 다시 확인한다.** 사용자 생성 콘텐츠·메시지·채팅은 "아니요"다 — 자유 입력은 기기 안에서만
쓰이고 다른 사람에게 보이지 않는다. "이 연령보다 높은 등급으로 설정" 같은 칸은 건드리지 않는다. **어린이용(Made for Kids)은 선택하지 않는다.**

---

## 4. 가격 및 사용 가능 여부 (왼쪽 **가격 및 사용 가능 여부 / Pricing and Availability**)

| 칸 | 넣을 값 |
|---|---|
| 가격 (Price) | **무료 (Free / USD 0.00)** |
| 사용 가능 국가 (Availability) | **대한민국만** 선택(소규모 출시). 나중에 언제든 늘릴 수 있다 |
| 사전 주문 (Pre-Order) | 사용 안 함 |
| iPad·Mac·Vision에서 사용 | Mac(Apple Silicon)·Vision Pro 사용 가능 체크는 **해제** 권장(테스트 안 함) |

**저장**.

---

## 5. 앱 개인정보 보호 (왼쪽 **앱 개인정보 보호 / App Privacy**)

### 5-1. 개인정보처리방침 URL
- **개인정보처리방침 URL (Privacy Policy URL)**: `https://humsleep.github.io/apps/mossol/privacy/`
- 사용자 개인정보 선택 URL (User Privacy Choices URL): **비워 둔다**(선택 사항)

### 5-2. 데이터 수집 설문 (**시작하기 / Get Started**)
1. "귀하 또는 제3자 파트너가 이 앱에서 데이터를 수집합니까?" → **예, 이 앱에서 데이터를 수집합니다**
2. 수집하는 데이터 유형 체크 — **아래 8개만** 체크하고 나머지는 전부 비운다.

| 분류 | 체크할 항목 |
|---|---|
| 식별자 (Identifiers) | **기기 ID (Device ID)** |
| 위치 (Location) | **대략적인 위치 (Coarse Location)** |
| 사용 데이터 (Usage Data) | **제품 상호 작용 (Product Interaction)**, **광고 데이터 (Advertising Data)**, **기타 사용 데이터 (Other Usage Data)** |
| 진단 (Diagnostics) | **충돌 데이터 (Crash Data)**, **성능 데이터 (Performance Data)**, **기타 진단 데이터 (Other Diagnostic Data)** |

연락처 정보, 건강, 금융, 사용자 콘텐츠, 검색·방문 기록, 구입 항목, 민감한 정보, 연락처 목록 → **모두 체크 안 함**.

3. **저장** 후, 항목마다 **설정(Set Up)** 을 눌러 세 가지 질문에 답한다.

| 항목 | 용도 (Purposes) — 체크 | 사용자 신원에 연결? (Linked) | 추적에 사용? (Tracking) |
|---|---|---|---|
| 기기 ID | **제3자 광고**, **개발자의 광고 또는 마케팅**, **분석** | **예** | **예** |
| 대략적인 위치 | 제3자 광고, 개발자의 광고 또는 마케팅, 분석 | **예** | 아니요 |
| 제품 상호 작용 | 제3자 광고, 개발자의 광고 또는 마케팅, 분석 | **예** | 아니요 |
| 광고 데이터 | 제3자 광고, 개발자의 광고 또는 마케팅, 분석 | **예** | 아니요 |
| 기타 사용 데이터 | **분석** 만 | 아니요 | 아니요 |
| 충돌 데이터 | **분석** 만 | 아니요 | 아니요 |
| 성능 데이터 | 제3자 광고, 개발자의 광고 또는 마케팅, 분석 | 아니요 | 아니요 |
| 기타 진단 데이터 | 제3자 광고, 개발자의 광고 또는 마케팅, 분석 | 아니요 | 아니요 |

- "앱 기능", "제품 개인화", "기타 목적"은 체크하지 않는다.
- 이 표는 Google 광고 SDK(AdMob)와 Firebase 가 공식 문서에 밝힌 수집 항목을 합친 것이다(`RELEASE_CHECKLIST.md` §3).

4. 오른쪽 위 **게시 (Publish)**. 요약 화면에 "사용자를 추적하는 데 사용되는 데이터: 기기 ID"가 보이면 맞다.

---

## 6. 1.0 버전 페이지 (왼쪽 맨 위 **iOS 앱 → 1.0 제출 준비 중**)

### 6-1. 버전 번호
왼쪽의 버전이 `1.0`으로 만들어져 있으면 눌러서 **`1.0.0`** 으로 바꾼다(앱 빌드 버전과 같아야 한다).

### 6-2. 스크린샷 (App Previews and Screenshots)
- 스크린샷 영역 **위쪽의 크기 탭에서 "iPhone 6.9형 디스플레이"** 를 먼저 고른다. 이게 핵심이다.
- 그 칸에 아래 순서로 끌어다 놓는다(1320×2868, 1~10장 허용):
  **`00a_lineup` → `02` → `01` → `04` → `05` → `03` → `06` → `07` → `08`** (9장, `docs/store_screenshots/promo/`).
  00a(12명 라인업, "100일 뒤, 연인이 될 수 있을까?") → 02(채팅·선택지) → 01(캐스트 화면) 순이라 검색 결과 앞 3장에
  얼굴·플레이·실제 화면이 다 보인다. **`00b_women`·`00c_men` 은 올리지 않는다**(파일은 SNS용으로 남김).
  라인업을 다시 만들려면 `python3 tool/store_images/lineup.py`. `STORE_LISTING.md` §6, `LAUNCH_GUIDE.md` 4단계와 같은 순서다.
- 다른 크기(6.5형 등)는 비워 둔다 — 6.9형에서 자동으로 줄여 쓴다.
- **"스크린샷 크기는 1242 × 2688px … 이어야 합니다" 오류**가 나면 6.5형 칸에 올리고 있는 것이다. 탭을 6.9형으로 바꾼다.
  6.9형 칸이 아예 없으면 6.5형용 한 벌(1284×2778)이 `docs/store_screenshots/promo65/` 에 있다(같은 파일 이름·같은 순서). 다시 만들려면 `python3 tool/store_images/make.py --65`.
- iPad 칸은 나오지 않는다(iPhone 전용 앱, `TARGETED_DEVICE_FAMILY = 1`). 만약 나오면 알려 주세요.
- 앱 미리보기(동영상)는 비워 둔다.

### 6-3. 프로모션 텍스트 (Promotional Text) — `복사`
```
오늘도 답장 올까? 썸 타는 그 사람에게 온 톡, 뭐라고 보낼지 골라 보세요. 읽씹과 질투, 한밤의 전화를 지나 100일 안에 고백까지. 남녀 캐릭터 각 6명, 엔딩 60개. 내 MBTI와 궁합이 가장 좋은 사람은 누구일까요?
```

### 6-4. 설명 (Description) — `복사`
```
답장 하나에 설레고, 읽씹 하나에 밤새 뒤척여 본 적 있나요?
연애 경험 0인 20대 중반 모쏠이, 100일 동안 메신저로 썸을 타고 고백까지 가는 연애 시뮬레이션이에요.
오늘 보낸 한 줄이 내일의 관계를 바꿔요.

■ 메신저 속 진짜 같은 썸
• 휴대폰 메신저처럼 오가는 대화에서 내 답장을 직접 골라요
• 답장이 늦으면 서운해하고, 다른 사람 얘기를 하면 질투해요
• 갑자기 걸려 오는 전화, 말없이 보내오는 사진 한 장
• 하루가 끝나면 "가까워졌다", "조금 멀어졌다"로 관계가 정리돼요
• 다음 날이 궁금해지는 한 줄 예고로 하루가 끝나요
• 선택지가 마음에 안 들면 직접 써서 보낼 수도 있어요

■ 누구와 설렐지 내가 정해요
• 남성 캐릭터 6명, 여성 캐릭터 6명, 총 12명
• 성별을 고르면 그에 맞는 사람들을 먼저 만나요. 고르지 않고 양쪽을 다 둘러볼 수도 있어요
• 동아리 선배, 소개팅 상대, 초등학교 동창까지, 사람마다 말투도 사연도 달라요
• 아직 소개되지 않은 숨은 캐릭터도 있어요

■ MBTI 궁합
• 내 MBTI를 고르면 캐릭터별 궁합이 하트로 보여요
• 몇몇 장면과 대사도 내 성격 유형에 따라 달라져요
• 잘 몰라도 괜찮아요. 건너뛰고 나중에 설정에서 바꿀 수 있어요

■ 100일, 엔딩 60개
• 고백에 성공하는 해피 엔딩부터 씁쓸한 엔딩, 숨겨진 엔딩까지 60개
• 어떤 답장을 보냈는지에 따라 전혀 다른 결말로 이어져요
• 실패한 순간도 흑역사 앨범에 모여 수집 요소가 돼요

■ 짧게 즐기는 미니게임 12종
• 답장 타이밍 맞추기, 프로필 고르기, 옷장 코디, 코스 짜기, 5초 안에 메시지 삭제하기 등
• 결과에 따라 매력, 화술, 눈치 같은 능력치와 호감도가 달라져요

■ 부담 없이
• 회원가입, 로그인 없이 바로 시작해요
• 진행 상황은 이 기기에만 저장돼요
• 다크 모드를 지원해요

■ 안내
• 무료로 즐길 수 있으며, 게임 중 광고가 표시돼요
• 행동에 쓰는 하트는 시간이 지나면 다시 채워지고, 원하면 광고를 보고 바로 받을 수 있어요
• 막힐 땐 광고를 보고 힌트를 받을 수 있어요(선택)
• 게임 속 인물과 사건은 모두 가상이에요
• MBTI는 The Myers-Briggs Company의 상표이며, 이 게임은 해당 회사와 관련이 없습니다.
```

### 6-5. 키워드 (Keywords) — `복사` (쉼표 뒤 띄어쓰기 없음)
```
미연시,메신저,채팅,대화,문자,읽씹,질투,밀당,소개팅,짝사랑,썸남,썸녀,남친,여친,로맨스,여성향,스토리,선택지,멀티엔딩,비주얼노벨,궁합,성격유형,두근두근,캐릭터,답장,설렘
```

### 6-6. 링크
| 칸 | 넣을 값 |
|---|---|
| 지원 URL (Support URL) | `https://humsleep.github.io/apps/mossol/` |
| 마케팅 URL (Marketing URL) | `https://humsleep.github.io/apps/` |

### 6-7. 빌드 (Build)
Xcode에서 업로드한 빌드가 처리되면(보통 10~30분) **빌드 추가(+)** 버튼이 생긴다. 1.0.0 (1) 을 고른다.
- 수출 규정 질문이 나오면: **"표준 암호화 알고리즘만 사용 / 면제"** 쪽(앱은 HTTPS만 씀). Info.plist 에 이미 답이 들어 있어서 안 물어볼 수도 있다.

### 6-8. 일반 앱 정보 (General App Information)
| 칸 | 넣을 값 |
|---|---|
| 앱 아이콘 | 빌드에서 자동으로 들어온다(따로 올리지 않음) |
| 버전 | `1.0.0` |
| 저작권 (Copyright) | `2026 안혁` (연도 + 이름. 실명이 싫으면 `2026 boheme`) |
| 라우팅 앱 커버리지 파일 | 비워 둔다 |

### 6-9. Game Center
**사용 안 함** (체크하지 않는다).

### 6-10. 앱 심사 정보 (App Review Information)
| 칸 | 넣을 값 |
|---|---|
| 로그인 필요 (Sign-In Required) | **체크 해제** (로그인 없음) |
| 연락처 — 이름 / 성 | `혁` / `안` (영문이면 `Hyuk` / `Ahn`) |
| 전화번호 | 본인 휴대폰 `+82 10-XXXX-XXXX` 형식 (심사관 연락용, 공개 안 됨) |
| 이메일 | `humsleep@naver.com` |
| 메모 (Notes) — `복사` | 아래 영어 문구 |
| 첨부 파일 | 없음 |

```
This is a single-player narrative/story simulation game. All characters, chats, and
"dating" scenarios are pre-written fictional content. There is no real-time matching,
no user accounts, no login, and no messaging between real users. Game progress is stored
only on the device. Please do not classify this as a dating or social-networking app.

Free-text input ("직접 쓰기" field under the reply buttons in chat scenes): the typed
text is matched on-device to one of the pre-written reply options. The text never
leaves the device; no AI/LLM and no server is used. Only non-content metrics (a usage
count bucket, length bucket, which pre-written option was matched) are logged to
Firebase Analytics, never the text itself.

App Tracking Transparency: on first launch the ATT prompt is intentionally shown right
after the short intro, not at app open. To reach it: tap "시작하기" on the title screen,
tap the lock-screen message card, then tap through the intro chat (answer "한다. 올해는
다르다", enter a name or tap "건너뛰기", choose a gender option), and tap "시작하기" on
the character introduction screen (about 5-7 taps, under a minute). A Google consent
message may appear first depending on region. The ATT prompt only appears if Settings >
Privacy & Security > Tracking > "Allow Apps to Request to Track" is ON and the app has
not been asked before (delete and reinstall to see it again).

Ads: Google AdMob (banner, interstitial, optional rewarded ads for refilling hearts and
hints). The app requests a maximum ad content rating of T (Teen) in code, and the same
limit is set in the AdMob console. Rewarded ads are optional; the game can be played
without watching them.

Firebase Analytics receives anonymous gameplay events (e.g. day reached, ending reached);
it does not collect the IDFA, and the player's name, MBTI, and typed text are never sent.

No in-app purchases. No login or account; no demo account is needed.
```

### 6-11. 이 버전의 새로운 기능 (What's New)
첫 버전에는 이 칸이 안 보일 수 있다. 보이면 `복사`:
```
모쏠 탈출기가 처음 출시됐어요!
• 남녀 캐릭터 각 6명과 메신저로 시작하는 100일의 썸
• MBTI 궁합, 엔딩 60개, 미니게임 12종
• 전화, 사진, 하루 정산까지 진짜 연애 같은 하루하루
첫 답장을 보내 보세요.
```

### 6-12. 버전 출시 (App Store Version Release)
**"이 버전을 수동으로 출시 (Manually release this version)"** 를 권장한다.
승인 뒤 AdMob·Firebase 가 정상인지 한 번 보고 **출시** 버튼을 직접 누르면 된다.

오른쪽 위 **저장**.

---

## 7. 제출 순서 요약

1. §1 새 앱 만들기 → §2 앱 정보 → §3 연령 등급 → §4 가격 → §5 개인정보 → §6 1.0.0 페이지(빌드만 빼고) 채우고 저장.
2. Xcode 로 빌드 업로드(`LAUNCH_GUIDE.md` 5단계) → 처리 끝나면 §6-7 에서 빌드 선택.
3. (권장) TestFlight 로 본인 폰에서 한 번 해 보기(`LAUNCH_GUIDE.md` 6단계).
4. 1.0.0 페이지 오른쪽 위 **심사에 추가 (Add for Review)** → **제출 (Submit for Review)**.
5. 상태가 "심사 대기 중 (Waiting for Review)" 이 되면 끝. 보통 1~3일. 반려되면 사유를 그대로 복사해서 보내 주세요.
