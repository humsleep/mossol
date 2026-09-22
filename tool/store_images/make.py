"""앱스토어 홍보 이미지(1320×2868) 생성기.

docs/store_screenshots/raw/*.png (6.9형 시뮬레이터 캡처)를 기기 프레임 안에 넣고,
위에 헤드라인·보조 문구를 얹어 docs/store_screenshots/promo/*.png 로 만든다.
HTML 한 장을 만들어 Chrome headless 로 찍는다(추가 설치 없음).

    python3 tool/store_images/make.py
"""

import html
import os
import subprocess
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "docs", "store_screenshots", "raw")
OUT = os.path.join(ROOT, "docs", "store_screenshots", "promo")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1320, 2868

# (출력 이름, 원본, 헤드라인, 보조, 테마)
SLIDES = [
    ("01", "01_cast_f.png", "이 사람들과 100일", "남녀 캐릭터 각 6명, 누구와 이어질까", "pink"),
    ("02", "02_chat.png", "답장, 뭐라고 보내?", "한 줄이 관계를 바꿔요", "paper"),
    ("03", "03_cast_m.png", "설레는 상대는\n내가 골라", "성별 선택 · 양쪽 다 만날 수 있어요", "pink"),
    ("04", "04_mbti.png", "내 MBTI랑\n궁합은?", "궁합에 따라 달라지는 대사와 엔딩", "paper"),
    ("05", "05_call.png", "그 사람의 전화", "받을까, 모른 척할까", "night"),
    ("06", "02b_reply.png", "물올랐다!", "호감과 신뢰가 쌓이는 순간", "paper"),
    ("07", "07_summary.png", "가까워졌다,\n멀어졌다", "내일은 누구에게서 연락이 올까", "pink", 2566),
    ("08", "08_ending.png", "엔딩 60개,\n다 모아 봐", "천생연분 엔딩까지", "paper"),
]

THEMES = {
    # 배경, 헤드라인색, 보조색, 기기 테두리
    "pink": ("#C2295A", "#FFFFFF", "#FFD9E4", "#1B1416"),
    "paper": ("#FFF1F4", "#2A1F22", "#8A5A67", "#1B1416"),
    "night": ("#1E1433", "#FFFFFF", "#CDBBF2", "#000000"),
}

TEMPLATE = """<!doctype html><html lang="ko"><head><meta charset="utf-8">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  body {{ background:{bg}; font-family:"Pretendard", "Apple SD Gothic Neo", sans-serif;
         display:flex; flex-direction:column; align-items:center; word-break:keep-all; }}
  .copy {{ padding:190px 90px 0; text-align:center; }}
  h1 {{ color:{head}; font-size:124px; font-weight:800; line-height:1.18; letter-spacing:-3px; white-space:pre-line; }}
  p  {{ color:{sub}; font-size:54px; font-weight:600; margin-top:36px; letter-spacing:-1px; }}
  .device {{ margin-top:110px; width:1040px; height:2260px; border-radius:150px; background:{frame};
            padding:26px; box-shadow:0 60px 120px rgba(0,0,0,.28); }}
  .device {{ position:relative; }}
  .device img {{ width:100%; height:100%; border-radius:124px; object-fit:cover; object-position:top; display:block; }}
  .mask {{ position:absolute; left:26px; right:26px; bottom:26px; top:calc(26px + {mask_pct}%);
          background:#FFFAF9; border-radius:0 0 124px 124px; }}
</style></head><body>
  <div class="copy"><h1>{headline}</h1><p>{subline}</p></div>
  <div class="device"><img src="file://{img}">{mask}</div>
</body></html>"""


def render(name, src, headline, subline, theme, mask_from=None):
    """mask_from: 원본 픽셀 y 이후를 앱 배경색으로 덮는다(테스트 광고 배너 가리기)."""
    img = os.path.join(RAW, src)
    if not os.path.exists(img):
        print(f"건너뜀 {name}: 원본 없음 {src}")
        return
    bg, head, sub, frame = THEMES[theme]
    mask_pct = 0 if mask_from is None else mask_from / H * (2260 - 52) / 2260 * 100
    mask = '' if mask_from is None else '<div class="mask"></div>'
    page = TEMPLATE.format(W=W, H=H, bg=bg, head=head, sub=sub, frame=frame, mask=mask, mask_pct=f'{mask_pct:.3f}',
                           headline=html.escape(headline), subline=html.escape(subline), img=img)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(page)
        path = f.name
    out = os.path.join(OUT, f"{name}.png")
    profile = tempfile.mkdtemp()
    if os.path.exists(out):
        os.unlink(out)
    # Chrome 은 스크린샷을 쓴 뒤에도 종료되지 않는 경우가 있어, 파일이 생기면 직접 끝낸다.
    proc = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={profile}", "--disable-gpu",
                             "--hide-scrollbars", "--allow-file-access-from-files",
                             "--force-device-scale-factor=1", f"--window-size={W},{H}",
                             "--virtual-time-budget=4000", f"--screenshot={out}", f"file://{path}"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(600):
        if proc.poll() is not None or (os.path.exists(out) and os.path.getsize(out) > 0):
            break
        time.sleep(0.1)
    time.sleep(0.5)
    proc.kill()
    os.unlink(path)
    print("만듦", out)


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])  # 예: python3 make.py 07 08
    for s in SLIDES:
        if not only or s[0] in only:
            render(*s)
