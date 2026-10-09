# 1.1.0 업데이트 제출 가이드 — App Store Connect

1.1.0 (11) 빌드를 App Store 에 업데이트로 내보내는 순서다. 위에서부터 그대로 따라 하면 된다.
`복사` 표시가 붙은 칸은 아래 코드 블록 내용을 그대로 붙여 넣는다.

| 단계 | 할 일 | 걸리는 시간 |
|---|---|---|
| 1 | 빌드가 처리됐는지 확인 | 1분 |
| 2 | 새 버전 1.1.0 만들기 | 1분 |
| 3 | 새로운 기능·프로모션 텍스트·설명 고치기 | 5분 |
| 4 | 빌드 고르기 | 1분 |
| 5 | 심사 메모 바꾸기 | 2분 |
| 6 | 출시 방식 고르고 심사 제출 | 2분 |
| 7 | 승인 뒤 출시 | 보통 1~2일 뒤 |

---

## 1. 빌드가 처리됐는지 확인

1. https://appstoreconnect.apple.com 에 들어가서 **앱 → 모쏠 탈출기**를 연다.
2. 위쪽 탭에서 **TestFlight** 를 누른다.
3. **iOS 빌드** 목록에 **1.1.0 → 11** 이 보이고 상태가 **테스트 준비 완료** 또는 **제출 준비 완료** 면 된다.
   - "처리 중"이면 10~30분 기다린다.
   - "수출 규정 정보 누락"이 보이면 눌러서 **"표준 암호화 알고리즘만 사용 / 면제"** 쪽을 고른다(앱은 HTTPS 만 쓴다).

## 2. 새 버전 1.1.0 만들기

1. 위쪽 탭에서 **배포(Distribution)** 를 누른다.
2. 왼쪽 메뉴 맨 위 **iOS 앱** 옆의 **파란 + (버전 추가)** 를 누른다.
3. 버전 번호에 `1.1.0` 을 넣고 **생성**을 누른다.
4. 왼쪽에 **1.1.0 제출 준비 중**이 생기고 그 페이지가 열린다. 이전 버전의 설명·키워드·스크린샷이 자동으로 복사되어 있다.

## 3. 글 고치기 (1.1.0 페이지)

### 3-1. 이 버전의 새로운 기능 (What's New) — `복사`

```
대규모 업데이트! 이제 매번 다른 이야기로 시작해요.
• 시작 스토리 6종: 단톡 박제, 축사 대참사, 마이크 켜진 새벽, 환승 목격, 새벽 3시의 나, 그리고 클래식. 운명 뽑기도 있어요
• 첫날 고른 선택이 중반 사건과 결말까지 따라와요
• 소문 지수: 판을 키울지, 잠수 타서 식힐지는 내 선택
• 진상 선택: 그 자리에선 통하지만 대가는 나중에 돌아와요
• 92일째 마지막 선택과 두 번째 대답, 새 엔딩 7개(총 67개)
• 다시 할 때는 이미 본 장면을 빠르게 넘길 수 있어요
```

### 3-2. 프로모션 텍스트 (Promotional Text) — `복사`

심사 없이 언제든 바꿀 수 있는 칸이다. 기존 문구의 "엔딩 60개"가 이제 틀리므로 바꾼다.

```
오늘은 어떤 사고로 시작할까? 단톡 박제, 축사 대참사, 환승 목격… 시작 스토리 6종과 엔딩 67개. 진상이 될지 진심이 될지는 내 선택. 썸 타는 그 사람에게 온 톡, 100일 안에 고백까지 가 보세요.
```

### 3-3. 설명 (Description) — 두 군데만 고친다

설명 칸에서 아래 부분을 찾아 바꾼다(나머지는 그대로 둔다).

**① `■ 100일, 엔딩 60개` 문단 전체를 아래로 바꾼다** — `복사`

```
■ 100일, 엔딩 67개
• 고백에 성공하는 해피 엔딩부터 씁쓸한 엔딩, 숨겨진 엔딩까지 67개
• 어떤 답장을 보냈는지에 따라 전혀 다른 결말로 이어져요
• 실패한 순간도 흑역사 앨범에 모여 수집 요소가 돼요
```

**② 바로 그 문단 위에 새 문단을 하나 넣는다** — `복사`

```
■ 매번 다른 시작, 시작 스토리 6종
• 고백 연습을 알바 단톡에 보내 버린 새벽, 축사 중 대형 화면에 뜬 친구의 톡, 방송에 실려 버린 혼잣말…
• 어떤 사고로 시작할지 고르거나 운명 뽑기에 맡겨 보세요
• 소문을 키울지 잠수 탈지, 진상이 될지 진심이 될지는 내 선택이에요
```

### 3-4. 스크린샷

**그대로 둬도 된다.** 이전 버전 스크린샷이 자동으로 들어와 있다.
(나중에 시작 카드 화면 스크린샷을 추가하면 좋다. 스크린샷 교체는 다음 업데이트 때 해도 된다.)

### 3-5. 키워드·지원 URL·마케팅 URL

그대로 둔다.

## 4. 빌드 고르기

1. 1.1.0 페이지를 아래로 내려 **빌드(Build)** 칸에서 **+ 빌드 추가**를 누른다.
2. **1.1.0 (11)** 을 고르고 **완료**.
3. 수출 규정 질문이 나오면 **"표준 암호화 알고리즘만 사용 / 면제"** 쪽으로 답한다.

## 5. 앱 심사 정보 → 메모 (Notes) 바꾸기 — `복사`

첫 실행 흐름에 **시작 카드 화면**이 새로 들어가서, 심사관이 추적 허용(ATT) 창까지 가는 길이 바뀌었다. 메모 칸 내용을 **전부 지우고** 아래로 바꾼다.
연락처·로그인 칸은 그대로 둔다.

```
This is a single-player narrative/story simulation game. All characters, chats, and
"dating" scenarios are pre-written fictional content. There is no real-time matching,
no user accounts, no login, and no messaging between real users. Game progress is stored
only on the device. Please do not classify this as a dating or social-networking app.

What's new in 1.1.0: six selectable opening stories (a "start card" screen during the
intro and before each new run), a hidden "rumor" meter, optional comic "villain" choices
with in-story consequences, and new endings. The "fate draw" card on the start screen
only picks one of the six free opening stories at random; nothing is wagered, bought or
won, so it is not gambling or a loot box. The rumor and villain mechanics are light
satire with no real-world harassment, no user-generated content, and no sharing.

Free-text input ("직접 쓰기" field under the reply buttons in chat scenes): the typed
text is matched on-device to one of the pre-written reply options. The text never
leaves the device; no AI/LLM and no server is used. Only non-content metrics (a usage
count bucket, length bucket, which pre-written option was matched) are logged to
Firebase Analytics, never the text itself.

App Tracking Transparency: on first launch the ATT prompt is intentionally shown right
after the short intro, not at app open. To reach it: tap "시작하기" on the title screen,
tap the lock-screen message card, answer "한다. 올해는 다르다" in the intro chat, then a
start-story sheet opens: tap any story card (for example the top one, "단톡 박제").
Then enter a name or tap "건너뛰기", choose a gender option, and tap "시작하기" on the
character introduction screen (about 7-9 taps, under a minute). A Google consent message
may appear first depending on region. The ATT prompt only appears if Settings > Privacy
& Security > Tracking > "Allow Apps to Request to Track" is ON and the app has not been
asked before (delete and reinstall to see it again).

Ads: Google AdMob (banner, interstitial, optional rewarded ads for refilling hearts and
hints). The app requests a maximum ad content rating of T (Teen) in code, and the same
limit is set in the AdMob console. Rewarded ads are optional; the game can be played
without watching them.

Firebase Analytics receives anonymous gameplay events (e.g. day reached, ending reached);
it does not collect the IDFA, and the player's name, MBTI, and typed text are never sent.

No in-app purchases. No login or account; no demo account is needed.
```

## 6. 출시 방식 고르고 심사 제출

### 6-1. 버전 출시 (App Store Version Release)
**"이 버전을 수동으로 출시 (Manually release this version)"** 를 고른다.
승인 메일이 오면 내가 원하는 때에 출시 버튼을 누르면 된다.

### 6-2. 단계별 출시 (Phased Release) — 권장
**"7일 동안 단계별로 출시"** 를 켠다. 자동 업데이트를 켜 둔 사용자에게 7일에 걸쳐 조금씩 퍼진다.
문제가 생기면 중간에 멈출 수 있다. (App Store 에서 직접 "업데이트"를 누르는 사람은 바로 받는다.)

### 6-3. 연령 등급·개인정보
**손대지 않는다.** 이번 업데이트는 광고·데이터 수집이 그대로이고, 새 내용(소문·진상)도 기존 답("비속어 또는 저속한 유머: 드물게")
안에 들어간다. 도박·모의 도박은 계속 **없음**이다(운명 뽑기는 무료로 시작 스토리를 고르는 것뿐이다).

### 6-4. 제출
1. 오른쪽 위 **저장**.
2. **심사에 추가 (Add for Review)** → **심사에 제출 (Submit for Review)**.
3. 상태가 **심사 대기 중 (Waiting for Review)** 으로 바뀌면 끝. 보통 1~2일 안에 결과 메일이 온다.

## 7. 승인 뒤

1. 메일이 오면 1.1.0 페이지의 **이 버전 출시** 버튼을 누른다.
2. 출시 뒤 하루 정도 지나서 AdMob 수익·Firebase 이벤트가 평소처럼 들어오는지 본다.
3. 거절되면 메일의 사유를 그대로 Claude 에게 붙여 넣는다.

### 자주 막히는 곳
- **빌드 추가 목록이 비어 있음** → 1단계 처리가 아직 안 끝났다. TestFlight 탭에서 1.1.0 (11) 상태를 다시 본다.
- **"새로운 기능" 칸이 없음** → 1.1.0 페이지가 아니라 1.0.0 페이지를 보고 있다. 왼쪽 메뉴에서 **1.1.0 제출 준비 중**을 누른다.
- **저장이 안 됨** → 프로모션 텍스트(170자)·새로운 기능(4000자) 글자 수를 넘었는지 본다. 이 문서의 문구는 모두 기준 안이다.
