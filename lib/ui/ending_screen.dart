import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart' show CenteredScrollColumn;
import 'album_screen.dart' show endingHintFor;
import 'design_system.dart';
import 'keepsake_share.dart';
import 'preference_screen.dart';
import 'retention_widgets.dart';
import 'scene_card.dart';
import 'scene_registry.dart';
import 'start_pick_sheet.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 회차의 마지막 화면. 규격은 docs/DESIGN_SYSTEM.md §2.5.
///
/// 이 화면은 보상이다. 엔딩 이름·등급·에필로그·기록을 한 덩어리로 묶어
/// 기념품처럼 보이게 하고, 그 덩어리만 [shareBoundaryKey] 로 따로 그려
/// 나중에 이미지로 저장·공유할 수 있게 해 둔다.
///
/// 기념품 아래에는 "다음 판" 카드([NextRunCard])가 붙는다(docs/ROADMAP.md Phase 1):
/// 권하는 캐릭터 · 못 본 엔딩 힌트 · (한쪽만 해 봤으면) 반대쪽 권유. 광고는 없고 흐름을
/// 막지 않는다 — 1차 버튼은 여전히 `N회차 시작` 하나다. 카드는 공유 캡처 경계 밖이다.
///
/// 기념품 바로 아래에 2차 버튼 하나가 더 붙는다: `엔딩 공유`([_ShareButton]).
/// [shareBoundaryKey] 는 진작 트리에 꽂혀 있었지만 `toImage()` 를 부르는 곳이 없어서
/// **죽은 경계**였다(docs/review/11_polish_verdict.md 10위). 이 장르의 자연 유입은
/// 전부 엔딩 인증샷에서 오므로, 그 하나를 잇는다([KeepsakeShare]).
class EndingScreen extends StatelessWidget {
  final GameController c;
  const EndingScreen({super.key, required this.c});

  /// 공유용 캡처 경계. [KeepsakeShare] 가 이 경계만 PNG 로 구워
  /// 버튼 없이 기념품 카드만 이미지로 내보낸다.
  static final GlobalKey shareBoundaryKey = GlobalKey();

  static const shareLabel = '엔딩 공유';

  /// 카드에 곁들여 나가는 문구. **앱 이름 한 줄로 고정이다** — 플레이어의 이름이나
  /// 기록을 붙이지 않는다. 나가는 개인적인 것은 카드에 이미 보이는 것뿐이어야 한다.
  static const shareText = '모쏠 탈출기 · 100일 연애 시뮬레이션';

  /// 그림을 못 굽거나 시트를 못 띄웠을 때. 던지지 않고 이 한 줄로 끝낸다.
  static const shareFailedText = '지금은 공유할 수 없어요';

  @override
  Widget build(BuildContext context) {
    final e = c.ending!;
    final s = c.state!;
    final next = c.nextRunSuggestion;
    final hintEnding = next?.hintEnding;
    final hint = hintEnding == null ? null : endingHintFor(hintEnding, c);
    final showNext =
        next != null &&
        (next.character != null || hint != null || next.otherSide != null);

    return Scaffold(
      body: SafeArea(
        // 에필로그가 길거나 글자가 커져도 넘치지 않게 스크롤 컬럼에 담는다.
        child: CenteredScrollColumn(
          padding: AppInsets.screen,
          children: [
            RepaintBoundary(
              key: shareBoundaryKey,
              child: _Keepsake(
                ending: e,
                epilogue: c.say(c.epilogueOf(e)),
                state: s,
                grade: _grade(s),
                tierLabel: _tierLabel(e.tier),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            // 기념품에 딸린 2차 버튼. 1차는 여전히 `N회차 시작` 하나다.
            const _ShareButton(),
            const SizedBox(height: AppSpace.xxl),
            if (showNext) ...[
              SizedBox(
                width: double.infinity,
                child: NextRunCard(
                  suggestion: next,
                  hintText: hint,
                  onPickCharacter: () => _next(context, tap: 'character'),
                  onOtherSide: next.otherSide == null
                      ? null
                      : () => _meetOtherSide(context, next.otherSide!),
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _next(context),
                child: Text(keepAll('${s.run + 1}회차 시작')),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton(onPressed: c.goHome, child: const Text('홈으로')),
          ],
        ),
      ),
    );
  }

  /// 반대쪽 캐스트 소개를 먼저 보여 주고, 고르면 그 쪽으로 다음 회차를 시작한다.
  /// 뒤로 가면 엔딩 화면에 그대로 남는다.
  Future<void> _meetOtherSide(BuildContext context, String side) async {
    final pref = await PreferenceScreen.show(
      context,
      c.bundle,
      side: side,
      playerMbti: c.playerMbti,
    );
    if (pref == null || !context.mounted) return;
    await _next(context, preference: pref, tap: 'other_side');
  }

  /// 다음 회차. 시작 카드(01_design §4.1)를 먼저 고른다 — 닫으면 엔딩 화면에 그대로 남는다.
  /// 시작 정의가 없으면 카드 없이 곧바로 클래식.
  /// [tap] 은 "다음 판" 카드에서 무엇을 눌렀는지(측정). 시작을 실제로 골랐을 때만 남긴다.
  Future<void> _next(
    BuildContext context, {
    String? preference,
    String? tap,
  }) async {
    final start = await StartPickSheet.showFor(
      context,
      c,
      preference: preference ?? c.state?.preference,
    );
    if (start == null || !context.mounted) return;
    if (tap != null) c.logNextRunTap(tap);
    await c.nextRun(preference: preference, start: start);
  }

  String _tierLabel(String tier) => switch (tier) {
    'happy' => '해피 엔딩',
    'good' => '굿 엔딩',
    'bad' => '배드 엔딩',
    'solo' => '솔로 엔딩',
    'hidden' => '히든 엔딩',
    _ => '엔딩',
  };

  /// 스탯 합과 최고 호감도로 S~F.
  String _grade(GameState s) {
    final core = [
      Stat.charm,
      Stat.talk,
      Stat.esteem,
      Stat.sense,
    ].fold<int>(0, (a, k) => a + s.stat(k));
    final best = s.relations.values.fold<int>(
      0,
      (a, r) => a > r.affection ? a : r.affection,
    );
    final score = core / 4 * 0.6 + best * 0.4;
    if (score >= 80) return 'S';
    if (score >= 65) return 'A';
    if (score >= 50) return 'B';
    if (score >= 35) return 'C';
    if (score >= 20) return 'D';
    return 'F';
  }
}

/// `엔딩 공유` 한 개. 누르면 기념품 카드를 PNG 로 굽고 시스템 공유 시트를 띄운다.
///
/// 누르는 동안 한 번만 돈다(두 번 눌러 시트가 두 장 뜨는 것을 막는다). 못 하면
/// 스낵바 한 줄([EndingScreen.shareFailedText]) — 예외는 밖으로 나가지 않는다.
class _ShareButton extends StatefulWidget {
  const _ShareButton();

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // 아이패드는 시트를 누른 자리에 띄운다. 버튼의 화면 좌표를 넘긴다.
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    var ok = false;
    try {
      ok = await KeepsakeShare.instance.shareBoundary(
        EndingScreen.shareBoundaryKey,
        pixelRatio: ratio,
        text: EndingScreen.shareText,
        origin: origin,
      );
    } catch (_) {
      // 어떤 이유로든 못 했으면 스낵바 한 줄로 끝낸다. 엔딩 화면이 예외로
      // 무너지면 3시간 걸어온 사람이 보상 화면을 잃는다.
      ok = false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text(EndingScreen.shareFailedText)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('ending-share'),
    onPressed: _busy ? null : _share,
    icon: const Icon(Icons.ios_share),
    label: const Text(EndingScreen.shareLabel),
  );
}

/// 기념품 덩어리: 티어 → 이름 → 에필로그 → 등급 카드.
///
/// 바탕을 `surface` 로 직접 칠해 둔다. 화면에서는 배경과 같은 색이라 보이지
/// 않지만, 이 경계만 이미지로 캡처했을 때 투명 배경이 되지 않게 한다.
class _Keepsake extends StatelessWidget {
  final Ending ending;

  /// 이름 치환을 끝낸 에필로그(docs/NAME_GUIDE.md).
  final String epilogue;
  final GameState state;
  final String grade;
  final String tierLabel;

  const _Keepsake({
    required this.ending,
    required this.epilogue,
    required this.state,
    required this.grade,
    required this.tierLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 엔딩 히어로(06 §1). 그림이 없으면 아무것도 그리지 않는다 — 지금 레이아웃 그대로.
            SceneScope(
              builder: (context, r) => EndingHero(
                path: SceneImages.forEnding(ending, registry: r),
                tier: ending.tier,
                name: ending.name,
                bundle: r.bundle,
              ),
            ),
            _TierPill(label: tierLabel),
            const SizedBox(height: AppSpace.xs),
            Text(
              keepAll(ending.name),
              textAlign: TextAlign.center,
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              keepAll(epilogue),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(height: 1.65),
            ),
            const SizedBox(height: AppSpace.xxxl),
            SizedBox(
              width: double.infinity,
              child: _GradeCard(state: state, grade: grade, tier: ending.tier),
            ),
          ],
        ),
      ),
    );
  }
}

/// 티어 라벨. 규격대로 primary 한 벌로 칠한다. 티어의 뜻은 색이 아니라
/// 낱말('배드 엔딩')이 전한다.
class _TierPill extends StatelessWidget {
  final String label;
  const _TierPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.rPill,
      ),
      child: Text(
        keepAll(label),
        style: context.text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 등급 카드. 이 화면에서 유일하게 떠 있는(`raised`) 요소다.
/// 좌측 3px 띠가 엔딩 티어를 색으로 거들고, 본문 글자색은 건드리지 않아
/// 라이트·다크 양쪽에서 대비를 유지한다.
class _GradeCard extends StatelessWidget {
  final GameState state;
  final String grade;
  final String tier;

  const _GradeCard({
    required this.state,
    required this.grade,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final accent = switch (tier) {
      'happy' => scheme.primary,
      'good' => t.success,
      'bad' => t.danger,
      'hidden' => scheme.tertiary,
      _ => t.neutralAccent.base,
    };

    return AppCard(
      raised: true,
      accentStripe: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('연애 등급', style: context.text.labelMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            grade,
            style: context.text.displayMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            keepAll(
              '${state.run}회차 · D+${state.day - 1} · 흑역사 ${state.album.length}개',
            ),
            textAlign: TextAlign.center,
            style: t.numericSmall,
          ),
        ],
      ),
    );
  }
}
