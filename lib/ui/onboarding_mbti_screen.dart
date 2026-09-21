import 'package:flutter/material.dart';

import '../engine/mbti.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 한 축의 한쪽 글자: 글자 · 짧은 이름 · 한 줄 힌트.
typedef MbtiSide = ({String letter, String name, String hint});

/// 새 게임 MBTI 단계("나의 MBTI는?")와 설정의 "내 MBTI" 편집 화면. docs/MBTI_SPEC.md §2.1.
///
/// 네 축(E/I, S/N, T/F, J/P)마다 두 칸 토글. 네 축을 다 고르면 `다음`. `잘 몰라요` 는
/// 4문항 간이 테스트([MbtiQuizScreen])를 띄우고, 결과를 토글에 채운 뒤 "대충 맞아요?" 로
/// 고칠 수 있게 한다. `건너뛰기` 는 모름(null). 저장은 하지 않는다 — 호출부가
/// [onSubmit]/[onSkip]/[onClear] 로 받아 처리한다(이름 단계와 같은 구조).
class OnboardingMbtiScreen extends StatefulWidget {
  /// 처음 값(설정에서 편집할 때 지금 MBTI).
  final String? initial;

  /// 네 축을 다 고른 값(대문자 4글자).
  final ValueChanged<String> onSubmit;

  /// 온보딩: MBTI 없이 진행. null 이면 링크를 그리지 않는다.
  final VoidCallback? onSkip;

  /// 설정: 저장된 MBTI 지우기. null 이면 링크를 그리지 않는다.
  final VoidCallback? onClear;

  /// 1차 버튼 문구. 온보딩 [nextLabel], 설정 [saveLabel].
  final String submitLabel;

  /// 설정에서 열 때 보이는 안내("다음 새 게임부터 적용"). null 이면 온보딩 안내.
  final String? note;

  const OnboardingMbtiScreen({
    super.key,
    this.initial,
    required this.onSubmit,
    this.onSkip,
    this.onClear,
    this.submitLabel = nextLabel,
    this.note,
  });

  static const title = '나의 MBTI는?';
  static const subtitle = '몇몇 장면과 대사, 캐릭터와의 궁합이 달라져요';
  static const unsureLabel = '잘 몰라요';
  static const nextLabel = '다음';
  static const saveLabel = '저장';
  static const skipLabel = '건너뛰기';
  static const clearLabel = 'MBTI 지우기';
  static const onboardingNote = '몰라도 괜찮아요. 설정에서 언제든 바꿀 수 있어요';
  static const settingsNote = '다음 새 게임부터 적용돼요. 진행 중인 회차는 그대로예요';
  static const quizNote = '간이 테스트로 채웠어요. 대충 맞아요? 다르면 눌러서 고쳐 주세요';
  static const pendingLabel = '네 가지를 모두 골라 주세요';

  /// 축마다 두 쪽. 순서가 곧 화면 순서이자 유형 글자 순서.
  static const axes = <(MbtiSide, MbtiSide)>[
    (
      (letter: 'E', name: '외향', hint: '사람을 만나면 충전돼요'),
      (letter: 'I', name: '내향', hint: '혼자 있으면 충전돼요'),
    ),
    (
      (letter: 'S', name: '감각', hint: '눈앞의 사실이 먼저예요'),
      (letter: 'N', name: '직관', hint: '떠오르는 상상이 먼저예요'),
    ),
    (
      (letter: 'T', name: '사고', hint: '해결책으로 마음을 전해요'),
      (letter: 'F', name: '감정', hint: '공감으로 마음을 전해요'),
    ),
    (
      (letter: 'J', name: '판단', hint: '계획이 있어야 편해요'),
      (letter: 'P', name: '인식', hint: '그때그때가 편해요'),
    ),
  ];

  /// 고른 글자 넷([picks], 축 순서, 안 고른 축은 null)을 유형으로. 하나라도 비면 null.
  static String? typeOf(List<String?> picks) =>
      picks.length == 4 && picks.every((p) => p != null) ? picks.join() : null;

  @override
  State<OnboardingMbtiScreen> createState() => _OnboardingMbtiScreenState();
}

class _OnboardingMbtiScreenState extends State<OnboardingMbtiScreen> {
  late final List<String?> _picks = _initialPicks();

  /// 간이 테스트 결과로 채웠는지. 채웠으면 "대충 맞아요?" 안내를 보인다.
  bool _fromQuiz = false;

  List<String?> _initialPicks() {
    final m = Mbti.parse(widget.initial);
    return m == null ? List.filled(4, null) : m.split('');
  }

  String? get _type => OnboardingMbtiScreen.typeOf(_picks);

  void _pick(int axis, String letter) => setState(() => _picks[axis] = letter);

  Future<void> _quiz() async {
    final r = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const MbtiQuizScreen()));
    if (r == null || !mounted) return;
    setState(() {
      for (var i = 0; i < 4; i++) {
        _picks[i] = r[i];
      }
      _fromQuiz = true;
    });
  }

  void _submit() {
    final t = _type;
    if (t != null) widget.onSubmit(t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final type = _type;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screenX,
                AppSpace.xs,
                AppSpace.screenX,
                AppSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    keepAll(OnboardingMbtiScreen.title),
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    keepAll(OnboardingMbtiScreen.subtitle),
                    style: context.text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sectionGap),
                  for (final (i, (a, b)) in OnboardingMbtiScreen.axes.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpace.gap),
                      // 두 칸 높이를 맞춘다(힌트가 한쪽만 두 줄이어도 같은 높이).
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (j, side) in [a, b].indexed) ...[
                              if (j > 0) const SizedBox(width: AppSpace.sm),
                              Expanded(
                                child: MbtiAxisOption(
                                  key: Key('mbti-${side.letter}'),
                                  side: side,
                                  selected: _picks[i] == side.letter,
                                  onTap: () => _pick(i, side.letter),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpace.lg),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      keepAll(
                        type == null
                            ? OnboardingMbtiScreen.pendingLabel
                            : '나는 $type',
                      ),
                      key: const Key('mbti-result'),
                      textAlign: TextAlign.center,
                      style: type == null
                          ? context.text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )
                          : context.text.titleMedium,
                    ),
                  ),
                  if (_fromQuiz) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      keepAll(OnboardingMbtiScreen.quizNote),
                      key: const Key('mbti-quiz-note'),
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Center(
                    child: TextButton.icon(
                      key: const Key('mbti-unsure'),
                      onPressed: _quiz,
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text(OnboardingMbtiScreen.unsureLabel),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxs),
                        child: Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          keepAll(
                            widget.note ?? OnboardingMbtiScreen.onboardingNote,
                          ),
                          style: context.text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          BottomPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  key: const Key('mbti-submit'),
                  onPressed: type == null ? null : _submit,
                  child: Text(widget.submitLabel),
                ),
                for (final (key, label, onTap) in [
                  if (widget.onSkip != null)
                    (
                      'mbti-skip',
                      OnboardingMbtiScreen.skipLabel,
                      widget.onSkip,
                    ),
                  if (widget.onClear != null)
                    (
                      'mbti-clear',
                      OnboardingMbtiScreen.clearLabel,
                      widget.onClear,
                    ),
                ]) ...[
                  const SizedBox(height: AppSpace.xs),
                  TextButton(
                    key: Key(key),
                    onPressed: onTap,
                    // 2차 링크는 1차 버튼과 다른 무게(DS §5.7 예외 ②와 같은 처리).
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: Text(label),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 축 토글 한 칸: 글자(`titleLarge`) + 이름 + 힌트 한 줄. 고르면 테두리 2px·배경·체크 아이콘이
/// 함께 바뀐다(색만으로 상태를 전하지 않는다). 스크린리더에는 "E 외향. 사람을 만나면 충전돼요".
class MbtiAxisOption extends StatelessWidget {
  final MbtiSide side;
  final bool selected;
  final VoidCallback onTap;

  const MbtiAxisOption({
    super.key,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final sub = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '${side.letter} ${side.name}. ${side.hint}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rMd,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? AppBorderWidth.emphasis : AppBorderWidth.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        side.letter,
                        style: context.text.titleLarge?.copyWith(color: fg),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          side.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(color: sub),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, size: 18, color: fg),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    keepAll(side.hint),
                    style: context.text.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 간이 테스트 한 문항: 상황 질문 + 답 두 개(각각 그 축의 한쪽 글자).
typedef MbtiQuestion = ({
  String question,
  (String, String) a,
  (String, String) b,
});

/// `잘 몰라요` 의 4문항 간이 테스트. 축마다 상황 질문 하나, 답 두 개. 답을 누르면 다음 문항,
/// 마지막 답을 누르면 결과 유형(대문자 4글자)으로 닫힌다. 뒤로 가면 앞 문항(첫 문항이면 null).
class MbtiQuizScreen extends StatefulWidget {
  const MbtiQuizScreen({super.key});

  static const title = '간단히 알아볼게요';
  static const note = '4문항 간이 테스트예요. 정식 검사는 아니에요';

  /// 축 순서(E/I, S/N, T/F, J/P). 답 = (글자, 문장).
  static const questions = <MbtiQuestion>[
    (
      question: '긴 한 주가 끝난 금요일 밤, 나는?',
      a: ('E', '친구들을 불러 맛있는 걸 먹으러 간다'),
      b: ('I', '집에서 좋아하는 걸 하며 조용히 쉰다'),
    ),
    (
      question: '하늘에 커다란 구름이 떠 있다. 먼저 드는 생각은?',
      a: ('S', '비 오려나? 우산 챙겨야겠다'),
      b: ('N', '고래 닮았다. 저 고래는 어디로 가는 걸까'),
    ),
    (
      question: '친구가 "나 오늘 면접 망쳤어"라고 톡을 보냈다. 내 첫 답장은?',
      a: ('T', '어떤 질문에서 막혔어? 다음엔 이렇게 해 보자'),
      b: ('F', '헐 많이 속상했겠다… 오늘은 푹 쉬어'),
    ),
    (
      question: '내일 친구와 놀기로 했다. 오늘 밤 나는?',
      a: ('J', '몇 시에 어디서 뭘 할지 정해 둬야 편하다'),
      b: ('P', '만나서 정하면 되지! 일단 잔다'),
    ),
  ];

  @override
  State<MbtiQuizScreen> createState() => _MbtiQuizScreenState();
}

class _MbtiQuizScreenState extends State<MbtiQuizScreen> {
  final List<String> _answers = [];

  int get _index => _answers.length;

  void _answer(String letter) {
    final next = [..._answers, letter];
    if (next.length == MbtiQuizScreen.questions.length) {
      Navigator.of(context).pop(next.join());
      return;
    }
    setState(() => _answers.add(letter));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final q = MbtiQuizScreen.questions[_index];
    final n = MbtiQuizScreen.questions.length;
    return PopScope(
      canPop: _answers.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_answers.removeLast);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(
            '${_index + 1} / $n',
            key: const Key('mbti-quiz-progress'),
            style: context.tokens.numericSmall,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            AppSpace.xs,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          children: [
            Text(
              keepAll(MbtiQuizScreen.title),
              style: context.text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              keepAll(q.question),
              key: Key('mbti-quiz-q$_index'),
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sectionGap),
            for (final (i, (letter, text)) in [q.a, q.b].indexed) ...[
              if (i > 0) const SizedBox(height: AppSpace.gap),
              AppCard(
                key: Key('mbti-quiz-$letter'),
                onTap: () => _answer(letter),
                padding: AppInsets.cardTight,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(keepAll(text), style: context.text.bodyLarge),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.sectionGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xxs),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    keepAll(MbtiQuizScreen.note),
                    style: context.text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
