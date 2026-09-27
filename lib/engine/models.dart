/// 모쏠 탈출기 데이터 모델.
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

  /// 돈 1 = **1,000원**. 대본이 이미 이 축척으로 쓰여 있다
  /// (`d_luck_01` money +50 = "5만원", `d_friend_05` -150 = "15만원",
  /// `haneul_r09` -30 = "3만원", `c_broke` +120 = "12만원").
  static const wonPerMoney = 1000;

  /// 돈을 사람이 읽는 금액으로. `72` → `7.2만원`, `30` → `3만원`, `5` → `5천원`.
  ///
  /// 숫자만 보여 주면("72") 현실감이 없다는 지적을 받았다. 원 단위 전체("72,000원")는
  /// 320pt·글자 1.3배에서 스탯 줄을 넘치고, 무엇보다 대본이 이미 만원으로 말한다
  /// ("5만원 벌었다"). 그래서 만원을 기본 단위로 쓰고 1만원 미만만 천원으로 내린다.
  static String won(int money) => _won(money, sign: false);

  /// 돈 증감. `15` → `+1.5만원`, `-5` → `-5천원`.
  static String wonDelta(int money) => _won(money, sign: true);

  static String _won(int money, {required bool sign}) {
    final s = sign && money > 0 ? '+' : (money < 0 ? '-' : '');
    final a = money.abs();
    if (a == 0) return '0원';
    if (a < 10) return '$s$a천원';
    final man = a / 10;
    // 1만원 단위로 떨어지면 소수점을 떼고, 아니면 한 자리만 남긴다.
    final text = man == man.truncateToDouble()
        ? man.toInt().toString()
        : man.toStringAsFixed(1);
    return '$s$text만원';
  }

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

/// MBTI 유형 문자열을 검사해 대문자 4글자로 돌려준다. 틀리거나 없으면 null.
/// 축마다 한 글자(E/I, S/N, T/F, J/P). 자세한 도구는 lib/engine/mbti.dart.
String? parseMbtiType(Object? v) {
  if (v is! String) return null;
  final t = v.trim().toUpperCase();
  if (t.length != 4) return null;
  const axes = ['EI', 'SN', 'TF', 'JP'];
  for (var i = 0; i < 4; i++) {
    if (!axes[i].contains(t[i])) return null;
  }
  return t;
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

/// `flagsAtLeast: {"n": 2, "of": ["a", "b", …]}` — [of] 중 [n]개 이상 플래그가 있으면 참.
/// docs/MBTI_SPEC.md §1.3.
class FlagCount {
  final int n;
  final List<String> of;
  const FlagCount(this.n, this.of);

  static FlagCount? parse(Object? j) {
    if (j == null) return null;
    if (j is! Map) throw FormatException('flagsAtLeast 형식 오류: $j');
    return FlagCount(((j['n'] as num?) ?? 0).toInt(), _strList(j['of']));
  }
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

  /// 플레이어 MBTI 글자 조건(`"I"`, `"NF"`, `"ESTJ"`). 적힌 글자가 모두 있어야 참,
  /// 플레이어 MBTI 가 없으면 거짓. docs/MBTI_SPEC.md §1.3.
  final String? mbti;

  /// true 면 MBTI 를 모르는(null) 플레이어에게만 참.
  final bool noMbti;

  /// 이 조건이 속한 캐릭터(이벤트·엔딩의 `character`)와 플레이어의 궁합 점수 범위(0~4).
  final Range? compat;

  /// [FlagCount.of] 중 [FlagCount.n]개 이상 플래그.
  final FlagCount? flagsAtLeast;

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
    this.mbti,
    this.noMbti = false,
    this.compat,
    this.flagsAtLeast,
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
      mbti: j['mbti'] as String?,
      noMbti: j['noMbti'] == true,
      compat: Range.parse(j['compat']),
      flagsAtLeast: FlagCount.parse(j['flagsAtLeast']),
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

/// 그림 에셋 경로 규약(docs/overhaul/06_scene_plan.md §4).
///
/// 경로는 **있는지 검사하지 않는다** — 테스트·CI 는 그림 파일 없이 돌아야 한다.
/// 형식(`assets/` 로 시작하는 한 줄)만 본다. 실제로 있는지는 화면을 그릴 때
/// `SceneRegistry` 가 답하고, 없으면 아무것도 그리지 않는다.
abstract final class AssetPath {
  static const prefix = 'assets/';

  /// 규약에 맞는 경로인지. 빈 칸·줄바꿈·역슬래시가 들어가면 오타다.
  static bool isValid(String path) =>
      path.startsWith(prefix) &&
      path.length > prefix.length &&
      !path.contains(RegExp(r'[\s\\]'));
}

/// 스티커 id 규약(06 §4, docs/SCENE_PROMPTS.md §0.3).
///
/// [Line.sticker] 값은 **파일 이름 그대로**다: `<캐릭터 id>_<감정>`(`seoyeon_joy`).
/// 넷은 감정 자리에 그 캐릭터만의 시그니처 이름이 온다([extras]).
abstract final class Sticker {
  /// 전원 공통 감정 4종.
  static const emotions = ['joy', 'sulk', 'shy', 'surprise'];

  /// 5번째 스티커가 있는 넷. 파일 이름이 곧 id 다.
  static const extras = [
    'daeun_blank',
    'sohee_call',
    'jeongwoo_haha',
    'seunghyun_sure',
  ];

  /// 화이트리스트 통과 여부. `<캐릭터>_<감정 4종>` 이거나 [extras] 중 하나.
  static bool isValid(String key) {
    if (extras.contains(key)) return true;
    final cut = key.lastIndexOf('_');
    if (cut <= 0 || cut == key.length - 1) return false;
    return emotions.contains(key.substring(cut + 1));
  }

  /// 스티커의 캐릭터 id. 규약 밖이면 null.
  static String? characterOf(String key) {
    if (!isValid(key)) return null;
    return key.substring(0, key.lastIndexOf('_'));
  }

  /// 스티커의 감정 id. 규약 밖이면 null.
  static String? emotionOf(String key) {
    if (!isValid(key)) return null;
    return key.substring(key.lastIndexOf('_') + 1);
  }

  /// 스크린리더용 감정 이름. 모르는 값이면 null.
  static const labels = {
    'joy': '기쁨',
    'sulk': '삐짐',
    'shy': '부끄',
    'surprise': '놀람',
    'blank': '무표정',
    'call': '집중',
    'haha': '하하',
    'sure': '응시',
  };
}

/// 사진 메시지(docs/MOMENTS_SPEC.md §1.3). [image] 가 없으면 아이콘과 장면 설명만으로
/// 그린다(지금까지의 모습).
class Photo {
  /// [Photo.icons] 중 하나. 모르는 값이면 UI 가 기본 사진 아이콘을 쓴다.
  final String icon;

  /// 사진 속 장면 설명. 20자 이내([maxCaption]).
  final String caption;

  /// 전용 사진 에셋 경로(선택, 06 §4). 없으면 아이콘 공용 그림을 찾는다.
  final String? image;

  const Photo({required this.icon, this.caption = '', this.image});

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
      Photo(icon: icon, caption: f(caption), image: image);

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
    icon: (j['icon'] as String?) ?? '',
    caption: (j['caption'] as String?) ?? '',
    image: j['image'] as String?,
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

  /// MBTI 조건(docs/MBTI_SPEC.md §1.3). 맞지 않으면 화면에 내기 전에 걸러진다
  /// (lib/engine/mbti.dart `MbtiFilter`).
  final String? mbti;
  final bool noMbti;

  /// 이 이벤트 캐릭터와의 궁합 점수 범위(0~4).
  final Range? compat;

  /// 이 줄 뒤에 붙는 스티커 id(선택, 06 §4). 파일 이름 그대로 `<캐릭터 id>_<감정>`.
  /// 규약은 [Sticker], 에셋이 없으면 아무것도 그리지 않는다(빈 줄도 없음).
  final String? sticker;

  const Line({
    required this.who,
    this.text = '',
    this.wait = 0,
    this.name,
    this.photo,
    this.mbti,
    this.noMbti = false,
    this.compat,
    this.sticker,
  });

  bool get isWait => who == 'sys' && wait > 0;

  /// MBTI·궁합 조건이 붙은 줄인지.
  bool get isGated => mbti != null || noMbti || compat != null;

  /// 글과 사진 캡션을 [f] 로 바꾼 사본. 화면에 내기 직전 이름 치환에 쓴다.
  ///
  /// [name] — 말풍선 머리에 뜨는 이름 — 도 함께 치환한다. `@top` 으로 호감이
  /// 움직이는 장면은 상대를 `{top}` 으로 부르는데, 여기서 건너뛰면 지문은
  /// "다은이한테" 라고 하면서 말풍선 머리에는 `{top}` 이 그대로 찍혔다.
  Line mapText(String Function(String) f) => Line(
    who: who,
    text: f(text),
    wait: wait,
    name: name == null ? null : f(name!),
    photo: photo?.mapText(f),
    mbti: mbti,
    noMbti: noMbti,
    compat: compat,
    sticker: sticker,
  );

  factory Line.fromJson(Map<String, dynamic> j) => Line(
    who: (j['who'] as String?) ?? 'them',
    text: (j['text'] as String?) ?? '',
    wait: ((j['wait'] as num?) ?? 0).toInt(),
    name: j['name'] as String?,
    photo: j['photo'] == null
        ? null
        : Photo.fromJson(j['photo'] as Map<String, dynamic>),
    mbti: j['mbti'] as String?,
    noMbti: j['noMbti'] == true,
    compat: Range.parse(j['compat']),
    sticker: j['sticker'] as String?,
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

  /// MBTI 조건(docs/MBTI_SPEC.md §1.3). 맞지 않는 선택지는 보이지 않는다.
  final String? mbti;
  final bool noMbti;

  /// 이 이벤트 캐릭터와의 궁합 점수 범위(0~4).
  final Range? compat;

  /// 자유 입력 보정(선택, docs/overhaul/07_free_input.md §2). 플레이어가 칠 법한 짧은 표현들.
  /// 문구 2-gram·태그에 합쳐진다. 없으면 빈 목록 — 스키마 호환.
  final List<String> intent;

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
    this.mbti,
    this.noMbti = false,
    this.compat,
    this.intent = const [],
  });

  /// MBTI·궁합 조건이 붙은 선택지인지.
  bool get isGated => mbti != null || noMbti || compat != null;

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
    mbti: mbti,
    noMbti: noMbti,
    compat: compat,
    intent: intent,
  );

  /// 반응 줄만 바꾼 사본(MBTI 줄 거르기).
  Choice withReplies({
    required List<Line> reply,
    required List<Line> failReply,
    required List<Line> critReply,
  }) => Choice(
    text: text,
    require: require,
    effects: effects,
    next: next,
    chance: chance,
    fail: fail,
    failNext: failNext,
    minigame: minigame,
    reply: reply,
    failReply: failReply,
    critReply: critReply,
    decline: decline,
    mbti: mbti,
    noMbti: noMbti,
    compat: compat,
    intent: intent,
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
    mbti: j['mbti'] as String?,
    noMbti: j['noMbti'] == true,
    compat: Range.parse(j['compat']),
    intent: _strList(j['intent']),
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

  /// 장면 삽화 에셋 경로(선택, 06 §4). 없으면 `assets/scenes/<id>.<확장자>` 를 찾는다.
  /// 여러 이벤트가 한 장을 나눠 쓸 때(`m03`/`m03_m`)만 적는다.
  final String? image;

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
    this.image,
  });

  /// 상대가 먼저 거는 전화인지.
  bool get isCall => format == formatCall;

  /// 루트 단계 번호. id 끝의 `_rNN`(`seoyeon_r03` → 3)에서 유도한다. 데이터에 새 칸을
  /// 만들지 않는 이유는 189개 루트 이벤트가 이미 전부 `<캐릭터>_rNN` 이기 때문이다
  /// (모먼트 루트 `mo_seoyeon_call_dawn` 48개만 번호가 없다 → null = 순서 제약 없음).
  /// `_pickRoute` 가 같은 캐릭터의 단계 역행을 막는 데 쓴다(docs/review/07_story_flow.md (c)#3).
  int? get stage {
    final m = _stagePattern.firstMatch(id);
    return m == null ? null : int.parse(m[1]!);
  }

  static final _stagePattern = RegExp(r'_r(\d+)$');

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
    image: image,
  );

  /// 대사·선택지·힌트만 바꾼 사본(MBTI 거르기, lib/engine/mbti.dart).
  StoryEvent withContent({
    required List<Line> lines,
    required List<Choice> choices,
    required int? hint,
  }) => StoryEvent(
    id: id,
    layer: layer,
    character: character,
    trigger: trigger,
    weight: weight,
    day: day,
    once: once,
    title: title,
    lines: lines,
    choices: choices,
    hint: hint,
    cliffhanger: cliffhanger,
    format: format,
    preview: preview,
    image: image,
  );

  /// 화면에 보이는 글 전부(위치, 문자열). 검증기가 자리표시자 형식을 본다.
  Iterable<(String, String)> get displayTexts sync* {
    yield ('$id.title', title);
    if (preview != null) yield ('$id.preview', preview!);
    if (cliffhanger != null) yield ('$id.cliffhanger', cliffhanger!);
    Iterable<(String, String)> linesOf(String where, List<Line> ls) sync* {
      for (var i = 0; i < ls.length; i++) {
        yield ('$where[$i]', ls[i].text);
        // 말풍선 머리에 뜨는 이름도 화면에 나가는 글이다. 여기 빠뜨리면
        // `"name": "{top}"` 이 치환 대상으로 안 잡혀 토큰이 그대로 찍힌다.
        final n = ls[i].name;
        if (n != null) yield ('$where[$i].name', n);
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
      image: j['image'] as String?,
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

  /// 캐릭터 MBTI(대문자 4글자, docs/MBTI_SPEC.md §1.1). 없으면 null(궁합 점수 보통).
  final String? mbti;

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
    this.mbti,
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
    mbti: switch ((j['mbti'] as String?)?.trim()) {
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

  /// 기질별 덧붙임 문단(`NT`·`NF`·`SJ`·`SP` → 문장). 플레이어 기질이 맞으면 [epilogue] 뒤에
  /// 한 문단으로 붙는다([epilogueFor]). docs/MBTI_SPEC.md §1.6.
  final Map<String, String> epilogueMbti;

  /// 앨범에서 아직 못 본 엔딩에 보여 줄 한 줄 힌트. 사람이 쓴 문장.
  /// 없으면 UI 가 조건으로 기계 문장을 만든다.
  final String? hint;

  /// true 면 100일을 기다리지 않고 조건 충족 즉시 종료.
  final bool immediate;
  final bool isDefault;

  /// 엔딩 히어로 그림 경로(선택, 06 §4). 없으면 엔딩 id → 캐릭터 id →
  /// 공용 `common_<tier>` 순으로 `assets/endings/` 를 찾는다.
  final String? image;

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
    this.epilogueMbti = const {},
    this.hint,
    this.immediate = false,
    this.isDefault = false,
    this.image,
  });

  /// [temperament](`NT`·`NF`·`SJ`·`SP`, 없으면 null) 플레이어에게 보여 줄 에필로그.
  /// 맞는 기질 문단이 있으면 기본 에필로그 뒤에 빈 줄 하나를 두고 붙인다.
  String epilogueForTemperament(String? temperament) {
    final extra = temperament == null ? null : epilogueMbti[temperament];
    if (extra == null || extra.trim().isEmpty) return epilogue;
    if (epilogue.trim().isEmpty) return extra;
    return '$epilogue\n\n$extra';
  }

  factory Ending.fromJson(Map<String, dynamic> j) => Ending(
    id: j['id'] as String,
    name: j['name'] as String,
    tier: (j['tier'] as String?) ?? 'good',
    priority: ((j['priority'] as num?) ?? 0).toInt(),
    character: j['character'] as String?,
    when: Trigger.fromJson(j['when'] as Map<String, dynamic>?),
    epilogue: (j['epilogue'] as String?) ?? '',
    epilogueMbti: j['epilogueMbti'] == null
        ? const {}
        : (j['epilogueMbti'] as Map).map(
            (k, v) => MapEntry(k as String, v as String),
          ),
    hint: j['hint'] as String?,
    immediate: (j['immediate'] as bool?) ?? false,
    isDefault: (j['default'] as bool?) ?? false,
    image: j['image'] as String?,
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

  /// 궁합 점수(0~4)별 호감 상승 배율. `config.mbti.compatMultiplier`. docs/MBTI_SPEC.md §1.5.
  final List<double> compatMultiplier;

  static const defaultCompatMultiplier = [1.0, 1.0, 1.0, 1.03, 1.06];

  /// 장 제목(`chapterTitles`, 선택). 날짜 카드의 장 첫날 pill 에만 쓴다 — 표시 전용이라
  /// 엔진·계획에는 들어가지 않는다(docs/overhaul/02_game_loop.md §2.2). 없으면 빈 목록.
  final List<String> chapterTitles;

  /// 1회차 오프닝 중 하트를 쓰지 않는 날 수(`firstRunFreeHeartDays`, 선택). 기본 0 = 예전 그대로.
  ///
  /// 왜: 첫 세션이 D+5~6, 약 10분에 하트로 끊겨 첫 모먼트(전화·사진)를 보기 전에 끝났다
  /// (docs/review/00_VERDICT.md §3 R4). `run == 1` 이고 `day <= 이 값` 인 아침만 공짜다.
  /// [GameController.startDay] 한 곳에서만 본다 — 엔진·밸런스 시뮬레이터는 이 값을 모른다.
  final int firstRunFreeHeartDays;

  /// 같은 일상(daily) 이벤트를 다시 뽑기까지 비워 두는 날 수(`dailyCooldownDays`, 선택).
  /// 0 이면 예전 그대로(무제한 반복). 기본 [defaultDailyCooldownDays].
  ///
  /// 왜: 일상 123개 중 105개가 `once:false` 라 같은 장면이 계속 재추첨됐다 — 300시드 **전부**
  /// 20일 안에 같은 일상을 두 번 이상 받았고, `d_misc_01` 은 5일 안에 네 번까지 나왔다
  /// (docs/review/07_story_flow.md (c)#8). [EventEngine.dailyPool] 이 이 기간 안에 본 일상을
  /// 후보에서 빼고, 그러면 후보가 비는 날에는 원래 후보로 되돌린다(막히지 않는다).
  final int dailyCooldownDays;

  /// 1회차 D+1 에 **반드시**, 적힌 순서대로 먼저 재생할 이벤트 id 목록(`openingScript`, 선택).
  /// 비어 있으면(기본) 예전과 똑같이 평소 추첨만 돈다.
  ///
  /// 왜: 100일 내기라는 전제를 세우는 `d_open_bet` 이 일상 풀에서 추첨되는 탓에 회차의
  /// 30.3% 가 전제를 못 듣고 시작했다(docs/review/07_story_flow.md (c)#4).
  /// 내용은 스토리 담당이 채운다 — 엔진은 "있으면 맨 앞에 순서대로 깐다"까지만 안다.
  final List<String> openingScript;

  /// [dailyCooldownDays] 기본값. 하루에 뽑는 일상은 1~2개(오프닝 3~4개)이므로 14일이면
  /// 최대 30개 남짓이 냉각 중이고, 조건을 통과한 일상 후보는 그보다 훨씬 많다.
  /// 2주면 플레이어가 같은 장면을 '방금 그거'로 알아채지 않는 선이기도 하다.
  static const defaultDailyCooldownDays = 14;

  const GameConfig({
    this.totalDays = 100,
    this.chapterLength = 20,
    this.maxHearts = 5,
    this.heartRegenMinutes = 30,
    this.initialStats = const {},
    this.actions = const [],
    this.earlyAffection = EarlyAffection.none,
    this.compatMultiplier = defaultCompatMultiplier,
    this.chapterTitles = const [],
    this.firstRunFreeHeartDays = 0,
    this.dailyCooldownDays = defaultDailyCooldownDays,
    this.openingScript = const [],
  });

  /// [chapter](1부터) 의 제목. 없거나 비어 있으면 null.
  String? chapterTitleFor(int chapter) {
    final i = chapter - 1;
    if (i < 0 || i >= chapterTitles.length) return null;
    final t = chapterTitles[i].trim();
    return t.isEmpty ? null : t;
  }

  /// 궁합 점수 [score] 의 호감 상승 배율. 범위 밖이면 1.
  double compatMultiplierFor(int score) =>
      score >= 0 && score < compatMultiplier.length
      ? compatMultiplier[score]
      : 1;

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
    compatMultiplier: switch ((j['mbti'] as Map?)?['compatMultiplier']) {
      final List l => [for (final v in l) (v as num).toDouble()],
      _ => defaultCompatMultiplier,
    },
    chapterTitles: [
      for (final v in (j['chapterTitles'] as List?) ?? const []) '$v',
    ],
    // 음수·이상한 값은 0(없음)으로 읽는다.
    firstRunFreeHeartDays: switch (j['firstRunFreeHeartDays']) {
      final num v when v > 0 => v.toInt(),
      _ => 0,
    },
    // 칸이 없는 예전 데이터는 기본값, 음수·이상한 값은 0(냉각 없음)으로 읽는다.
    dailyCooldownDays: switch (j['dailyCooldownDays']) {
      final num v when v > 0 => v.toInt(),
      final num _ => 0,
      _ => defaultDailyCooldownDays,
    },
    openingScript: [
      for (final v in (j['openingScript'] as List?) ?? const [])
        if ('$v'.trim().isNotEmpty) '$v'.trim(),
    ],
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

/// 자유 입력 기록 한 건(docs/overhaul/07_free_input.md §3.4). 기기 세이브에만 남고 밖으로 안 나간다.
class FreeInputEntry {
  final String eventId;
  final int choiceIndex;

  /// 친 문장. [maxChars] 자까지.
  final String text;
  final int day;

  /// 자동 확정이었는지(피커·확인을 거치지 않음). 무료 되돌리기 대상.
  final bool auto;

  static const maxChars = 80;

  FreeInputEntry({
    required this.eventId,
    required this.choiceIndex,
    required String text,
    required this.day,
    required this.auto,
  }) : text = text.length > maxChars ? text.substring(0, maxChars) : text;

  Map<String, dynamic> toJson() => {
    'e': eventId,
    'i': choiceIndex,
    't': text,
    'd': day,
    'a': auto ? 1 : 0,
  };

  /// 형식이 틀린 항목은 null(건너뛴다).
  static FreeInputEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['e'];
    final i = j['i'];
    final t = j['t'];
    if (e is! String || i is! num || t is! String) return null;
    return FreeInputEntry(
      eventId: e,
      choiceIndex: i.toInt(),
      text: t,
      day: ((j['d'] as num?) ?? 0).toInt(),
      auto: j['a'] == 1 || j['a'] == true,
    );
  }
}

/// 한 회차의 전체 상태. 저장·복원 대상.
class GameState {
  int day;
  int run;
  int seed;

  /// 이 회차의 선호([Preference]). 새 게임에서 고르고 회차 내내 바뀌지 않는다.
  /// 필드가 없는 예전 세이브는 [Preference.all] 로 읽는다.
  final String preference;

  /// 이 회차의 플레이어 MBTI(대문자 4글자). 새 게임 때 기기 설정(`PlayerMeta.mbti`)에서 복사한다.
  /// 모름·건너뜀·예전 세이브는 null. docs/MBTI_SPEC.md §1.2.
  ///
  /// 회차 도중에 바뀌는 자리는 하나뿐이다: 온보딩에서 MBTI 를 묻지 않은 첫 회차가 D+4
  /// `m_mbti_chat` 대화에서 처음 답할 때([GameController.adoptMbti]). 그때도 null → 값
  /// 한 방향뿐이고, 이미 지나간 이벤트를 다시 거르지 않는다(00_VERDICT §3 R6).
  String? mbti;
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

  /// 오늘 아침 행동으로 하트를 쓰고 하루를 시작했는지. 마감(endDay)에서 풀린다.
  /// 하루 도중 앱을 다시 켜면 이 값으로 행동 화면 대신 남은 이벤트로 돌아간다.
  bool dayStarted;

  /// 오늘 남은 이벤트 id(진행 중이던 이벤트가 맨 앞). [dayStarted] 일 때만 의미가 있다.
  List<String> dayQueue;

  GameState({
    this.day = 1,
    this.run = 1,
    required this.seed,
    this.preference = Preference.all,
    this.mbti,
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
    this.dayStarted = false,
    List<String>? dayQueue,
  }) : dayQueue = dayQueue ?? [],
       flags = flags ?? {},
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
    String? mbti,
    List<String>? previousEndings,
    int? nowMs,
  }) => GameState(
    seed: seed,
    run: run,
    preference: Preference.parse(preference),
    mbti: parseMbtiType(mbti),
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
    'mbti': mbti,
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
    'dayStarted': dayStarted,
    'dayQueue': dayQueue,
    'signalHistory': signalHistory.map((k, v) => MapEntry(k, List.of(v))),
    'signalPins': signalPins.map((k, v) => MapEntry(k, List.of(v))),
    'overnightShifts': Map.of(overnightShifts),
    'dayDelta': dayDelta.map((k, v) => MapEntry(k, Map.of(v))),
    'dailySeenDay': Map.of(dailySeenDay),
    'freeInputs': [for (final f in freeInputs) f.toJson()],
  };

  factory GameState.fromJson(Map<String, dynamic> j) =>
      GameState(
          day: (j['day'] as num).toInt(),
          run: ((j['run'] as num?) ?? 1).toInt(),
          seed: (j['seed'] as num).toInt(),
          preference: Preference.parse(j['preference']),
          mbti: parseMbtiType(j['mbti']),
          // 세이브에 칸이 없으면 _intMap/_strList 가 const 빈 값을 돌려준다. 게임 중에 고쳐 쓰므로 복사본으로.
          stats: {..._intMap(j['stats'])},
          relations: ((j['relations'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(
              k as String,
              Relation.fromJson(v as Map<String, dynamic>),
            ),
          ),
          flags: _strList(j['flags']).toSet(),
          seen: _strList(j['seen']).toSet(),
          album: [..._strList(j['album'])],
          endings: [..._strList(j['endings'])],
          hearts: ((j['hearts'] as num?) ?? 5).toInt(),
          lastHeartMs: ((j['lastHeartMs'] as num?) ?? 0).toInt(),
          lastCliffhanger: j['lastCliffhanger'] as String?,
          combo: ((j['combo'] as num?) ?? 0).toInt(),
          rouletteDay: ((j['rouletteDay'] as num?) ?? 0).toInt(),
          lastMomentDay: ((j['lastMomentDay'] as num?) ?? 0).toInt(),
          dayStarted: j['dayStarted'] == true,
          dayQueue: [..._strList(j['dayQueue'])],
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
        })
        ..dailySeenDay.addAll(_intMap(j['dailySeenDay']))
        ..freeInputs.addAll([
          for (final e in (j['freeInputs'] as List?) ?? const [])
            ?FreeInputEntry.fromJson(e),
        ]);

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

  /// 일상(daily) 이벤트 id → 마지막으로 본 날. 같은 장면이 며칠 안에 또 나오지 않게
  /// [GameConfig.dailyCooldownDays] 동안 후보에서 빼는 데 쓴다(`EventEngine.dailyPool`).
  /// 칸이 없는 예전 세이브는 빈 맵 = 냉각 중인 일상이 없음 → 예전과 똑같이 굴러간다.
  /// 냉각이 지난 기록은 [noteDailySeen] 이 지워서 세이브가 계속 커지지 않는다.
  final Map<String, int> dailySeenDay = {};

  /// 오늘 일상 [id] 를 봤다고 적고, 냉각이 지난 기록은 버린다.
  void noteDailySeen(String id, {required int cooldownDays}) {
    dailySeenDay[id] = day;
    if (cooldownDays <= 0) {
      dailySeenDay.clear();
      return;
    }
    dailySeenDay.removeWhere((_, d) => day - d >= cooldownDays);
  }

  /// 자유 입력 기록(최근 [maxFreeInputs] 건, 추가만). 없는 예전 세이브는 빈 목록.
  final List<FreeInputEntry> freeInputs = [];

  static const maxFreeInputs = 30;

  /// 기록을 뒤에 붙이고 오래된 것부터 버린다.
  void addFreeInput(FreeInputEntry e) {
    freeInputs.add(e);
    if (freeInputs.length > maxFreeInputs) {
      freeInputs.removeRange(0, freeInputs.length - maxFreeInputs);
    }
  }

  static Map<String, List<int>> _intListMap(Object? j) => {
    for (final e in ((j as Map?) ?? const {}).entries)
      e.key as String: [
        for (final v in (e.value as List?) ?? const []) (v as num).toInt(),
      ],
  };
}
