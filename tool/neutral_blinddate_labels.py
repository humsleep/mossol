"""거절·거짓말 회차에서 앱이 "소개팅 상대" 라고 부르지 않게 한다.

`m03` 에서 엄마의 소개팅을 거절하거나 거짓말로 피한 회차에는 소개팅이 없었다.
그런데 `characters.json` 의 `title` 이 `"소개팅 상대"` 라 **프로필 크게 보기
(`profile_view.dart`)·캐스트 소개·홈 사람들 줄** 세 곳이 계속 그렇게 부른다.
이번에 프로필 화면이 생기면서 노출이 늘었다(docs/review/11_claims_audit.md).

`엄마 친구 딸/아들` 은 세 갈래 어디서나 사실이다 — 두 집 어머니가 아는 사이라는
전제는 `m_brief` 가 이미 깔아 둔다("엄마들이 같은 미용실"). 직업은 `tagline`
(`바빠도 답장은 칼같은 변호사`)이 이미 말하므로 겹치지 않는다.

`d_twist_04` 제목도 같은 이유로 바꾼다 — 본문은 소개팅을 한 줄도 언급하지 않고,
호감 23 이상·45일차 이후라 어느 갈래에서도 나올 수 있다.

다시 돌려도 안전하다.
"""

from __future__ import annotations

import story_io

TITLES = {"jiwoo": "엄마 친구 딸", "seunghyun": "엄마 친구 아들"}
OLD_TITLE = "소개팅 상대"

EVENT_TITLES = {
    "d_twist_04": ("소개팅 상대의 정체", "상대편 변호사"),
    "d_twist_04_m": ("소개팅 상대의 정체", "진료실 문이 열렸다"),
}


def main() -> None:
    chars = story_io.load("characters.json")
    n = 0
    for c in chars:
        if c.get("id") in TITLES:
            want = TITLES[c["id"]]
            if c.get("title") == want:
                continue
            if c.get("title") != OLD_TITLE:
                raise SystemExit(f"{c['id']}: title 이 {c.get('title')!r} — 예상과 다르다")
            c["title"] = want
            n += 1
            print(f"  characters {c['id']}: {OLD_TITLE} -> {want}")
    story_io.save("characters.json", chars)

    daily = story_io.load("events_daily.json")
    for e in daily:
        spec = EVENT_TITLES.get(e.get("id"))
        if not spec:
            continue
        old, new = spec
        if e.get("title") == new:
            continue
        if e.get("title") != old:
            raise SystemExit(f"{e['id']}: title 이 {e.get('title')!r} — 예상과 다르다")
        e["title"] = new
        n += 1
        print(f"  {e['id']}: {old} -> {new}")
    story_io.save("events_daily.json", daily)
    print(f"바꾼 곳 {n}")


if __name__ == "__main__":
    main()
