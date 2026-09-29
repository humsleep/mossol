#!/usr/bin/env python3
"""스티커(`Line.sticker`) 배치를 assets/story/*.json 에 적용한다 — 개편 4단계 후속.

06_scene_plan.md §2.2·§5 의 배치표를 코드로 옮긴 것이다. 손으로 87곳을 고치는 대신
표 하나만 고치고 다시 돌리면 되게 했다(작가가 나중에 늘릴 때도 같다).

규칙(검증기가 아니라 이 스크립트가 지키는 것):
  * 이벤트당 스티커 1개.
  * `who: "them"` 줄에만.
  * 스티커의 캐릭터 == 그 줄의 화자(줄에 `name` 이 있으면 그 이름, 없으면 이벤트 `character`).
  * `photo` 가 붙은 줄에는 안 붙인다(창이 이미 찼다).
  * `reply`/`critReply`/`failReply` 의 문자열 항목은 스티커를 못 다니까 붙이는 자리만
    `{"who": "them", "text": …}` 객체로 바꾸고, 나머지 항목은 건드리지 않는다.

JSON 은 `json.dumps(..., ensure_ascii=False, indent=1)` 로 원본과 바이트가 같다(확인 완료).
`sticker` 키는 각 줄의 맨 뒤에 붙는다 — models.dart `Line` 의 필드 순서와 같다.

사용법:  python3 tool/add_stickers.py [--check]
        --check 는 파일을 쓰지 않고 검증만 한다.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / "assets" / "story"

# 캐릭터 id → 대사 줄의 `name` 에 쓰이는 이름(characters.json 과 같다).
CHAR_NAME = {
    "seoyeon": "서연",
    "haneul": "하늘",
    "jiwoo": "지우",
    "minjae": "민재",
    "yeeun": "예은",
    "doyun": "도윤",
    "jeongwoo": "정우",
    "daeun": "다은",
    "seunghyun": "승현",
    "sohee": "소희",
    "geonwoo": "건우",
    "yuna": "유나",
}

EMOTIONS = ("joy", "sulk", "shy", "surprise")
EXTRAS = ("daeun_blank", "sohee_call", "jeongwoo_haha", "seunghyun_sure")

# ── 배치표 ────────────────────────────────────────────────────────────────────
# (이벤트 id, 위치, 그 줄의 글 시작, 스티커 id)
#   위치 = ("lines", i) | ("choices", 선택지 index, "reply"|"critReply"|"failReply", i)
#   "그 줄의 글 시작" 은 오타 방지용 — 안 맞으면 스크립트가 멈춘다.
PLACEMENTS: list[tuple[str, tuple, str, str]] = [
    # ── 서연 (7) ─────────────────────────────────────────────────────────────
    ("seoyeon_r00", ("choices", 0, "reply", 0), "ㅋㅋ 역시 맞네", "seoyeon_joy"),
    ("seoyeon_r02", ("choices", 1, "critReply", 0), "ㅋㅋㅋ 너 이런 애였어?", "seoyeon_joy"),
    ("seoyeon_r04", ("choices", 1, "critReply", 0), "…서연아?", "seoyeon_surprise"),
    ("seoyeon_r09", ("choices", 0, "critReply", 0), "…", "seoyeon_shy"),
    ("seoyeon_r11", ("choices", 2, "reply", 0), "…또 선배네", "seoyeon_sulk"),
    ("mo_seoyeon_seen_you", ("choices", 1, "failReply", 0), "뭔 소리야. 선배로서", "seoyeon_sulk"),
    ("mo_seoyeon_photo_night", ("choices", 2, "reply", 1), "…아 이거 말하지 말걸", "seoyeon_shy"),
    # ── 하늘 (7) ─────────────────────────────────────────────────────────────
    ("haneul_r00", ("choices", 1, "reply", 0), "ㅋㅋㅋ 첫날부터 뻔뻔하네", "haneul_joy"),
    ("haneul_r03", ("choices", 1, "reply", 1), "…됐어. 다음부턴 주문", "haneul_sulk"),
    ("haneul_r07", ("choices", 0, "reply", 0), "34?????", "haneul_surprise"),
    ("haneul_r09", ("choices", 1, "critReply", 1), "…아 데이트라고 해 버렸네", "haneul_shy"),
    ("haneul_r15", ("choices", 0, "critReply", 2), "…그게 좀 싫다", "haneul_sulk"),
    ("mo_haneul_photo_sandwich", ("choices", 0, "reply", 0), "ㅋㅋㅋㅋ 진짜 오네", "haneul_joy"),
    ("mo_haneul_preview_manager", ("choices", 0, "reply", 0), "…아 몰라 ㅋㅋㅋ", "haneul_shy"),
    # ── 지우 (8) ─────────────────────────────────────────────────────────────
    ("m11", ("choices", 0, "reply", 0), "벌써요? ㅋㅋ 저 아직 지하철인데", "jiwoo_surprise"),
    ("jiwoo_r02", ("choices", 1, "reply", 1), "…보통 여기서 다들 한 번 멈칫", "jiwoo_sulk"),
    ("jiwoo_r05", ("choices", 1, "critReply", 1), "…오늘 약간 설레도 되는 거죠?", "jiwoo_shy"),
    ("jiwoo_r09", ("choices", 1, "critReply", 0), "…", "jiwoo_shy"),
    ("jiwoo_r12", ("choices", 1, "reply", 0), "ㅋㅋㅋㅋ 역시", "jiwoo_joy"),
    ("jiwoo_r15", ("choices", 2, "reply", 0), "…진짜 다요?", "jiwoo_surprise"),
    ("mo_jiwoo_photo_dinner", ("choices", 2, "critReply", 0), "ㅋㅋㅋ 사무실에서 혼자 웃었어요", "jiwoo_joy"),
    ("mo_jiwoo_preview_lookalike", ("choices", 1, "reply", 0), "…질문이 유도신문이네요", "jiwoo_sulk"),
    # ── 민재 (7) ─────────────────────────────────────────────────────────────
    ("m24", ("choices", 0, "reply", 0), "ㄹㅇ? 진짜 나와?", "minjae_surprise"),
    ("minjae_r00", ("choices", 1, "reply", 0), "ㅋㅋㅋㅋㅋ 아 이 짤 뭔데 저장함", "minjae_joy"),
    ("minjae_r01", ("choices", 2, "reply", 1), "아 몰라 헤드셋 볼륨 줄임", "minjae_shy"),
    ("minjae_r04", ("choices", 1, "critReply", 0), "헐", "minjae_surprise"),
    ("minjae_r13", ("choices", 2, "reply", 1), "내가 알던 게 어디까지 너야?", "minjae_sulk"),
    ("mo_minjae_call_offgame", ("choices", 2, "reply", 1), "…다행이다. 진짜 다행", "minjae_joy"),
    ("mo_minjae_photo_shadow", ("choices", 0, "reply", 1), "…ㅋㅋ 아 이거 좀 떨린다", "minjae_shy"),
    # ── 예은 (8) ─────────────────────────────────────────────────────────────
    ("yeeun_r00", ("choices", 0, "reply", 0), "헐 진짜?? ㅋㅋㅋ 다행이다", "yeeun_surprise"),
    ("yeeun_r01", ("choices", 1, "critReply", 0), "ㅋㅋㅋㅋㅋ 아 배 아파", "yeeun_joy"),
    ("yeeun_r03", ("choices", 0, "reply", 1), "그 얘기 들으려던 건 아니었는데", "yeeun_sulk"),
    ("yeeun_r04", ("choices", 2, "reply", 0), "6학년 3반!!", "yeeun_joy"),
    ("yeeun_r06", ("choices", 0, "reply", 1), "완전 오글거리는 내용이었어", "yeeun_shy"),
    ("mo_yeeun_photo_snackbar", ("choices", 2, "reply", 1), "우리 맨날 같이 갔는데", "yeeun_sulk"),
    ("mo_yeeun_preview_dream", ("choices", 1, "reply", 0), "…야", "yeeun_surprise"),
    ("mo_yeeun_call_letter", ("choices", 1, "reply", 1), "여기까지만. 나머지는 얼굴 보고", "yeeun_shy"),
    # ── 도윤 (7) ─────────────────────────────────────────────────────────────
    ("doyun_r04", ("choices", 2, "critReply", 0), "…연애요?", "doyun_surprise"),
    ("doyun_r06", ("choices", 1, "reply", 1), "샐러드는 입가에 양념 안 남아요", "doyun_sulk"),
    ("doyun_r09", ("choices", 2, "reply", 1), "아 이거 생각보다 심박수 올라가네", "doyun_shy"),
    ("doyun_r14", ("choices", 1, "reply", 0), "안 돼요", "doyun_sulk"),
    ("doyun_r15", ("choices", 0, "reply", 0), "됐어요!! 봤죠?", "doyun_joy"),
    ("mo_doyun_photo_run", ("choices", 0, "reply", 1), "…진짜 나왔네요", "doyun_surprise"),
    ("mo_doyun_preview_absent", ("choices", 2, "reply", 0), "…못 들은 걸로 해요", "doyun_shy"),
    # ── 정우 (7) ─────────────────────────────────────────────────────────────
    ("jeongwoo_r00", ("choices", 1, "reply", 0), "…그래?", "jeongwoo_surprise"),
    ("jeongwoo_r03", ("lines", 5), "취소가 안 되네. 하하.", "jeongwoo_haha"),
    ("jeongwoo_r08", ("choices", 1, "critReply", 0), "…신경 쓰였어.", "jeongwoo_sulk"),
    ("jeongwoo_r10", ("lines", 2), "ㅋㅋ", "jeongwoo_joy"),
    ("jeongwoo_r15", ("choices", 1, "reply", 0), "…기대라니.", "jeongwoo_shy"),
    ("mo_jeongwoo_preview_cancel", ("choices", 1, "critReply", 2), "이건 취소 못 하겠다. 하하.", "jeongwoo_shy"),
    ("mo_jeongwoo_call_iron", ("choices", 1, "critReply", 1), "이상하다. 오늘은 하나도 안 무거웠어.", "jeongwoo_joy"),
    # ── 다은 (7) ─────────────────────────────────────────────────────────────
    ("daeun_r00", ("choices", 0, "reply", 0), "네.", "daeun_blank"),
    ("daeun_r02", ("choices", 1, "reply", 0), "…정산부터 해요.", "daeun_sulk"),
    ("daeun_r06", ("choices", 1, "reply", 0), "…봤어요?", "daeun_surprise"),
    ("daeun_r07", ("choices", 0, "reply", 2), "…이제 말 놔도 돼요?", "daeun_shy"),
    ("daeun_r15", ("choices", 0, "reply", 0), "응. 나 볼 때만.", "daeun_joy"),
    ("mo_daeun_photo_receipt", ("choices", 0, "reply", 0), "…그거 좀 웃기네요.", "daeun_joy"),
    ("mo_daeun_call_pencil", ("choices", 2, "reply", 1), "어떻게 알았어.", "daeun_surprise"),
    # ── 소희 (7) ─────────────────────────────────────────────────────────────
    ("m24_f", ("choices", 0, "reply", 0), "ㅋㅋㅋㅋ 이거지", "sohee_joy"),
    ("sohee_r01", ("lines", 1), "드래곤 ㄱㄱ!! 탑 빠져!", "sohee_call"),
    ("sohee_r06", ("lines", 1), "ㅋㅋ 목 나감. 샷콜 너무 해서", "sohee_sulk"),
    ("sohee_r07", ("choices", 2, "reply", 0), "…", "sohee_shy"),
    ("sohee_r15", ("choices", 2, "critReply", 0), "…야 대기실에서 웃었다", "sohee_joy"),
    ("mo_sohee_photo_mic", ("choices", 2, "reply", 0), "…어떻게 알았어? 진짜 40번째 씀", "sohee_surprise"),
    ("mo_sohee_preview_tutorial", ("choices", 1, "reply", 0), "야야야 ㅋㅋㅋㅋ 그거 지워", "sohee_surprise"),
    # ── 승현 (8) ─────────────────────────────────────────────────────────────
    ("m11_m", ("choices", 1, "reply", 0), "…다행이다. 말로 들으니까 더 좋네요.", "seunghyun_joy"),
    ("seunghyun_r00", ("choices", 0, "reply", 1), "아, 이건 속으로 할 말이었는데", "seunghyun_shy"),
    ("seunghyun_r06", ("choices", 2, "reply", 0), "…물어보는 게 저한텐 중요해서요.", "seunghyun_sulk"),
    ("seunghyun_r07", ("choices", 1, "reply", 0), "…진짜요? 이 시간에?", "seunghyun_surprise"),
    ("seunghyun_r13", ("choices", 2, "reply", 0), "떠보신 거면, 확실하게 말할게요. 좋아해요.", "seunghyun_sure"),
    ("seunghyun_r15", ("choices", 1, "critReply", 0), "…방금 심장 소리 들렸죠.", "seunghyun_shy"),
    ("mo_seunghyun_photo_kitten", ("choices", 1, "reply", 1), "맞아요. 두 단계쯤 올라가 있어요.", "seunghyun_joy"),
    ("mo_seunghyun_call_surgery", ("choices", 2, "reply", 0), "…기다렸다고요?", "seunghyun_surprise"),
    # ── 건우 (7) ─────────────────────────────────────────────────────────────
    ("geonwoo_r00", ("choices", 0, "reply", 0), "ㅋㅋ 아 그건 반칙이지", "geonwoo_joy"),
    ("geonwoo_r01", ("choices", 1, "reply", 0), "…어떻게 알았어?", "geonwoo_surprise"),
    ("geonwoo_r07", ("choices", 0, "reply", 0), "…나 질투하는 거 티 나냐?", "geonwoo_shy"),
    ("geonwoo_r09", ("choices", 2, "reply", 1), "ㅋㅋ 괜히 말했다", "geonwoo_sulk"),
    ("mo_geonwoo_preview_milk", ("choices", 3, "reply", 1), "재밌는 줄 알았는데", "geonwoo_sulk"),
    ("mo_geonwoo_photo_note", ("choices", 2, "reply", 1), "ㅋㅋ 농담이지?", "geonwoo_surprise"),
    ("mo_geonwoo_call_classroom", ("choices", 3, "reply", 0), "ㅋㅋ 들켰다", "geonwoo_joy"),
    # ── 유나 (7) ─────────────────────────────────────────────────────────────
    ("yuna_r00", ("choices", 0, "reply", 0), "좋아요!! 체험은 무료", "yuna_joy"),
    ("yuna_r03", ("choices", 1, "reply", 1), "그럼 다음부턴 목례로 할게요", "yuna_sulk"),
    ("yuna_r08", ("choices", 0, "reply", 1), "…아 반말 하니까 좀 떨린다", "yuna_shy"),
    ("yuna_r09", ("choices", 2, "reply", 0), "…봤어?", "yuna_surprise"),
    ("yuna_r15", ("choices", 0, "reply", 0), "됐다!! 봤지?", "yuna_joy"),
    ("mo_yuna_photo_tteok", ("choices", 0, "critReply", 1), "…진짜 뛰어왔네요 ㅋㅋ", "yuna_surprise"),
    ("mo_yuna_preview_mood", ("choices", 2, "critReply", 0), "…아 반칙", "yuna_shy"),
]


def sticker_char(sticker: str) -> str:
    """스티커 id 의 캐릭터. models.dart `Sticker.characterOf` 와 같은 규약."""
    if sticker in EXTRAS:
        return sticker.rsplit("_", 1)[0]
    head, _, tail = sticker.rpartition("_")
    if not head or tail not in EMOTIONS:
        raise SystemExit(f"화이트리스트 밖의 스티커 id: {sticker}")
    return head


def fail(msg: str) -> None:
    raise SystemExit(f"[중단] {msg}")


def load_events() -> tuple[dict, dict]:
    """{이벤트 id: 이벤트}, {파일명: 원본 리스트}"""
    by_id: dict[str, dict] = {}
    files: dict[str, list] = {}
    for path in sorted(STORY.glob("*.json")):
        if path.name in ("characters.json", "config.json", "signals.json", "endings.json"):
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        files[path.name] = data
        for event in data:
            if event["id"] in by_id:
                fail(f"이벤트 id 중복: {event['id']}")
            by_id[event["id"]] = event
    return by_id, files


def locate(event: dict, where: tuple):
    """그 줄을 읽고 쓰는 (getter, setter, 줄 수).

    `reply`/`critReply`/`failReply` 는 리스트가 아니라 **값 하나**일 수도 있다
    (models.dart `_replyLines` 가 리스트가 아니면 한 줄로 감싼다). 그 경우
    index 0 만 유효하고, 고칠 때도 리스트로 바꾸지 않고 그 자리에 그대로 쓴다.
    """
    if where[0] == "lines":
        lines, i = event["lines"], where[1]
        return (lambda: lines[i]), (lambda v: lines.__setitem__(i, v)), len(lines)

    _, ci, key, ri = where
    choices = event.get("choices") or []
    if ci >= len(choices):
        fail(f"{event['id']}: choices[{ci}] 가 없다(선택지 {len(choices)}개)")
    choice = choices[ci]
    if key not in choice:
        fail(f"{event['id']}: choices[{ci}].{key} 가 없다")
    entries = choice[key]
    if isinstance(entries, list):
        return (
            (lambda: entries[ri]),
            (lambda v: entries.__setitem__(ri, v)),
            len(entries),
        )
    return (lambda: entries), (lambda v: choice.__setitem__(key, v)), 1


def main() -> int:
    check_only = "--check" in sys.argv
    by_id, files = load_events()

    seen_events: set[str] = set()
    per_char: Counter[str] = Counter()
    per_sticker: Counter[str] = Counter()
    touched: set[str] = set()

    for event_id, where, expect, sticker in PLACEMENTS:
        if event_id in seen_events:
            fail(f"이벤트당 스티커는 1개: {event_id}")
        seen_events.add(event_id)

        event = by_id.get(event_id)
        if event is None:
            fail(f"없는 이벤트: {event_id}")

        char = sticker_char(sticker)
        if char not in CHAR_NAME:
            fail(f"없는 캐릭터: {sticker}")

        get, put, count = locate(event, where)
        idx = where[-1]
        if idx >= count:
            fail(f"{event_id} {where}: 줄이 {count}개뿐")
        entry = get()

        if isinstance(entry, str):
            who, text, name, has_photo, has_sticker = "them", entry, None, False, False
        else:
            who = entry.get("who", "them")
            text = entry.get("text", "")
            name = entry.get("name")
            has_photo = entry.get("photo") is not None
            has_sticker = entry.get("sticker") is not None

        if who != "them":
            fail(f"{event_id} {where}: who={who} — them 줄에만 붙인다")
        if has_photo:
            fail(f"{event_id} {where}: 사진이 붙은 줄")
        if has_sticker and entry.get("sticker") != sticker:
            fail(f"{event_id} {where}: 다른 스티커가 이미 있다 ({entry['sticker']})")
        if not text.startswith(expect):
            fail(f"{event_id} {where}: 글이 다르다\n  기대: {expect!r}\n  실제: {text!r}")

        # 화자 검증 — 이름이 있으면 그 이름이, 없으면 이벤트 캐릭터가 스티커 주인이어야 한다.
        speaker = name if name else CHAR_NAME.get(event.get("character") or "")
        if speaker != CHAR_NAME[char]:
            fail(
                f"{event_id} {where}: 화자가 {speaker!r} 인데 스티커는 {sticker} "
                f"({CHAR_NAME[char]}) — 스티커는 말한 사람 것만 붙인다"
            )

        if isinstance(entry, str):
            put({"who": "them", "text": entry, "sticker": sticker})
        else:
            entry["sticker"] = sticker  # dict 맨 뒤 = Line 필드 순서와 같다

        per_char[char] += 1
        per_sticker[sticker] += 1

    # 52개 id 전수 사용 확인.
    expected_ids = {f"{c}_{e}" for c in CHAR_NAME for e in EMOTIONS} | set(EXTRAS)
    unused = sorted(expected_ids - set(per_sticker))
    if unused:
        fail(f"한 번도 안 쓰인 스티커 {len(unused)}개: {', '.join(unused)}")

    for name, data in files.items():
        out = json.dumps(data, ensure_ascii=False, indent=1)
        path = STORY / name
        if path.read_text(encoding="utf-8") != out:
            touched.add(name)
            if not check_only:
                path.write_text(out, encoding="utf-8")

    print(f"배치 {len(PLACEMENTS)}개 · 스티커 id {len(per_sticker)}/52 · 파일 {len(touched)}개")
    print("\n캐릭터별")
    for char in CHAR_NAME:
        row = " ".join(
            f"{e}={per_sticker.get(f'{char}_{e}', 0)}" for e in EMOTIONS
        )
        extra = [x for x in EXTRAS if sticker_char(x) == char]
        if extra:
            row += " " + " ".join(f"{x.split('_', 1)[1]}={per_sticker.get(x, 0)}" for x in extra)
        print(f"  {char:<10} {per_char[char]:>2}   {row}")
    print("\n감정별")
    for e in EMOTIONS:
        print(f"  {e:<9} {sum(v for k, v in per_sticker.items() if k.endswith('_' + e) and k not in EXTRAS)}")
    print(f"  5번째     {sum(per_sticker[x] for x in EXTRAS)}")
    if check_only:
        print("\n--check: 파일은 쓰지 않았다. 바뀔 파일:", ", ".join(sorted(touched)) or "없음")
    else:
        print("\n쓴 파일:", ", ".join(sorted(touched)) or "없음")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
