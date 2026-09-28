"""캐릭터 라인업 홍보 이미지 생성기.

assets/portraits/<id>.jpg 초상화를 그대로(다시 그리지 않고) 카드에 넣어
앱스토어 스크린샷 앞장 3장과 SNS 링크 미리보기 1장을 만든다.

    python3 tool/store_images/lineup.py            # 전부
    python3 tool/store_images/lineup.py 00a social # 일부만

출력
    docs/store_screenshots/promo/00a_lineup.png, 00b_women.png, 00c_men.png   (1320×2868, 6.9형)
    docs/store_screenshots/promo65/ 같은 이름                                  (1284×2778, 6.5형)
    docs/store_screenshots/social/lineup_1200x630.png                          (카톡·인스타 링크 미리보기)

Chrome 경로와 스크린샷은 make.py 의 find_chrome()/shoot() 를 그대로 쓴다.
글꼴은 네트워크 없이 assets/fonts/Pretendard-*.otf 를 file:// 로 읽는다(400/500/600/700).
"""

import html
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make  # noqa: E402

ROOT = make.ROOT
SHOTS = os.path.join(ROOT, "docs", "store_screenshots")
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
FONTS = os.path.join(ROOT, "assets", "fonts")

APP_NAME = "모쏠 탈출기"
APP_SUB = "100일 연애 시뮬레이션"

# 카드 순서(성별 안에서). 히든 캐릭터는 맨 끝.
WOMEN = ["seoyeon", "jiwoo", "yeeun", "daeun", "sohee", "yuna"]
MEN = ["haneul", "minjae", "jeongwoo", "seunghyun", "geonwoo", "doyun"]


def load_chars():
    with open(os.path.join(ROOT, "assets", "story", "characters.json"), encoding="utf-8") as f:
        return {c["id"]: c for c in json.load(f)}


def font_css():
    faces = []
    for weight, name in ((400, "Regular"), (500, "Medium"), (600, "SemiBold"), (700, "Bold")):
        faces.append(f'@font-face {{ font-family:"PT"; font-weight:{weight}; '
                     f'src:url("file://{FONTS}/Pretendard-{name}.otf") format("opentype"); }}')
    return "\n".join(faces)


def img(cid):
    return f"file://{PORTRAITS}/{cid}.jpg"


def e(s):
    return html.escape(s)


BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html, body { overflow:hidden; }
body { font-family:"PT", "Apple SD Gothic Neo", "Noto Sans CJK KR", sans-serif; word-break:keep-all;
       -webkit-font-smoothing:antialiased; }
.stage { width:1320px; transform-origin:0 0; display:flex; flex-direction:column; position:relative; overflow:hidden; }
.photo { display:block; width:100%; object-fit:cover; object-position:50% 28%; }
.hidden-badge { position:absolute; top:18px; right:18px; padding:8px 18px 9px; border-radius:999px;
                background:rgba(20,10,30,.72); color:#FFD36E; font-weight:700; letter-spacing:.5px;
                border:2px solid rgba(255,211,110,.7); backdrop-filter:blur(6px); }
"""


def page(w, h, inner, css, stage_h=None, bg="#000", base=1320):
    """1320 폭 기준으로 짠 화면을 w×h 로 맞춘다(6.5형은 살짝 줄여 찍는다)."""
    scale = w / base
    stage_h = stage_h or round(h / scale)
    return f"""<!doctype html><html lang="ko"><head><meta charset="utf-8"><style>
{font_css()}
{BASE_CSS}
html, body {{ width:{w}px; height:{h}px; background:{bg}; }}
.stage {{ width:{base}px; height:{stage_h}px; transform:scale({scale:.6f}); }}
{css}
</style></head><body><div class="stage">{inner}</div></body></html>"""


# ---------------------------------------------------------------- 00a 전체 라인업

HERO_CSS = """
.stage { background:
    radial-gradient(900px 700px at 50% 6%, rgba(194,41,90,.55), rgba(194,41,90,0) 70%),
    radial-gradient(700px 600px at 100% 100%, rgba(122,70,200,.35), rgba(0,0,0,0) 70%),
    #1E1433; color:#fff; }
.head { flex:1; display:flex; flex-direction:column; justify-content:center; align-items:center; text-align:center;
        padding:40px 60px 10px; }
.kicker { display:inline-block; font-size:40px; font-weight:600; color:#FFD9E4; letter-spacing:-.5px;
          padding:12px 30px; border:2px solid rgba(255,217,228,.45); border-radius:999px; margin-bottom:40px; }
h1 { font-size:118px; font-weight:700; line-height:1.16; letter-spacing:-4px; white-space:pre-line; }
h1 em { font-style:normal; color:#FF7FA6; }
.sub { margin-top:34px; font-size:50px; font-weight:600; color:#E9DDFF; letter-spacing:-1px; }
.group { padding:0 56px; }
.label { display:flex; align-items:center; gap:18px; margin:0 6px 20px; font-size:38px; font-weight:700;
         color:#fff; letter-spacing:-.5px; }
.label span { font-size:30px; font-weight:500; color:#CDBBF2; }
.label::after { content:""; flex:1; height:2px; background:linear-gradient(90deg, rgba(255,255,255,.35), rgba(255,255,255,0)); }
.grid { display:grid; grid-template-columns:repeat(3, 1fr); gap:24px; }
.card { position:relative; border-radius:34px; overflow:hidden; background:#fff;
        box-shadow:0 18px 44px rgba(0,0,0,.38); }
.card .photo { height:372px; }
.card .meta { padding:16px 22px 20px; display:flex; align-items:baseline; gap:12px; background:#fff; }
.card .name { font-size:42px; font-weight:700; color:#2A1F22; letter-spacing:-1px; }
.card .title { font-size:28px; font-weight:600; color:#C2295A; letter-spacing:-.5px; }
.card .hidden-badge { font-size:24px; }
.gap { height:44px; }
.foot { padding:40px 0 70px; text-align:center; font-size:36px; font-weight:600; color:#CDBBF2; letter-spacing:-.5px; }
.foot b { color:#fff; font-weight:700; }
"""


def hero_card(c):
    badge = '<div class="hidden-badge">히든</div>' if c["hidden"] else ""
    return (f'<div class="card"><img class="photo" src="{img(c["id"])}">{badge}'
            f'<div class="meta"><div class="name">{e(c["name"])}</div><div class="title">{e(c["title"])}</div></div></div>')


def slide_lineup(chars):
    women = "".join(hero_card(chars[i]) for i in WOMEN)
    men = "".join(hero_card(chars[i]) for i in MEN)
    inner = f"""
<div class="head">
  <div class="kicker">당신의 첫 연애 상대는?</div>
  <h1>이 중 한 명과\n<em>100일 뒤</em> 연인이 된다</h1>
  <div class="sub">톡 한 줄로 썸부터 고백까지</div>
</div>
<div class="group"><div class="label">그녀들 <span>여성 캐릭터 6명</span></div><div class="grid">{women}</div></div>
<div class="gap"></div>
<div class="group"><div class="label">그들 <span>남성 캐릭터 6명</span></div><div class="grid">{men}</div></div>
<div class="foot"><b>히든 캐릭터</b>는 어떤 조건에서 나타날까?</div>
"""
    return HERO_CSS, inner, "#1E1433"


# ---------------------------------------------------------------- 00b / 00c 성별 라인업

SIDE_CSS = """
.stage { background:var(--bg); color:var(--head); }
.head { flex:1; display:flex; flex-direction:column; justify-content:center; align-items:center; text-align:center;
        padding:40px 60px 20px; }
h1 { font-size:120px; font-weight:700; line-height:1.16; letter-spacing:-4px; white-space:pre-line; }
.sub { margin-top:30px; font-size:48px; font-weight:600; color:var(--sub); letter-spacing:-1px; }
.grid { display:grid; grid-template-columns:repeat(2, 1fr); gap:34px 30px; padding:0 64px 84px; }
.card { position:relative; border-radius:44px; overflow:hidden; background:#fff;
        box-shadow:0 24px 56px var(--shadow); }
.card .photo { height:500px; }
.card .meta { padding:22px 30px 30px; }
.row { display:flex; align-items:center; gap:14px; }
.name { font-size:54px; font-weight:700; color:#2A1F22; letter-spacing:-1.5px; }
.mbti { font-size:24px; font-weight:700; color:#8A5A67; padding:5px 14px; border:2px solid #EBD3DA; border-radius:999px; letter-spacing:.5px; }
.title { font-size:30px; font-weight:600; color:#C2295A; letter-spacing:-.5px; margin-left:auto; }
.quote { margin-top:14px; font-size:32px; font-weight:600; color:#4A3A3F; letter-spacing:-1px; line-height:1.3;
         white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.card .hidden-badge { font-size:28px; top:22px; right:22px; }
"""

THEME_SIDE = {
    "women": {"--bg": "#C2295A", "--head": "#FFFFFF", "--sub": "#FFD9E4", "--shadow": "rgba(70,0,25,.35)"},
    "men": {"--bg": "#FFF1F4", "--head": "#2A1F22", "--sub": "#8A5A67", "--shadow": "rgba(120,40,70,.18)"},
}


def side_card(c):
    badge = '<div class="hidden-badge">히든 캐릭터</div>' if c["hidden"] else ""
    return (f'<div class="card"><img class="photo" src="{img(c["id"])}">{badge}<div class="meta">'
            f'<div class="row"><div class="name">{e(c["name"])}</div><div class="mbti">{e(c["mbti"])}</div>'
            f'<div class="title">{e(c["title"])}</div></div>'
            f'<div class="quote">“{e(c["tagline"])}”</div></div></div>')


def slide_side(chars, which, headline, sub):
    ids = WOMEN if which == "women" else MEN
    vars_ = ";".join(f"{k}:{v}" for k, v in THEME_SIDE[which].items())
    cards = "".join(side_card(chars[i]) for i in ids)
    inner = f"""<div class="head"><h1>{e(headline)}</h1><div class="sub">{e(sub)}</div></div>
<div class="grid">{cards}</div>"""
    css = SIDE_CSS.replace(".stage { background", f".stage {{ {vars_}; }}\n.stage {{ background", 1)
    return css, inner, THEME_SIDE[which]["--bg"]


# ---------------------------------------------------------------- 소셜 1200×630

SOCIAL_CSS = """
.stage { width:1200px; flex-direction:row; align-items:center; color:#fff;
  background:
    radial-gradient(520px 420px at 12% 20%, rgba(194,41,90,.60), rgba(194,41,90,0) 70%),
    radial-gradient(520px 420px at 100% 100%, rgba(122,70,200,.35), rgba(0,0,0,0) 70%),
    #1E1433; }
.left { width:430px; padding:0 0 0 58px; }
.kicker { font-size:22px; font-weight:600; color:#FFD9E4; letter-spacing:-.3px; }
.app { margin-top:14px; font-size:66px; font-weight:700; letter-spacing:-2.5px; line-height:1.05; }
.appsub { margin-top:10px; font-size:24px; font-weight:600; color:#CDBBF2; letter-spacing:-.5px; }
.hook { margin-top:34px; font-size:36px; font-weight:700; line-height:1.28; letter-spacing:-1.2px; white-space:pre-line; }
.hook em { font-style:normal; color:#FF7FA6; }
.cta { display:inline-block; margin-top:30px; padding:12px 26px; border-radius:999px; background:#C2295A;
       font-size:22px; font-weight:700; letter-spacing:-.3px; box-shadow:0 10px 24px rgba(194,41,90,.45); }
.right { flex:1; padding:0 44px 0 10px; display:flex; flex-direction:column; gap:22px; }
.rowlabel { font-size:18px; font-weight:600; color:#CDBBF2; margin:0 0 8px 2px; letter-spacing:-.2px; }
.strip { display:grid; grid-template-columns:repeat(6, 1fr); gap:10px; }
.mini { position:relative; border-radius:16px; overflow:hidden; background:#fff; box-shadow:0 8px 18px rgba(0,0,0,.35); }
.mini .photo { height:128px; }
.mini .n { padding:5px 0 7px; text-align:center; font-size:19px; font-weight:700; color:#2A1F22; letter-spacing:-.5px; }
.mini .hidden-badge { font-size:13px; top:6px; right:6px; padding:3px 8px 4px; border-width:1.5px; }
"""


def mini(c):
    badge = '<div class="hidden-badge">히든</div>' if c["hidden"] else ""
    return (f'<div class="mini"><img class="photo" src="{img(c["id"])}">{badge}'
            f'<div class="n">{e(c["name"])}</div></div>')


def slide_social(chars):
    inner = f"""
<div class="left">
  <div class="kicker">당신의 첫 연애 상대는?</div>
  <div class="app">{e(APP_NAME)}</div>
  <div class="appsub">{e(APP_SUB)}</div>
  <div class="hook">이 중 한 명과\n<em>100일 뒤</em> 연인이 된다</div>
  <div class="cta">톡 한 줄로 썸부터 고백까지</div>
</div>
<div class="right">
  <div><div class="rowlabel">그녀들</div><div class="strip">{"".join(mini(chars[i]) for i in WOMEN)}</div></div>
  <div><div class="rowlabel">그들</div><div class="strip">{"".join(mini(chars[i]) for i in MEN)}</div></div>
</div>"""
    return SOCIAL_CSS, inner, "#1E1433"


# ---------------------------------------------------------------- 실행

def build(chars):
    return {
        "00a": ("00a_lineup", slide_lineup(chars)),
        "00b": ("00b_women", slide_side(chars, "women", "누가 먼저\n말을 걸어올까", "그녀들과의 100일, 톡 한 줄로 시작돼요")),
        "00c": ("00c_men", slide_side(chars, "men", "오늘 밤,\n누구 톡을 기다릴래?", "그들과의 100일, 고백까지 가 볼까요")),
    }


def shoot_html(doc, out, w, h):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(doc)
        path = f.name
    os.makedirs(os.path.dirname(out), exist_ok=True)
    make.shoot(path, out, w, h)
    os.unlink(path)
    print("만듦", out)


def main(only):
    chars = load_chars()
    for key, (name, (css, inner, bg)) in build(chars).items():
        if only and key not in only:
            continue
        for size, folder in (("6.9", "promo"), ("6.5", "promo65")):
            w, h = make.SIZES[size]
            shoot_html(page(w, h, inner, css, bg=bg), os.path.join(SHOTS, folder, f"{name}.png"), w, h)
    if not only or "social" in only:
        css, inner, bg = slide_social(chars)
        doc = page(1200, 630, inner, css, bg=bg, base=1200)
        shoot_html(doc, os.path.join(SHOTS, "social", "lineup_1200x630.png"), 1200, 630)


if __name__ == "__main__":
    main(set(sys.argv[1:]))
