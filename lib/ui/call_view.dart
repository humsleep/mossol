/// 상대가 먼저 거는 전화(`format: "call"`) 화면. docs/MOMENTS_SPEC.md §1.1,
/// docs/DESIGN_SYSTEM.md §2.3 "전화 변형" · §3.2 `CallBackdrop` 외.
///
/// 이 게임의 "유료 게임 같은 순간" 이다. 라이트 모드에서도 **항상 다크 테마**로 그린다 —
/// 밤에 걸려 온 전화처럼 화면 전체가 자수정빛으로 바뀌어야 채팅과 다른 사건으로 읽힌다.
/// 색은 전부 `AppTheme.dark` 의 토큰에서 꺼내므로 대비 규칙은 다크 모드와 같다.
///
/// 트레이드드레스 회피: 둥근 초록/빨강 버튼, 밀어서 받기, 상단 발신자 배너, 흰 배경 위
/// 키패드 격자 같은 특정 OS·메신저의 통화 화면 요소를 쓰지 않는다. 버튼은 이 앱의 기본
/// 버튼(받기 = 로즈 1차 `FilledButton`, 거절 = `OutlinedButton`)을 가로로 나란히 둔다.
/// 진동·소리는 없다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/models.dart';
import 'design_system.dart';
import 'widgets.dart';

/// `mm:ss`. 한 시간을 넘으면 분이 60 을 넘어 그대로 센다(통화가 그렇게 길 일은 없다).
String formatCallTime(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 전화 화면 공통 바탕. 다크 테마를 강제하고 자수정 → 밤 잉크 세로 그라데이션을 깐다.
///
/// 그라데이션 양 끝(`AppPalette.violet900` → `scheme.surface`)은 둘 다 충분히 어두워서
/// 어느 지점에서도 `onSurface`·`onSurfaceVariant` 글자가 4.5:1 을 넘는다.
class CallBackdrop extends StatelessWidget {
  final Widget child;
  const CallBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 배경이 항상 어두우므로 상태 표시줄(시계·배터리)도 밝은 글자로. 앱이 라이트
    // 모드면 시스템이 검은 글자를 써서 자수정 배경 위에서 거의 안 보인다.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: AppTheme.dark,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.scheme.surface,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppPalette.violet900, context.scheme.surface],
                  stops: const [0, 0.85],
                ),
              ),
              child: SafeArea(bottom: false, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이니셜 원형 아바타(전화용 큰 크기). 사진 대신 강조색 이니셜(§4.3).
class _CallAvatar extends StatelessWidget {
  final String name;
  final CharacterAccent accent;
  final double size;
  const _CallAvatar({
    required this.name,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final style = size >= 64
        ? context.text.headlineMedium
        : context.text.titleMedium;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.container,
        shape: BoxShape.circle,
        border: Border.all(color: accent.base, width: AppBorderWidth.emphasis),
      ),
      child: Text(
        name.isEmpty ? '' : name.characters.first,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: style?.copyWith(
          color: accent.onContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 아바타 주변 펄스 링. 링 두 개가 번갈아 퍼지며 사라진다.
/// 동작 줄이기면 멈춘 링 하나만 그린다(깜빡임·흔들림 없음, §1.10).
class PulseAvatar extends StatefulWidget {
  final String name;
  final CharacterAccent accent;

  /// 아바타 지름. 링은 바깥으로 [ringSpread] 만큼 더 퍼진다.
  final double size;
  final double ringSpread;

  const PulseAvatar({
    super.key,
    required this.name,
    required this.accent,
    this.size = 96,
    this.ringSpread = AppSpace.xxxl,
  });

  /// 링 한 바퀴 시간. 호흡보다 약간 빠른, 울리는 느낌의 속도.
  static const period = Duration(milliseconds: 1600);

  @override
  State<PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<PulseAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: PulseAvatar.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c
        ..stop()
        ..value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size + widget.ringSpread * 2;
    final reduced = AppMotion.reduced(context);
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            t: _c.value,
            color: widget.accent.base,
            inner: widget.size / 2,
            spread: widget.ringSpread,
            rings: reduced ? 1 : 2,
          ),
          child: child,
        ),
        child: Center(
          child: _CallAvatar(
            name: widget.name,
            accent: widget.accent,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  final double inner;
  final double spread;
  final int rings;

  _RingPainter({
    required this.t,
    required this.color,
    required this.inner,
    required this.spread,
    required this.rings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < rings; i++) {
      final p = (t + i / rings) % 1.0;
      final r = inner + spread * p;
      final alpha = rings == 1 ? 0.35 : (1 - p) * 0.55;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppBorderWidth.emphasis + (1 - p) * AppSpace.xs
          ..color = color.withValues(alpha: math.max(0, alpha)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.color != color || old.rings != rings;
}

/// 1단계: 걸려 오는 전화. 큰 아바타(펄스 링) · 이름 · "전화가 왔어요" · 받기/거절.
class IncomingCallView extends StatelessWidget {
  final String name;

  /// 캐릭터 id. 강조색을 다크 테마에서 다시 꺼낸다.
  final String? characterId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallView({
    super.key,
    required this.name,
    required this.characterId,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return CallBackdrop(
      child: Builder(
        builder: (context) {
          final scheme = context.scheme;
          final accent = context.tokens.accentFor(characterId);
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: AppInsets.screen,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            '전화가 왔어요',
                            textAlign: TextAlign.center,
                            style: context.text.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        ExcludeSemantics(
                          child: PulseAvatar(name: name, accent: accent),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.headlineMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenX,
                    AppSpace.lg,
                    AppSpace.screenX,
                    AppSpace.xxl,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDecline,
                          icon: const Icon(Icons.call_end),
                          label: const Text('거절'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.call),
                          label: const Text('받기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 2단계: 통화 중. 상단 이름·타이머, 가운데 자막, 아래 [bottom](선택지·결과 패널).
class ActiveCallView extends StatelessWidget {
  final String name;
  final String? characterId;

  /// 통화 시간(초). [ended] 면 "통화 종료" 와 함께 멈춘 값을 보여 준다.
  final int seconds;
  final bool ended;

  /// 자막 목록. 호출부가 스크롤 컨트롤러와 함께 만든다.
  final List<Widget> subtitles;
  final ScrollController? scroll;

  /// 선택지·결과 패널. 없으면 자막만.
  final Widget? bottom;

  const ActiveCallView({
    super.key,
    required this.name,
    required this.characterId,
    required this.seconds,
    required this.subtitles,
    this.ended = false,
    this.scroll,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return CallBackdrop(
      child: Builder(
        builder: (context) {
          final scheme = context.scheme;
          final t = context.tokens;
          final accent = t.accentFor(characterId);
          final time = formatCallTime(seconds);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenX,
                  AppSpace.md,
                  AppSpace.screenX,
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: _CallAvatar(
                        name: name,
                        accent: accent,
                        size: AppSpace.huge,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            ended ? '통화 종료' : '통화 중',
                            maxLines: 1,
                            style: context.text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Semantics(
                      label: '통화 시간 $time',
                      excludeSemantics: true,
                      child: Text(
                        time,
                        style: t.numericMedium.copyWith(
                          color: ended
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: AppBorderWidth.hairline,
                thickness: AppBorderWidth.hairline,
                color: scheme.outlineVariant,
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                  children: subtitles,
                ),
              ),
              ?bottom,
            ],
          );
        },
      ),
    );
  }
}

/// 통화 자막 한 줄. `them` 은 크게 가운데, `me` 는 작게 오른쪽, `narr` 는 기울임,
/// 대기 줄은 "…(침묵)". 사진 줄은 가운데 사진 카드 + (있으면) 자막.
class CallSubtitle extends StatelessWidget {
  final Line line;
  final String partnerName;
  final String? characterId;

  const CallSubtitle({
    super.key,
    required this.line,
    required this.partnerName,
    this.characterId,
  });

  /// 대기 줄 표시 문구. 테스트가 찾는다.
  static const silence = '…(침묵)';

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final t = context.tokens;
    final text = context.text;

    Widget pad(Widget child, {AlignmentGeometry align = Alignment.center}) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl,
            vertical: AppSpace.sm,
          ),
          child: Align(alignment: align, child: child),
        );

    final photo = line.photo;
    if (photo != null) {
      final me = line.who == 'me';
      return pad(
        Column(
          crossAxisAlignment: me
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
          children: [
            PhotoBubble(
              photo: photo,
              accent: t.accentFor(characterId),
              width: MediaQuery.sizeOf(context).width * 0.6,
            ),
            if (line.text.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                line.text,
                textAlign: me ? TextAlign.end : TextAlign.center,
                style: (me ? text.bodyMedium : text.titleLarge)?.copyWith(
                  color: me ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ],
          ],
        ),
        align: me ? AlignmentDirectional.centerEnd : Alignment.center,
      );
    }

    if (line.isWait) {
      return pad(
        Text(
          silence,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    switch (line.who) {
      case 'me':
        return pad(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: Text(
              line.text,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          align: AlignmentDirectional.centerEnd,
        );
      case 'narr':
        return pad(
          Text(
            line.text,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: t.narration,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        );
      case 'sys':
        return pad(
          Text(
            line.text.isEmpty ? '…' : line.text,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        );
      default:
        final other = line.name != null && line.name != partnerName;
        return pad(
          Column(
            children: [
              if (other)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: Text(
                    line.name!,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                line.text,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
        );
    }
  }
}

/// 자막 자리의 "상대가 말하는 중" 표시. 채팅의 타이핑 말풍선과 같은 문구 '…'.
class CallTyping extends StatelessWidget {
  const CallTyping({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
    child: Center(
      child: Text(
        '…',
        style: context.text.titleLarge?.copyWith(
          color: context.scheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
