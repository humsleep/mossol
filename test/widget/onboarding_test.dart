/// 새 게임 온보딩: 1단계 "나는?" → 2단계 캐스트 소개 → 시작. 기기 메타의 `playerGender`,
/// 두 번째 새 게임의 1단계 건너뛰기, 설정의 "내 성별", 전체 초기화, 홈 힌트 범위.
///
/// 홈은 1초 타이머를 돌리므로 테스트 끝에 `unmount` 로 내린다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/meta_service.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/home_screen.dart';
import 'package:mossol/ui/onboarding_gender_screen.dart';
import 'package:mossol/ui/preference_screen.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // 설정 목록이 끝까지 지어지도록 넉넉한 화면.
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

  Future<void> tapStart(WidgetTester tester) async {
    await tester.tap(findText(PreferenceScreen.startLabel));
    await tester.pumpAndSettle();
  }

  group('1단계 → 2단계 → 시작', () {
    testWidgets('1단계: 제목 · 부제 · 큰 버튼 셋(44 이상) · 저장 안내', (tester) async {
      await showHome(tester);
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsOneWidget);
      expect(findText('나는?'), findsOneWidget);
      expect(findText('만나게 될 사람들이 달라져요'), findsOneWidget);
      for (final g in PlayerGender.values) {
        final r = tester.getRect(find.byKey(Key('gender-$g')));
        expect(r.height, greaterThanOrEqualTo(GenderOptionCard.minHeight));
      }
      expect(findText('남자'), findsOneWidget);
      expect(findText('여자'), findsOneWidget);
      expect(findText('선택 안 할래요'), findsOneWidget);
      expect(findText(OnboardingGenderScreen.note), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('남자 → 여성 쪽 캐스트 → 시작하기: 선호 f, 메타에 m 저장', (tester) async {
      await showHome(tester);
      await tapNewGame(tester);
      await tester.tap(findText('남자'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      expect(find.byKey(const Key('cast-seoyeon')), findsOneWidget);
      expect(find.byKey(const Key('cast-jeongwoo')), findsNothing);
      // 시작 전에는 아무것도 저장되지 않는다.
      expect(c.playerGender, isNull);
      await tapStart(tester);
      expect(c.phase, Phase.action);
      expect(c.state!.preference, Preference.female);
      expect(c.playerGender, PlayerGender.male);
      // 기기 메타(SharedPreferences)에 실제로 남았다.
      expect((await MetaService().load()).playerGender, PlayerGender.male);
      await unmount(tester);
    });

    testWidgets('여자 → 남성 쪽 기본 → 반대쪽 캐릭터 만나기 → 시작: 선호 f, 성별은 f 그대로', (
      tester,
    ) async {
      await showHome(tester);
      await tapNewGame(tester);
      await tester.tap(findText('여자'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      await tester.tap(findText(PreferenceScreen.flipLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      expect(findText(PreferenceScreen.restoreLabel), findsOneWidget);
      await tapStart(tester);
      expect(c.state!.preference, Preference.female);
      expect(c.playerGender, PlayerGender.female);
      await unmount(tester);
    });

    testWidgets('선택 안 할래요 → 비교(기본 없음, 시작 꺼짐) → 두 쪽을 오가다 남성 → 시작', (
      tester,
    ) async {
      await showHome(tester);
      await tapNewGame(tester);
      await tester.tap(findText('선택 안 할래요'));
      await tester.pumpAndSettle();
      FilledButton start() =>
          tester.widget<FilledButton>(find.byKey(const Key('cast-start')));
      expect(start().onPressed, isNull);
      expect(find.byType(PreferenceCard), findsNWidgets(2));
      Finder seg(String label) => find.descendant(
        of: find.byKey(const Key('cast-segment')),
        matching: findText(label),
      );
      await tester.tap(seg('여성 캐릭터'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-f')), findsOneWidget);
      await tester.tap(seg('남성 캐릭터'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      expect(start().onPressed, isNotNull);
      await tapStart(tester);
      expect(c.state!.preference, Preference.male);
      expect(c.playerGender, PlayerGender.none);
      await unmount(tester);
    });

    testWidgets('두 번째 새 게임은 1단계를 건너뛰고 기본 쪽 캐스트로 바로 간다', (tester) async {
      await showHome(tester);
      await tapNewGame(tester);
      await tester.tap(findText('여자'));
      await tester.pumpAndSettle();
      await tapStart(tester);
      expect(c.state!.preference, Preference.male);
      await spinRouletteSheet(tester);

      c.goHome();
      await tester.pumpAndSettle();
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsNothing);
      expect(find.byType(PreferenceScreen), findsOneWidget);
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      // 이번에는 반대쪽으로 시작해도 성별 답은 바뀌지 않는다.
      await tester.tap(findText(PreferenceScreen.flipLabel));
      await tester.pumpAndSettle();
      await tapStart(tester);
      expect(c.state!.preference, Preference.female);
      expect(c.playerGender, PlayerGender.female);
      await unmount(tester);
    });

    testWidgets('"선택 안 함" 이면 다음 새 게임도 1단계 없이 비교 모드', (tester) async {
      await c.setPlayerGender(PlayerGender.none);
      await showHome(tester);
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsNothing);
      expect(find.byKey(const Key('cast-segment')), findsOneWidget);
      expect(find.byType(PreferenceCard), findsNWidgets(2));
      await unmount(tester);
    });
  });

  group('설정 · 초기화', () {
    testWidgets('설정의 내 성별: 현재 값 표시 → 바꾸면 메타 저장, 다음 새 게임 기본 쪽이 바뀐다', (
      tester,
    ) async {
      await c.setPlayerGender(PlayerGender.male);
      await showHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('settings-gender'));
      expect(
        find.descendant(of: row, matching: findText('남자')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(findText('내 성별'), findsNWidgets(2), reason: '행 제목 + 다이얼로그 제목');
      // 지금 값에 체크.
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-gender-m')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-gender-f')));
      await tester.pumpAndSettle();
      expect(c.playerGender, PlayerGender.female);
      expect((await MetaService().load()).playerGender, PlayerGender.female);
      expect(
        find.descendant(of: row, matching: findText('여자')),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      // 홈 등장인물 줄도 남성 쪽으로.
      final strip = tester.widget<CastStrip>(find.byType(CastStrip));
      expect(
        strip.entries.map((e) => e.id),
        containsAll(['haneul', 'jeongwoo']),
      );
      await tapNewGame(tester);
      expect(find.byKey(const Key('cast-side-m')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('설정 다이얼로그를 그냥 닫으면 값이 그대로다', (tester) async {
      await tester.pumpWidget(wrapApp(SettingsScreen(c: c)));
      expect(findText('아직 안 정함'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-gender')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(c.playerGender, isNull);
    });

    testWidgets('전체 초기화 뒤 새 게임은 다시 "나는?" 을 묻는다', (tester) async {
      await c.setPlayerGender(PlayerGender.male);
      await c.newGame(preference: Preference.female, seed: 3);
      c.goHome();
      await showHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(findText('저장 데이터 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(findText('지우기'));
      await tester.pumpAndSettle();
      expect(c.playerGender, isNull);
      await tapNewGame(tester);
      expect(find.byType(OnboardingGenderScreen), findsOneWidget);
      await unmount(tester);
    });
  });

  group('홈 힌트 범위(세이브 있음)', () {
    for (final pref in Preference.genders) {
      testWidgets('세이브 선호 $pref: 힌트는 그 쪽 + 공용 엔딩에서만', (tester) async {
        // 나는? 답과 반대쪽 회차여도 세이브 쪽을 따른다.
        await c.setPlayerGender(
          pref == Preference.female ? PlayerGender.female : PlayerGender.male,
        );
        await c.newGame(preference: pref, seed: 3);
        c.goHome();
        final scope = homeHintScope(c);
        for (final e in c.bundle.endings) {
          final side = c.bundle.endingSide(e);
          expect(
            scope.contains(e),
            side == null || side == pref,
            reason: '${e.id} ($side)',
          );
        }
        await showHome(tester);
        final first = c.bundle.endings.firstWhere(
          (e) => scope.contains(e) && e.tier != 'bad' && e.tier != 'hidden',
        );
        expect(c.bundle.characterById[first.character]?.gender, pref);
        expect(
          findText('다음 엔딩 힌트 · ${endingHintFor(first, c)}'),
          findsOneWidget,
        );
        await unmount(tester);
      });
    }
  });

  group('데이터 · 메타 호환', () {
    test('12명 모두 한 줄 매력(20자 이내), 보이는 사람은 첫 메시지가 있다', () {
      final b = testBundle();
      expect(b.characters, hasLength(12));
      for (final ch in b.characters) {
        expect(ch.tagline, isNotEmpty, reason: ch.id);
        expect(
          ch.tagline.runes.length,
          lessThanOrEqualTo(CharacterDef.maxTagline),
          reason: ch.id,
        );
        if (!ch.hidden) {
          expect(b.firstLineOf(ch.id), isNotNull, reason: ch.id);
        }
      }
      // 사람이 쓴 firstLine 이 우선, 없으면 첫 접촉 이벤트의 첫 them 대사.
      expect(b.firstLineOf('jeongwoo'), '아까 공지 딱딱했지. 하하. 반가워.');
      final r00 = b.eventById['seoyeon_r00']!;
      expect(
        b.firstLineOf('seoyeon'),
        r00.lines.firstWhere((l) => l.who == 'them').text,
      );
      // 지우는 r00 이 없고 r01 에 them 대사가 없어 r02 로 내려간다.
      expect(
        b.firstLineOf('jiwoo'),
        b.eventById['jiwoo_r02']!.lines.firstWhere((l) => l.who == 'them').text,
      );
    });

    test('tagline 20자 초과는 검증에서 막는다', () {
      String read(String f) => File('assets/story/$f').readAsStringSync();
      final chars = jsonDecode(read('characters.json')) as List<dynamic>;
      (chars.first as Map<String, dynamic>)['tagline'] = '가' * 21;
      expect(
        () => StoryBundle.fromJsonStrings(
          config: read('config.json'),
          characters: jsonEncode(chars),
          events: [for (final f in StoryBundle.eventFiles) read(f)],
          endings: read('endings.json'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('예전 메타 JSON(playerGender 없음) · 깨진 값은 null, 저장하면 왕복된다', () async {
      SharedPreferences.setMockInitialValues({
        'mossol_meta_v1': jsonEncode({'streakDays': 3, 'totalRuns': 2}),
      });
      final svc = MetaService();
      final old = await svc.load();
      expect(old.playerGender, isNull);
      expect(old.streakDays, 3);

      expect(PlayerMeta.fromJson({'playerGender': 'x'}).playerGender, isNull);
      expect(PlayerMeta.fromJson({'playerGender': 3}).playerGender, isNull);

      old.playerGender = PlayerGender.none;
      await svc.save(old);
      expect((await svc.load()).playerGender, PlayerGender.none);
      await svc.clear();
      expect((await svc.load()).playerGender, isNull);
    });

    test('기본 쪽: 남자 → 여성, 여자 → 남성, 선택 안 함·없음 → 비교', () {
      expect(PlayerGender.sideFor('m'), Preference.female);
      expect(PlayerGender.sideFor('f'), Preference.male);
      expect(PlayerGender.sideFor('none'), isNull);
      expect(PlayerGender.sideFor(null), isNull);
    });
  });
}
