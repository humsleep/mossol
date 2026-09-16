import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';

/// 스탯 6개를 바로 보여 주는 막대.
class StatBars extends StatelessWidget {
  final GameState state;
  final Map<String, int>? delta;
  const StatBars({super.key, required this.state, this.delta});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final k in Stat.visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    Stat.label(k),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (state.stat(k) / Stat.maxOf(k))
                          .clamp(0, 1)
                          .toDouble(),
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: k == Stat.stress ? scheme.error : scheme.primary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _label(k),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _deltaColor(k, scheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _label(String k) {
    final d = delta?[k];
    final v = state.stat(k).toString();
    if (d == null || d == 0) return v;
    return '$v (${d > 0 ? '+' : ''}$d)';
  }

  Color? _deltaColor(String k, ColorScheme scheme) {
    final d = delta?[k];
    if (d == null || d == 0) return null;
    final good = k == Stat.stress ? d < 0 : d > 0;
    return good ? Colors.green.shade700 : scheme.error;
  }
}

class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;
  final Duration nextIn;
  const HeartsRow({
    super.key,
    required this.hearts,
    required this.max,
    required this.nextIn,
  });

  @override
  Widget build(BuildContext context) {
    final mm = nextIn.inMinutes;
    final ss = nextIn.inSeconds % 60;
    return Semantics(
      label: '하트 $hearts개 / $max개',
      child: Row(
        children: [
          for (var i = 0; i < max; i++)
            ExcludeSemantics(
              child: Icon(
                i < hearts ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: Colors.pink.shade400,
              ),
            ),
          const SizedBox(width: 8),
          if (hearts < max)
            Flexible(
              child: Text(
                '다음 하트 ${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

/// 배너 슬롯. 광고를 지원하지 않는 환경에서는 빈 공간도 차지하지 않는다.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});
  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  static const _maxAttempts = 5;

  BannerAd? _ad;
  bool _loaded = false;
  int _attempts = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// SDK 초기화 전에 요청하면 조용히 실패한다. 동의 절차가 끝날 때까지 기다렸다 붙인다.
  void _load() {
    if (!mounted || !AdManager.instance.supported) return;
    if (!AdManager.instance.sdkInitialized) return _scheduleRetry();

    final template = AdManager.instance.createBanner();
    _ad = BannerAd(
      adUnitId: template.adUnitId,
      size: template.size,
      request: template.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          debugPrint('배너 로드 실패: ${err.message}');
          _scheduleRetry();
        },
      ),
    )..load();
  }

  /// 무한 재요청은 무효 트래픽으로 잡힌다. 횟수를 제한하고 간격을 늘린다.
  void _scheduleRetry() {
    if (!mounted || _attempts >= _maxAttempts) return;
    _attempts++;
    _retry?.cancel();
    final seconds = (1 << _attempts).clamp(2, 60);
    _retry = Timer(Duration(seconds: seconds), _load);
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Line line;
  final String partnerName;
  const ChatBubble({super.key, required this.line, required this.partnerName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (line.who == 'narr') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Text(
          line.text,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      );
    }
    if (line.who == 'sys') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            line.text.isEmpty ? '— 읽음 —' : line.text,
            style: TextStyle(color: scheme.outline, fontSize: 12),
          ),
        ),
      );
    }
    final me = line.who == 'me';
    final name = line.name ?? partnerName;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: me
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!me && name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                name,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: me ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(me ? 14 : 4),
                bottomRight: Radius.circular(me ? 4 : 14),
              ),
            ),
            child: Text(
              line.text,
              style: TextStyle(
                color: me ? scheme.onPrimary : scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 물오름(콤보) 표시. 3연속부터 색이 바뀐다.
class ComboBadge extends StatelessWidget {
  final int combo;
  final bool onFire;
  const ComboBadge({super.key, required this.combo, required this.onFire});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onFire ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            onFire ? Icons.local_fire_department : Icons.trending_up,
            size: 16,
            color: onFire ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            onFire ? '물올랐다 $combo' : '$combo연속',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onFire ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
