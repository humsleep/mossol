# 신규 캐릭터 집필 산출물 (병합 대기)

캐릭터 작가는 자기 루트를 `assets/story/route_<id>.json` 에 직접 쓰고, 공용 파일(endings.json, signals.json)에
들어갈 부분은 여기에 따로 둔다. 코디네이터가 한 번에 병합한다.

- `<id>_endings.json` : 엔딩 3개 배열 (endings.json 항목과 같은 형식, hint 필수)
- `<id>_signals.json` : signals.json 의 캐릭터 항목 하나 ({"<id>": {...}} 형식, 기존 항목과 같은 구조)
- `<id>_order.json`   : route_order_test 에 추가할 선후 관계 [["뒤 id","앞 id"], ...] 와 순서 관계
