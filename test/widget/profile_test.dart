/// 채팅 아바타 → 전체 화면 프로필(docs/DESIGN_SYSTEM.md §2.15).
///
/// "진짜 메신저처럼 상대 사진을 누르면 크게 본다"(유저 요청 2026-09-26). 여기서 고정하는 것:
/// ① 캐스트 아바타는 눌리고 초상화가 Hero 로 커진다,
/// ② 화면에 오르는 값은 플레이어가 이미 다른 화면에서 본 것뿐이다(스포일러 금지),
/// ③ 히든 미해금·`모르는 번호`·캐스트 밖 조연은 아예 열리지 않는다,
/// ④ 탭·아래로 쓸기·`닫기` 로 닫힌다,
/// ⑤ 320×568 · 글자 1.3배에서 넘치지 않고 탭 타깃·대비를 지킨다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/portraits.dart';
import 'package:mossol/ui/profile_view.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';
import 'portrait_helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11, preference: Preference.female);
  });

  /// 서연(캐스트) · 모르는 번호 · 엄마(캐스트 밖 조연)가 한 화면에 나오는 단톡.
  /// 세 가지 아바타를 한 번에 볼 수 있다.
  StoryEvent groupEvent() => StoryEvent.fromJson({
    'id': 't_profile',
    'layer': 'daily',
    'character': 'seoyeon',
    'title': '단톡',
    'lines': [
      {'who': 'them', 'text': '다들 뭐 해'},
      {'who': 'them', 'name': '모르는 번호', 'text': '안녕하세요'},
      {'who': 'them', 'name': '엄마', 'text': '밥은 먹었니'},
    ],
    'choices': [
      {'text': 'x', 'reply': 'ㅇㅇ'},
    ],
  });

  Future<void> showGroup(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    final ev = groupEvent();
    c.current = ev;
    c.revealed = ev.lines.length;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c), mode: mode));
    await tester.pump();
  }

  /// [name] 의 말풍선에 달린 아바타.
  Finder avatarOf(String name) => find.descendant(
    of: find.ancestor(of: findText(name), matching: find.byType(ChatBubble)),
    matching: find.byType(CharacterAvatar),
  );

  CharacterDef seoyeon() =>
      c.bundle.characters.firstWhere((ch) => ch.id == 'seoyeon');

  testWidgets('캐스트 아바타를 누르면 초상화가 Hero 로 커지고 아는 것만 뜬다', (tester) async {
    usePortraits();
    c.state!.rel('seoyeon').affection = 42;
    await showGroup(tester);
    await settleImages(tester);

    final ch = seoyeon();
    expect(find.byType(CharacterProfileView), findsNothing);
    await tester.tap(avatarOf(ch.name).first);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterProfileView), findsOneWidget);
    // 큰 초상화 한 장. 작은 아바타와 같은 Hero 태그로 날아온다.
    final big = tester.widget<CharacterAvatar>(
      find.descendant(
        of: find.byType(CharacterProfileView),
        matching: find.byType(CharacterAvatar),
      ),
    );
    expect(big.size, AppSize.avatarHero);
    expect(big.characterId, ch.id);
    expect(
      find.descendant(
        of: find.byType(CharacterProfileView),
        matching: find.byType(Hero),
      ),
      findsOneWidget,
    );

    // 캐스트 소개(§2.9)·홈 사람들 줄(§2.10)이 이미 보여 준 것들.
    expect(
      find.descendant(
        of: find.byType(CharacterProfileView),
        matching: findText(ch.name),
      ),
      findsOneWidget,
    );
    expect(findText(ch.displayTitle), findsOneWidget);
    expect(findText(ch.tagline), findsOneWidget);
    expect(findText('♥42'), findsOneWidget);
    if (ch.mbti case final m?) expect(findText(m), findsOneWidget);
    // 화면 어디에도 없는 값(취향·지뢰)은 여기서도 내지 않는다.
    for (final like in ch.likes) {
      expect(findText(like), findsNothing, reason: '취향은 아직 모르는 정보다');
    }
    for (final mine in ch.mines) {
      expect(findText(mine), findsNothing, reason: '지뢰는 아직 모르는 정보다');
    }
  });

  testWidgets('MBTI 를 알려 줬으면 궁합 줄까지, 아니면 궁합 줄은 없다', (tester) async {
    usePortraits();
    await showGroup(tester);
    await tester.tap(avatarOf(seoyeon().name).first);
    await tester.pumpAndSettle();
    expect(find.byType(CompatRow), findsNothing, reason: '내 MBTI 를 모른다');
    await tester.tap(find.byType(CharacterProfileView));
    await tester.pumpAndSettle();

    await c.setPlayerMbti('INFP');
    await c.newGame(seed: 11, preference: Preference.female);
    await showGroup(tester);
    await tester.tap(avatarOf(seoyeon().name).first);
    await tester.pumpAndSettle();
    expect(
      find.byType(CompatRow),
      seoyeon().mbti == null ? findsNothing : findsOneWidget,
    );
  });

  testWidgets('모르는 번호 · 캐스트 밖 조연은 열리지 않는다(스포일러 · 빈 화면 방지)', (tester) async {
    usePortraits();
    await showGroup(tester);

    for (final name in ['모르는 번호', '엄마']) {
      await tester.tap(avatarOf(name).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(CharacterProfileView),
        findsNothing,
        reason: '$name 은 열 것이 없다',
      );
    }
  });

  testWidgets('히든은 호감이 생기기 전까지 열리지 않는다', (tester) async {
    usePortraits();
    final hidden = c.bundle.characters.firstWhere(
      (ch) => ch.hidden && ch.gender == Preference.female,
    );
    final ev = StoryEvent.fromJson({
      'id': 't_hidden',
      'layer': 'hidden',
      'character': hidden.id,
      'title': '히든',
      'lines': [
        {'who': 'them', 'text': '누구게'},
      ],
      'choices': [
        {'text': 'x', 'reply': 'ㅇㅇ'},
      ],
    });
    Future<void> show() async {
      c.current = ev;
      c.revealed = ev.lines.length;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
    }

    expect(c.state!.affectionOf(hidden.id), 0);
    await show();
    await tester.tap(avatarOf(hidden.name).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsNothing);

    // 호감이 생기면(= 만났으면) 홈 사람들 줄과 같은 규칙으로 풀린다.
    c.state!.rel(hidden.id).affection = 3;
    await show();
    await tester.tap(avatarOf(hidden.name).first);
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsOneWidget);
    expect(findText(hidden.displayTitle), findsOneWidget);
  });

  testWidgets('초상화가 아직 없는 캐스트도 열린다(이니셜 원 + 아는 것)', (tester) async {
    // 번들에 그림이 하나도 없는 상태. 그래도 이름·역할·매력은 이미 아는 정보다.
    PortraitRegistry.debugOverride(null);
    await showGroup(tester);
    await tester.tap(avatarOf(seoyeon().name).first);
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsOneWidget);
    expect(findText(seoyeon().displayTitle), findsOneWidget);
  });

  testWidgets('아바타 탭 대상은 44 인데 말풍선 왼쪽 선은 제자리다 (§4.2)', (tester) async {
    // 스크롤 안의 노드는 `iOSTapTargetGuideline` 이 건너뛰므로(부분 스크롤 판정)
    // 여기서 직접 잰다. 그림은 40 그대로, 상자만 44 다.
    usePortraits();
    await showGroup(tester);

    final slot = tester.getRect(find.byType(ChatAvatarSlot).first);
    expect(slot.width, AppSpace.minTouch);
    expect(slot.height, AppSpace.minTouch);
    final avatar = tester.getRect(avatarOf(seoyeon().name).first);
    expect(avatar.width, AppSize.avatarMd, reason: '그림 크기는 그대로');
    expect(avatar.topLeft, slot.topLeft, reason: '그림은 상자 왼쪽 위에 붙는다');

    // 말풍선 왼쪽 선 = 바깥 여백 md + 들여쓰기 48. 예전(40 + sm 8)과 같은 자리다.
    expect(ChatAvatarSlot.indent, AppSize.avatarMd + AppSpace.sm);
    final bubble = tester.getRect(
      find
          .ancestor(of: findText('다들 뭐 해'), matching: find.byType(Container))
          .first,
    );
    expect(bubble.left, AppSpace.md + ChatAvatarSlot.indent);
  });

  testWidgets('탭 · 아래로 쓸기 · 닫기 셋 다 닫는다', (tester) async {
    usePortraits();
    await showGroup(tester);

    Future<void> open() async {
      await tester.tap(avatarOf(seoyeon().name).first);
      await tester.pumpAndSettle();
      expect(find.byType(CharacterProfileView), findsOneWidget);
    }

    // ① 화면 아무 데나 탭.
    await open();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsNothing);

    // ② 아래로 쓸기.
    await open();
    await tester.drag(
      find.byType(CharacterProfileView),
      const Offset(0, CharacterProfileView.dismissDistance + 40),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsNothing);

    // ③ 닫기 버튼.
    await open();
    await tester.tap(findText('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsNothing);
    // 닫고 나면 대화는 그대로다.
    expect(find.byType(EventScreen), findsOneWidget);
    expect(findText('다들 뭐 해'), findsOneWidget);
  });

  testWidgets('조금만 끌다 놓으면 닫히지 않고 제자리로 돌아온다', (tester) async {
    usePortraits();
    await showGroup(tester);
    await tester.tap(avatarOf(seoyeon().name).first);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CharacterProfileView),
      const Offset(0, CharacterProfileView.dismissDistance - 40),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CharacterProfileView), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode == ThemeMode.dark ? '다크' : '라이트';
    testWidgets('320x568 1.3배 $tag: 프로필이 넘치지 않고 탭 타깃·대비를 지킨다', (tester) async {
      useSmallScreenLargeFont(tester);
      if (mode == ThemeMode.dark) useDarkMode(tester);
      usePortraits();
      c.state!.rel('seoyeon').affection = 88;
      await c.setPlayerMbti('ENFP');
      await showGroup(tester, mode: mode);
      await settleImages(tester);

      await tester.tap(avatarOf(seoyeon().name).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 큰 초상화가 좌우 여백 안에 들어간다.
      final big = tester.getRect(
        find.descendant(
          of: find.byType(CharacterProfileView),
          matching: find.byType(CharacterAvatar),
        ),
      );
      expect(big.left, greaterThanOrEqualTo(0));
      expect(big.right, lessThanOrEqualTo(320));
      final close = tester.getRect(findWidgetWithText(FilledButton, '닫기'));
      expect(close.height, greaterThanOrEqualTo(AppSpace.minTouch));
      expect(close.bottom, lessThanOrEqualTo(568));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
