import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import '../ads/ad_manager.dart';
import '../analytics/analytics.dart';
import '../audio/sfx_service.dart';
import '../engine/event_engine.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import '../minigames/minigame.dart';
import '../minigames/registry.dart';
import 'call_view.dart';
import 'design_system.dart';
import 'notification_card.dart';
import 'scene_card.dart';
import 'scene_registry.dart';
import 'widgets.dart';
import 'keep_all.dart';

/// 전화 이벤트의 단계. docs/MOMENTS_SPEC.md §1.1.
enum CallStage { ringing, active, declined }

/// 하루 안의 가짜 시계(docs/overhaul/02_game_loop.md §3 P1). 표현 전용 — 엔진·세이브 무관.
///
/// 오늘 큐의 i 번째 이벤트에 시간대를 준다: 4개면 09·12·16·21, 3개면 10·15·21, 2개면 12·20,
/// 1개면 19. 분은 `stableSeed(seed, day, 'clock$i') % 60`. 줄마다 +1분, `wait` 줄은 그 초만큼 더한다.
/// 통화·미니게임 전후로는 흐르지 않는다.
abstract final class ChatClock {
  static const _slots = <int, List<int>>{
    1: [19],
    2: [12, 20],
    3: [10, 15, 21],
    4: [9, 12, 16, 21],
  };

  /// [total] 개 중 [index](0부터) 번째 이벤트의 시작 시각(자정부터 초). 5개 이상이면
  /// 4칸 표에 비례해 얹는다.
  static int startSeconds({
    required int seed,
    required int day,
    required int index,
    required int total,
  }) {
    final n = total.clamp(1, 4);
    final table = _slots[n]!;
    final i = total <= 4
        ? index.clamp(0, n - 1)
        : (index * n ~/ total).clamp(0, n - 1);
    final minute = EventEngine.stableSeed(seed, day, 'clock$index') % 60;
    return table[i] * 3600 + minute * 60;
  }

  /// `오후 4:12` — 한국어 12시간, 앞 0 없음.
  static String label(int seconds) {
    final h = (seconds ~/ 3600) % 24;
    final m = (seconds ~/ 60) % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mm = m < 10 ? '0$m' : '$m';
    return '${h < 12 ? '오전' : '오후'} $h12:$mm';
  }

  /// [lines] 각 줄의 시각(초). [start] 에서 줄마다 +60, `wait` 줄은 그 초만큼 더.
  static List<int> timesFor(List<Line> lines, int start) {
    final out = <int>[];
    var t = start;
    for (final l in lines) {
      out.add(t);
      t += 60;
      if (l.isWait) t += l.wait;
    }
    return out;
  }
}

/// 채팅형 이벤트 화면. 말풍선이 순서대로 나타나고, 끝나면 하단 패널이 올라온다.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.3, docs/overhaul/03_chat_ui_spec.md §1·§2.
/// - 주인공은 말풍선 흐름이다. 대화 영역은 `tokens.chatBackground` 로 화면 바탕과
///   한 단 구분하고, 상단 헤더와 하단 패널은 배경으로 물러난다.
/// - 헤더는 이름 + 상태 한 줄(`온라인`/`자리 비움`/`부재중`/`온라인 · N명`)과 진행 막대뿐.
///   이벤트 제목과 D+N 은 대화 첫 항목 `ChatDivider('D+N · 제목')` 로 내려갔다.
/// - 상대 줄은 아바타 열(묶음 첫 줄만) → 이름 + 말풍선 → 시각·읽음 메타 열. 시각은
///   [ChatClock] 의 가짜 시계, 읽음은 낱말 하나(숫자 배지 금지).
/// - 컨트롤러 호출과 상태 사용 방식은 이전과 같다. 표현 계층만 바뀌었다.
///
/// 모먼트 변형(docs/MOMENTS_SPEC.md, DESIGN_SYSTEM §2.3):
/// - `format == "call"`: 수신 화면 → (받기) 통화 화면(자막·타이머) → 선택지(decline 숨김)
///   → 반응(자막) → 결과 패널. (거절) decline 선택지를 고르고 반응은 채팅 말풍선.
/// - `preview`: 대화가 열리기 전 잠금화면 알림 카드. 탭하거나 1.8초 뒤 열린다.
///   대사 자동 공개 타이머는 알림이 닫힌 뒤에 시작한다.
class EventScreen extends StatefulWidget {
  final GameController c;
  const EventScreen({super.key, required this.c});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> with WidgetsBindingObserver {
  Timer? _timer;
  int _waitLeft = 0;
  String? _eventId;
  final _scroll = ScrollController();

  /// 방금 고른 선택지 문구(버튼). 결과 패널이 떠 있는 동안 내 말풍선으로 대화에 남긴다.
  /// 자유 입력이면 컨트롤러의 [GameController.playerText](친 문장)가 먼저다 — 세이브에서도
  /// 복원되므로 화면이 다시 만들어져도 말풍선이 남는다(07 §3.4).
  String? _picked;

  String? get _myText => c.playerText ?? _picked;

  /// 선택 뒤 상대 반응 중 지금까지 보여 준 줄 수.
  int _replyShown = 0;
  Timer? _replyTimer;
  ChoiceOutcome? _replyFor;

  /// 내 말풍선 옆 `읽음`. 보낸 뒤 500ms(실패 톤 1500ms) 지나 켜진다(04 §2.4).
  bool _readShown = false;
  Timer? _readTimer;

  /// "쓰다 지움"(04 §2.3)을 이 이벤트에서 이미 했는지 — 이벤트당 1회.
  bool _eraseDone = false;

  /// 쓰다 지움의 빈 구간. 타이핑 표시를 페이드로 숨긴다(트리에는 남아 `'…'` 하나 유지).
  bool _typingHidden = false;

  /// 전화 이벤트 단계. 채팅 이벤트에서는 쓰지 않는다.
  CallStage _callStage = CallStage.active;

  /// 통화 시간(초)과 그 타이머.
  int _callSeconds = 0;
  Timer? _callTimer;

  /// 알림 카드가 떠 있는지와 자동 열림 타이머.
  bool _previewOpen = false;
  Timer? _previewTimer;

  /// 통화 중 대기 줄(`wait`)은 카운트다운 대신 이만큼 침묵한다. 벌점·광고 없음.
  static const callSilence = Duration(seconds: 2);

  /// 쓰다 지움 박자: `…` 700ms → 사라짐 → 600ms 빈 상태 → `…` 다시 → 대사(04 §2.3).
  static const eraseShow = Duration(milliseconds: 700);
  static const eraseGap = Duration(milliseconds: 600);

  /// `읽음` 지연. 실패 톤이면 "읽고 고민했다" 를 숫자 없이 전하려고 더 늦춘다.
  static const readDelay = Duration(milliseconds: 500);
  static const readDelayFail = Duration(milliseconds: 1500);

  /// initState 에서는 MediaQuery(동작 줄이기)를 읽을 수 없어서 첫 동기화를 미룬다.
  bool _started = false;

  GameController get c => widget.c;

  /// 효과음·진동(docs/overhaul/05_audio_haptics.md §1). 큐는 화면 상태 전환과 한곳에 둔다.
  SfxService get _sfx => SfxService.instance;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 백그라운드에서 서비스가 벨을 끊었으니, 돌아왔을 때 아직 수신 화면이면 벨만 다시 건다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (c.current?.isCall == true && _callStage == CallStage.ringing) {
      _sfx.startRing();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _syncEvent();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _replyTimer?.cancel();
    _readTimer?.cancel();
    _callTimer?.cancel();
    _previewTimer?.cancel();
    _sfx.stopRing();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (c.lastOutcome == null) {
      _picked = null;
      // 거절을 되돌리면(광고) 다시 울리는 화면으로. 벨도 다시.
      if (_callStage == CallStage.declined) {
        _callStage = CallStage.ringing;
        _sfx.startRing();
      }
    }
    _syncEvent();
    _syncReply();
    if (c.current?.isCall == true &&
        _callStage == CallStage.active &&
        !_callEnded &&
        !(_callTimer?.isActive ?? false)) {
      _startCallClock();
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 프레임 사이에 화면이 내려갔을 수 있다. dispose 된 컨트롤러는 건드리지 않는다.
      if (!mounted || !_scroll.hasClients) return;
      // 동작 줄이기가 켜져 있으면 0ms 라 곧바로 끝까지 내려간다.
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.base(context),
        curve: AppMotion.curve(context),
      );
    });
  }

  void _syncEvent() {
    final ev = c.current;
    final id = ev?.id;
    if (id == _eventId) return;
    _eventId = id;
    _timer?.cancel();
    _callTimer?.cancel();
    _previewTimer?.cancel();
    // 다른 이벤트로 넘어가면 울리던 벨은 끊는다.
    _sfx.stopRing();
    _waitLeft = 0;
    _callSeconds = 0;
    _previewOpen = false;
    _callStage = CallStage.active;
    _eraseDone = false;
    _typingHidden = false;
    // 처음부터 보는 이벤트일 때만 전화 수신·알림을 연출한다(복원·디버그 진입은 건너뜀).
    final fresh = ev != null && c.revealed == 0 && c.lastOutcome == null;
    if (ev != null && ev.isCall) {
      if (fresh) {
        _callStage = CallStage.ringing;
        _sfx.startRing();
        return;
      }
      _startCallClock();
    } else if (ev != null && fresh && _previewName(ev) != null) {
      // 문자 도착음·진동. 동작 줄이기로 알림 카드가 생략돼도 이건 낸다(04 §2.1).
      _sfx.cue(Sfx.msgIn);
      // 동작 줄이기면 알림 없이 바로 대화가 열린다.
      if (!AppMotion.reduced(context)) {
        _previewOpen = true;
        _previewTimer = Timer(NotificationPreview.autoOpen, _openPreview);
        return;
      }
    }
    _scheduleReveal();
  }

  /// 알림 카드에 쓸 이름. 캐릭터 이름, 없으면 첫 `them` 줄의 name. 둘 다 없으면 null
  /// (알림을 띄우지 않는다). `preview` 가 없어도 null.
  String? _previewName(StoryEvent ev) {
    if (ev.preview == null) return null;
    if (ev.character != null) return c.characterName(ev.character);
    for (final l in ev.lines) {
      if (l.who == 'them') return l.name;
    }
    return null;
  }

  void _openPreview() {
    if (!mounted || !_previewOpen) return;
    _previewTimer?.cancel();
    setState(() => _previewOpen = false);
    _scheduleReveal();
  }

  // ---- 전화 ----

  /// 결과 패널이 떠서 통화가 끝났는지.
  bool get _callEnded =>
      c.lastOutcome != null && _replyShown >= c.lastReply.length;

  void _startCallClock() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_callEnded) {
        t.cancel();
        _sfx.cue(Sfx.callEnd);
        setState(() {});
        return;
      }
      setState(() => _callSeconds++);
    });
  }

  void _acceptCall() {
    _sfx
      ..stopRing()
      ..cue(Sfx.callConnect);
    setState(() => _callStage = CallStage.active);
    _startCallClock();
    _scheduleReveal();
  }

  /// 거절 = decline 선택지를 고른 것. 효과·반응·결과 패널이 그대로 따라온다.
  void _declineCall() {
    final i = c.current?.declineIndex;
    if (i == null) return;
    _timer?.cancel();
    _sfx
      ..stopRing()
      ..cue(Sfx.callEnd);
    setState(() => _callStage = CallStage.declined);
    _picked = null;
    c.choose(i);
  }

  /// 선택 결과가 새로 나오면 상대 반응을 한 줄씩 타이핑하듯 보여 준다.
  /// 동작 줄이기가 켜져 있으면 한 번에 다 보여 준다.
  void _syncReply() {
    final o = c.lastOutcome;
    if (identical(o, _replyFor)) return;
    _replyFor = o;
    // 결과가 새로 나온 순간의 성패음. 거절은 판정이 아니라 종료음(callEnd)만 낸다.
    if (o != null && c.lastChoice?.decline != true) {
      _sfx.cue(o.success ? Sfx.choiceOk : Sfx.choiceFail);
    }
    _replyTimer?.cancel();
    _readTimer?.cancel();
    _replyShown = 0;
    // 되돌리기로 결과가 사라지면 읽음도 같이 사라진다.
    _readShown = false;
    final total = c.lastReply.length;
    if (o == null) return;
    if (MediaQuery.of(context).disableAnimations) {
      _replyShown = total;
      _readShown = true;
      return;
    }
    // 읽음은 보낸 뒤 조금 있다가. 실패면 더 늦게 — "읽고 고민했다".
    _readTimer = Timer(o.success ? readDelay : readDelayFail, () {
      if (!mounted || !identical(c.lastOutcome, o)) return;
      setState(() => _readShown = true);
    });
    if (total == 0) return;
    void step() {
      _replyTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted || !identical(c.lastOutcome, o)) return;
        setState(() => _replyShown++);
        _scrollToEnd();
        if (_replyShown < total) step();
      });
    }

    step();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.base(context),
        curve: AppMotion.curve(context),
      );
    });
  }

  /// 상대 줄의 타이핑 시간. 긴 말은 오래 친다: `clamp(600 + 글자×18, 800, 2400)`ms.
  /// 글자는 공백을 뺀 수(치는 건 글자다).
  static int themDelayMs(String text) {
    final chars = text.replaceAll(RegExp(r'\s'), '').length;
    return (600 + chars * 18).clamp(800, 2400);
  }

  /// 이벤트 안 `them` 줄 중 가장 긴 줄인지(같은 길이면 앞쪽 하나만).
  static bool isLongestThem(StoryEvent ev, int index) {
    final line = ev.lines[index];
    if (line.who != 'them') return false;
    var best = -1;
    for (var i = 0; i < ev.lines.length; i++) {
      final l = ev.lines[i];
      if (l.who == 'them' && l.text.length > best) best = l.text.length;
    }
    if (line.text.length != best) return false;
    for (var i = 0; i < index; i++) {
      final l = ev.lines[i];
      if (l.who == 'them' && l.text.length == best) return false;
    }
    return true;
  }

  /// 다음 줄을 자동으로 공개. 대기 줄이면 카운트다운.
  ///
  /// 상대 줄 앞에는 "쓰다 지움" 을 이벤트당 한 번 넣는다(04 §2.3): 가장 긴 `them` 줄이거나
  /// 직전 줄이 `wait` 였을 때, `…` → 사라짐 → 빈 상태 → `…` → 대사. 동작 줄이기면 지연만.
  void _scheduleReveal() {
    _timer?.cancel();
    if (_typingHidden) _typingHidden = false;
    final ev = c.current;
    if (ev == null || c.linesDone) return;
    final next = ev.lines[c.revealed];
    if (next.isWait && ev.isCall) {
      // 통화 중 대기 줄은 "…(침묵)" 을 바로 띄우고 잠시 멈춘다.
      c.revealNext();
      _timer = Timer(callSilence, () {
        if (mounted) _scheduleReveal();
      });
      return;
    }
    if (next.isWait) {
      _waitLeft = next.wait;
      _runWaitCountdown();
      return;
    }
    final delay = Duration(
      milliseconds: switch (next.who) {
        'me' => 450,
        'narr' => 350,
        'them' => themDelayMs(next.text),
        _ => 800,
      },
    );
    void reveal() {
      if (!mounted) return;
      c.revealNext();
      _scheduleReveal();
    }

    final afterWait = c.revealed > 0 && ev.lines[c.revealed - 1].isWait;
    final erase =
        next.who == 'them' &&
        !ev.isCall &&
        !_eraseDone &&
        !AppMotion.reduced(context) &&
        (afterWait || isLongestThem(ev, c.revealed));
    if (!erase) {
      _timer = Timer(delay, reveal);
      return;
    }
    _eraseDone = true;
    _timer = Timer(eraseShow, () {
      if (!mounted) return;
      setState(() => _typingHidden = true);
      _timer = Timer(AppMotion.dFast + eraseGap, () {
        if (!mounted) return;
        setState(() => _typingHidden = false);
        _timer = Timer(delay, reveal);
      });
    });
  }

  /// 남은 시간부터 1초씩 센다. 광고가 실패해 돌아왔을 때도 이 지점부터 이어 센다.
  void _runWaitCountdown() {
    _timer?.cancel();
    if (_waitLeft <= 0) return _finishWait();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _waitLeft--);
      if (_waitLeft <= 0) {
        t.cancel();
        _finishWait();
      }
    });
  }

  void _finishWait() {
    _sfx.cue(Sfx.waitRead);
    // 읽씹 대기는 자존감을 1 깎는다. 모쏠 체험의 핵심 감정.
    // 엔진을 거쳐야 정산 화면과 되돌리기, 세이브에 함께 잡힌다.
    c.applyWaitPenalty();
    c.revealNext();
    _scheduleReveal();
  }

  Future<void> _skipWait() async {
    // 광고를 기다리는 동안 카운트다운이 계속 돌면, 광고를 보고도 자존감이 깎이고
    // 대사 한 줄이 건너뛰어진다. 광고를 띄우기 전에 먼저 멈춘다.
    _timer?.cancel();
    final ok = await AdManager.instance.showRewarded(placement: 'wait_skip');
    if (!mounted) return;
    if (ok) {
      _waitLeft = 0;
      c.revealNext();
      _scheduleReveal();
    } else {
      _snack('광고를 불러오지 못했어요.');
      _runWaitCountdown();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// 말풍선 묶음 기준. 같은 사람이 이어 말하면 같은 키가 나온다.
  String _speakerKey(Line l, String partner) => switch (l.who) {
    'narr' => '#narr',
    'sys' => '#sys',
    'me' => '#me',
    _ => 'them:${l.name ?? partner}',
  };

  /// 줄의 화자 캐릭터 id(03 §1.2). 이름이 없거나 상대 이름이면 상대 본인, 캐스트 이름이면
  /// 그 id(그룹 대화), 그 밖(태현·엄마·모르는 번호)은 NPC → null.
  String? _speakerIdFor(Line l, StoryEvent ev) {
    final name = l.name;
    if (name == null) return ev.character;
    if (ev.character != null && name == c.characterName(ev.character)) {
      return ev.character;
    }
    for (final ch in c.bundle.characters) {
      if (ch.name == name) return ch.id;
    }
    return null;
  }

  /// 이벤트 안 서로 다른 `them` 화자 수(그룹 대화 판정).
  int _themSpeakers(StoryEvent ev, String partner) {
    final names = <String>{};
    for (final l in ev.lines) {
      if (l.who == 'them') names.add(l.name ?? partner);
    }
    return names.length;
  }

  @override
  Widget build(BuildContext context) {
    // 화면에는 이름을 치환한 사본(docs/NAME_GUIDE.md). 엔진 호출은 c.current(원본).
    final ev = c.shownEvent;
    if (ev == null) return const SizedBox.shrink();
    final partner = c.characterName(ev.character);
    if (_previewOpen) {
      return NotificationPreview(
        name: _previewName(ev) ?? partner,
        characterId: ev.character,
        preview: ev.preview ?? '',
        day: c.state!.day,
        onOpen: _openPreview,
      );
    }
    if (ev.isCall) {
      switch (_callStage) {
        case CallStage.ringing:
          return IncomingCallView(
            name: partner,
            characterId: ev.character,
            onAccept: _acceptCall,
            onDecline: _declineCall,
          );
        case CallStage.active:
          return _activeCall(ev, partner);
        case CallStage.declined:
          return _chat(ev, partner, missedCall: true);
      }
    }
    return _chat(ev, partner);
  }

  /// 통화 중 화면. 자막 → 선택지(decline 숨김) → 내 말·반응(자막) → 결과 패널.
  Widget _activeCall(StoryEvent ev, String partner) {
    final visible = ev.lines.take(c.revealed).toList();
    final o = c.lastOutcome;
    final replying = o != null && _replyShown < c.lastReply.length;
    Widget sub(Line l) =>
        CallSubtitle(line: l, partnerName: partner, characterId: ev.character);
    return SceneScope(
      builder: (context, r) => ActiveCallView(
        name: partner,
        characterId: ev.character,
        // 통화 배경 삽화(06 §1). 없으면 지금까지의 바탕 그대로.
        image: SceneImages.forEvent(ev, registry: r),
        seconds: _callSeconds,
        ended: _callEnded,
        scroll: _scroll,
        subtitles: [
          for (final l in visible) sub(l),
          if (o != null && _myText != null) sub(Line(who: 'me', text: _myText!)),
          if (o != null)
            for (final l in c.lastReply.take(_replyShown)) sub(l),
          if (replying || (o == null && !c.linesDone && !_pendingIsWait(ev)))
            const CallTyping(),
        ],
        bottom: o != null
            ? (replying ? null : _ResultPanel(c: c))
            : c.linesDone
            ? _ChoicePanel(
                key: ValueKey('choices-${ev.id}'),
                c: c,
                hideDecline: true,
                onPicked: (text) => _picked = text,
                onHangUp: _declineCall,
              )
            : null,
      ),
    );
  }

  bool _pendingIsWait(StoryEvent ev) =>
      !c.linesDone && ev.lines[c.revealed].isWait;

  /// 채팅 화면. [missedCall] 이면 거절한 전화 뒤의 톡: 대사 대신 "부재중 전화" 와 반응만.
  Widget _chat(StoryEvent ev, String partner, {bool missedCall = false}) {
    final s = c.state!;
    final t = context.tokens;
    final accent = t.accentFor(ev.character);
    final o = c.lastOutcome;
    final visible = missedCall
        ? const <Line>[]
        : ev.lines.take(c.revealed).toList();
    final waitLine = c.linesDone || missedCall ? null : ev.lines[c.revealed];
    final waiting = waitLine != null && waitLine.isWait && _waitLeft > 0;
    final total = ev.lines.length;
    final progress = total == 0 || missedCall ? 1.0 : c.revealed / total;
    final replying = o != null && _replyShown < c.lastReply.length;

    // 지금까지 공개된 줄 전부: 대사 → 내 선택 → 상대 반응. 묶음·시계·읽음은 이 순서로 센다.
    final mine = _myText;
    final pickedAt = o != null && mine != null ? visible.length : -1;
    final rows = <Line>[
      ...visible,
      if (pickedAt >= 0) Line(who: 'me', text: mine!),
      if (o != null) ...c.lastReply.take(_replyShown),
    ];
    final keys = [for (final l in rows) _speakerKey(l, partner)];
    // 가짜 시계. 대사 줄은 큐의 시간대에서, 내 선택·반응은 그 뒤로 이어진다.
    final times = ChatClock.timesFor(
      rows,
      ChatClock.startSeconds(
        seed: s.seed,
        day: s.day,
        index: c.todayEventIndex,
        total: c.todayEventTotal,
      ),
    );

    // 다음에 칠 줄(타이핑 표시의 화자). 없으면 null.
    final Line? upcoming = replying
        ? c.lastReply[_replyShown]
        : (o == null && !c.linesDone && !missedCall && !waiting)
        ? ev.lines[c.revealed]
        : null;

    final bubbles = <Widget>[];
    String? lastLabel;
    for (var i = 0; i < rows.length; i++) {
      final l = rows[i];
      final first = i == 0 || keys[i - 1] != keys[i];
      final last = i == rows.length - 1 || keys[i + 1] != keys[i];
      // 시각은 묶음 마지막 줄에만. 직전 묶음과 같은 분이면 생략.
      String? time;
      if (last && (l.who == 'them' || l.who == 'me')) {
        final label = ChatClock.label(times[i]);
        if (label != lastLabel) time = label;
        lastLabel = label;
      }
      // 읽음: 내 말 뒤로 상대 줄이 하나라도 공개됐을 때. 방금 보낸 말은 타이머(04 §2.4).
      final read =
          l.who == 'me' &&
          (i == pickedAt
              ? _readShown
              : rows.skip(i + 1).any((x) => x.who == 'them'));
      final id = _speakerIdFor(l, ev);
      bubbles.add(
        ChatBubble(
          line: l,
          partnerName: partner,
          accent: t.accentFor(id),
          characterId: id,
          isFirstOfGroup: first,
          isLastOfGroup: last,
          showAvatar: first,
          meta: time == null && !read ? null : ChatMeta(time: time, read: read),
        ),
      );
      // 스티커는 그 대사 바로 아래 별도 줄. 상대 줄에만, 에셋이 없으면 빈 칸도 없다.
      final sticker = l.who == 'them' ? l.sticker : null;
      if (sticker != null) {
        final char = Sticker.characterOf(sticker);
        final emotion = Sticker.emotionOf(sticker);
        if (char != null && emotion != null) {
          bubbles.add(
            StickerBubble(
              characterId: char,
              emotion: emotion,
              name: l.name ?? partner,
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: _header(
        context,
        ev,
        partner,
        accent,
        progress,
        status: missedCall
            ? '부재중'
            : waiting
            ? '자리 비움'
            : switch (_themSpeakers(ev, partner)) {
                final n when n >= 2 => '온라인 · ${n + 1}명',
                _ => '온라인',
              },
      ),
      body: Column(
        children: [
          // 대화 영역만 한 단 어두운(밝은) 바탕을 깔아 패널·헤더와 분리한다.
          Expanded(
            child: ColoredBox(
              color: t.chatBackground,
              // 대화는 길어야 십수 줄이라 전부 그린다. 게으른 ListView 는 끝 높이를 어림해
              // 마지막 줄(대기 블록·사진)로 스크롤이 못 미칠 때가 있다.
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(
                  top: AppSpace.sm,
                  bottom: AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 장면 삽화(06 §1). 그림이 없으면 아무것도 그리지 않는다 — 여백도 0.
                    SceneScope(
                      builder: (context, r) => SceneCard(
                        path: SceneImages.forEvent(ev, registry: r),
                        title: ev.title,
                        bundle: r.bundle,
                      ),
                    ),
                    // 제목은 헤더가 아니라 대화의 첫 줄이다.
                    ChatDivider(
                      text: ev.title.isEmpty
                          ? 'D+${s.day}'
                          : 'D+${s.day} · ${ev.title}',
                    ),
                    if (missedCall) _MissedCall(name: partner),
                    ...bubbles,
                    if (waiting)
                      _WaitingBlock(
                        secondsLeft: _waitLeft,
                        secondsTotal: waitLine.wait,
                        onSkip: _skipWait,
                      )
                    else if (upcoming != null)
                      _typing(
                        upcoming,
                        ev,
                        partner,
                        first:
                            keys.isEmpty ||
                            keys.last != _speakerKey(upcoming, partner),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 결과 패널은 상대 반응을 다 보여 준 뒤에 올린다. 대화의 끝을 먼저 읽게 한다.
          if (o != null)
            replying ? const SizedBox.shrink() : _ResultPanel(c: c)
          else if (c.linesDone)
            _ChoicePanel(
              // 이벤트마다 새 상태(입력창 문장·전송 잠금이 다음 이벤트로 새지 않게).
              key: ValueKey('choices-${ev.id}'),
              c: c,
              onPicked: (text) => _picked = text,
            ),
        ],
      ),
    );
  }

  /// 타이핑 표시. 다음 줄이 `them` 이면 그 화자의 아바타 + 말풍선 `'…'`, 지문·시스템 줄이면
  /// 가운데 `'…'`([CallTyping]) — 지문이 "입력 중" 으로 읽히면 이상하다. 어느 쪽이든
  /// `Text('…')` 는 정확히 하나다. 쓰다 지움의 빈 구간은 불투명도로만 숨긴다.
  Widget _typing(
    Line next,
    StoryEvent ev,
    String partner, {
    required bool first,
  }) {
    if (next.who != 'them') return const CallTyping();
    final id = _speakerIdFor(next, ev);
    return AnimatedOpacity(
      opacity: _typingHidden ? 0 : 1,
      duration: AppMotion.fast(context),
      child: TypingIndicator(
        name: next.name ?? partner,
        characterId: id,
        accent: context.tokens.accentFor(id),
        showAvatar: first,
      ),
    );
  }

  /// 이름 + 상태 한 줄 + 대화 진행도. 아바타·제목·D+N 은 없다(03 §2) — 제목은 [ChatDivider].
  /// 상대 없는 독백 이벤트는 제목이 이름 자리에 오고 상태 줄이 없다.
  PreferredSizeWidget _header(
    BuildContext context,
    StoryEvent ev,
    String partner,
    CharacterAccent accent,
    double progress, {
    required String status,
  }) {
    final scheme = context.scheme;
    final t = context.tokens;
    final hasPartner = partner.isNotEmpty;

    return AppBar(
      titleSpacing: AppSpace.lg,
      title: hasPartner
          ? Semantics(
              label: '$partner, $status',
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge,
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              ev.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleLarge,
            ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(AppSpace.xs),
        child: AppProgressBar(
          value: progress,
          height: AppSpace.xs,
          semanticLabel: '대화 진행',
          // 상대가 없는 독백 이벤트는 강조색이 중립(거의 검정)이라 선이 무겁다.
          fill: hasPartner ? accent.base : t.systemLine,
        ),
      ),
    );
  }
}

/// 거절한 전화 자리 표시. 시스템 줄과 같은 중립 pill 이되 아이콘을 붙이고 글자는
/// 본문 2차색(`onSurfaceVariant`)으로 둔다 — 이 줄은 장식이 아니라 사건이라 읽혀야 한다.
class _MissedCall extends StatelessWidget {
  final String name;
  const _MissedCall({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs + 2,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.rPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_missed, size: 14, color: fg),
              const SizedBox(width: AppSpace.xs),
              Flexible(
                child: Text(
                  name.isEmpty ? '부재중 전화' : '부재중 전화 · $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 읽씹 대기 연출. 중립 pill 안에서 숫자가 줄고, 아래 막대가 남은 시간을 그린다.
///
/// 카운트다운 문구는 숫자를 포함한 **하나의 Text** 여야 한다(테스트 고정).
/// 자리수가 흔들리지 않도록 tabular 숫자를 쓴다.
class _WaitingBlock extends StatelessWidget {
  final int secondsLeft;
  final int secondsTotal;
  final Future<void> Function() onSkip;

  const _WaitingBlock({
    required this.secondsLeft,
    required this.secondsTotal,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final base = context.text.labelSmall ?? const TextStyle();
    final left = secondsTotal <= 0
        ? 0.0
        : (secondsLeft / secondsTotal).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.md,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.rPill,
            ),
            child: Text(
              keepAll('읽음 · $secondsLeft초째 답이 없다'),
              textAlign: TextAlign.center,
              style: AppTypography.tabular(base.copyWith(color: t.systemLine)),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          // 기다림의 길이를 형태로도 보여 준다. 색만으로 말하지 않는다.
          AppProgressBar(
            value: left,
            height: AppSpace.xs,
            semanticLabel: '답장 대기 남은 시간',
            fill: t.systemLine,
          ),
          const SizedBox(height: AppSpace.xs),
          TextButton.icon(
            onPressed: onSkip,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('광고 보고 기다리지 않기'),
          ),
        ],
      ),
    );
  }
}

/// 선택지 패널. 대화와 같은 세계에 있되 한 단 위로 올라온 종이처럼 보인다.
///
/// 선택지는 `ChoiceButton` 하나로 통일한다. 내부가 `OutlinedButton` 이고
/// 이 영역에 다른 `OutlinedButton` 이 없어야 한다(§4.1) — 입력창·칩·시트는 전부 다른 위젯이다.
///
/// 자유 입력(docs/overhaul/07_free_input.md §3): 버튼 아래 한 줄 입력창 `직접 쓰기…`. 포커스가 오면
/// 버튼은 가로 칩 한 줄로 접힌다(빈 입력창은 백지 공포 — 후보를 계속 보여 준다). 보내면 컨트롤러가
/// 매핑하고, 결정에 따라 바로 확정 · 확인 시트 · "이런 뜻이에요?" 피커 · 잠김 안내 한 줄.
class _ChoicePanel extends StatefulWidget {
  final GameController c;

  /// 선택이 확정되기 직전에 부른다. 화면이 내 말풍선을 그리는 데만 쓴다.
  final ValueChanged<String> onPicked;

  /// 통화 중이면 `decline` 선택지(= 거절 버튼)를 숨긴다.
  final bool hideDecline;

  /// 통화 중 "끊을게" 계열 입력(07 §4 #7). 확인 뒤 거절 경로로.
  final VoidCallback? onHangUp;

  const _ChoicePanel({
    super.key,
    required this.c,
    required this.onPicked,
    this.hideDecline = false,
    this.onHangUp,
  });

  @override
  State<_ChoicePanel> createState() => _ChoicePanelState();
}

/// 입력창 위 한 줄. 잠김·금칙어는 지문(narr) 톤, 빈 입력은 2차 글자색 안내.
class _InlineNote {
  final String text;
  final bool narr;
  const _InlineNote(this.text, {this.narr = true});
}

enum _ConfirmAction { go, other }

class _ChoicePanelState extends State<_ChoicePanel> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _lockTimer;

  /// 보낸 뒤 [sendLock] 동안 다시 못 보낸다(연타 방지, 07 §4 #5).
  bool _sendLocked = false;
  _InlineNote? _note;
  int _lastLen = 0;

  static const sendLock = Duration(milliseconds: 1200);

  /// 칩 문구 최대 글자. 넘으면 `…`.
  static const chipChars = 14;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    // 무료 되돌리기 뒤: 친 문장을 되살려 다시 고르게 한다(07 §3.3).
    final retry = c.takeFreeRetryText();
    if (retry != null) {
      _ctrl.text = retry;
      _lastLen = retry.length;
    }
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// 미니게임이 붙은 선택지는 먼저 게임을 돌리고 그 결과로 성패를 정한다.
  Future<void> _pick(int index) async {
    final ev = c.current!;
    final id = ev.choices[index].minigame;
    if (id == null) {
      // 보내기 슉: 누르는 순간 클릭 진동 + 전송음(04 §2.5).
      SfxService.instance.cue(Sfx.msgOut);
      widget.onPicked(c.say(ev.choices[index].text));
      c.choose(index);
      return;
    }
    final result = await playMinigame(
      context,
      id,
      MinigameContext(state: c.state!, partner: c.characterOf(ev.character)),
    );
    // 미니게임 도중 컨트롤러가 갱신돼도 지워지지 않게 결과 직전에 넘긴다.
    // 미니게임 선택지는 결과가 돌아온 뒤에 같은 연출.
    SfxService.instance.cue(Sfx.msgOut);
    widget.onPicked(c.say(ev.choices[index].text));
    c.choose(
      index,
      minigameSuccess: result.success,
      minigameCritical: result.critical,
      note: result.message,
    );
  }

  // ---- 자유 입력 ----

  void _onChanged(String v) {
    // 붙여넣기로 상한에 걸리면 한 번 말해 준다(07 §4 #4). maxLength 가 이미 잘랐다.
    if (v.length >= FreeInputThresholds.maxChars && v.length - _lastLen > 20) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('짧게 말해 주세요')),
      );
    }
    _lastLen = v.length;
    setState(() {});
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sendLocked) return;
    final r = c.chooseFree(text);
    _lock();
    setState(() => _note = null);
    switch (r.decision) {
      case MatchDecision.auto:
        await _confirm(r, r.top!.index, auto: true, via: 'auto');
      case MatchDecision.confirm:
        await _confirmSheet(r);
      case MatchDecision.locked:
        // 확정하지 않는다. 턴·되돌리기 소모 없음, 문장은 남긴다(07 §3.2-4).
        setState(
          () => _note = _InlineNote('아직 그 말은 안 나온다 (${r.top!.view.reason})'),
        );
      case MatchDecision.pick:
        await _pickSheet(r);
      case MatchDecision.empty:
        setState(() => _note = const _InlineNote('조금만 더 써 주세요', narr: false));
      case MatchDecision.blocked:
        // 저장·기록·분석 없음. 문장도 지운다.
        _ctrl.clear();
        _lastLen = 0;
        setState(() => _note = const _InlineNote('그 말은 보내지 않기로 했다.'));
      case MatchDecision.hangUp:
        await _hangUpSheet();
    }
  }

  void _lock() {
    _lockTimer?.cancel();
    setState(() => _sendLocked = true);
    _lockTimer = Timer(sendLock, () {
      if (mounted) setState(() => _sendLocked = false);
    });
  }

  /// 매핑 결과를 선택지 [index] 로 확정한다. [auto] 는 자동 확정(무료 되돌리기 대상). 미니게임이면
  /// 먼저 게임 — 실력 판정은 문장으로 건너뛸 수 없다(07 §3.2-5).
  Future<void> _confirm(
    MatchResult r,
    int index, {
    required bool auto,
    required String via,
  }) async {
    final ev = c.current!;
    final choice = ev.choices[index];
    c.noteFreeConfidence(r);
    bool? ok;
    bool? crit;
    String? note;
    final mg = choice.minigame;
    if (mg != null) {
      final result = await playMinigame(
        context,
        mg,
        MinigameContext(state: c.state!, partner: c.characterOf(ev.character)),
      );
      ok = result.success;
      crit = result.critical;
      note = result.message;
      auto = false;
    }
    if (!mounted) return;
    _focus.unfocus();
    SfxService.instance.cue(Sfx.msgOut);
    widget.onPicked(r.text);
    c.confirmFree(
      index,
      text: r.text,
      auto: auto,
      match: r,
      via: via,
      minigameSuccess: ok,
      minigameCritical: crit,
      note: note,
    );
  }

  /// `chance`·`minigame` 이 1위: 확인 한 번(07 §3.2-5).
  Future<void> _confirmSheet(MatchResult r) async {
    _focus.unfocus();
    final top = r.top!;
    final choice = top.view.choice;
    final mg = choice.minigame;
    final label = mg != null
        ? (minigameLabels[mg] ?? '미니게임')
        : '${c.onFire ? (choice.chance! + 20).clamp(0, 100) : choice.chance}%';
    final res = await showModalBottomSheet<_ConfirmAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        text: r.text,
        choiceText: c.say(choice.text),
        label: label,
        primary: mg != null ? '게임 시작' : '이대로',
      ),
    );
    if (!mounted || res == null) return;
    switch (res) {
      case _ConfirmAction.go:
        await _confirm(r, top.index, auto: false, via: 'confirm');
      case _ConfirmAction.other:
        await _pickSheet(r);
    }
  }

  /// "이런 뜻이에요?" 피커(07 §3.2-3). `다시 쓰기` 면 문장을 남긴 채 돌아온다.
  Future<void> _pickSheet(MatchResult r) async {
    _focus.unfocus();
    final forced = c.freePickForced;
    final idx = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickSheet(c: c, result: r, forced: forced),
    );
    if (!mounted || idx == null) return;
    await _confirm(r, idx, auto: false, via: forced ? 'forced' : 'picker');
  }

  Future<void> _hangUpSheet() async {
    _focus.unfocus();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: AppInsets.panel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('전화를 끊을까요?', style: ctx.text.titleMedium),
              const SizedBox(height: AppSpace.md),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('끊기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('계속 통화'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || ok != true) return;
    _ctrl.clear();
    widget.onHangUp?.call();
  }

  static String _short(String t) =>
      t.length > chipChars ? '${t.substring(0, chipChars)}…' : t;

  /// 우측 짧은 라벨: 미니게임 이름 또는 성공 확률. 잠긴 선택지는 이유만 보여 준다.
  String? _trailingLabel(ChoiceView v) {
    if (v.locked) return null;
    final mg = v.choice.minigame;
    if (mg != null) return minigameLabels[mg] ?? '미니게임';
    final chance = v.choice.chance;
    // 내 MBTI 에게만 보이는 선택지. 무엇이 '나다운' 선택인지 알아보게 성향 글자를 단다.
    if (chance == null) {
      final m = v.choice.mbti;
      return m == null ? null : '$m 성향';
    }
    return c.onFire ? '${(chance + 20).clamp(0, 100)}%' : '$chance%';
  }

  /// 미니게임은 브랜드, 물올라 보정된 확률은 성공, 나머지는 중립.
  AppTone _trailingTone(ChoiceView v) {
    if (v.choice.minigame != null) return AppTone.brand;
    if (v.choice.mbti != null && v.choice.chance == null) return AppTone.brand;
    if (v.choice.chance != null && c.onFire) return AppTone.success;
    return AppTone.neutral;
  }

  Widget _buttons(List<ChoiceView> choices) => Column(
    key: const ValueKey('choice-buttons'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < choices.length; i++)
        Padding(
          padding: EdgeInsets.only(
            bottom: i == choices.length - 1 ? 0 : AppSpace.listGap,
          ),
          child: ChoiceButton(
            text: c.say(choices[i].choice.text),
            onPressed: choices[i].locked ? null : () => _pick(choices[i].index),
            lockedReason: choices[i].locked ? choices[i].reason : null,
            leadingIcon: choices[i].locked
                ? Icons.lock_outline
                : choices[i].choice.minigame != null
                ? Icons.sports_esports_outlined
                : choices[i].choice.mbti != null
                ? Icons.auto_awesome_outlined
                : null,
            trailingLabel: _trailingLabel(choices[i]),
            trailingTone: _trailingTone(choices[i]),
            recommended: c.hintIndex == choices[i].index,
          ),
        ),
    ],
  );

  /// 키보드가 올라온 동안의 후보 칩 한 줄(07 §3.1). 칩을 누르면 버튼과 같은 경로.
  Widget _chips(List<ChoiceView> choices) => SingleChildScrollView(
    key: const ValueKey('choice-chips'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final v in choices)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: ActionChip(
              avatar: v.locked ? const Icon(Icons.lock_outline, size: 16) : null,
              label: Text(_short(c.say(v.choice.text))),
              onPressed: v.locked ? null : () => _pick(v.index),
            ),
          ),
      ],
    ),
  );

  Widget _inputRow(BuildContext context) {
    final scheme = context.scheme;
    final canSend = !_sendLocked && _ctrl.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('free-input'),
            controller: _ctrl,
            focusNode: _focus,
            maxLength: FreeInputThresholds.maxChars,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            onChanged: _onChanged,
            style: context.text.bodyMedium,
            decoration: InputDecoration(
              hintText: '직접 쓰기…',
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              contentPadding: AppInsets.chip,
              border: OutlineInputBorder(
                borderRadius: AppRadius.rPill,
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.rPill,
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.rPill,
                borderSide: BorderSide(
                  color: scheme.primary,
                  width: AppBorderWidth.emphasis,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        IconButton.filled(
          key: const Key('free-send'),
          tooltip: '보내기',
          onPressed: canSend ? _send : null,
          icon: const Icon(Icons.send_rounded, size: 18),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = c.current!;
    final t = context.tokens;
    final choices = [
      for (final v in c.choices)
        if (!(widget.hideDecline && v.choice.decline)) v,
    ];
    final freeOn = c.canFreeInput;
    final collapsed = freeOn && _focus.hasFocus;
    final note = _note;

    return BottomPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 동작 줄이기면 0ms — 즉시 바뀐다.
          AnimatedSwitcher(
            duration: AppMotion.base(context),
            switchInCurve: AppMotion.curve(context),
            child: collapsed ? _chips(choices) : _buttons(choices),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                keepAll(note.text),
                style: context.text.bodySmall?.copyWith(
                  color: note.narr ? t.narration : context.scheme.onSurfaceVariant,
                  fontStyle: note.narr ? FontStyle.italic : null,
                ),
              ),
            ),
          if (freeOn)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: _inputRow(context),
            ),
          // 힌트는 선택지보다 한 단 아래. 광고 제안이 선택을 밀어내지 않게 한다.
          if (ev.hint != null && c.hintIndex == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await AdManager.instance.showRewarded(
                      placement: 'hint',
                    );
                    if (ok) {
                      c.analytics.log(Analytics.adHintUsed);
                      c.revealHint();
                    } else if (context.mounted) {
                      // 광고가 안 뜨면 아무 말 없이 끝내지 않는다.
                      adFailedSnack(context);
                    }
                  },
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(keepAll('태현에게 물어보기 (광고)')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 친 문장 인용 한 줄(피커·확인 시트 공용).
class _Quote extends StatelessWidget {
  final String text;
  const _Quote(this.text);

  @override
  Widget build(BuildContext context) => Text(
    keepAll('"$text"'),
    style: context.text.bodyMedium?.copyWith(
      color: context.scheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    ),
  );
}

/// `chance`·`minigame` 확인 시트: `"선택지 원문" (75%)` [이대로] [다른 뜻].
class _ConfirmSheet extends StatelessWidget {
  final String text;
  final String choiceText;
  final String label;
  final String primary;
  const _ConfirmSheet({
    required this.text,
    required this.choiceText,
    required this.label,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: AppInsets.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Quote(text),
          const SizedBox(height: AppSpace.sm),
          Text(
            keepAll('"$choiceText" ($label)'),
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ConfirmAction.go),
            child: Text(primary),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ConfirmAction.other),
            child: const Text('다른 뜻'),
          ),
        ],
      ),
    ),
  );
}

/// "이런 뜻이에요?" 피커. 후보를 점수순으로, 상위 1~2개 강조(잘 못 알아들었으면 강조 없음).
/// 행은 `OutlinedButton` 이 아니다(§4.1 — 선택지 개수만큼만 존재해야 한다).
class _PickSheet extends StatelessWidget {
  final GameController c;
  final MatchResult result;

  /// 무료 되돌리기 뒤 강제 피커 — 강조 없음(같은 실수를 반복하지 않게).
  final bool forced;
  const _PickSheet({required this.c, required this.result, required this.forced});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final weak = r.weak || forced;
    return SafeArea(
      child: SingleChildScrollView(
        padding: AppInsets.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('이런 뜻이에요?', style: context.text.titleMedium),
            if (r.weak)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Text(
                  keepAll('잘 못 알아들었어요 — 어느 쪽에 가까워요?'),
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            _Quote(r.text),
            const SizedBox(height: AppSpace.md),
            for (var i = 0; i < r.ranked.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.listGap),
                child: _PickRow(
                  text: c.say(r.ranked[i].view.choice.text),
                  recommended:
                      !weak &&
                      (i == 0 ||
                          (i == 1 && r.margin < FreeInputThresholds.autoMargin)),
                  lockedReason: r.ranked[i].view.locked ? r.ranked[i].view.reason : null,
                  onTap: r.ranked[i].view.locked
                      ? null
                      : () => Navigator.pop(context, r.ranked[i].index),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('다시 쓰기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String text;
  final bool recommended;
  final String? lockedReason;
  final VoidCallback? onTap;
  const _PickRow({
    required this.text,
    required this.recommended,
    required this.lockedReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final t = context.tokens;
    final locked = onTap == null;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: AppRadius.rMd,
      child: InkWell(
        borderRadius: AppRadius.rMd,
        onTap: onTap,
        child: Container(
          padding: AppInsets.cardTight,
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: recommended ? scheme.primary : scheme.outlineVariant,
              width: recommended ? AppBorderWidth.emphasis : AppBorderWidth.hairline,
            ),
          ),
          child: Row(
            children: [
              if (locked) ...[
                Icon(Icons.lock_outline, size: 18, color: t.lockedForeground),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keepAll(text),
                      style: context.text.labelLarge?.copyWith(
                        color: locked ? t.lockedForeground : scheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                    if (lockedReason != null)
                      Text(
                        keepAll(lockedReason!),
                        style: context.text.bodySmall?.copyWith(
                          color: t.lockedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 결과 패널. 크리티컬·성공·실패를 배경 톤 + 아이콘 + 문구 3중으로 알린다(§2.3).
class _ResultPanel extends StatelessWidget {
  final GameController c;
  const _ResultPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = context.scheme;
    final o = c.lastOutcome!;

    final tone = o.critical
        ? AppTone.brand
        : !o.success
        ? AppTone.danger
        : AppTone.neutral;
    // 패널 배경이 톤에 따라 바뀌므로 글자색도 그 배경 위의 색으로 맞춘다.
    final fg = o.critical
        ? scheme.onPrimaryContainer
        : !o.success
        ? t.onDangerContainer
        : scheme.onSurface;
    // 전화를 거절한 건 '성공'이 아니다. 판정 없는 선택이므로 담담하게 적는다.
    final declined = c.lastChoice?.decline == true;
    // 자유 입력이면 어느 선택지로 알아들었는지 캡션으로 — 오매핑을 스스로 알아채는 유일한 창(07 §3.2).
    final heard = c.lastChoiceSource == ChoiceSource.freeText ? c.lastChoice : null;
    final headline = declined
        ? '전화를 넘겼다'
        : o.critical
        // 초반에는 초반 가속과 겹쳐 2배가 넘으므로 배수를 적지 않는다. 실제 수치는 아래 칩에 있다.
        ? (o.delta.affection.values.any((v) => v > 0) ? '크리티컬! 호감 폭발' : '크리티컬!')
        : !o.success
        ? '실패…'
        : o.comboStarted
        ? '물올랐다!'
        : '성공';
    final icon = declined
        ? Icons.phone_missed_outlined
        : o.critical
        ? Icons.auto_awesome
        : !o.success
        ? Icons.error_outline
        : o.comboStarted
        ? Icons.local_fire_department
        : Icons.check_circle_outline;

    final parts = <_DeltaPart>[
      for (final e in o.delta.stats.entries)
        _DeltaPart(
          '${Stat.label(e.key)} ${signed(e.value)}',
          good: e.key == Stat.stress ? e.value < 0 : e.value > 0,
          up: e.value > 0,
        ),
      for (final e in o.delta.affection.entries)
        _DeltaPart(
          '${c.characterName(e.key)} 호감 ${signed(e.value)}',
          good: e.value > 0,
          up: e.value > 0,
        ),
      for (final e in o.delta.trust.entries)
        _DeltaPart(
          '${c.characterName(e.key)} 신뢰 ${signed(e.value)}',
          good: e.value > 0,
          up: e.value > 0,
        ),
    ];

    return BottomPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  keepAll(headline),
                  style: context.text.titleMedium?.copyWith(color: fg),
                ),
              ),
              if (o.combo > 0) ...[
                const SizedBox(width: AppSpace.sm),
                ComboBadge(combo: o.combo, onFire: o.combo >= 3, dense: true),
              ],
            ],
          ),
          if (heard != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                keepAll('→ "${c.say(heard.text)}" 으로 알아들었어요'),
                style: context.text.bodySmall?.copyWith(color: fg),
              ),
            ),
          if (o.comboBroken)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Row(
                children: [
                  Icon(Icons.trending_down, size: 14, color: fg),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '콤보 끊김',
                    style: context.text.labelMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          if (c.minigameNote != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                keepAll(c.minigameNote!),
                style: context.text.bodyMedium?.copyWith(color: fg),
              ),
            ),
          const SizedBox(height: AppSpace.md),
          // 변화량은 색 + 부호 + 화살표 3중. 한 줄 문장 나열보다 눈에 먼저 든다.
          if (parts.isEmpty)
            Text('변화 없음', style: context.text.bodyMedium?.copyWith(color: fg))
          else
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [for (final p in parts) _DeltaChip(part: p)],
            ),
          if (o.delta.album != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.photo_album_outlined, size: 16, color: fg),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      keepAll('흑역사 앨범에 추가: ${o.delta.album}'),
                      style: context.text.bodySmall?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          // 자유 입력 자동 확정이면 무료 되돌리기(이벤트당 1회, 광고 없음 — 07 §3.3).
          // 광고 되돌리기와 합쳐 1회라 둘 다 뜨지 않는다.
          if (c.canOfferFreeUndo)
            Center(
              child: TextButton.icon(
                onPressed: c.undoFree,
                icon: const Icon(Icons.replay, size: 18),
                style: TextButton.styleFrom(foregroundColor: fg),
                label: Text(keepAll('그런 뜻 아니었어요')),
              ),
            )
          else if (c.canOfferUndo)
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await AdManager.instance.showRewarded(
                    placement: 'undo',
                  );
                  if (ok) {
                    c.undoChoice();
                  } else if (context.mounted) {
                    adFailedSnack(context);
                  }
                },
                icon: const Icon(Icons.replay, size: 18),
                // 톤 배경 위에서도 대비를 지키기 위해 전경색만 맞춘다.
                style: TextButton.styleFrom(foregroundColor: fg),
                label: const Text('10초 전으로 (광고)'),
              ),
            ),
          if (c.canOfferFreeUndo || c.canOfferUndo)
            const SizedBox(height: AppSpace.sm),
          FilledButton(
            onPressed: c.continueAfterChoice,
            child: const Text('계속'),
          ),
        ],
      ),
    );
  }
}

/// 결과 한 항목. 문자열은 가공하지 않고 방향만 따로 들고 있다.
@immutable
class _DeltaPart {
  final String text;

  /// 이로운 변화인지. 색을 정한다.
  final bool good;

  /// 수치가 올랐는지. 화살표 방향을 정한다(스트레스 +2 는 ↑ + 위험색).
  final bool up;
  const _DeltaPart(this.text, {required this.good, required this.up});
}

/// 변화량 칩. 색 + 부호(문자열에 이미 있음) + 화살표 아이콘으로 방향을 말한다.
class _DeltaChip extends StatelessWidget {
  final _DeltaPart part;
  const _DeltaChip({required this.part});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.deltaColor(good: part.good);
    // 결과 패널 배경이 톤(로즈·위험)으로 바뀌어도 의미색 대비가 무너지지 않게
    // 칩은 항상 가장 밝은(다크: 가장 어두운) 표면 위에 올린다.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLowest,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: color, width: AppBorderWidth.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            part.up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 13,
            color: color,
          ),
          const SizedBox(width: AppSpace.xxs),
          Text(part.text, style: t.numericSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
