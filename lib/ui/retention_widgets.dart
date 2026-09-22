import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/retention.dart';
import '../engine/text_template.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 리텐션 장치의 화면 조각(docs/ROADMAP.md Phase 1). 로직은 lib/engine/retention.dart.
///
/// - [NextRunCard]: 엔딩 화면 "다음 판" 카드.
/// - [TomorrowLine]: 정산의 "내일 ○○에게서 연락이 올 것 같다".
/// - [PreviousRunNote]: 새 회차 첫날·홈의 "지난 판엔 …으로 끝났다".
///
/// 어느 것도 광고를 띄우지 않고 흐름을 막지 않는다.

/// 엔딩 화면 "다음 판" 카드. 기념품(공유 캡처 경계) 밖, 1차 버튼 위에 놓는다.
///
/// 캐릭터 줄(초상화 · 이름 · 한 줄 매력 · 궁합/중립 문장)을 누르면 [onPickCharacter],
/// "반대쪽 캐릭터도 만나 보기" 를 누르면 [onOtherSide]. 힌트 줄은 읽기 전용.
class NextRunCard extends StatelessWidget {
  final NextRunSuggestion suggestion;

  /// 못 본 엔딩 힌트 문장(이름 치환 끝, `endingHintFor`). 없으면 줄을 그리지 않는다.
  final String? hintText;

  final VoidCallback onPickCharacter;
  final VoidCallback? onOtherSide;

  const NextRunCard({
    super.key,
    required this.suggestion,
    required this.hintText,
    required this.onPickCharacter,
    this.onOtherSide,
  });

  static const title = '다음 판';
  static const otherSideLabel = '반대쪽 캐릭터도 만나 보기';

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final t = context.tokens;
    final ch = suggestion.character;
    final hint = hintText;
    return AppCard(
      key: const Key('next-run-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: context.text.labelMedium),
          if (ch != null) ...[
            const SizedBox(height: AppSpace.sm),
            _SuggestRow(
              character: ch,
              reason: suggestion.reason,
              onTap: onPickCharacter,
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              key: const Key('next-run-hint'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xxs),
                  child: Icon(Icons.lightbulb_outline, size: 16, color: t.info),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    keepAll('못 본 엔딩 힌트 · $hint'),
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (onOtherSide != null) ...[
            const SizedBox(height: AppSpace.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('next-run-other-side'),
                onPressed: onOtherSide,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(keepAll(otherSideLabel)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestRow extends StatelessWidget {
  final CharacterDef character;
  final String reason;
  final VoidCallback onTap;
  const _SuggestRow({
    required this.character,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = context.tokens.accentFor(character.id);
    final name = character.name;
    final wa = TextTemplate.particleFor(name, '과와');
    final tagline = character.tagline;
    return Semantics(
      button: true,
      label: '다음엔 $name$wa 시작하기. $reason',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('next-run-character'),
        onTap: onTap,
        borderRadius: AppRadius.rLg,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(
              children: [
                CharacterAvatar(
                  name: name,
                  accent: accent,
                  characterId: character.id,
                  size: 56,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        keepAll('다음엔 $name$wa 어때요?'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                      if (tagline.isNotEmpty)
                        Text(
                          keepAll(tagline),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        keepAll(reason),
                        key: const Key('next-run-reason'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // 본문 대비(4.5:1)를 지키려고 글자색은 그대로 둔다.
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 정산의 내일 예고 한 줄. [line] 은 "내일 서연에게서 연락이 올 것 같다",
/// [preview] 는 모먼트 알림 미리보기(이름 치환 끝) — 있으면 아래에 흐린 따옴표 줄.
class TomorrowLine extends StatelessWidget {
  final String characterId;
  final String line;
  final String? preview;
  const TomorrowLine({
    super.key,
    required this.characterId,
    required this.line,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    final p = preview;
    return Row(
      key: const Key('tomorrow-line'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xxs),
          child: Icon(
            Icons.mark_chat_unread_outlined,
            size: 18,
            color: context.tokens.accentFor(characterId).base,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(keepAll(line), style: context.text.bodyMedium),
              if (p != null)
                Text(
                  keepAll('“$p”'),
                  key: const Key('tomorrow-preview'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "지난 판엔 서연과 대등한 연인으로 끝났다". 조용한 한 줄(아이콘 + 흐린 글씨).
class PreviousRunNote extends StatelessWidget {
  final String text;
  const PreviousRunNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = context.scheme.onSurfaceVariant;
    return Row(
      key: const Key('previous-run'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xxs),
          child: Icon(Icons.history, size: 16, color: muted),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            keepAll(text),
            style: context.text.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
