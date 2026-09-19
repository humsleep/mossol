/// 플레이어 이름: 온보딩 이름 단계(입력 · 미리보기 · 건너뛰기 · 부적절한 말 · 길이 · 한글 조합),
/// 두 번째 새 게임의 생략, 설정의 "내 이름", 대사 치환(채팅 · 선택지 · 반응 · 사진 · 전화 ·
/// 알림 · 클리프행어 · 엔딩 · 캐스트 소개 첫 메시지), 이름 없음 대체, 전체 초기화.
/// 규격: docs/NAME_GUIDE.md, docs/DESIGN_SYSTEM.md §2.12.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/engine/text_template.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/call_view.dart';
import 'package:mossol/ui/ending_screen.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/onboarding_name_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/summary_screen.dart';

import 'helpers.dart';

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(Container());
  }

  Future<void> showHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fullApp(c));
    await tester.pump();
  }

  Future<void> tapNewGame(WidgetTester tester) async {
    await tester.tap(findText('새 게임'));
    await tester.pumpAndSettle();
    if (findText('진행 중인 회차가 지워집니다. 시작할까요?').evaluate().isNotEmpty) {
      await tester.tap(findText('시작'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> toNameStep(WidgetTester tester) async {
    await showHome(tester);
    await tapNewGame(tester);
    await tester.tap(find.byKey(const Key('gender-m')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingNameScreen), findsOneWidget);
  }

  Finder field() => find.byKey(const Key('name-field'));
  FilledButton submit(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('name-submit')));

  group('온보딩 이름 단계', () {
    testWidgets('나는? 다음에 뜬다: 제목 · 입력창 · 미리보기 · 다음(꺼짐) · 건너뛰기', (tester) async {
      await toNameStep(tester);
      expect(findText(OnboardingNameScreen.title), findsOneWidget);
      expect(findText(OnboardingNameScreen.subtitle), findsOneWidget);
      expect(field(), findsOneWidget);
      // 빈 입력: 미리보기는 이름 없는 대사, 다음은 꺼짐.
      expect(
        find.descendant(
          of: find.byKey(const Key('name-preview')),
          matching: findText('자?'),
        ),
        findsOneWidget,
      );
      expect(submit(tester).onPressed, isNull);
      expect(findText(OnboardingNameScreen.skipLabel), findsOneWidget);
      // 탭 대상 44 이상.
      for (final k in ['name-submit', 'name-skip']) {
        expect(
          tester.getSize(find.byKey(Key(k))).height,
          greaterThanOrEqualTo(44),
        );
      }
      await unmount(tester);
    });

    testWidgets('입력하면 미리보기가 바로 바뀐다(받침 유무)', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '민석');
      await tester.pump();
      expect(findText('민석아, 자?'), findsOneWidget);
      await tester.enterText(field(), '민수');
      await tester.pump();
      expect(findText('민수야, 자?'), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
      await unmount(tester);
    });

    testWidgets('다음 → 캐스트 소개 → 시작: 이름이 메타에 저장된다', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '민지');
      await tester.pump();
      // 시작 전에는 저장하지 않는다.
      expect(c.playerName, isNull);
      await tester.tap(find.byKey(const Key('name-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(PreferenceScreen), findsOneWidget);
      expect(c.playerName, isNull);
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(c.playerName, '민지');
      final m = await MetaService().load();
      expect(m.playerName, '민지');
      expect(m.nameAsked, isTrue);
      expect(TextTemplate.currentName, '민지');
      await unmount(tester);
    });

    testWidgets('캐스트 소개에서 뒤로 가면 이름 단계, 입력값은 저장되지 않는다', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '민지');
      await tester.pump();
      await tester.tap(find.byKey(const Key('name-submit')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingNameScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(c.phase, Phase.home);
      expect(c.playerName, isNull);
      expect(c.shouldAskName, isTrue);
      expect(TextTemplate.currentName, isNull);
      await unmount(tester);
    });

    testWidgets('건너뛰기: 이름 없이 시작하고 다음 새 게임에서는 묻지 않는다', (tester) async {
      await toNameStep(tester);
      await tester.tap(find.byKey(const Key('name-skip')));
      await tester.pumpAndSettle();
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.phase, Phase.action);
      expect(c.playerName, isNull);
      expect(c.shouldAskName, isFalse);
      await spinRouletteSheet(tester);

      c.goHome();
      await tester.pumpAndSettle();
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsNothing);
      expect(find.byType(OnboardingNameScreen), findsNothing);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('두 번째 새 게임: 이름이 이미 있으면 이름 단계를 건너뛴다', (tester) async {
      await c.setPlayerGender(PlayerGender.female);
      await c.setPlayerName('하늘');
      await showHome(tester);
      await tapNewGame(tester);
      expect(find.byType(OnboardingNameScreen), findsNothing);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('성별 답은 있고 이름은 아직 안 물었으면 이름 단계부터', (tester) async {
      await c.setPlayerGender(PlayerGender.male);
      await showHome(tester);
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsNothing);
      expect(find.byType(OnboardingNameScreen), findsOneWidget);
      await tester.enterText(field(), 'Mina');
      await tester.pump();
      await tester.tap(find.byKey(const Key('name-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.startLabel));
      await tester.pumpAndSettle();
      expect(c.playerName, 'Mina');
      await unmount(tester);
    });

    testWidgets('부적절한 말은 막고 안내한다', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '병신');
      await tester.pump();
      expect(findTextContaining('쓸 수 없어요'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);
      // 미리보기에 그 말을 싣지 않는다.
      expect(findText('병신아, 자?'), findsNothing);
      await unmount(tester);
    });

    testWidgets('허용 밖 글자(공백·기호)는 걸러지고, 자모만 남으면 안내한다', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '민 지!');
      await tester.pump();
      expect(tester.widget<TextField>(field()).controller!.text, '민지');
      await tester.enterText(field(), '민ㅈ');
      await tester.pump();
      expect(findText('완성된 글자로 써 주세요'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);
      await unmount(tester);
    });

    testWidgets('길이: 6자에서 잘리고 카운터는 자소 묶음으로 센다', (tester) async {
      await toNameStep(tester);
      await tester.enterText(field(), '가나다라마바사');
      await tester.pump();
      final ctl = tester.widget<TextField>(field()).controller!;
      expect(ctl.text, '가나다라마바');
      expect(findText('6/6'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('한글 조합 중에는 자르지 않고, 조합이 끝나면 6자로 자른다', (tester) async {
      await toNameStep(tester);
      await tester.showKeyboard(field());
      // 여섯 글자 뒤 일곱 번째 음절을 조합 중(밑줄 구간).
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '가나다라마바ㅅ',
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange(start: 6, end: 7),
        ),
      );
      await tester.pump();
      final ctl = tester.widget<TextField>(field()).controller!;
      expect(ctl.text, '가나다라마바ㅅ', reason: '조합 중에 자르면 입력기가 깨진다');
      // 조합 중에는 오류를 띄우지 않는다(자모가 잠깐 보여도).
      expect(findText('완성된 글자로 써 주세요'), findsNothing);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '가나다라마바사',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      expect(ctl.text, '가나다라마바');
      await unmount(tester);
    });
  });

  group('설정 · 초기화', () {
    testWidgets('설정의 내 이름: 없음 → 저장 → 바꾸기 → 지우기', (tester) async {
      await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
      final row = find.byKey(const Key('settings-name'));
      expect(
        find.descendant(of: row, matching: findText('없음')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingNameScreen), findsOneWidget);
      expect(findText(OnboardingNameScreen.saveLabel), findsOneWidget);
      expect(find.byKey(const Key('name-skip')), findsNothing);
      expect(find.byKey(const Key('name-clear')), findsNothing);
      await tester.enterText(field(), '민지');
      await tester.pump();
      await tester.tap(find.byKey(const Key('name-submit')));
      await tester.pumpAndSettle();
      expect(c.playerName, '민지');
      expect((await MetaService().load()).playerName, '민지');
      expect(
        find.descendant(of: row, matching: findText('민지')),
        findsOneWidget,
      );

      // 바꾸기: 지금 이름이 입력창에 들어 있다.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, '민지');
      await tester.enterText(field(), '하늘');
      await tester.pump();
      await tester.tap(find.byKey(const Key('name-submit')));
      await tester.pumpAndSettle();
      expect(c.playerName, '하늘');

      // 지우기.
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('name-clear')));
      await tester.pumpAndSettle();
      expect(c.playerName, isNull);
      expect((await MetaService().load()).playerName, isNull);
      // 지웠어도 다시 묻지 않는다(설정에서 직접 지운 것).
      expect(c.shouldAskName, isFalse);
    });

    testWidgets('전체 초기화는 이름도 지우고, 다음 새 게임에서 다시 묻는다', (tester) async {
      await c.setPlayerGender(PlayerGender.male);
      await c.setPlayerName('민지');
      await c.resetAllData();
      expect(c.playerName, isNull);
      expect(c.shouldAskName, isTrue);
      expect(TextTemplate.currentName, isNull);
      expect((await MetaService().load()).playerName, isNull);
    });

    test('예전 메타 JSON(이름 없음)은 null · 묻지 않은 상태로 읽힌다', () {
      final m = PlayerMeta.fromJson({'streakDays': 3});
      expect(m.playerName, isNull);
      expect(m.nameAsked, isFalse);
      final back = PlayerMeta.fromJson(
        (PlayerMeta(playerName: '민지', nameAsked: true)).toJson(),
      );
      expect(back.playerName, '민지');
      expect(back.nameAsked, isTrue);
    });
  });

  group('대사 치환', () {
    StoryEvent chatEvent() => StoryEvent.fromJson({
      'id': 't_name',
      'layer': 'daily',
      'character': 'seoyeon',
      'title': '이름 테스트',
      'cliffhanger': '내일 {name|이가} 먼저 연락할까',
      'lines': [
        {'who': 'them', 'text': '{name|아야}, 자?'},
        {
          'who': 'them',
          'text': '{name|이}랑 가고 싶은 데',
          'photo': {'icon': 'cafe', 'caption': '{name|이}랑 올 곳'},
        },
      ],
      'choices': [
        {
          'text': '{name|은는} 안 자',
          'reply': ['{name|이가} 그럴 줄 알았어'],
        },
      ],
    });

    Future<void> show(WidgetTester tester, StoryEvent ev) async {
      await c.newGame(preference: Preference.female, seed: 11);
      c.current = ev;
      c.revealed = ev.lines.length;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
    }

    testWidgets('채팅: 대사 · 사진 캡션 · 선택지 · 내 말 · 반응 · 클리프행어', (tester) async {
      await c.setPlayerName('민석');
      await show(tester, chatEvent());
      expect(findText('민석아, 자?'), findsOneWidget);
      expect(findText('민석이랑 가고 싶은 데'), findsOneWidget);
      expect(findText('민석이랑 올 곳'), findsOneWidget);
      expect(findTextContaining('{name'), findsNothing);
      await tester.tap(findWidgetWithText(OutlinedButton, '민석은 안 자'));
      await tester.pump();
      // 내 말풍선.
      expect(findText('민석은 안 자'), findsOneWidget);
      await settleReplies(tester);
      expect(findText('민석이 그럴 줄 알았어'), findsOneWidget);
      // 엔진에는 원본이 남는다(세이브에 이름이 들어가지 않는다).
      expect(c.current!.lines.first.text, '{name|아야}, 자?');
      expect(c.cliffhanger, '내일 {name|이가} 먼저 연락할까');
      await tester.pumpWidget(wrapApp(SummaryScreen(c: c)));
      await tester.pump(const Duration(seconds: 2));
      expect(findText('내일 민석이 먼저 연락할까'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('이름이 없으면 대체어: 호격은 빠지고 나머지는 너', (tester) async {
      await show(tester, chatEvent());
      expect(findText('자?'), findsOneWidget);
      expect(findText('너랑 가고 싶은 데'), findsOneWidget);
      await tester.tap(findWidgetWithText(OutlinedButton, '너는 안 자'));
      await tester.pump();
      await settleReplies(tester);
      expect(findText('네가 그럴 줄 알았어'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('회차 도중 이름을 바꾸면 다음에 그려지는 대사부터', (tester) async {
      await c.setPlayerName('민석');
      await show(tester, chatEvent());
      expect(findText('민석아, 자?'), findsOneWidget);
      await c.setPlayerName('민수');
      await tester.pump();
      expect(findText('민수야, 자?'), findsOneWidget);
      // 세이브에는 이름이 없다.
      expect(c.state!.toJson().toString().contains('민수'), isFalse);
      await unmount(tester);
    });

    testWidgets('전화: 자막과 반응이 치환된다', (tester) async {
      await c.setPlayerName('하늘');
      await c.newGame(preference: Preference.female, seed: 11);
      final ev = StoryEvent.fromJson({
        'id': 't_name_call',
        'layer': 'daily',
        'character': 'seoyeon',
        'format': 'call',
        'lines': [
          {'who': 'them', 'text': '여보세요, {name|아야}?'},
        ],
        'choices': [
          {
            'text': '{name|으로로} 할게',
            'reply': ['{name|으로로} 정했다'],
          },
          {
            'text': '거절',
            'decline': true,
            'reply': ['…'],
          },
        ],
      });
      c.current = ev;
      c.revealed = 0;
      c.lastOutcome = null;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
      await tester.tap(findText('받기'));
      await tester.pump();
      await revealAll(tester, c);
      expect(
        find.descendant(
          of: find.byType(CallSubtitle),
          matching: findText('여보세요, 하늘아?'),
        ),
        findsOneWidget,
      );
      await tester.tap(findWidgetWithText(OutlinedButton, '하늘로 할게'));
      await tester.pump();
      await settleReplies(tester);
      expect(findText('하늘로 정했다'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('알림 미리보기(preview)도 치환된다', (tester) async {
      await c.setPlayerName('민지');
      await c.newGame(preference: Preference.female, seed: 11);
      final ev = StoryEvent.fromJson({
        'id': 't_name_preview',
        'layer': 'daily',
        'character': 'seoyeon',
        'preview': '{name|아야} 퇴근했어?',
        'lines': [
          {'who': 'them', 'text': '응'},
        ],
        'choices': [
          {
            'text': 'ㅇㅇ',
            'reply': ['ㅋㅋ'],
          },
        ],
      });
      c.current = ev;
      c.revealed = 0;
      c.lastOutcome = null;
      c.phase = Phase.event;
      await tester.pumpWidget(wrapApp(EventScreen(c: c)));
      await tester.pump();
      expect(findText('민지야 퇴근했어?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('엔딩 에필로그', (tester) async {
      await c.setPlayerName('민지');
      await c.newGame(preference: Preference.female, seed: 11);
      c.ending = const Ending(
        id: 't_end',
        name: '테스트 엔딩',
        tier: 'normal',
        priority: 1,
        when: Trigger.always,
        epilogue: '서연은 {name|을를} 오래 기억했다.',
      );
      c.phase = Phase.ending;
      await tester.pumpWidget(wrapApp(EndingScreen(c: c)));
      await tester.pump();
      expect(findText('서연은 민지를 오래 기억했다.'), findsOneWidget);
      await unmount(tester);
    });

    test('캐스트 소개 첫 메시지(StoryBundle.firstLineOf)는 지금 이름으로', () {
      final b = testBundle();
      final id = b.characters.firstWhere((ch) => !ch.hidden).id;
      final raw = b.rawFirstLineOf(id)!;
      final saved = TextTemplate.currentName;
      addTearDown(() => TextTemplate.currentName = saved);
      TextTemplate.currentName = '민지';
      expect(b.firstLineOf(id), TextTemplate.fill(raw, name: '민지'));
    });

    test('검증기: 모르는 조사 · 닫히지 않은 중괄호 · 치환 안 하는 필드는 오류, 정상 형식은 통과', () {
      String read(String f) => File('assets/story/$f').readAsStringSync();
      StoryBundle build(Map<String, dynamic> extra) =>
          StoryBundle.fromJsonStrings(
            config: read('config.json'),
            characters: read('characters.json'),
            events: [
              for (final f in StoryBundle.eventFiles) read(f),
              jsonEncode([extra]),
            ],
            endings: read('endings.json'),
          );
      Map<String, dynamic> ev(String text, {String? album}) => {
        'id': 't_validate',
        'layer': 'daily',
        'lines': [
          {'who': 'them', 'text': text},
        ],
        'choices': [
          {
            'text': 'a',
            'reply': 'b',
            if (album != null) 'effects': {'album': album},
          },
        ],
      };
      for (final bad in ['{name|의} 안녕', '{name|아야, 자?', '안녕}', '{nmae}']) {
        expect(
          () => build(ev(bad)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('자리표시자'),
            ),
          ),
          reason: bad,
        );
      }
      expect(() => build(ev('ㅋ', album: '{name}의 흑역사')), throwsStateError);
      expect(
        () => build(ev('{name|아야|자기}, 자? {name|씨+이가} 왔어')),
        returnsNormally,
      );
    });
  });
}
