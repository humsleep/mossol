import 'dart:convert';
import 'dart:io';

import 'package:mossol/engine/story_repository.dart';

/// `assets/story/<f>` 를 읽는다. 작가가 채우는 중이라 아직 없는 선택 이벤트 파일
/// ([StoryBundle.optionalEventFiles] — 예: `events_start.json`)은 빈 배열로 본다.
/// 앱의 [StoryBundle.loadFromAssets] 와 같은 규칙이다.
String readStoryFile(String f, {String dir = 'assets/story'}) {
  final file = File('$dir/$f');
  if (!file.existsSync() && StoryBundle.optionalEventFiles.contains(f)) {
    return '[]';
  }
  return file.readAsStringSync();
}

/// 시작 스토리 정의(`starts.json`). 없으면 null(클래식만).
String? readStartsFile({String dir = 'assets/story'}) {
  final file = File('$dir/${StoryBundle.startsFile}');
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// 개편 2 가 더하는 엔딩(docs/overhaul2/01_design.md §5.1). 분량 고정 검사는 이것을 빼고 센다 —
/// 작가가 채우는 동안에도 예전 분량 불변식이 그대로 서 있게. `villain_legend` 는 2라운드(E4)에 더해진다.
/// `m36_waiting`·`m36_letgo` 는 3라운드(F5), `m36_together`·`m36_still` 은 5라운드(H3)에 더해진다.
const overhaul2EndingIds = {
  'influencer',
  'infamous',
  'villain_legend',
  'm36_waiting',
  'm36_letgo',
  // 5라운드(H3): 고백 성공·아무것도 안 함의 good 엔딩.
  'm36_together',
  'm36_still',
};

/// 개편 2 의 의뢰(부업) 행동 장면 접두어(§5.3). `events_action.json` 에 덧붙는다.
const overhaul2HustlePrefix = 'a_hustle_';

/// 개편 2 의 새 이벤트 파일에 든 이벤트 id(파일이 없으면 빈 집합).
Set<String> overhaul2FileEventIds() => {
  for (final f in const ['events_start.json', 'events_freedom.json'])
    for (final e in jsonDecode(readStoryFile(f)) as List)
      (e as Map)['id'] as String,
};
