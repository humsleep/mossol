/// 상대가 먼저 보낸 톡 알림(`preview`). docs/MOMENTS_SPEC.md §1.2,
/// docs/DESIGN_SYSTEM.md §2.3 "알림 변형" · §3.2 `NotificationCard`.
///
/// 이벤트 대화가 열리기 직전, 폰 잠금화면처럼 어두운 바탕 위로 알림 카드 한 장이
/// 위에서 내려온다. 탭하거나 [NotificationPreview.autoOpen] 뒤에 대화가 열린다.
/// 전화 화면과 같은 이유로 항상 다크 테마(`CallBackdrop`)에 그린다.
///
/// 특정 OS 알림의 모양(앱 아이콘 + 앱 이름 머리줄, 반투명 블러 카드)을 흉내내지 않는다.
/// 카드는 이 앱의 표면 단계 + 1px 테두리 카드이고, 머리에 보낸 사람 이니셜 원형을 둔다.
library;

import 'package:flutter/material.dart';

import 'call_view.dart';
import 'design_system.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 알림 카드 한 장. 탭하면 [onOpen].
class NotificationCard extends StatelessWidget {
  final String name;
  final String? characterId;
  final String preview;
  final VoidCallback onOpen;

  const NotificationCard({
    super.key,
    required this.name,
    required this.characterId,
    required this.preview,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      button: true,
      label: '$name 새 메시지: $preview',
      hint: '대화 열기',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppBorderWidth.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
            child: Padding(
              padding: AppInsets.card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CharacterAvatar(
                    name: name,
                    characterId: characterId,
                    accent: context.tokens.accentFor(characterId),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              '지금',
                              style: context.text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        Text(
                          keepAll(preview),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
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

/// 잠금화면 한 장: 어두운 바탕, 위에서 내려오는 [NotificationCard], 아래 "탭해서 열기".
///
/// 자동 열림 타이머는 호출부(`EventScreen`)가 가진다. 여기서는 등장 연출만 한다.
/// 동작 줄이기면 호출부가 이 화면을 아예 건너뛴다.
class NotificationPreview extends StatefulWidget {
  final String name;
  final String? characterId;
  final String preview;
  final int day;
  final VoidCallback onOpen;

  const NotificationPreview({
    super.key,
    required this.name,
    required this.characterId,
    required this.preview,
    required this.day,
    required this.onOpen,
  });

  /// 탭하지 않아도 이만큼 뒤에 대화가 열린다(규격 1.8초).
  static const autoOpen = Duration(milliseconds: 1800);

  @override
  State<NotificationPreview> createState() => _NotificationPreviewState();
}

class _NotificationPreviewState extends State<NotificationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.dSlow,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: AppMotion.standard));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallBackdrop(
      child: Builder(
        builder: (context) {
          final scheme = context.scheme;
          return SingleChildScrollView(
            padding: AppInsets.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: AppSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Text(
                      keepAll('D+${widget.day}'),
                      style: context.tokens.numericSmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                SlideTransition(
                  position: _slide,
                  child: NotificationCard(
                    name: widget.name,
                    characterId: widget.characterId,
                    preview: widget.preview,
                    onOpen: widget.onOpen,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                ExcludeSemantics(
                  child: Text(
                    '탭해서 열기',
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
