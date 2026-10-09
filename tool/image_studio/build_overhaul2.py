"""개편 2 그림 작업판(ChatGPT 이미지 생성용) HTML 을 만든다.

docs/overhaul2/03_image_prompts.md 의 프롬프트 15개를 읽어, 한 장마다
"번호 · 저장 이름 · [복사] 버튼 · 확인할 것" 이 있는 한 장짜리 페이지를 만든다.
복사되는 프롬프트에는 화풍 규칙이 이미 들어 있어서, 공통 블록을 먼저 붙여 넣을 필요가 없다.
받은 PNG 를 `NN.png`(예: 01.png) 로 art_inbox/ 에 두면 tool/import_overhaul2_art.py 가 나머지를 한다.

    python3 tool/image_studio/build_overhaul2.py   # → docs/overhaul2/art_board.html
"""
import html
import json
import os
import re

R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")) + "/"
DOC = R + "docs/overhaul2/03_image_prompts.md"
OUT = R + "docs/overhaul2/art_board.html"

# 번호 순서 = 만드는 순서. 1~5 는 필수(시작 카드 겸 1일차 장면), 6~15 는 선택(우선순위 순).
ORDER = [
    ("sc_leak_d1", "단톡 박제 — 시작 카드"),
    ("sc_speech_d1", "축사 대참사 — 시작 카드"),
    ("sc_clip_d1", "마이크 켜진 새벽 — 시작 카드"),
    ("sc_swap_d1", "환승 목격 — 시작 카드"),
    ("sc_ghost_d1", "새벽 3시의 나 — 시작 카드"),
    ("sc_leak_d3", "단톡 박제 3일차"),
    ("sc_clip_d3", "마이크 켜진 새벽 3일차"),
    ("sc_speech_d2", "축사 대참사 2일차"),
    ("sc_swap_d2", "환승 목격 2일차"),
    ("influencer", "엔딩 · 인플루언서"),
    ("infamous", "엔딩 · 악명"),
    ("m36_waiting", "엔딩 · 대답은 101일째에"),
    ("m36_letgo", "엔딩 · 내가 정한 끝"),
    ("villain_legend", "엔딩 · 동네 전설"),
    ("sc_ghost_d2", "새벽 3시의 나 2일차"),
]
ENDINGS = {"influencer", "infamous", "m36_waiting", "m36_letgo", "villain_legend"}

# 한 프롬프트만 보내도 되도록 붙이는 화풍 규칙(03 문서 §1 공통 블록과 같은 내용).
STYLE = (
    "Generate one image now, do not ask questions. "
    "Landscape 3:2, 1536x1024, key props inside the central 80%, mid-tone palette, no large white areas. "
    "Clean semi-realistic Korean romance-webtoon digital illustration, thin outlines, soft cel shading, "
    "warm soft lighting, quiet cinematic still-life of everyday Korean spaces like anime background art, "
    "one main light source. The protagonist appears only as hands, back view or silhouette "
    "(medium-length hair covering the ears, plain grey hoodie or shirt, no jewelry, no gender cues). "
    "Nobody's face is ever visible; other people are backs, hands or dark featureless silhouettes. "
    "Screens show only soft glowing shapes, never readable. "
    "No text, letters, numbers, logos, watermark, visible faces, alcohol, real brands or real app interfaces."
)


def parse():
    t = open(DOC, encoding="utf-8").read()
    found = {}
    # "### 2.1 `assets/scenes/sc_leak_d1.webp` — …" 또는 "### 3.5 `influencer` (엔딩…" 다음의 첫 코드 블록.
    for m in re.finditer(r"^### \d+\.\d+ `([^`]+)`[^\n]*\n(.*?)(?=^### |^## |\Z)", t, re.S | re.M):
        key = m.group(1).split("/")[-1].replace(".webp", "")
        body = m.group(2)
        cb = re.search(r"```\n(.*?)\n```", body, re.S)
        if not cb:
            continue
        check = re.search(r"^검수:\s*(.*?)(?:\n\n|\n###|\Z)", body, re.S | re.M)
        found[key] = dict(prompt=cb.group(1).strip(), check=(check.group(1).strip() if check else ""))
    return found


def main():
    found = parse()
    missing = [k for k, _ in ORDER if k not in found]
    if missing:
        raise SystemExit(f"03_image_prompts.md 에서 못 찾은 프롬프트: {missing}")
    cards = []
    for i, (key, title) in enumerate(ORDER, 1):
        folder = "endings" if key in ENDINGS else "scenes"
        cards.append(dict(
            n=f"{i:02d}", key=key, title=title, must=i <= 5,
            dest=f"assets/{folder}/{key}.webp",
            prompt=found[key]["prompt"] + "\n\n" + STYLE,
            check=found[key]["check"],
        ))
    page = TEMPLATE.replace("__CARDS__", json.dumps(cards, ensure_ascii=False))
    open(OUT, "w", encoding="utf-8").write(page)
    print(f"→ {os.path.relpath(OUT, R)} ({len(cards)}장)")


TEMPLATE = """<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>모쏠 그림 작업판</title>
<style>
:root{--bg:#f7f5f2;--card:#fff;--ink:#222;--sub:#666;--line:#e3ded8;--accent:#d6457a;--ok:#2e8b57}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#17161a;--card:#222127;--ink:#eee;--sub:#aaa;--line:#38363d;--accent:#f06e9e;--ok:#5fc48c}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 -apple-system,"Apple SD Gothic Neo",sans-serif}
main{max-width:760px;margin:0 auto;padding:20px 16px 60px}
h1{font-size:22px;margin:0 0 6px}.steps{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px 16px;margin:12px 0 20px}
.steps ol{margin:4px 0;padding-left:20px}.steps code{background:var(--line);padding:1px 5px;border-radius:4px}
.bar{position:sticky;top:0;background:var(--bg);padding:8px 0;z-index:2;font-weight:600}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:12px 0}
.card.done{opacity:.55}.head{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.num{font-size:20px;font-weight:800;color:var(--accent);min-width:34px}.title{font-weight:700;flex:1;min-width:150px}
.tag{font-size:12px;border:1px solid var(--line);border-radius:999px;padding:1px 8px;color:var(--sub)}.tag.must{border-color:var(--accent);color:var(--accent)}
.save{margin:6px 0;color:var(--sub);font-size:14px}.save b{color:var(--ink);font-size:16px}
button{font:inherit;border:0;border-radius:8px;padding:8px 14px;cursor:pointer;background:var(--accent);color:#fff;font-weight:600}
button.ghost{background:transparent;color:var(--sub);border:1px solid var(--line)}
.row{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
details{margin-top:8px;color:var(--sub);font-size:13px}pre{white-space:pre-wrap;word-break:break-word;font-size:12px;background:var(--bg);padding:8px;border-radius:8px}
label{display:flex;gap:6px;align-items:center;color:var(--sub);font-size:14px}
</style></head><body><main>
<h1>모쏠 탈출기 · 그림 작업판</h1>
<div class="steps">
<ol>
<li>ChatGPT 에서 <b>[복사]</b> 를 눌러 붙여 넣고 보낸다. 대화 하나에 8장 정도까지 쓰고, 그 뒤엔 새 대화를 연다.</li>
<li>마음에 들면 PNG 로 받아 이름을 <b>번호.png</b>(예: <code>01.png</code>)로 바꾼다.</li>
<li>저장소의 <code>art_inbox/</code> 폴더에 넣는다. 다 넣고 나서 말하면 앱에 넣는 건 Claude 가 한다.<br>(직접 하려면 <code>python3 tool/import_overhaul2_art.py</code>)</li>
</ol>
<div>필수는 <b>01~05</b>(시작 카드) 다섯 장뿐이다. 06~15 는 없어도 게임이 돌아간다.</div>
</div>
<div class="bar" id="bar"></div>
<div id="list"></div>
</main>
<script>
const CARDS = __CARDS__;
const KEY = "mossol_art_done_v1";
let done = {};
try { done = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) {}
function save(){ try { localStorage.setItem(KEY, JSON.stringify(done)); } catch (e) {} }
function render(){
  const n = CARDS.filter(c => done[c.n]).length;
  document.getElementById("bar").textContent = `완료 ${n} / ${CARDS.length} · 필수 ${CARDS.filter(c=>c.must&&done[c.n]).length} / 5`;
  document.getElementById("list").innerHTML = CARDS.map(c => `
    <div class="card ${done[c.n]?"done":""}">
      <div class="head"><span class="num">${c.n}</span><span class="title">${c.title}</span>
        <span class="tag ${c.must?"must":""}">${c.must?"필수":"선택"}</span></div>
      <div class="save">저장 이름 <b>${c.n}.png</b></div>
      <div class="row"><button data-copy="${c.n}">프롬프트 복사</button>
        <label><input type="checkbox" data-done="${c.n}" ${done[c.n]?"checked":""}> 받음</label></div>
      ${c.check?`<details><summary>다시 뽑아야 할 때</summary>${c.check}<br>얼굴이 보이면: <i>Redraw the same scene, but no face may be visible at all.</i><br>글자가 생기면: <i>Remove every letter, number and logo; keep everything else.</i></details>`:""}
      <details><summary>프롬프트 보기</summary><pre>${c.prompt.replace(/[&<]/g, s => s=="&"?"&amp;":"&lt;")}</pre></details>
    </div>`).join("");
}
document.addEventListener("click", async e => {
  const n = e.target.dataset && e.target.dataset.copy; if (!n) return;
  const c = CARDS.find(x => x.n === n);
  try { await navigator.clipboard.writeText(c.prompt); e.target.textContent = "복사됨 ✓"; }
  catch (err) { const t = document.createElement("textarea"); t.value = c.prompt; document.body.appendChild(t); t.select(); document.execCommand("copy"); t.remove(); e.target.textContent = "복사됨 ✓"; }
  setTimeout(() => e.target.textContent = "프롬프트 복사", 1500);
});
document.addEventListener("change", e => {
  const n = e.target.dataset && e.target.dataset.done; if (!n) return;
  done[n] = e.target.checked; save(); render();
});
render();
</script></body></html>
"""

if __name__ == "__main__":
    main()
