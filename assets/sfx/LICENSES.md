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

형식: 전부 WAV 16-bit 44.1kHz mono, 피크 약 -12 dBFS. 교체할 때 0.5초 넘는 큐는 05 §3 대로
AAC `.m4a` 로 바꿔도 된다(코드는 `assets/sfx/<큐 id>.wav` 를 찾으므로 `lib/audio/sfx_service.dart`
의 확장자도 같이 고친다). `.ogg` 는 iOS 가 재생하지 못하므로 쓰지 않는다.
