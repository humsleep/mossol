import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../game_controller.dart';
import 'widgets.dart';

/// 흑역사 앨범과 엔딩 앨범. 실패도 수집 요소가 된다.
class AlbumScreen extends StatelessWidget {
  final GameController c;
  const AlbumScreen({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('앨범'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '흑역사'),
              Tab(text: '엔딩'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ShameTab(c: c),
            _EndingTab(c: c),
          ],
        ),
        bottomNavigationBar: const BannerSlot(),
      ),
    );
  }
}

class _ShameTab extends StatelessWidget {
  final GameController c;
  const _ShameTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final album = c.state?.album ?? const <String>[];
    if (album.isEmpty) {
      return _Empty(
        icon: Icons.sentiment_satisfied_alt,
        title: '아직 흑역사가 없다',
        body: '실패한 선택은 여기에 카드로 남는다. 20개를 모으면 전용 엔딩이 열린다.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${album.length} / 20',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (album.length / 20).clamp(0, 1),
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = album.length - 1; i >= 0; i--)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
              ),
              title: Text(
                album[i],
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _EndingTab extends StatelessWidget {
  final GameController c;
  const _EndingTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final got = c.endingAlbum.toSet();
    final all = c.bundle.endings;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${got.length} / ${all.length}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: all.isEmpty ? 0 : got.length / all.length,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 16),
        for (final e in all)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                got.contains(e.id) ? Icons.check_circle : Icons.lock_outline,
                color: got.contains(e.id) ? scheme.primary : scheme.outline,
              ),
              title: Text(
                got.contains(e.id) ? e.name : '???',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: got.contains(e.id) ? null : scheme.outline,
                ),
              ),
              subtitle: Text(
                got.contains(e.id) ? e.epilogue : _hintFor(e, c),
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
              trailing: Text(
                _tier(e.tier),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  String _tier(String t) => switch (t) {
    'happy' => '해피',
    'good' => '굿',
    'bad' => '배드',
    'solo' => '솔로',
    'hidden' => '히든',
    _ => '',
  };

  /// 플래그 이름만으로는 무슨 조건인지 알 수 없어 사람 말로 옮긴다.
  static const _flagHints = {
    'hardcore': '하드코어 모드',
    'seoyeon_banmal': '서연에게 반말하기',
    'burnout_x3': '번아웃 3번',
    'album_20': '흑역사 20개 수집',
    'chose_loop': '100일째의 마지막 선택',
    'jiwoo_intro': '엄마의 소개팅 나가기',
    'yeeun_avoid_1': '옛날 얘기 피하기',
    'fake_record': '운동일지에 거짓말',
    'learner': '준호의 비결 묻기',
  };

  /// 미획득 엔딩에는 조건을 한 줄 힌트로 보여 준다.
  /// 하한이 있으면 "N 이상", 상한만 있으면 "N 이하"로 읽기 쉽게 옮긴다.
  String _hintFor(Ending e, GameController c) {
    final w = e.when;
    final parts = <String>[];

    void rel(Map<String, Range> src, String label) {
      for (final x in src.entries) {
        final name = c.characterName(x.key == '*' ? e.character : x.key);
        if (x.value.min > 0) {
          parts.add('$name $label ${x.value.min} 이상');
        } else if (x.value.max < 100) {
          parts.add('$name $label ${x.value.max} 이하');
        }
      }
    }

    rel(w.trust, '신뢰');
    rel(w.affection, '호감');
    for (final x in w.stats.entries) {
      parts.add(
        x.value.min > 0
            ? '${Stat.label(x.key)} ${x.value.min} 이상'
            : '${Stat.label(x.key)} ${x.value.max} 이하',
      );
    }
    if (w.anyAffection != null) {
      parts.add('호감 ${w.anyAffection!.min} 이상인 사람 ${w.anyAffection!.count}명');
    }
    for (final f in w.flags) {
      parts.add(_flagHints[f] ?? f);
    }
    if (w.run != null && w.run!.min > 1) parts.add('${w.run!.min}회차 이상');

    if (parts.isEmpty) {
      return e.isDefault ? '아무것도 이루지 못했을 때' : '조건을 찾아보자';
    }
    // 다 보여 주면 재미가 없다. 두 개까지만.
    final shown = parts.take(2).join(' · ');
    return parts.length > 2 ? '$shown 외 ${parts.length - 2}개' : shown;
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Empty({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
