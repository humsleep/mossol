import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart';
import '../minigames/registry.dart';
import 'widgets.dart';

/// 카톡형 이벤트 화면. 말풍선이 순서대로 나타나고, 끝나면 선택지가 뜬다.
class EventScreen extends StatefulWidget {
  final GameController c;
  const EventScreen({super.key, required this.c});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  Timer? _timer;
  int _waitLeft = 0;
  String? _eventId;
  final _scroll = ScrollController();

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _syncEvent();
  }

  @override
  void dispose() {
    _timer?.cancel();
    c.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    _syncEvent();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 프레임 사이에 화면이 내려갔을 수 있다. dispose 된 컨트롤러는 건드리지 않는다.
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _syncEvent() {
    final id = c.current?.id;
    if (id != _eventId) {
      _eventId = id;
      _timer?.cancel();
      _waitLeft = 0;
      _scheduleReveal();
    }
  }

  /// 다음 줄을 자동으로 공개. 대기 줄이면 카운트다운.
  void _scheduleReveal() {
    _timer?.cancel();
    final ev = c.current;
    if (ev == null || c.linesDone) return;
    final next = ev.lines[c.revealed];
    if (next.isWait) {
      _waitLeft = next.wait;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _waitLeft--);
        if (_waitLeft <= 0) {
          t.cancel();
          _finishWait();
        }
      });
      return;
    }
    final delay = switch (next.who) {
      'me' => 450,
      'narr' => 350,
      _ => 800,
    };
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      c.revealNext();
      _scheduleReveal();
    });
  }

  void _finishWait() {
    // 읽씹 대기는 자존감을 1 깎는다. 모쏠 체험의 핵심 감정.
    final s = c.state!;
    s.stats[Stat.esteem] = (s.stat(Stat.esteem) - 1).clamp(0, 100);
    c.revealNext();
    _scheduleReveal();
  }

  Future<void> _skipWait() async {
    final ok = await AdManager.instance.showRewarded();
    if (!mounted) return;
    if (ok) {
      _timer?.cancel();
      _waitLeft = 0;
      c.revealNext();
      _scheduleReveal();
    } else {
      _snack('광고를 불러오지 못했어요.');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final ev = c.current;
    if (ev == null) return const SizedBox.shrink();
    final s = c.state!;
    final partner = c.characterName(ev.character);
    final scheme = Theme.of(context).colorScheme;
    final visible = ev.lines.take(c.revealed).toList();
    final waiting =
        !c.linesDone && ev.lines[c.revealed].isWait && _waitLeft > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(partner.isEmpty ? ev.title : '$partner  ·  ${ev.title}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('D+${s.day}', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final l in visible)
                  ChatBubble(line: l, partnerName: partner),
                if (waiting)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(
                            '— 읽음 · $_waitLeft초째 답이 없다 —',
                            style: TextStyle(
                              color: scheme.outline,
                              fontSize: 12,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _skipWait,
                            icon: const Icon(
                              Icons.play_circle_outline,
                              size: 18,
                            ),
                            label: const Text('광고 보고 기다리지 않기'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!c.linesDone)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      '…',
                      style: TextStyle(color: scheme.outline, fontSize: 20),
                    ),
                  ),
              ],
            ),
          ),
          if (c.lastOutcome != null)
            _ResultPanel(c: c)
          else if (c.linesDone)
            _ChoicePanel(c: c),
        ],
      ),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  final GameController c;
  const _ChoicePanel({required this.c});

  /// 미니게임이 붙은 선택지는 먼저 게임을 돌리고 그 결과로 성패를 정한다.
  Future<void> _pick(BuildContext context, int index) async {
    final ev = c.current!;
    final id = ev.choices[index].minigame;
    if (id == null) {
      c.choose(index);
      return;
    }
    final result = await playMinigame(
      context,
      id,
      MinigameContext(state: c.state!, partner: c.characterOf(ev.character)),
    );
    c.choose(
      index,
      minigameSuccess: result.success,
      minigameCritical: result.critical,
      note: result.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ev = c.current!;
    // 선택지 4개 + 힌트 버튼이 큰 글꼴로 두 줄씩 접히면 대화 영역을 다 먹는다.
    // 패널은 화면의 55% 까지만 차지하고 그 안에서 스크롤한다.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final v in c.choices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: BorderSide(
                      color: c.hintIndex == v.index
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: c.hintIndex == v.index ? 2 : 1,
                    ),
                  ),
                  onPressed: v.locked ? null : () => _pick(context, v.index),
                  child: Row(
                    children: [
                      if (v.locked) const Icon(Icons.lock_outline, size: 16),
                      if (v.locked) const SizedBox(width: 6),
                      if (!v.locked && v.choice.minigame != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.sports_esports_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                      Expanded(child: Text(v.choice.text)),
                      if (v.locked)
                        Flexible(
                          child: Text(
                            v.reason,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.outline,
                            ),
                          ),
                        )
                      else if (v.choice.minigame != null)
                        Text(
                          minigameLabels[v.choice.minigame] ?? '미니게임',
                          style: TextStyle(fontSize: 11, color: scheme.primary),
                        )
                      else if (v.choice.chance != null)
                        Text(
                          c.onFire
                              ? '${(v.choice.chance! + 20).clamp(0, 100)}%'
                              : '${v.choice.chance}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onFire ? scheme.primary : scheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (ev.hint != null && c.hintIndex == null)
              TextButton.icon(
                onPressed: () async {
                  final ok = await AdManager.instance.showRewarded();
                  if (ok) c.revealHint();
                },
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('태현에게 물어보기 (광고)'),
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final GameController c;
  const _ResultPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = c.lastOutcome!;
    final parts = <String>[
      ...o.delta.stats.entries.map(
        (e) => '${Stat.label(e.key)} ${_sign(e.value)}',
      ),
      ...o.delta.affection.entries.map(
        (e) => '${c.characterName(e.key)} 호감 ${_sign(e.value)}',
      ),
      ...o.delta.trust.entries.map(
        (e) => '${c.characterName(e.key)} 신뢰 ${_sign(e.value)}',
      ),
    ];
    final headline = o.critical
        ? '크리티컬! 호감 2배'
        : !o.success
        ? '실패…'
        : o.comboStarted
        ? '물올랐다!'
        : '결과';
    return Container(
      color: o.critical
          ? scheme.primaryContainer
          : !o.success
          ? scheme.errorContainer
          : scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    headline,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (o.combo > 0)
                  ComboBadge(combo: o.combo, onFire: o.combo >= 3),
                if (o.comboBroken)
                  Text(
                    '콤보 끊김',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (c.minigameNote != null) ...[
              const SizedBox(height: 4),
              Text(c.minigameNote!, style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 4),
            Text(parts.isEmpty ? '변화 없음' : parts.join(' · ')),
            if (o.delta.album != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '흑역사 앨범에 추가: ${o.delta.album}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (c.canOfferUndo)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await AdManager.instance.showRewarded();
                        if (ok) c.undoChoice();
                      },
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('10초 전으로 (광고)'),
                    ),
                  ),
                if (c.canOfferUndo) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: c.continueAfterChoice,
                    child: const Text('계속'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sign(int v) => v > 0 ? '+$v' : '$v';
}
