"""그림 작업판(ChatGPT 이미지 생성용) HTML 을 만든다.

docs/image_prompts/*.md 를 읽어 캐릭터별 대화 묶음으로 나누고, 프롬프트 복사·저장 이름·완료 체크가 있는
한 장짜리 페이지를 만든다. 초상화는 페이지 안에 넣는다(끌어다 ChatGPT 에 첨부).

    python3 tool/image_studio/build.py   # → build/image-studio.html
"""
import base64
import collections
import json
import os
import re

R = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")) + "/"
HERE = os.path.dirname(os.path.abspath(__file__)) + "/"
OUT = R + "build/image-studio.html"


def parse():
    items = []
    for doc, prefix in [("01_endings", "assets/endings/"), ("02_photos", "assets/photos/"), ("03_scenes_and_more", "")]:
        t = open(R + f"docs/image_prompts/{doc}.md", encoding="utf-8").read()
        parts = re.split(r"^(#{2,4} .*)$", t, flags=re.M)
        for i in range(1, len(parts), 2):
            h, body = parts[i], parts[i + 1]
            m = re.search(r"`([^`]+\.png)`", h)
            cb = re.search(r"```\n(.*?)\n```", body, re.S)
            if h.startswith("## ") or not m or not cb:
                continue
            f = m.group(1)
            path = f if f.startswith("assets/") else prefix + f
            att = re.search(r"portraits/(\w+)\.jpg", body.split("```")[0])
            attach = att.group(1) if att else None
            if not attach and path.startswith("assets/expressions/"):
                attach = path.split("/")[-1].split("_")[0]
            if not attach and "첨부한" in cb.group(1)[:200]:
                att = re.search(r"portraits/(\w+)\.jpg", body)
                attach = att.group(1) if att else None
            title = re.sub(r"^#{2,4}\s*(\d+\.\s*)?", "", h)
            title = re.sub(r"\s*—\s*`[^`]+`", "", title)
            title = re.sub(r"`[^`]+`\s*—\s*", "", title)
            kind = {"01_endings": "엔딩", "02_photos": "사진 메시지"}.get(doc) or {
                "scenes": "행동 배경", "expressions": "표정", "keyart": "홈 키 아트",
                "events": "위기·히든", "stamps": "흑역사 도장"}[path.split("/")[1]]
            items.append(dict(kind=kind, title=title.strip(), path=path, file=path.split("/")[-1],
                              attach=attach, alt="대안" in title, prompt=cb.group(1)))
    return items

items = parse()
chars=json.load(open(R+'assets/story/characters.json'))
names={c['id']:c['name'] for c in chars}
order=['seoyeon','daeun','jiwoo','sohee','yeeun','yuna','jeongwoo','haneul','seunghyun','minjae','geonwoo','doyun']
portraits={c:'data:image/jpeg;base64,'+base64.b64encode(open(R+f'assets/portraits/{c}.jpg','rb').read()).decode() for c in order}
kindrank={'엔딩':0,'사진 메시지':1,'위기·히든':2,'표정':3}
def endrank(p):
    for i,k in enumerate(['_happy','_destiny','_friend','_some','_growth','_bad']):
        if k in p: return i
    return 9
batches=[]
for c in order:
    its=[i for i in items if i['attach']==c]
    its.sort(key=lambda i:(kindrank.get(i['kind'],9),endrank(i['path'])))
    batches.append(dict(title=f"{names[c]} 묶음",who=c,note="초상화를 첨부한 대화에서 이 캐릭터 그림을 모두 만듭니다. 표정 3장은 매번 초상화를 다시 첨부하세요.",items=its))
rest=[i for i in items if not i['attach']]
def chunk(name,its,n,note):
    for k in range(0,len(its),n):
        part=its[k:k+n]
        t=name if len(its)<=n else f"{name} {k//n+1}"
        batches.append(dict(title=t,who=None,note=note,items=part))
plain="첨부 없이 프롬프트만 붙여 넣으면 됩니다."
chunk('첨부 없는 엔딩',[i for i in rest if i['kind']=='엔딩'],10,plain)
chunk('행동 배경',[i for i in rest if i['kind']=='행동 배경'],10,plain+" '대안'은 마음에 드는 쪽 하나만 쓰면 됩니다.")
chunk('사진 메시지',[i for i in rest if i['kind']=='사진 메시지'],10,plain+" 주인공 얼굴이 나오면 수정 문장을 보내세요.")
chunk('위기 장면',[i for i in rest if i['kind']=='위기·히든'],10,plain)
chunk('홈 키 아트',[i for i in rest if i['kind']=='홈 키 아트'],10,plain+" 두 안 중 하나만 쓰면 됩니다.")
chunk('흑역사 도장',[i for i in rest if i['kind']=='흑역사 도장'],10,"투명 배경이 안 나오면 '배경을 투명하게 다시'라고 보내세요.")
assert sum(len(b['items']) for b in batches)==len(items)
for bi,b in enumerate(batches):
    for i in b['items']:
        i['key']=i['path']+('#alt' if i['alt'] else '')
data=json.dumps(dict(batches=batches,portraits=portraits,names=names),ensure_ascii=False).replace('</','<\\/')
html=open(HERE+'template.html',encoding='utf-8').read().replace('/*DATA*/null',data)
os.makedirs(os.path.dirname(OUT),exist_ok=True)
open(OUT,'w',encoding='utf-8').write(html)
print(len(batches),[ (b['title'],len(b['items'])) for b in batches])
