// 흑역사 출처 찾기(AlbumIndex)와 도장 분류(ShameStamp).
//
// 스토리 데이터의 흑역사 제목 **전부**가 출처를 찾고 8가지 도장 중 하나로 떨어지는지 본다.
// 분포는 출력으로 남긴다 — 한 종류로 쏠리면 낱말 규칙을 손볼 때다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/album_index.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';

StoryBundle _bundle() {
  String read(String f) {
    final file = File('assets/story/$f');
    return file.existsSync() ? file.readAsStringSync() : '[]';
  }

  return StoryBundle.fromJsonStrings(
    config: read('config.json'),
    characters: read('characters.json'),
    events: [for (final f in StoryBundle.eventFiles) read(f)],
    endings: read('endings.json'),
  );
}

void main() {
  late StoryBundle bundle;
  setUpAll(() => bundle = _bundle());

  /// 데이터에 있는 흑역사 제목 전부(중복 제거, 등장 순서).
  List<String> allTitles() {
    final out = <String>{};
    for (final e in bundle.events) {
      for (final c in e.choices) {
        for (final a in [c.effects.album, c.fail.album]) {
          if (a != null) out.add(a);
        }
      }
    }
    return out.toList();
  }

  test('흑역사 제목마다 출처를 찾고 도장이 하나로 정해진다(분포 출력)', () {
    final titles = allTitles();
    expect(titles, isNotEmpty);
    final dist = {for (final k in ShameStamp.kinds) k: <String>[]};
    for (final t in titles) {
      final src = AlbumIndex.find(bundle.events, t);
      expect(src, isNotNull, reason: t);
      final kind = ShameStamp.classify(t, source: src);
      expect(ShameStamp.kinds, contains(kind), reason: t);
      dist[kind]!.add(t);
    }
    // ignore: avoid_print
    print('흑역사 도장 분포(${titles.length}개):');
    for (final e in dist.entries) {
      // ignore: avoid_print
      print(
        '  ${e.key.padRight(10)} ${ShameStamp.label(e.key)} '
        '${e.value.length}',
      );
    }
    // 대체값(어색한 침묵)으로 절반 넘게 떨어지면 규칙이 제 일을 못 하는 것이다.
    expect(dist[ShameStamp.awkward]!.length, lessThan(titles.length ~/ 2));
    // 8종 모두 적어도 한 장은 쓰인다(그림을 넣어 놓고 안 쓰는 도장이 없게).
    for (final k in ShameStamp.kinds) {
      expect(dist[k], isNotEmpty, reason: '$k 도장이 한 번도 안 쓰인다');
    }
  });

  test('대표 사례', () {
    String kind(String t) =>
        ShameStamp.classify(t, source: AlbumIndex.find(bundle.events, t));
    expect(kind('삭제 실패, 읽음 1'), ShameStamp.misfire);
    expect(kind('뒤풀이 드립 폭주'), ShameStamp.drink);
    expect(kind('상하의 둘 다 체크무늬'), ShameStamp.fashion);
    expect(kind('오마카세 한 번에 월세 절반'), ShameStamp.money);
    expect(kind('부상 중에 운동 강행'), ShameStamp.gym);
    expect(kind('92일차 고백 실패'), ShameStamp.confession);
    expect(kind('3년 전 사진 좋아요 알림 발송 완료'), ShameStamp.sns);
    expect(kind('이미 눌러진 층 물어보기'), ShameStamp.awkward);
    // 데이터에 없는 옛 제목도 제목 낱말만으로 분류된다.
    expect(ShameStamp.classify('술자리에서 노래 부름'), ShameStamp.drink);
    expect(ShameStamp.classify('처음 보는 제목'), ShameStamp.awkward);
  });

  test('출처: 실패 흑역사는 failReply, 선택 흑역사는 reply', () {
    final fail = AlbumIndex.find(bundle.events, '92일차 고백 실패')!;
    expect(fail.failed, isTrue);
    expect(fail.event.id, 'm36');
    expect(fail.aftermath, isNot(same(fail.choice.reply)));
    final chose = AlbumIndex.find(bundle.events, '거울 치우기')!;
    expect(chose.failed, isFalse);
    for (final l in [...fail.setup(), ...fail.aftermath, ...chose.aftermath]) {
      expect(l.text.trim(), isNotEmpty);
      expect(l.isWait, isFalse);
    }
    expect(fail.setup(max: 2).length, lessThanOrEqualTo(2));
  });

  test('같은 제목이 남녀 쌍에 있으면 로스터 캐릭터 쪽을 먼저', () {
    final both = [
      for (final e in bundle.events)
        for (final c in e.choices)
          if (c.effects.album == '영화표 두 장으로 준호와 데이트') e,
    ];
    expect(both.length, greaterThanOrEqualTo(2));
    final chars = {for (final e in both) e.character}.whereType<String>();
    for (final ch in chars) {
      final src = AlbumIndex.find(
        bundle.events,
        '영화표 두 장으로 준호와 데이트',
        roster: {ch},
      );
      expect(src!.event.character, ch);
    }
  });

  test('없는 제목은 null', () {
    expect(AlbumIndex.find(bundle.events, '없는 흑역사'), isNull);
    expect(AlbumIndex.find(const <StoryEvent>[], '거울 치우기'), isNull);
  });
}
