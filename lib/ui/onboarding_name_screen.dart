import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/player_name.dart';
import '../engine/text_template.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 새 게임 이름 단계("뭐라고 불러 드릴까요?")와 설정의 "내 이름" 편집 화면.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.12, 대사 규격은 docs/NAME_GUIDE.md.
/// 입력창 1~6자(한글 완성형·영문·숫자, 띄어쓰기 없음) + 실시간 미리보기 말풍선
/// (`{name|아야}, 자?` 를 입력값으로 치환) + 하단 고정 패널([다음] + [건너뛰기]).
/// 패널은 본문 아래에 두어 키보드가 올라오면 함께 올라간다(가려지지 않는다).
///
/// 저장은 하지 않는다. 호출부가 [onSubmit]/[onSkip]/[onClear] 로 받아 처리한다.
class OnboardingNameScreen extends StatefulWidget {
  /// 입력창 처음 값(설정에서 편집할 때 지금 이름).
  final String? initial;

  /// 규칙을 통과한 이름(공백 제거 끝).
  final ValueChanged<String> onSubmit;

  /// 온보딩: 이름 없이 진행. null 이면 링크를 그리지 않는다.
  final VoidCallback? onSkip;

  /// 설정: 저장된 이름 지우기. null 이면 링크를 그리지 않는다.
  final VoidCallback? onClear;

  /// 1차 버튼 문구. 온보딩 [nextLabel], 설정 [saveLabel].
  final String submitLabel;

  const OnboardingNameScreen({
    super.key,
    this.initial,
    required this.onSubmit,
    this.onSkip,
    this.onClear,
    this.submitLabel = nextLabel,
  });

  static const title = '뭐라고 불러 드릴까요?';
  static const subtitle = '캐릭터들이 대화에서 이 이름으로 불러요';
  static const fieldHint = '예: 민지';
  static const rule = '한글 · 영문 · 숫자 6자까지, 띄어쓰기 없이';
  static const previewLabel = '이렇게 불러요';
  static const previewTemplate = '{name|아야}, 자?';
  static const nextLabel = '다음';
  static const saveLabel = '저장';
  static const skipLabel = '건너뛰기';
  static const clearLabel = '이름 지우기';
  static const note = '이 기기에만 저장돼요. 설정에서 바꿀 수 있어요';

  /// 미리보기 말풍선 문장. 이름이 비었거나 규칙에 어긋나면 이름 없는 대사(`자?`).
  static String previewFor(String raw) {
    final n = PlayerName.normalize(raw);
    return TextTemplate.fill(
      previewTemplate,
      name: PlayerName.isValid(n) ? n : null,
    );
  }

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.initial ?? '',
  )..addListener(_onChanged);

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// 한글 조합 중(밑줄 구간이 있음)인지. 조합 중에는 오류를 띄우지 않는다.
  bool get _composing {
    final c = _ctl.value.composing;
    return c.isValid && !c.isCollapsed;
  }

  String? get _error => _composing ? null : PlayerName.validate(_ctl.text);

  bool get _canSubmit => PlayerName.isValid(_ctl.text) && _error == null;

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(PlayerName.normalize(_ctl.text));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final preview = OnboardingNameScreen.previewFor(_ctl.text);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(),
      // 키보드가 올라오면 본문이 줄고 하단 패널이 키보드 위로 올라간다.
      resizeToAvoidBottomInset: true,
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
                    keepAll(OnboardingNameScreen.title),
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    keepAll(OnboardingNameScreen.subtitle),
                    style: context.text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sectionGap),
                  _field(context),
                  const SizedBox(height: AppSpace.lg),
                  NamePreviewBubble(text: preview),
                  const SizedBox(height: AppSpace.sectionGap),
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
                          keepAll(OnboardingNameScreen.note),
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
                  key: const Key('name-submit'),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(widget.submitLabel),
                ),
                for (final (key, label, onTap) in [
                  if (widget.onSkip != null)
                    (
                      'name-skip',
                      OnboardingNameScreen.skipLabel,
                      widget.onSkip,
                    ),
                  if (widget.onClear != null)
                    (
                      'name-clear',
                      OnboardingNameScreen.clearLabel,
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

  Widget _field(BuildContext context) {
    final scheme = context.scheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );
    final error = _error;
    return TextField(
      key: const Key('name-field'),
      controller: _ctl,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      style: context.text.titleLarge,
      // 글자 수는 자소 묶음 기준. 한글 조합 중에는 자르지 않고 조합이 끝난 뒤 자른다
      // (iOS 에서 조합 중에 자르면 입력기가 깨진다).
      maxLength: PlayerName.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
      inputFormatters: [NameInputFormatter()],
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              Semantics(
                label: '$maxLength자 중 $currentLength자',
                child: ExcludeSemantics(
                  child: Text(
                    '$currentLength/$maxLength',
                    style: context.tokens.numericSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      decoration: InputDecoration(
        hintText: OnboardingNameScreen.fieldHint,
        hintStyle: context.text.titleLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperText: OnboardingNameScreen.rule,
        helperStyle: context.text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperMaxLines: 2,
        errorText: error,
        errorStyle: context.text.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 2,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        border: border(scheme.outline, AppBorderWidth.hairline),
        enabledBorder: border(scheme.outline, AppBorderWidth.hairline),
        focusedBorder: border(scheme.primary, AppBorderWidth.emphasis),
        errorBorder: border(scheme.error, AppBorderWidth.hairline),
        focusedErrorBorder: border(scheme.error, AppBorderWidth.emphasis),
      ),
    );
  }
}

/// 이름 입력 거르개. 한글 조합 중(밑줄 구간)에는 손대지 않고, 조합이 끝난 값에서
/// 허용 밖 글자(공백·기호·이모지)를 뺀다. 조합 중에 글자를 지우면 iOS 입력기가 깨진다.
class NameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final c = newValue.composing;
    if (c.isValid && !c.isCollapsed) return newValue;
    final text = newValue.text;
    final buf = StringBuffer();
    var removedBeforeCursor = 0;
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : text.length;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (PlayerName.allowedChar.hasMatch(ch)) {
        buf.write(ch);
      } else if (i < cursor) {
        removedBeforeCursor++;
      }
    }
    final out = buf.toString();
    if (out == text) return newValue;
    final at = (cursor - removedBeforeCursor).clamp(0, out.length);
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: at),
    );
  }
}

/// 미리보기 말풍선: `'이렇게 불러요'` 라벨 + 상대 말풍선 한 개(상대 말풍선 토큰 그대로).
/// 스크린리더에는 "미리보기: 민지야, 자?" 한 덩어리.
class NamePreviewBubble extends StatelessWidget {
  final String text;
  const NamePreviewBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      label: '미리보기: $text',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              OnboardingNameScreen.previewLabel,
              style: context.text.labelMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Container(
              key: const Key('name-preview'),
              padding: AppInsets.bubble,
              decoration: BoxDecoration(
                color: t.bubbleTheirs,
                borderRadius: AppRadius.bubble(mine: false),
                border: Border.all(
                  color: t.bubbleBorder,
                  width: AppBorderWidth.hairline,
                ),
              ),
              child: Text(
                keepAll(text),
                style: context.text.bodyLarge?.copyWith(
                  color: context.scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
