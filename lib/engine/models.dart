/// 모쏠 키우기 데이터 모델.
/// 모든 스토리 데이터는 assets/story/*.json 에서 읽어 이 클래스들로 변환된다.
library;

enum EventLayer { main, route, daily, crisis, hidden }

EventLayer layerFrom(String? s) => EventLayer.values.firstWhere(
  (e) => e.name == s,
  orElse: () => EventLayer.daily,
);

/// 스탯 키와 표시 이름.
class Stat {
  static const charm = 'charm';
  static const talk = 'talk';
  static const esteem = 'esteem';
  static const sense = 'sense';
  static const money = 'money';
  static const stress = 'stress';
  static const sincerity = 'sincerity';
  static const reputation = 'reputation';

  static const visible = [charm, talk, esteem, sense, money, stress];
  static const hidden = [sincerity, reputation];
  static const all = [...visible, ...hidden];

  static const labels = {
    charm: '매력',
    talk: '화술',
    esteem: '자존감',
    sense: '눈치',
    money: '돈',
    stress: '스트레스',
    sincerity: '진정성',
    reputation: '평판',
  };

  static String label(String key) => labels[key] ?? key;
  static int maxOf(String key) => key == money ? 9999 : 100;
}

/// 새 게임에서 고르는 "누구를 만나고 싶나요?" 선호. 회차마다 하나.
///
/// - [female] / [male]: 그 성별 캐릭터만 등장한다(이벤트·효과·엔딩·신호·홈 전부).
/// - [all]: 선호 필드가 없던 예전 세이브. 모든 캐릭터가 등장하고, 쪽별 버전이 있는
///   이벤트(`trigger.pref`)는 [female] 쪽을 쓴다(선호 도입 전 경험을 그대로 유지).
class Preference {
  static const female = 'f';
  static const male = 'm';
  static const all = 'all';

  /// 캐릭터 성별이자 `trigger.pref` 가 가질 수 있는 값.
  static const genders = [female, male];
  static const values = [female, male, all];

  /// 모르는 값·없는 값은 [all] (예전 세이브 호환).
  static String parse(Object? v) => v is String && values.contains(v) ? v : all;

  /// `trigger.pref` 판정에 쓰는 쪽. [all] 은 [female] 쪽 버전을 본다.
  static String side(String pref) => pref == male ? male : female;

  /// [gender] 캐릭터가 [pref] 회차에 등장하는지.
  static bool allowsGender(String pref, String gender) =>
      pref == all || pref == gender;

  /// `trigger.pref` 가 [eventPref] 인 이벤트·엔딩이 [pref] 회차에 열리는지.
  static bool allowsSide(String pref, String? eventPref) =>
      eventPref == null || eventPref == side(pref);

  /// 화면 표기. 예: "1회차 · 여성 캐릭터".
  static String label(String pref) => switch (pref) {
    female => '여성 캐릭터',
    male => '남성 캐릭터',
    _ => '모든 캐릭터',
  };
}

/// 온보딩 1단계 "나는?" 의 답. 기기 메타(`PlayerMeta.playerGender`)에만 저장하고
/// 밖으로 보내지 않는다. 주인공 대사는 이 값과 무관하게 성별 중립이다.
///
/// 쓰임은 단 하나: 새 게임의 캐스트 소개(2단계)에서 어느 쪽을 **먼저** 보여 줄지.
class PlayerGender {
  static const male = 'm';
  static const female = 'f';

  /// "선택 안 할래요". 캐스트 소개에서 두 쪽을 비교해 고른다.
  static const none = 'none';

  static const values = [male, female, none];

  /// 모르는 값·없는 값은 null(아직 안 물어봄).
  static String? parse(Object? v) =>
      v is String && values.contains(v) ? v : null;

  /// 캐스트 소개의 기본 쪽. 남자 → 여성 캐릭터, 여자 → 남성 캐릭터, 그 밖은 null(비교).
  static String? sideFor(String? gender) => switch (gender) {
    male => Preference.female,
    female => Preference.male,
    _ => null,
  };

  /// 온보딩 버튼·설정 행의 표기.
  static String label(String? gender) => switch (gender) {
    male => '남자',
    female => '여자',
    none => '선택 안 함',
    _ => '아직 안 정함',
  };
}

/// 캐릭터 역할. 여성·남성 쪽이 역할마다 한 명씩 짝을 이룬다(docs/CAST_BIBLE.md).
class CastRole {
  static const senior = 'senior';
  static const parttime = 'parttime';
  static const blinddate = 'blinddate';
  static const online = 'online';
  static const classmate = 'classmate';

  /// 히든 역할. 이 역할이면 `hidden: true`, 아니면 `hidden: false`.
  static const trainer = 'trainer';

  static const values = [
    senior,
    parttime,
    blinddate,
    online,
    classmate,
    trainer,
  ];

  static const labels = {
    senior: '선배',
    parttime: '알바 동료',
    blinddate: '소개팅 상대',
    online: '온라인 친구',
    classmate: '초등 동창',
    trainer: '트레이너',
  };

  static String label(String role) => labels[role] ?? role;
}

class Range {
  final int min;
  final int max;
  const Range(this.min, this.max);

  bool contains(int v) => v >= min && v <= max;

  static Range? parse(Object? j) {
    if (j == null) return null;
    if (j is List && j.length == 2) {
      return Range((j[0] as num).toInt(), (j[1] as num).toInt());
    }
    if (j is num) return Range(j.toInt(), 1 << 30);
    throw FormatException('range 형식 오류: $j');
  }

  @override
  String toString() => '[$min, $max]';
}

Map<String, Range> _rangeMap(Object? j) => j == null
    ? const {}
    : (j as Map).map((k, v) => MapEntry(k as String, Range.parse(v)!));

Map<String, int> _intMap(Object? j) => j == null
    ? const {}
    : (j as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));

List<String> _strList(Object? j) =>
    j == null ? const [] : (j as List).map((e) => e as String).toList();

/// "N명 이상이 호감도 min 이상" 같은 집계 조건.
class CountCondition {
  final int min;
  final int count;
  const CountCondition(this.min, this.count);
}

/// 이벤트·엔딩 발생 조건. 키 `*` 는 이벤트가 속한 캐릭터 자신을 뜻한다.
class Trigger {
  final Range? day;
  final Range? run;
  final Map<String, Range> stats;
  final Map<String, Range> affection;
  final Map<String, Range> trust;
  final List<String> flags;
  final List<String> notFlags;
  final CountCondition? anyAffection;

  /// [Preference.female] | [Preference.male]. 있으면 그 선호로 시작한 회차에서만 열린다.
  /// main 이벤트의 쪽별 버전, 공용 엔딩의 쪽별 조건에 쓴다. [Preference.all] 세이브는
  /// [Preference.female] 쪽으로 본다([Preference.side]).
  final String? pref;

  const Trigger({
    this.day,
    this.run,
    this.stats = const {},
    this.affection = const {},
    this.trust = const {},
    this.flags = const [],
    this.notFlags = const [],
    this.anyAffection,
    this.pref,
  });

  static const always = Trigger();

  factory Trigger.fromJson(Map<String, dynamic>? j) {
    if (j == null) return always;
    final any = j['anyAffection'] as Map?;
    return Trigger(
      day: Range.parse(j['day']),
      run: Range.parse(j['run']),
      stats: _rangeMap(j['stats']),
      affection: _rangeMap(j['affection']),
      trust: _rangeMap(j['trust']),
      flags: _strList(j['flags']),
      notFlags: _strList(j['notFlags']),
      anyAffection: any == null
          ? null
          : CountCondition(
              (any['min'] as num).toInt(),
              (any['count'] as num).toInt(),
            ),
      pref: j['pref'] as String?,
    );
  }
}

/// 선택지 잠금 조건. 값은 최소치.
class Requirement {
  final Map<String, int> stats;
  final Map<String, int> affection;
  final Map<String, int> trust;
  final List<String> flags;

  const Requirement({
    this.stats = const {},
    this.affection = const {},
    this.trust = const {},
    this.flags = const [],
  });

  factory Requirement.fromJson(Map<String, dynamic> j) => Requirement(
    stats: _intMap(j['stats']),
    affection: _intMap(j['affection']),
    trust: _intMap(j['trust']),
    flags: _strList(j['flags']),
  );
}

/// 선택 결과로 적용되는 변화.
class Effects {
  final Map<String, int> stats;
  final Map<String, int> affection;
  final Map<String, int> trust;
  final List<String> setFlags;
  final List<String> clearFlags;
  final String? album;

  const Effects({
    this.stats = const {},
    this.affection = const {},
    this.trust = const {},
    this.setFlags = const [],
    this.clearFlags = const [],
    this.album,
  });

  static const none = Effects();

  factory Effects.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    return Effects(
      stats: _intMap(j['stats']),
      affection: _intMap(j['affection']),
      trust: _intMap(j['trust']),
      setFlags: _strList(j['setFlags']),
      clearFlags: _strList(j['clearFlags']),
      album: j['album'] as String?,
    );
  }
}

/// 사진 메시지(docs/MOMENTS_SPEC.md §1.3). 실제 이미지는 없고 아이콘과 장면 설명만 있다.
class Photo {
  /// [Photo.icons] 중 하나. 모르는 값이면 UI 가 기본 사진 아이콘을 쓴다.
  final String icon;

  /// 사진 속 장면 설명. 20자 이내([maxCaption]).
  final String caption;

  const Photo({required this.icon, this.caption = ''});

  /// 규격이 정한 아이콘 이름 14종.
  static const icons = [
    'cafe',
    'food',
    'sky',
    'night',
    'sea',
    'selfie',
    'pet',
    'book',
    'gym',
    'game',
    'music',
    'flower',
    'street',
    'ticket',
  ];

  static const maxCaption = 20;

  /// 캡션을 [f] 로 바꾼 사본(이름 치환, lib/engine/text_template.dart).
  Photo mapText(String Function(String) f) =>
      Photo(icon: icon, caption: f(caption));

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
    icon: (j['icon'] as String?) ?? '',
    caption: (j['caption'] as String?) ?? '',
  );
}

/// 채팅 한 줄. who: them | me | narr | sys. sys 는 wait(초) 로 읽씹 대기를 표현한다.
class Line {
  final String who;
  final String text;
  final int wait;
  final String? name;

  /// 사진 메시지. 있으면 말풍선 대신 사진 카드를 그리고 [text] 는 그 아래 말풍선이 된다.
  final Photo? photo;

  const Line({
    required this.who,
    this.text = '',
    this.wait = 0,
    this.name,
    this.photo,
  });

  bool get isWait => who == 'sys' && wait > 0;

  /// 글과 사진 캡션을 [f] 로 바꾼 사본. 화면에 내기 직전 이름 치환에 쓴다.
  Line mapText(String Function(String) f) => Line(
    who: who,
    text: f(text),
    wait: wait,
    name: name,
    photo: photo?.mapText(f),
  );

  factory Line.fromJson(Map<String, dynamic> j) => Line(
    who: (j['who'] as String?) ?? 'them',
    text: (j['text'] as String?) ?? '',
    wait: ((j['wait'] as num?) ?? 0).toInt(),
    name: j['name'] as String?,
    photo: j['photo'] == null
        ? null
        : Photo.fromJson(j['photo'] as Map<String, dynamic>),
  );
}

class Choice {
  final String text;
  final Requirement? require;
  final Effects effects;
  final String? next;

  /// 0~100. null 이면 항상 성공.
  final int? chance;
  final Effects fail;
  final String? failNext;

  /// 미니게임 id. 있으면 확률 대신 실력이 성패를 가른다.
  final String? minigame;

  /// 선택 뒤 상대의 반응. 성공이면 [reply], 실패면 [failReply],
  /// 크리티컬이면 [critReply](없으면 [reply]). 대화가 한쪽 말로 끝나지 않게 한다.
  final List<Line> reply;
  final List<Line> failReply;
  final List<Line> critReply;

  /// 전화(`format: "call"`) 이벤트의 `거절` 버튼이 고르는 선택지.
  /// 통화 중 선택지 패널에는 보이지 않는다(docs/MOMENTS_SPEC.md §1.1).
  final bool decline;

  const Choice({
    required this.text,
    this.require,
    this.effects = Effects.none,
    this.next,
    this.chance,
    this.fail = Effects.none,
    this.failNext,
    this.minigame,
    this.reply = const [],
    this.failReply = const [],
    this.critReply = const [],
    this.decline = false,
  });

  /// 문구와 반응 줄을 [f] 로 바꾼 사본. 효과·조건·다음 이벤트는 그대로.
  Choice mapText(String Function(String) f) => Choice(
    text: f(text),
    require: require,
    effects: effects,
    next: next,
    chance: chance,
    fail: fail,
    failNext: failNext,
    minigame: minigame,
    reply: [for (final l in reply) l.mapText(f)],
    failReply: [for (final l in failReply) l.mapText(f)],
    critReply: [for (final l in critReply) l.mapText(f)],
    decline: decline,
  );

  /// 이 결과에 맞는 반응 줄.
  List<Line> replyFor({required bool success, required bool critical}) {
    if (!success) return failReply;
    if (critical && critReply.isNotEmpty) return critReply;
    return reply;
  }

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(
    text: j['text'] as String,
    require: j['require'] == null
        ? null
        : Requirement.fromJson(j['require'] as Map<String, dynamic>),
    effects: Effects.fromJson(j['effects'] as Map<String, dynamic>?),
    next: j['next'] as String?,
    chance: (j['chance'] as num?)?.toInt(),
    fail: Effects.fromJson(j['fail'] as Map<String, dynamic>?),
    failNext: j['failNext'] as String?,
    minigame: j['minigame'] as String?,
    reply: _replyLines(j['reply']),
    failReply: _replyLines(j['failReply']),
    critReply: _replyLines(j['critReply']),
    decline: (j['decline'] as bool?) ?? false,
  );
}

/// 반응 줄. 문자열이면 상대(them)의 말 한 줄, 객체면 [Line] 그대로.
List<Line> _replyLines(Object? j) {
  if (j == null) return const [];
  final list = j is List ? j : [j];
  return [
    for (final e in list)
      e is String
          ? Line(who: 'them', text: e)
          : Line.fromJson(e as Map<String, dynamic>),
  ];
}

class StoryEvent {
  final String id;
  final EventLayer layer;
  final String? character;
  final Trigger trigger;
  final int weight;

  /// main 이벤트의 고정 날짜.
  final int? day;

  /// true 면 한 회차에 한 번만 등장.
  final bool once;
  final String title;
  final List<Line> lines;
  final List<Choice> choices;

  /// 힌트 리워드 광고가 가리킬 정답 선택지 인덱스.
  final int? hint;
  final String? cliffhanger;

  /// 화면 형식. [formatChat](기본) | [formatCall]. 검증기가 그 밖의 값을 거부한다.
  final String format;

  /// 상대가 먼저 보낸 톡 알림 문장(40자 이내). 있으면 이벤트 진입 때 알림 카드가 먼저 뜬다.
  final String? preview;

  static const formatChat = 'chat';
  static const formatCall = 'call';
  static const formats = [formatChat, formatCall];
  static const maxPreview = 40;

  const StoryEvent({
    required this.id,
    required this.layer,
    this.character,
    this.trigger = Trigger.always,
    this.weight = 1,
    this.day,
    this.once = true,
    this.title = '',
    this.lines = const [],
    this.choices = const [],
    this.hint,
    this.cliffhanger,
    this.format = formatChat,
    this.preview,
  });

  /// 상대가 먼저 거는 전화인지.
  bool get isCall => format == formatCall;

  /// 화면에 보이는 글(제목·대사·사진 캡션·선택지·반응·알림·클리프행어)을 [f] 로 바꾼
  /// 사본. id·조건·효과는 그대로라 엔진에는 원본을 넘긴다. `GameController.shownEvent`.
  StoryEvent mapText(String Function(String) f) => StoryEvent(
    id: id,
    layer: layer,
    character: character,
    trigger: trigger,
    weight: weight,
    day: day,
    once: once,
    title: f(title),
    lines: [for (final l in lines) l.mapText(f)],
    choices: [for (final c in choices) c.mapText(f)],
    hint: hint,
    cliffhanger: cliffhanger == null ? null : f(cliffhanger!),
    format: format,
    preview: preview == null ? null : f(preview!),
  );

  /// 화면에 보이는 글 전부(위치, 문자열). 검증기가 자리표시자 형식을 본다.
  Iterable<(String, String)> get displayTexts sync* {
    yield ('$id.title', title);
    if (preview != null) yield ('$id.preview', preview!);
    if (cliffhanger != null) yield ('$id.cliffhanger', cliffhanger!);
    Iterable<(String, String)> linesOf(String where, List<Line> ls) sync* {
      for (var i = 0; i < ls.length; i++) {
        yield ('$where[$i]', ls[i].text);
        final p = ls[i].photo;
        if (p != null) yield ('$where[$i].photo.caption', p.caption);
      }
    }

    yield* linesOf('$id.lines', lines);
    for (var i = 0; i < choices.length; i++) {
      final c = choices[i];
      final w = '$id.choices[$i]';
      yield ('$w.text', c.text);
      yield* linesOf('$w.reply', c.reply);
      yield* linesOf('$w.failReply', c.failReply);
      yield* linesOf('$w.critReply', c.critReply);
    }
  }

  /// 사진 줄이 있는지. 대사와 반응(reply/failReply/critReply) 전부를 본다.
  bool get hasPhoto =>
      lines.any((l) => l.photo != null) ||
      choices.any(
        (c) => [
          ...c.reply,
          ...c.failReply,
          ...c.critReply,
        ].any((l) => l.photo != null),
      );

  /// 형식을 깨는 이벤트("모먼트"): 전화이거나, 알림이 있거나, 사진 줄이 있다.
  bool get isMoment => isCall || preview != null || hasPhoto;

  /// 전화의 거절 선택지 인덱스. 없으면 null.
  int? get declineIndex {
    final i = choices.indexWhere((c) => c.decline);
    return i < 0 ? null : i;
  }

  factory StoryEvent.fromJson(Map<String, dynamic> j) {
    final layer = layerFrom(j['layer'] as String?);
    return StoryEvent(
      id: j['id'] as String,
      layer: layer,
      character: j['character'] as String?,
      trigger: Trigger.fromJson(j['trigger'] as Map<String, dynamic>?),
      weight: ((j['weight'] as num?) ?? 1).toInt(),
      day: (j['day'] as num?)?.toInt(),
      once: (j['once'] as bool?) ?? true,
      title: (j['title'] as String?) ?? '',
      lines: ((j['lines'] as List?) ?? const [])
          .map((e) => Line.fromJson(e as Map<String, dynamic>))
          .toList(),
      choices: ((j['choices'] as List?) ?? const [])
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
      hint: (j['hint'] as num?)?.toInt(),
      cliffhanger: j['cliffhanger'] as String?,
      format: (j['format'] as String?) ?? formatChat,
      // 빈 문자열은 없는 것으로 본다(알림 카드에 빈 문장이 뜨지 않게).
      preview: switch (j['preview'] as String?) {
        final p? when p.trim().isNotEmpty => p,
        _ => null,
      },
    );
  }
}

class CharacterDef {
  final String id;
  final String name;

  /// [Preference.female] | [Preference.male]. 필수(검증기가 잡는다).
  final String gender;

  /// [CastRole.values] 중 하나. 필수. 성별마다 역할당 최대 한 명.
  final String role;

  /// 사람이 읽는 소개 호칭(예: "동아리 선배"). 없으면 [CastRole.label].
  final String title;
  final List<String> likes;
  final List<String> mines;
  final bool hidden;

  /// 미니게임용 취향.
  /// [replyZone] 은 선호하는 답장 속도 구간(0 = 즉답, 1 = 하루 뒤).
  final List<double> replyZone;
  final String humor;
  final List<String> tags;
  final int budget;

  /// 캐스트 소개의 한 줄 매력(20자 이내, [maxTagline]). 히든은 써 두되 화면에 내지 않는다.
  final String tagline;

  /// 캐스트 소개의 첫 메시지 미리보기. 없으면 [StoryBundle.firstLineOf] 가 첫 접촉
  /// 이벤트(`<id>_r00`, `<id>_r01` …)의 첫 `them` 대사를 꺼낸다.
  final String? firstLine;

  static const maxTagline = 20;

  const CharacterDef({
    required this.id,
    required this.name,
    this.gender = '',
    this.role = '',
    this.title = '',
    this.likes = const [],
    this.mines = const [],
    this.hidden = false,
    this.replyZone = const [0.35, 0.6],
    this.humor = 'warm',
    this.tags = const [],
    this.budget = 40,
    this.tagline = '',
    this.firstLine,
  });

  factory CharacterDef.fromJson(Map<String, dynamic> j) => CharacterDef(
    id: j['id'] as String,
    name: j['name'] as String,
    gender: (j['gender'] as String?) ?? '',
    role: (j['role'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    likes: _strList(j['likes']),
    mines: _strList(j['mines']),
    hidden: (j['hidden'] as bool?) ?? false,
    replyZone: j['replyZone'] == null
        ? const [0.35, 0.6]
        : (j['replyZone'] as List).map((e) => (e as num).toDouble()).toList(),
    humor: (j['humor'] as String?) ?? 'warm',
    tags: _strList(j['tags']),
    budget: ((j['budget'] as num?) ?? 40).toInt(),
    tagline: ((j['tagline'] as String?) ?? '').trim(),
    firstLine: switch ((j['firstLine'] as String?)?.trim()) {
      final String v when v.isNotEmpty => v,
      _ => null,
    },
  );

  /// [pref] 회차에 등장하는지.
  bool appearsIn(String pref) => Preference.allowsGender(pref, gender);

  /// 화면에 쓰는 호칭. [title] 이 없으면 역할 이름.
  String get displayTitle => title.isNotEmpty ? title : CastRole.label(role);
}

class Ending {
  final String id;
  final String name;
  final String tier;
  final int priority;
  final String? character;
  final Trigger when;
  final String epilogue;

  /// 앨범에서 아직 못 본 엔딩에 보여 줄 한 줄 힌트. 사람이 쓴 문장.
  /// 없으면 UI 가 조건으로 기계 문장을 만든다.
  final String? hint;

  /// true 면 100일을 기다리지 않고 조건 충족 즉시 종료.
  final bool immediate;
  final bool isDefault;

  // 캐릭터 엔딩([character])은 그 캐릭터의 성별로 자동 필터된다([EndingResolver]).
  // 공용 엔딩을 한쪽에만 두려면 `when.pref` 를 쓴다.

  const Ending({
    required this.id,
    required this.name,
    required this.tier,
    this.priority = 0,
    this.character,
    this.when = Trigger.always,
    this.epilogue = '',
    this.hint,
    this.immediate = false,
    this.isDefault = false,
  });

  factory Ending.fromJson(Map<String, dynamic> j) => Ending(
    id: j['id'] as String,
    name: j['name'] as String,
    tier: (j['tier'] as String?) ?? 'good',
    priority: ((j['priority'] as num?) ?? 0).toInt(),
    character: j['character'] as String?,
    when: Trigger.fromJson(j['when'] as Map<String, dynamic>?),
    epilogue: (j['epilogue'] as String?) ?? '',
    hint: j['hint'] as String?,
    immediate: (j['immediate'] as bool?) ?? false,
    isDefault: (j['default'] as bool?) ?? false,
  );
}

class DayAction {
  final String id;
  final String name;
  final String desc;
  final Effects effects;

  const DayAction({
    required this.id,
    required this.name,
    this.desc = '',
    this.effects = Effects.none,
  });

  factory DayAction.fromJson(Map<String, dynamic> j) => DayAction(
    id: j['id'] as String,
    name: j['name'] as String,
    desc: (j['desc'] as String?) ?? '',
    effects: Effects.fromJson(j['effects'] as Map<String, dynamic>?),
  );
}

/// 초반 호감 가속. 첫 며칠은 호감이 **오르는** 효과를 크게 줘서 "붙는 맛" 을
/// 먼저 보여 준다. 감소 효과·신뢰에는 적용하지 않는다(`applyEffects`).
///
/// config.json 예:
/// `"earlyAffection": {"curve": [2, 2, 2, 1.5, 1.5], "maxTotal": 3}` — curve[i] 는 i+1일차 배율.
/// 또는 간단히 `{"untilDay": 10, "multiplier": 1.5}` (1~10일차 1.5배).
/// 곡선 밖(그 뒤 날짜)은 1배. 배율을 곱한 결과는 올림한다(+1 이 +2 가 되는 체감).
class EarlyAffection {
  /// curve[i] = (i+1)일차 배율. 1 보다 작은 값은 1 로 본다.
  final List<double> curve;

  /// 크리티컬(2배)과 곱했을 때의 상한. 1일차 크리티컬이 4배로 폭주하지 않게.
  final double maxTotal;

  const EarlyAffection({this.curve = const [], this.maxTotal = 3});

  static const none = EarlyAffection();

  bool get isEmpty => curve.every((m) => m <= 1);

  /// 마지막으로 가속이 걸리는 날. 가속이 없으면 0.
  int get lastDay {
    for (var i = curve.length - 1; i >= 0; i--) {
      if (curve[i] > 1) return i + 1;
    }
    return 0;
  }

  /// [day] 일차의 초반 배율. 곡선 밖이면 1.
  double multiplierFor(int day) {
    if (day < 1 || day > curve.length) return 1;
    final m = curve[day - 1];
    return m < 1 ? 1 : m;
  }

  /// 초반 배율 × (크리티컬이면 [critFactor]) 를 상한 [maxTotal] 로 자른다.
  /// 상한은 크리티컬 배율보다 작아지지 않는다(크리티컬이 초반에 손해가 되면 안 된다).
  double combined(int day, {bool critical = false, double critFactor = 2}) {
    final base = multiplierFor(day);
    final raw = base * (critical ? critFactor : 1);
    final cap = maxTotal < critFactor ? critFactor : maxTotal;
    return raw > cap ? (base > cap ? base : cap) : raw;
  }

  factory EarlyAffection.fromJson(Object? j) {
    if (j is! Map) return none;
    final cap = ((j['maxTotal'] as num?) ?? 3).toDouble();
    final curve = j['curve'];
    if (curve is List) {
      return EarlyAffection(
        curve: [for (final v in curve) (v as num).toDouble()],
        maxTotal: cap,
      );
    }
    final until = ((j['untilDay'] as num?) ?? 0).toInt();
    final m = ((j['multiplier'] as num?) ?? 1).toDouble();
    return EarlyAffection(
      curve: List.filled(until < 0 ? 0 : until, m),
      maxTotal: cap,
    );
  }
}

class GameConfig {
  final int totalDays;
  final int chapterLength;
  final int maxHearts;
  final int heartRegenMinutes;
  final Map<String, int> initialStats;
  final List<DayAction> actions;

  /// 초반 호감 가속. 없으면 [EarlyAffection.none] (항상 1배).
  final EarlyAffection earlyAffection;

  const GameConfig({
    this.totalDays = 100,
    this.chapterLength = 20,
    this.maxHearts = 5,
    this.heartRegenMinutes = 30,
    this.initialStats = const {},
    this.actions = const [],
    this.earlyAffection = EarlyAffection.none,
  });

  factory GameConfig.fromJson(Map<String, dynamic> j) => GameConfig(
    totalDays: ((j['totalDays'] as num?) ?? 100).toInt(),
    chapterLength: ((j['chapterLength'] as num?) ?? 20).toInt(),
    maxHearts: ((j['maxHearts'] as num?) ?? 5).toInt(),
    heartRegenMinutes: ((j['heartRegenMinutes'] as num?) ?? 30).toInt(),
    initialStats: _intMap(j['initialStats']),
    actions: ((j['actions'] as List?) ?? const [])
        .map((e) => DayAction.fromJson(e as Map<String, dynamic>))
        .toList(),
    earlyAffection: EarlyAffection.fromJson(j['earlyAffection']),
  );
}

/// 캐릭터 한 명과의 관계.
class Relation {
  int affection;
  int trust;
  bool contactedToday;

  Relation({this.affection = 0, this.trust = 0, this.contactedToday = false});

  Map<String, dynamic> toJson() => {
    'affection': affection,
    'trust': trust,
    'contactedToday': contactedToday,
  };

  factory Relation.fromJson(Map<String, dynamic> j) => Relation(
    affection: ((j['affection'] as num?) ?? 0).toInt(),
    trust: ((j['trust'] as num?) ?? 0).toInt(),
    contactedToday: (j['contactedToday'] as bool?) ?? false,
  );
}

/// 한 회차의 전체 상태. 저장·복원 대상.
class GameState {
  int day;
  int run;
  int seed;

  /// 이 회차의 선호([Preference]). 새 게임에서 고르고 회차 내내 바뀌지 않는다.
  /// 필드가 없는 예전 세이브는 [Preference.all] 로 읽는다.
  final String preference;
  final Map<String, int> stats;
  final Map<String, Relation> relations;
  final Set<String> flags;
  final Set<String> seen;
  final List<String> album;
  final List<String> endings;
  int hearts;
  int lastHeartMs;
  String? lastCliffhanger;

  /// 좋은 선택을 연속으로 한 횟수. 3 이상이면 '물올랐다' 상태.
  int combo;

  /// 오늘 럭키 룰렛을 돌렸는지. 날이 바뀌면 풀린다.
  int rouletteDay;

  /// 마지막으로 모먼트(전화·알림·사진 이벤트)를 본 날. 0 이면 아직 없다.
  /// `planDay` 가 모먼트 가중치를 올릴지 정하는 데 쓴다(docs/MOMENTS_SPEC.md §2).
  int lastMomentDay;

  GameState({
    this.day = 1,
    this.run = 1,
    required this.seed,
    this.preference = Preference.all,
    required this.stats,
    required this.relations,
    Set<String>? flags,
    Set<String>? seen,
    List<String>? album,
    List<String>? endings,
    this.hearts = 5,
    this.lastHeartMs = 0,
    this.lastCliffhanger,
    this.combo = 0,
    this.rouletteDay = 0,
    this.lastMomentDay = 0,
  }) : flags = flags ?? {},
       seen = seen ?? {},
       album = album ?? [],
       endings = endings ?? [];

  /// [nowMs] 는 하트 회복 기준 시각. 테스트에서 시계를 고정할 때 넘긴다.
  factory GameState.fresh(
    GameConfig cfg,
    List<CharacterDef> characters, {
    required int seed,
    int run = 1,
    String preference = Preference.all,
    List<String>? previousEndings,
    int? nowMs,
  }) => GameState(
    seed: seed,
    run: run,
    preference: Preference.parse(preference),
    stats: {for (final k in Stat.all) k: cfg.initialStats[k] ?? 0},
    relations: {for (final c in characters) c.id: Relation()},
    hearts: cfg.maxHearts,
    lastHeartMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    endings: List.of(previousEndings ?? const []),
  );

  int stat(String key) => stats[key] ?? 0;

  int affectionOf(String id) => relations[id]?.affection ?? 0;
  int trustOf(String id) => relations[id]?.trust ?? 0;

  Relation rel(String id) => relations.putIfAbsent(id, Relation.new);

  int chapter(GameConfig cfg) => ((day - 1) ~/ cfg.chapterLength) + 1;

  /// 콤보 3 이상. 다음 판정 성공률과 크리티컬 확률이 오른다.
  bool get onFire => combo >= 3;

  /// 되돌리기 스냅샷으로도 쓰이므로 live 컬렉션을 그대로 넣지 않고 복사한다.
  Map<String, dynamic> toJson() => {
    'day': day,
    'run': run,
    'seed': seed,
    'preference': preference,
    'stats': Map.of(stats),
    'relations': relations.map((k, v) => MapEntry(k, v.toJson())),
    'flags': flags.toList(),
    'seen': seen.toList(),
    'album': List.of(album),
    'endings': List.of(endings),
    'hearts': hearts,
    'lastHeartMs': lastHeartMs,
    'lastCliffhanger': lastCliffhanger,
    'combo': combo,
    'rouletteDay': rouletteDay,
    'lastMomentDay': lastMomentDay,
    'signalHistory': signalHistory.map((k, v) => MapEntry(k, List.of(v))),
    'signalPins': signalPins.map((k, v) => MapEntry(k, List.of(v))),
    'overnightShifts': Map.of(overnightShifts),
    'dayDelta': dayDelta.map((k, v) => MapEntry(k, Map.of(v))),
  };

  factory GameState.fromJson(Map<String, dynamic> j) =>
      GameState(
          day: (j['day'] as num).toInt(),
          run: ((j['run'] as num?) ?? 1).toInt(),
          seed: (j['seed'] as num).toInt(),
          preference: Preference.parse(j['preference']),
          stats: _intMap(j['stats']),
          relations: ((j['relations'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(
              k as String,
              Relation.fromJson(v as Map<String, dynamic>),
            ),
          ),
          flags: _strList(j['flags']).toSet(),
          seen: _strList(j['seen']).toSet(),
          album: _strList(j['album']),
          endings: _strList(j['endings']),
          hearts: ((j['hearts'] as num?) ?? 5).toInt(),
          lastHeartMs: ((j['lastHeartMs'] as num?) ?? 0).toInt(),
          lastCliffhanger: j['lastCliffhanger'] as String?,
          combo: ((j['combo'] as num?) ?? 0).toInt(),
          rouletteDay: ((j['rouletteDay'] as num?) ?? 0).toInt(),
          lastMomentDay: ((j['lastMomentDay'] as num?) ?? 0).toInt(),
        )
        ..signalHistory.addAll(_intListMap(j['signalHistory']))
        ..signalPins.addAll(_intListMap(j['signalPins']))
        ..overnightShifts.addAll({
          for (final e in ((j['overnightShifts'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String,
        })
        ..dayDelta.addAll({
          for (final e in ((j['dayDelta'] as Map?) ?? const {}).entries)
            e.key as String: _intMap(e.value),
        });

  // ---- 서사 신호(lib/engine/signals.dart). 없는 예전 세이브는 전부 빈 값. ----

  /// 반복 방지 기록. 키 `캐릭터:구간번호`(또는 `캐릭터:down`) → 최근 보여 준 문장 번호.
  final Map<String, List<int>> signalHistory = {};

  /// 어젯밤 마감에서 고정한 오늘의 신호. 캐릭터 → [구간번호, 문장번호].
  final Map<String, List<int>> signalPins = {};

  /// 어젯밤 마감(연락 없음 −1)으로 호감 구간이 내려간 사람 → 하강 문장.
  final Map<String, String> overnightShifts = {};

  /// 오늘 쌓인 변화(`stats`/`affection`/`trust` → 키 → 변화량). 하루 도중 앱을 다시
  /// 켜도 정산이 이어지게 컨트롤러가 저장 직전에 채운다.
  final Map<String, Map<String, int>> dayDelta = {};

  static Map<String, List<int>> _intListMap(Object? j) => {
    for (final e in ((j as Map?) ?? const {}).entries)
      e.key as String: [
        for (final v in (e.value as List?) ?? const []) (v as num).toInt(),
      ],
  };
}
