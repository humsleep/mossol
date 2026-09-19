/// 작은 화면 · 큰 글꼴 · 다크 모드 · 접근성 기준 검사.
///
/// 레이아웃이 넘치면(RenderFlex overflow) Flutter 가 오류를 보고하고 테스트가 실패한다.
/// 그래서 "화면을 띄우고 주요 상태로 옮겨 본다" 만으로 넘침 검사가 된다.
/// 여기에 더해 iOS 터치 영역 44pt, 글자 대비(WCAG AA) 가이드라인을 확인한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/debug/debug_gallery.dart';
import 'package:mossol/game_controller.dart';
import 'package:mossol/minigames/minigame.dart';
import 'package:mossol/ui/action_screen.dart';
import 'package:mossol/ui/album_screen.dart';
import 'package:mossol/ui/call_view.dart';
import 'package:mossol/ui/design_system.dart';
import 'package:mossol/ui/event_screen.dart';
import 'package:mossol/ui/notification_card.dart';
import 'package:mossol/ui/settings_screen.dart';
import 'package:mossol/ui/widgets.dart';

import 'helpers.dart';

/// 큰 화면 한 벌과 작은 화면 한 벌. 각각 라이트·다크로 돈다.
enum _Env { smallLight, smallDark }

void main() {
  late GameController c;

  setUp(() async {
    c = await makeController();
    await c.newGame(seed: 11);
  });

  void apply(WidgetTester tester, _Env env) {
    useSmallScreenLargeFont(tester);
    if (env == _Env.smallDark) useDarkMode(tester);
  }

  ThemeMode modeOf(_Env env) =>
      env == _Env.smallDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> showEvent(
    WidgetTester tester,
    _Env env,
    String id, {
    bool revealed = true,
  }) async {
    final ev = c.bundle.eventById[id]!;
    c.current = ev;
    c.revealed = revealed ? ev.lines.length : 0;
    c.phase = Phase.event;
    await tester.pumpWidget(wrapApp(EventScreen(c: c), mode: modeOf(env)));
    await tester.pump();
  }

  /// 타이머가 남은 화면을 내리고 시간을 흘려 정리한다.
  Future<void> teardownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  for (final env in _Env.values) {
    final tag = env == _Env.smallDark ? '320x568 1.3배 다크' : '320x568 1.3배 라이트';

    group(tag, () {
      testWidgets('홈: 세이브 있음 · 없음이 넘치지 않고 시작 버튼이 첫 화면에 보인다', (tester) async {
        apply(tester, env);
        c.goHome();
        c.hasSave = false;
        await tester.pumpWidget(fullApp(c));
        await tester.pump();
        final start = tester.getRect(find.text('새 게임'));
        expect(start.bottom, lessThanOrEqualTo(568), reason: '스크롤 없이 시작 버튼이 보여야 한다');
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        c.hasSave = true;
        c.notifyListeners();
        await tester.pump();
        expect(find.text('이어하기'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('홈 v2: 세이브 있음(예고·최고 호감·하트 부족)에서 1차 버튼이 첫 화면 안에 있다', (tester) async {
        apply(tester, env);
        c.state!
          ..day = 37
          ..hearts = 2
          ..lastHeartMs = DateTime.now().millisecondsSinceEpoch
          ..lastCliffhanger = '내일 서연이 먼저 연락한다고 했는데 아직 아무 말이 없다. 밤새 폰만 봤다.';
        c.state!.rel('seoyeon').affection = 42;
        await c.save.save(c.state!);
        c.goHome();
        await tester.pumpWidget(fullApp(c));
        await tester.pump();
        expect(find.textContaining('어젯밤:'), findsOneWidget);
        expect(find.textContaining('서연 ♥42'), findsOneWidget);
        // 홈 신호 줄: 최애의 서사 신호가 첫 화면 안에 넘치지 않고 보인다.
        final signal = c.saveSummary!.topSignal!;
        expect(find.textContaining(signal), findsOneWidget);
        expect(tester.getRect(find.textContaining(signal)).bottom, lessThanOrEqualTo(568));
        expect(find.text('받기'), findsOneWidget);
        // 배너 없는 조건. 예산표(HOME_REDESIGN §1.5)는 배너 포함 466 이라 더 여유롭다.
        final primary = tester.getRect(find.widgetWithText(FilledButton, '이어하기'));
        expect(primary.bottom, lessThanOrEqualTo(568), reason: '1차 버튼이 첫 화면 안에 있어야 한다');
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // 출석 수령 뒤·스크롤 끝(앨범 카드)까지 넘침 없이.
        await tester.tap(find.text('받기'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(find.textContaining('앨범  '), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('설정 화면이 넘치지 않고 탭 타깃·대비를 지킨다', (tester) async {
        apply(tester, env);
        await tester.pumpWidget(wrapApp(SettingsScreen(c: c), mode: modeOf(env)));
        await tester.pump();
        expect(find.text('개인정보처리방침'), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('저장 데이터 초기화'), findsOneWidget);
        expect(find.text('앱 버전'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // 초기화 확인 다이얼로그(다크 표면 + 위험색 버튼)도 대비를 지킨다.
        await tester.tap(find.text('저장 데이터 초기화'));
        await tester.pumpAndSettle();
        expect(find.text('저장 데이터를 지울까요?'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        await teardownScreen(tester);
      });

      testWidgets('행동 화면 + 룰렛 시트(전·후)', (tester) async {
        apply(tester, env);
        c.state!
          ..combo = 4
          ..lastCliffhanger = '내일 서연이 먼저 연락한다고 했는데 아직 아무 말이 없다';
        c.state!.rel('seoyeon').affection = 88;
        c.state!.rel('haneul').trust = 100;
        await tester.pumpWidget(wrapApp(ActionScreen(c: c), mode: modeOf(env)));
        await tester.pumpAndSettle();
        expect(find.text('오늘의 운'), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await spinRouletteSheet(tester);

        // 스탯 라벨은 가장 긴 '스트레스' 도 말줄임 없이 다 들어가야 한다.
        final stress = tester.renderObject<RenderParagraph>(find.text('스트레스'));
        expect(stress.didExceedMaxLines, isFalse, reason: '스탯 라벨이 잘렸다');

        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('이벤트: 대사 · 잠긴 선택지 · 결과 패널(성공·실패·크리티컬)', (tester) async {
        apply(tester, env);
        await showEvent(tester, env, 'm02');
        // 잠긴 선택지는 작은 화면에서도 여전히 누를 수 없다.
        final locked = c.choices.firstWhere((v) => v.locked);
        final btn = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, locked.choice.text));
        expect(btn.onPressed, isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // 실패 결과(되돌리기 제안 포함).
        await showEvent(tester, env, 'm01');
        c.choose(0, minigameSuccess: false);
        await tester.pump();
        await settleReplies(tester);
        expect(find.text('실패…'), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // 크리티컬 결과.
        c.undoChoice();
        await tester.pump();
        final idx = c.choices.indexWhere((v) => !v.locked);
        c.choose(c.choices[idx].index, minigameSuccess: true, minigameCritical: true, note: '전부 맞췄다. 표정 읽기의 달인.');
        await tester.pump();
        await settleReplies(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('이벤트: 읽씹 대기 줄', (tester) async {
        apply(tester, env);
        final ev = c.bundle.eventById['m03']!;
        final waitIdx = ev.lines.indexWhere((l) => l.isWait);
        await showEvent(tester, env, 'm03', revealed: false);
        for (var i = 0; i < 40 && c.revealed < waitIdx; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('초째 답이 없다'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await teardownScreen(tester);
      });

      // 모먼트(docs/MOMENTS_SPEC.md): 전화 두 화면 · 알림 카드 · 사진 말풍선.
      Future<void> showMoment(WidgetTester tester, StoryEvent ev, {bool revealed = false}) async {
        c.current = ev;
        c.revealed = revealed ? ev.lines.length : 0;
        c.lastOutcome = null;
        c.phase = Phase.event;
        await tester.pumpWidget(wrapApp(EventScreen(c: c), mode: modeOf(env)));
        await tester.pump();
      }

      testWidgets('모먼트: 전화 수신 · 통화 중(선택지·결과)', (tester) async {
        apply(tester, env);
        final call = momentSamples(c.bundle)[0].$3;
        await showMoment(tester, call);
        expect(find.byType(IncomingCallView), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(find.text('받기'));
        await tester.pump();
        await revealAll(tester, c);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ActiveCallView), findsOneWidget);
        expect(find.text(CallSubtitle.silence), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(find.widgetWithText(OutlinedButton, call.choices.first.text));
        await tester.pump();
        await settleReplies(tester);
        expect(find.text('계속'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('모먼트: 거절 뒤 채팅(부재중 전화 · 반응 · 결과)', (tester) async {
        apply(tester, env);
        await showMoment(tester, momentSamples(c.bundle)[0].$3);
        await tester.tap(find.text('거절'));
        await tester.pump();
        await settleReplies(tester);
        expect(find.textContaining('부재중 전화'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('모먼트: 알림 카드(40자 알림)', (tester) async {
        apply(tester, env);
        final ev = StoryEvent.fromJson({
          'id': 'mo_layout_preview',
          'layer': 'route',
          'character': c.bundle.characters.first.id,
          'preview': '가나다라마바사아자차카타파하 오늘 진짜 긴 알림 문장이 두 줄을 넘어가',
          'lines': [
            {'who': 'them', 'text': '안녕'},
          ],
          'choices': [
            {'text': 'x', 'reply': 'ㅇㅇ'},
          ],
        });
        expect(ev.preview!.length, lessThanOrEqualTo(StoryEvent.maxPreview));
        await showMoment(tester, ev);
        await tester.pump(const Duration(milliseconds: 400)); // 내려오는 연출 끝
        expect(find.byType(NotificationCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('모먼트: 사진 말풍선(20자 설명 · 글 동반 · 내 사진)', (tester) async {
        apply(tester, env);
        final ev = StoryEvent.fromJson({
          'id': 'mo_layout_photo',
          'layer': 'daily',
          'character': c.bundle.characters.first.id,
          'lines': [
            {
              'who': 'them',
              'photo': {'icon': 'night', 'caption': '가나다라마바사아자차카타파하 한강 야경'},
              'text': '여기 진짜 예쁘다. 다음에 같이 올래? 야경 보면서 걷자',
            },
            {
              'who': 'me',
              'photo': {'icon': 'selfie', 'caption': '출발 인증'},
            },
          ],
          'choices': [
            {'text': 'x', 'reply': 'ㅇㅇ'},
          ],
        });
        expect(ev.lines.first.photo!.caption.length, lessThanOrEqualTo(Photo.maxCaption));
        await showMoment(tester, ev, revealed: true);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PhotoBubble), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await teardownScreen(tester);
      });

      testWidgets('정산 화면: 변화가 많은 날', (tester) async {
        apply(tester, env);
        for (final k in Stat.visible) {
          c.dayDelta.stats[k] = k == Stat.stress ? 12 : -7;
        }
        for (final ch in c.bundle.characters) {
          c.dayDelta.affection[ch.id] = 4;
          c.dayDelta.trust[ch.id] = -3;
        }
        c.cliffhanger = '내일은 뭔가 다르다. 서연의 프로필 사진이 바뀌었다는 알림이 왔다.';
        c.phase = Phase.summary;
        await tester.pumpWidget(fullApp(c));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text('다음 날로'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('정산 화면: 관계 변화 카드 2장(상승) · 하강 카드가 넘치지 않는다', (tester) async {
        apply(tester, env);
        final s = c.state!;
        // 가장 긴 이름·신호 조합이 나올 수 있게 오른 사람 둘, 내려간 사람 하나.
        s.rel('seoyeon').affection = 90;
        c.dayDelta.affection['seoyeon'] = 5;
        s.rel('yeeun').affection = 12;
        c.dayDelta.affection['yeeun'] = 5;
        s.rel('haneul').affection = 9;
        c.dayDelta.affection['haneul'] = -3;
        c.cliffhanger = '내일은 뭔가 다르다. 서연의 프로필 사진이 바뀌었다는 알림이 왔다.';
        c.phase = Phase.summary;
        await tester.pumpWidget(fullApp(c));
        await tester.pumpAndSettle();
        expect(find.byType(RelationShiftCard), findsNWidgets(2));
        expect(find.text('가까워졌다'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text('다음 날로'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        // 하강만 있는 날: 조용한 카드 한 장.
        await tester.pumpWidget(const SizedBox());
        for (final id in ['seoyeon', 'yeeun']) {
          c.dayDelta.affection.remove(id);
        }
        await tester.pumpWidget(fullApp(c));
        await tester.pumpAndSettle();
        expect(find.text('조금 멀어졌다'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('RelationShiftCard · ContinueCard: 40자 신호도 넘치지 않는다', (tester) async {
        apply(tester, env);
        final long = '가나다라마바사아자차' * 4;
        await tester.pumpWidget(
          wrapApp(
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ContinueCard(
                    run: 12,
                    chapter: 5,
                    day: 100,
                    totalDays: 100,
                    cliffhanger: long,
                    topName: '서연',
                    topAffection: 100,
                    topSignal: long,
                  ),
                  for (final id in c.bundle.characters.map((x) => x.id))
                    Builder(
                      builder: (context) => RelationShiftCard(
                        name: c.characterName(id),
                        text: long,
                        up: id != 'doyun',
                        accent: context.tokens.accentFor(id),
                      ),
                    ),
                ],
              ),
            ),
            mode: modeOf(env),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('서연 ♥100'), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('앨범: 흑역사 · 엔딩(획득 섞임)', (tester) async {
        apply(tester, env);
        c.state!.album.addAll([
          '술자리에서 노래 부르다가 마이크를 놓치고 박수도 못 받음',
          '읽씹 당하고 3번 더 보냄',
        ]);
        for (final e in c.bundle.endings.take(3)) {
          await c.save.addEnding(e.id);
        }
        c.endingAlbum = await c.save.loadEndings();
        await tester.pumpWidget(wrapApp(AlbumScreen(c: c), mode: modeOf(env)));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.tap(find.text('엔딩'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      });

      testWidgets('엔딩 화면', (tester) async {
        apply(tester, env);
        c.state!.day = c.config.totalDays;
        await c.endDay();
        await tester.pumpWidget(fullApp(c));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text('홈으로'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });

      testWidgets('미니게임 12종이 첫 화면에서 넘치지 않는다', (tester) async {
        apply(tester, env);
        for (final id in minigameRegistry.keys) {
          final builder = minigameRegistry[id]!;
          await tester.pumpWidget(wrapApp(
            Builder(builder: (_) => builder(ctxFor(c, partner: 'seoyeon'), (_) {})),
            mode: modeOf(env),
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: '미니게임 $id');
          expect(find.byType(MinigameScaffold), findsOneWidget, reason: id);
          await teardownScreen(tester);
        }
      });
    });
  }

  testWidgets('배너 틀은 bottomNavigationBar 에서 본문을 밀어내지 않는다', (tester) async {
    // 실기기에서 배너가 로드되면 Center 가 세로로 늘어나 본문 높이가 0 이 되던 회귀.
    await tester.pumpWidget(wrapApp(const Scaffold(
      body: SizedBox.expand(key: ValueKey('body')),
      bottomNavigationBar: BannerFrame(
        width: 320,
        height: 50,
        child: SizedBox.expand(),
      ),
    )));
    final body = tester.getSize(find.byKey(const ValueKey('body')));
    final banner = tester.getSize(find.byType(BannerFrame));
    expect(banner.height, lessThan(100));
    expect(body.height, greaterThan(400));
  });
}
