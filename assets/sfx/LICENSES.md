# 효과음 라이선스

이 폴더의 파일은 전부 `tool/make_placeholder_sfx.py` 가 합성한 **자리표시자(placeholder)** 다.
사인파 합성만으로 만들었고 외부 소리를 쓰지 않았다. 저작권을 주장하지 않으며 CC0 1.0 (퍼블릭 도메인
헌정) 으로 둔다. 실제 효과음은 사용자가 CC0 출처(docs/overhaul/05_audio_haptics.md §3) 에서 골라
같은 파일명으로 교체하고, 아래 표의 행을 그 파일의 출처로 바꾼다. **기록 없는 파일은 커밋하지 않는다.**

절대 쓰지 말 것: Apple 시스템 사운드, 카카오톡·LINE·삼성 등 다른 메신저의 알림음과 그 유사 편곡,
"royalty-free" 라고만 적힌 출처 불명 파일(05 §3).

| 파일명 | 출처 URL | 작성자 | 라이선스 | 받은 날짜 | 가공 여부 |
|---|---|---|---|---|---|
| `msg_in.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `call_ring.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 · 3.0s 루프 |
| `call_connect.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `call_end.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `msg_out.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `wait_read.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `choice_ok.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `choice_fail.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `summary.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `ending.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |
| `day_start.wav` | (합성) `tool/make_placeholder_sfx.py` | 모쏠 탈출기 | CC0 1.0 | 2026-09-23 | 원본 생성 |

형식: 전부 WAV 16-bit 44.1kHz mono, 피크 약 -12 dBFS. 코드가 `assets/sfx/<큐 id>.wav` 를
찾으므로 확장자는 `.wav` 로 둔다(`.ogg` 는 iOS 가 재생하지 못한다).

## 교체하는 법

1. 아래 출처에서 소리를 받아 `art_src/sfx_src/<큐 id>.mp3` 로 저장한다(형식은 아무거나 — mp3·m4a·wav·aiff·flac).
2. `python3 tool/import_sfx.py` — 형식 변환·무음 잘라내기·음량 정규화를 한 번에 하고 `assets/sfx/` 에 넣는다.
3. `python3 tool/play_sfx.py` 로 들어 본다.
4. **아래 표의 그 줄을 실제 출처로 고친다.** 이 파일은 앱의 오픈소스 라이선스 화면에
   그대로 나오므로, 안 고치면 표시가 거짓이 된다.

## 쓸 수 있는 출처 (무료 · 상업적 이용 가능)

| 출처 | 라이선스 | 출처 표기 | 메모 |
|---|---|---|---|
| [Kenney](https://kenney.nl/assets?q=audio) | CC0 1.0 | 불필요 | 게임 UI 소리 묶음. 계정 없이 받는다. 가장 안전 |
| [freesound.org](https://freesound.org/search/?f=license:%22Creative+Commons+0%22) | CC0 1.0 | 불필요 | **반드시 License 필터를 "Creative Commons 0" 으로.** 계정 필요 |
| [Pixabay 효과음](https://pixabay.com/sound-effects/) | Pixabay Content License | 불필요 | 상업적 이용 가능. 소리 파일 자체를 따로 재배포하는 것만 금지(앱 내장은 해당 없음) |
| [Mixkit](https://mixkit.co/free-sound-effects/) | Mixkit Free License | 불필요 | 상업적 이용 가능 |
| [OpenGameArt](https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=13) | 항목마다 다름 | 항목마다 다름 | CC0 로 거른 것만 쓴다 |

출처 표기가 필요한 라이선스(freesound 의 CC-BY, Zapsplat 무료 등)도 쓸 수는 있지만, 그때는
아래 표에 작성자와 URL 을 반드시 적어야 하고 그 내용이 앱 라이선스 화면에 노출된다.
표기 의무가 없는 CC0·Pixabay·Mixkit 쪽이 관리가 편하다.
