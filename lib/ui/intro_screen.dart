import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics.dart';
import '../ads/ad_manager.dart';
import '../audio/sfx_service.dart';
import '../engine/models.dart';
import '../engine/player_name.dart';
import '../engine/text_template.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'notification_card.dart';
import 'onboarding_gender_screen.dart';
import 'onboarding_name_screen.dart';
import 'preference_screen.dart';
import 'title_screen.dart';
import 'widgets.dart';

/// 첫 실행 화면. 규격은 docs/DESIGN_SYSTEM.md §2.14.
///
/// 홈(세이브 카드·하트·앨범이 있는 관리 화면)은 이미 이 게임을 아는 사람의 화면이다.
/// 처음 켠 사람에게는 **타이틀 한 장**([TitleScreen], §2.16)으로 무슨 앱인지 먼저 말하고,
/// 그다음 설명 대신 **문자 한 통**을 준다 — 태현의 알림 카드가 내려오고
/// (`Sfx.msgIn` + 진동), 탭해서 열면 그 대화 안에서 대답·이름·"나는?" 까지 끝난다.
/// 대화 안에는 여전히 "시작하기" 버튼이 없다 — 마지막 답이 곧 시작 버튼이다.
/// 근거: docs/review/00_VERDICT.md §3, docs/overhaul/01_benchmark.md §2 #5·#12.
///
/// 마지막 답 뒤에는 캐스트 소개([PreferenceScreen], §2.9)가 한 장 선다. 누구를 만나는지
/// 모르고 100일에 들어가지 않게 하려고 새 게임 흐름이 원래 갖고 있던 단계인데, 인트로가
/// `newGame` 을 직접 부르면서 첫 실행에서만 빠져 있었다. 거기서 뒤로 가면 인트로의
/// 마지막 질문으로 돌아온다(아무것도 저장되지 않는다).
///
/// MBTI 는 여기서 묻지 않는다. D+4 `m_mbti_chat` 대화 안에서 받는다(R6,
/// `GameController.shouldAskMbti` · `event_screen.dart` 의 MBTI 시트).
///
/// 이 화면은 아무것도 저장하지 않다가 **캐스트 소개의 `시작하기`** 에서 한 번에 저장한다 —
/// 그 전에 앱을 닫으면 다음 실행에 타이틀부터 다시 선다.
class IntroScreen extends StatefulWidget {
  final GameController c;
  const IntroScreen({super.key, required this.c});

  /// 첫 문자를 보내는 친구. 성별 중립 조연이라 캐스트(characters.json)에 없다 —
  /// 아바타는 이니셜로 그린다.
  static const friendName = '태현';

  /// 알림 카드에 뜨는 한 줄. 첫 화면에서 읽히는 유일한 문장이다.
  static const previewLine = '100일 프로젝트, 진짜 할 거야?';

  static const openLines = ['야', previewLine];
  static const yesLabel = '한다. 올해는 다르다';
  static const maybeLabel = '…일단 해볼게';
  static const dealReply = '오케이. 오늘부터 D+1이다';

  static const nameQuestion = '그래서, 뭐라고 부르지?';
  static const nameHint = OnboardingNameScreen.fieldHint;
  static const nameRule = OnboardingNameScreen.rule;
  static const nameSubmitLabel = '이걸로 불러';
  static const nameSkipLabel = OnboardingNameScreen.skipLabel;
  static const nameSkipReply = '알았다. 그냥 부르던 대로 부른다';

  static const genderQuestion = '아 맞다, 너는?';
  static const genderNote = OnboardingGenderScreen.note;

  /// 성별을 묻는 태현의 말. 온보딩 화면의 부제(`만나게 될 사람들이 달라져요`)는
  /// 존댓말이라 반말을 쓰는 태현의 말풍선에 그대로 넣으면 말투가 깨진다.
  static const genderAsk = '누가 먼저 말 걸지가 달라지거든';
  static const sideQuestion = '그럼 누구부터 소개해 줄까?';
  static const startReply = '좋아. 그럼 시작이다';

  /// 캐스트 소개로 넘어가기 직전의 한 줄. 다음 화면(`이 사람들을 만나게 돼요`)이
  /// 대화에서 튀어나온 것이 아니라 태현이 보여 주는 것으로 읽히게 한다.
  static const castIntro = '누가 있는지부터 보여 줄게';

  /// 마지막 답 뒤 태현의 두 줄을 읽을 시간. 이만큼 뒤에 캐스트 소개가 열린다.
  static const startDelay = Duration(milliseconds: 900);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

/// 인트로의 단계. 0단계(타이틀)와 1단계(알림)만 화면을 통째로 바꾸고,
/// 그 뒤로는 화면 하나에 하단 패널만 바뀐다.
enum IntroStep {
  /// 앱의 첫 프레임. 이름·부제·그림 한 장([TitleScreen]).
  title,

  /// 잠금화면 알림 카드(탭해서 열기).
  notice,

  /// "진짜 할 거야?" 에 대한 답.
  deal,

  /// "뭐라고 부르지?" — 이름 입력(건너뛰기 있음).
  name,

  /// "너는?" — 남자 / 여자 / 선택 안 할래요.
  gender,

  /// "선택 안 할래요" 일 때만. 어느 쪽 캐스트부터 만날지.
  side,

  /// 답이 끝났다. 태현의 마지막 줄을 읽는 동안 캐스트 소개를 연다.
  starting,
}

class _IntroScreenState extends State<IntroScreen> {
  GameController get c => widget.c;

  IntroStep _step = IntroStep.title;

  /// 지금까지의 대화. 태현 줄·내 줄이 온 순서대로 쌓인다.
  final List<Line> _lines = [];

  /// 알림 자동 열림 · 시작 지연. 화면이 내려가면 끊는다.
  Timer? _timer;

  late final TextEditingController _name = TextEditingController()
    ..addListener(() => setState(() {}));

  /// 이번 인트로에서 고른 값들. 마지막 답에서 한 번에 저장한다.
  String? _gender;
  String? _pickedName;

  @override
  void initState() {
    super.initState();
    c.logOnboardingStep(Analytics.stepIntro);
  }

  /// 타이틀의 `시작하기`. 여기서부터가 예전의 첫 화면이다 — 문자 도착음과 진동도
  /// 알림 카드가 실제로 내려올 때 낸다(04 §2.1과 같은 큐). 타이틀 위에서 울리면
  /// 화면에 없는 알림의 소리가 된다.
  void _enterNotice() {
    if (!mounted || _step != IntroStep.title) return;
    SfxService.instance.cue(Sfx.msgIn);
    setState(() => _step = IntroStep.notice);
    _timer?.cancel();
    _timer = Timer(NotificationPreview.autoOpen, _openChat);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    super.dispose();
  }

  /// 알림 카드를 열어 대화를 시작한다(탭 또는 1.8초 자동). 두 번 불려도 한 번만 연다.
  void _openChat() {
    if (!mounted || _step != IntroStep.notice) return;
    _timer?.cancel();
    setState(() {
      _lines.addAll([
        for (final t in IntroScreen.openLines) Line(who: 'them', text: t),
      ]);
      _step = IntroStep.deal;
    });
  }

  void _say(String text) => _lines.add(Line(who: 'me', text: text));
  void _them(String text) => _lines.add(Line(who: 'them', text: text));

  /// "진짜 할 거야?" 에 대한 답. 어느 쪽이든 판은 시작된다 — 이 답이 시작 버튼이다.
  void _answerDeal(String label) {
    SfxService.instance.cue(Sfx.msgOut);
    setState(() {
      _say(label);
      _them(IntroScreen.dealReply);
      _them(IntroScreen.nameQuestion);
      _step = IntroStep.name;
    });
    c.logOnboardingStep(Analytics.stepName);
  }

  String? get _nameError => _composing ? null : PlayerName.validate(_name.text);

  /// 한글 조합 중에는 오류를 띄우지 않는다(이름 화면과 같은 규칙).
  bool get _composing {
    final v = _name.value.composing;
    return v.isValid && !v.isCollapsed;
  }

  bool get _canSubmitName =>
      PlayerName.isValid(_name.text) && _nameError == null;

  void _submitName() {
    if (!_canSubmitName) return;
    final n = PlayerName.normalize(_name.text);
    SfxService.instance.cue(Sfx.msgOut);
    _pickedName = n;
    setState(() {
      _say(n);
      _them('$n. 외웠다');
      _them(IntroScreen.genderQuestion);
      _them(IntroScreen.genderAsk);
      _step = IntroStep.gender;
    });
    c.logOnboardingStep(Analytics.stepGender);
  }

  /// 이름 없이 진행. 대사는 대체어로 나간다(docs/NAME_GUIDE.md) — 아무것도 막지 않는다.
  void _skipName() {
    _pickedName = null;
    setState(() {
      _them(IntroScreen.nameSkipReply);
      _them(IntroScreen.genderQuestion);
      _them(IntroScreen.genderAsk);
      _step = IntroStep.gender;
    });
    c.logOnboardingStep(Analytics.stepGender);
  }

  /// "나는?" 의 답. 남자·여자면 만날 쪽이 정해지므로 여기서 캐스트 소개가 열리고,
  /// "선택 안 할래요" 면 어느 쪽부터 볼지 한 번 더 묻는다.
  void _answerGender(String gender, String label) {
    _markCastReturn();
    SfxService.instance.cue(Sfx.msgOut);
    _gender = gender;
    final side = PlayerGender.sideFor(gender);
    if (side != null) {
      setState(() => _say(label));
      _finish(side);
      return;
    }
    setState(() {
      _say(label);
      _them(IntroScreen.sideQuestion);
      _step = IntroStep.side;
    });
  }

  void _answerSide(String preference) {
    _markCastReturn();
    SfxService.instance.cue(Sfx.msgOut);
    setState(() => _say(Preference.label(preference)));
    _finish(preference);
  }

  /// 캐스트 소개에서 뒤로 왔을 때 돌아갈 자리. 마지막 답 **직전**의 대화 길이와 단계다.
  int? _castReturnLines;
  IntroStep? _castReturnStep;

  void _markCastReturn() {
    _castReturnLines = _lines.length;
    _castReturnStep = _step;
  }

  /// 마지막 답. 태현의 두 줄을 읽는 동안 캐스트 소개를 연다. 저장은 아직 안 한다 —
  /// 캐스트 소개에서 뒤로 가면 이 대화로 돌아오고 아무것도 남지 않아야 한다.
  void _finish(String preference) {
    setState(() {
      _them(IntroScreen.startReply);
      _them(IntroScreen.castIntro);
      _step = IntroStep.starting;
    });
    _timer?.cancel();
    _timer = Timer(
      IntroScreen.startDelay,
      () => unawaited(_openCast(preference)),
    );
  }

  /// 캐스트 소개(§2.9). 인트로에서 고른 쪽을 먼저 펼치고, 거기서 반대쪽으로 넘어가면
  /// 실제로 시작하는 쪽은 **보고 있던 쪽**이다(홈에서 여는 새 게임과 같은 규칙).
  Future<void> _openCast(String side) async {
    if (!mounted) return;
    // 이름·MBTI 는 아직 저장 전이다. 캐스트 카드의 첫 메시지가 `{name}` 을 그대로
    // 드러내지 않도록 잠깐만 올려 둔다(onboarding_gender_screen 의 `cast` 와 같은 처리).
    final savedName = TextTemplate.currentName;
    final savedMbti = TextTemplate.currentMbti;
    TextTemplate.currentName = _pickedName;
    TextTemplate.currentMbti = c.playerMbti;
    final String? picked;
    try {
      picked = await PreferenceScreen.show(
        context,
        c.bundle,
        side: side,
        playerMbti: c.playerMbti,
      );
    } finally {
      TextTemplate.currentName = savedName;
      TextTemplate.currentMbti = savedMbti;
    }
    if (!mounted) return;
    if (picked == null) {
      _revertToLastQuestion();
      return;
    }
    await _start(picked);
  }

  /// 캐스트 소개에서 뒤로 온 경우. 마지막 답과 그 뒤 태현의 줄을 지우고 질문으로
  /// 되돌린다. 이 화면에는 다른 출구가 없으므로 되돌리지 않으면 막다른 길이 된다.
  void _revertToLastQuestion() {
    final n = _castReturnLines;
    final step = _castReturnStep;
    if (n == null || step == null || n > _lines.length) return;
    setState(() {
      _lines.removeRange(n, _lines.length);
      _step = step;
    });
  }

  /// 고른 값을 한 번에 저장하고 첫날을 연다. 여기서 홈을 거치지 않는다 —
  /// 캐스트 소개 다음 화면은 D+1 날짜 카드다.
  Future<void> _start(String preference) async {
    if (!mounted) return;
    final g = _gender;
    if (g != null) await c.setPlayerGender(g);
    // 이름 단계는 거쳤다 — 건너뛰었어도 다음 새 게임에서 다시 묻지 않는다.
    final n = _pickedName;
    n == null ? await c.skipPlayerName() : await c.setPlayerName(n);
    await c.markIntroSeen();
    // 이제야 ATT·동의 폼을 띄운다(main 이 첫 실행에서는 미뤄 뒀다).
    unawaited(AdManager.instance.init());
    // MBTI 는 D+4 대화에서 묻는다(mbtiAsked 를 여기서 세우지 않는다).
    c.logOnboardingDone(
      preference: preference,
      mbtiSource: Analytics.mbtiLater,
    );
    await c.newGame(preference: preference);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == IntroStep.title) {
      return TitleScreen(onStart: _enterNotice);
    }
    if (_step == IntroStep.notice) {
      return NotificationPreview(
        name: IntroScreen.friendName,
        characterId: null,
        preview: IntroScreen.previewLine,
        day: 1,
        onOpen: _openChat,
      );
    }
    final t = context.tokens;
    return Scaffold(
      appBar: _header(context),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: t.chatBackground,
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.only(
                  top: AppSpace.sm,
                  bottom: AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ChatDivider(text: 'D+1'),
                    for (final (i, l) in _lines.indexed)
                      ChatBubble(
                        line: l,
                        partnerName: IntroScreen.friendName,
                        isFirstOfGroup: i == 0 || _lines[i - 1].who != l.who,
                        isLastOfGroup:
                            i == _lines.length - 1 ||
                            _lines[i + 1].who != l.who,
                      ),
                  ],
                ),
              ),
            ),
          ),
          _panel(context),
        ],
      ),
    );
  }

  /// 채팅 화면과 같은 머리줄: 이름 + 상태 한 줄. 뒤로 갈 곳이 없으므로 뒤로 버튼은 없다.
  PreferredSizeWidget _header(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: AppSpace.screenX,
    title: Row(
      children: [
        const CharacterAvatar(
          name: IntroScreen.friendName,
          size: AppSize.avatarSm,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(IntroScreen.friendName, style: context.text.titleMedium),
              Text(
                '온라인',
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _panel(BuildContext context) => switch (_step) {
    IntroStep.deal => BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChoiceButton(
            key: const Key('intro-yes'),
            text: IntroScreen.yesLabel,
            onPressed: () => _answerDeal(IntroScreen.yesLabel),
          ),
          const SizedBox(height: AppSpace.listGap),
          ChoiceButton(
            key: const Key('intro-maybe'),
            text: IntroScreen.maybeLabel,
            onPressed: () => _answerDeal(IntroScreen.maybeLabel),
          ),
        ],
      ),
    ),
    IntroStep.name => BottomPanel(child: _nameField(context)),
    IntroStep.gender => BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (g, icon, label, hint))
              in OnboardingGenderScreen.options.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpace.listGap),
            GenderOptionCard(
              key: Key('gender-$g'),
              icon: icon,
              label: label,
              hint: hint,
              onTap: () => _answerGender(g, label),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          _note(context, IntroScreen.genderNote),
        ],
      ),
    ),
    IntroStep.side => BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, p) in Preference.genders.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpace.listGap),
            ChoiceButton(
              key: Key('intro-side-$p'),
              text: Preference.label(p),
              onPressed: () => _answerSide(p),
            ),
          ],
        ],
      ),
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _nameField(BuildContext context) {
    final scheme = context.scheme;
    OutlineInputBorder border(Color color, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: w),
    );
    final error = _nameError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('intro-name-field'),
          controller: _name,
          autofocus: false,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitName(),
          style: context.text.titleMedium,
          // 이름 규칙·거르개는 이름 화면과 같은 것을 쓴다(docs/NAME_GUIDE.md).
          maxLength: PlayerName.maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
          inputFormatters: [NameInputFormatter()],
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
          decoration: InputDecoration(
            hintText: IntroScreen.nameHint,
            helperText: IntroScreen.nameRule,
            helperStyle: context.text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            helperMaxLines: 2,
            errorText: error,
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
        ),
        const SizedBox(height: AppSpace.sm),
        FilledButton(
          key: const Key('intro-name-submit'),
          onPressed: _canSubmitName ? _submitName : null,
          child: const Text(IntroScreen.nameSubmitLabel),
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          key: const Key('intro-name-skip'),
          onPressed: _skipName,
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
          ),
          child: const Text(IntroScreen.nameSkipLabel),
        ),
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: AppSpace.xxs),
        child: Icon(
          Icons.lock_outline,
          size: 16,
          color: context.scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Text(
          keepAll(text),
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
