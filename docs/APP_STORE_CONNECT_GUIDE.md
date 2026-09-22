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

---

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

화면에 나오는 순서대로 답한다. (Apple 새 설문 기준. 문항이 조금 달라도 같은 뜻이면 같은 답.)

**앱 내 제어 기능 (In-App Controls)**
| 문항 | 답 |
|---|---|
| 보호자 통제 (Parental Controls) | **아니요** |
| 연령 확인 (Age Assurance) | **아니요** |

**기능 (Capabilities)**
| 문항 | 답 | 이유 |
|---|---|---|
| 제한 없는 웹 접근 (Unrestricted Web Access) | **아니요** | 방침 링크 하나만 외부 브라우저로 연다 |
| 사용자 생성 콘텐츠 (User-Generated Content) | **아니요** | 이름 입력은 기기 안에만 저장 |
| 메시지·채팅 (Messaging and Chat) | **아니요** | 실제 사람끼리 대화 없음(미리 쓴 가상 캐릭터 대사) |
| 광고 (Advertising) | **예** | AdMob 광고 |

**성인 테마 (Mature Themes)**
| 문항 | 답 |
|---|---|
| 비속어 또는 저속한 유머 (Profanity or Crude Humor) | **드물게/경미 (Infrequent)** |
| 공포/무서운 테마 (Horror/Fear Themes) | **없음 (None)** |
| 알코올·담배·약물 (Alcohol, Tobacco, or Drug Use or References) | **드물게/경미 (Infrequent)** |
| 성인 또는 선정적 테마 (Mature or Suggestive Themes) | **드물게/경미 (Infrequent)** |

**의료 (Medical or Wellness)** — 전부 **없음 / 아니요**

**성적 내용·노출 (Sexuality or Nudity)** — 전부 **없음**

**폭력 (Violence)** — 전부 **없음** (만화·판타지 폭력, 사실적 폭력, 장시간·잔인한 폭력, 총기 등)

**확률 기반 활동 (Chance-Based Activities)**
| 문항 | 답 |
|---|---|
| 모의 도박 (Simulated Gambling) | **없음** |
| 도박 (Gambling) | **아니요** |
| 콘테스트 (Contests) | **아니요** |
| 루트 박스 (Loot Boxes) | **아니요** |

→ 결과는 보통 **13+** 로 나온다(12+로 보이면 옛 체계 표시, 그것도 정상).
"이 연령보다 높은 등급으로 설정" 같은 칸은 건드리지 않는다. **어린이용(Made for Kids)은 선택하지 않는다.**

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
- **iPhone 6.9형 디스플레이** 칸에 `docs/store_screenshots/promo/01.png` ~ `08.png` 를 **순서대로** 끌어다 놓는다.
- 다른 크기(6.5형 등)는 비워 둔다 — 6.9형에서 자동으로 줄여 쓴다.
- iPad 칸은 나오지 않는다(iPhone 전용 앱). 만약 나오면 알려 주세요.
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
• 게임 속 인물과 사건은 모두 가상이에요
```

### 6-5. 키워드 (Keywords) — `복사` (쉼표 뒤 띄어쓰기 없음)
```
게임,미연시,메신저,채팅,대화,문자,읽씹,질투,밀당,소개팅,짝사랑,썸남,썸녀,남친,여친,로맨스,여성향,스토리,선택지,멀티엔딩,비주얼노벨,궁합,성격유형,두근두근,캐릭터,답장,설렘
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
"dating" scenarios are pre-written fictional content — there is no real-time matching,
no user accounts, no login, and no messaging between real users. Game progress is stored
only on the device. Please do not classify this as a dating or social-networking app.

Network use: Google AdMob serves ads (production ad units) and the Google UMP consent
form; the App Tracking Transparency prompt is shown only after the consent flow.
Firebase Analytics receives anonymous gameplay events (e.g. day reached, ending reached);
it does not collect the IDFA, and the player's name/MBTI are never sent.

No in-app purchases. Rewarded ads are optional (refill hearts, hints); the game can be
played without watching them.
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
