/// 흑역사 한 장의 출처 찾기와 도장 분류. 순수 Dart(UI 를 모른다).
///
/// 세이브에는 흑역사 **제목만** 남는다(예전 세이브 호환). 앨범 상세가 "그날 무슨 일이"
/// 를 다시 보여 주려면 제목으로 스토리 데이터를 거꾸로 찾아야 한다([AlbumIndex]).
/// 카드에 찍히는 빨간 도장은 그 출처와 제목의 낱말로 고른다([ShameStamp]).
library;

import 'models.dart';

/// 흑역사 한 장이 어디서 나왔는지.
class ShameSource {
  final StoryEvent event;
  final Choice choice;

  /// 실패해서 남은 흑역사면 true(`fail.album`), 선택 자체가 흑역사면 false(`effects.album`).
  final bool failed;

  const ShameSource(this.event, this.choice, {required this.failed});

  /// 그 선택 뒤에 돌아온 반응. 대기 줄·빈 줄은 뺀다.
  List<Line> get aftermath => _plain(failed ? choice.failReply : choice.reply);

  /// 선택 직전 장면에서 마지막 대사 몇 줄(맥락).
  List<Line> setup({int max = 2}) {
    final said = _plain(event.lines);
    return said.length <= max ? said : said.sublist(said.length - max);
  }

  /// 글이 있는 줄 중 조건(MBTI·궁합·목소리) 없는 것. 조건 줄은 같은 비트를 여러 벌로
  /// 쓴 것이라 전부 늘어놓으면 같은 말이 겹친다. 조건 없는 줄이 하나도 없으면 첫 벌만.
  static List<Line> _plain(List<Line> lines) {
    final said = [
      for (final l in lines)
        if (l.text.trim().isNotEmpty && !l.isWait) l,
    ];
    final open = [
      for (final l in said)
        if (!l.isGated) l,
    ];
    if (open.isNotEmpty || said.isEmpty) return open;
    return [said.first];
  }
}

abstract final class AlbumIndex {
  /// [title] 흑역사의 출처. 못 찾으면 null(데이터에서 빠진 옛 흑역사 등).
  ///
  /// 같은 제목이 여러 이벤트에 있으면(남녀 쌍 `_m` 등) [roster] 에 있는 캐릭터의 것을
  /// 먼저, 그다음 캐릭터 없는 이벤트, 마지막으로 아무 것이나 고른다.
  static ShameSource? find(
    Iterable<StoryEvent> events,
    String title, {
    Set<String> roster = const {},
  }) {
    ShameSource? neutral;
    ShameSource? other;
    for (final e in events) {
      for (final c in e.choices) {
        final ShameSource hit;
        if (c.fail.album == title) {
          hit = ShameSource(e, c, failed: true);
        } else if (c.effects.album == title) {
          hit = ShameSource(e, c, failed: false);
        } else {
          continue;
        }
        final ch = e.character;
        if (ch != null && roster.contains(ch)) return hit;
        if (ch == null) {
          neutral ??= hit;
        } else {
          other ??= hit;
        }
      }
    }
    return neutral ?? other;
  }
}

/// 흑역사 도장 종류. 그림은 `assets/stamps/<종류>.webp`(1:1 투명, 빨간 고무도장).
///
/// 분류는 낱말 규칙이다. 앨범 제목 → 출처 이벤트 제목 → 이벤트 id·미니게임 id 순으로
/// 보고, 먼저 걸린 것을 쓴다. 한 곳 안에서는 [_rules] 순서가 우선순위다(고백 실패가
/// 막차 앞에서 일어났으면 '술자리' 보다 '고백 실패' 가 그날의 요점이다).
/// 아무것도 안 걸리면 [awkward] — 흑역사의 대부분은 결국 어색한 침묵이다.
abstract final class ShameStamp {
  static const misfire = 'misfire';
  static const drink = 'drink';
  static const fashion = 'fashion';
  static const money = 'money';
  static const gym = 'gym';
  static const confession = 'confession';
  static const sns = 'sns';
  static const awkward = 'awkward';

  static const kinds = [
    misfire,
    drink,
    fashion,
    money,
    gym,
    confession,
    sns,
    awkward,
  ];

  /// 도장에 새겨진 글(스크린리더 라벨).
  static const labels = {
    misfire: '오발송',
    drink: '술자리',
    fashion: '패션 참사',
    money: '지갑 텅',
    gym: '운동 부상',
    confession: '고백 실패',
    sns: 'SNS 참사',
    awkward: '어색한 침묵',
  };

  static String label(String kind) => labels[kind] ?? labels[awkward]!;

  /// 종류별 낱말(`|` 로 나눔). 순서가 우선순위다. 영문은 이벤트·미니게임 id 조각이다.
  static const List<(String, String)> _rules = [
    (confession, '고백|차였|차인|거절|차단|매달리|애프터|운명이라|양다리|밀당|어장|문전박대'),
    (gym, '헬스|운동|PT|부상|세트|러닝|트레이너|3대|식단|스쿼트|바벨|허리|gym'),
    (money, '돈|계산|예산|잔고|할부|카드값|월세|식비|영수증|판돈|가격|정산|회비|오마카세|브런치|결제|선물|쿠폰'),
    (fashion, '옷|코디|미용실|머리|셔츠|체크무늬|셀카|거울|외모|outfit|style'),
    (drink, '술자리|술김|소주|맥주|취해|뒤풀이|막차|2차|회식|진실게임|택시|노래방|drink'),
    (sns, 'SNS|스토리|좋아요|프사|팔로우|계정|태그|숏폼|알고리즘|조회수|스와이프|매칭|댓글|인증샷|친추|정주행|_sns_'),
    (
      misfire,
      '오발송|단톡|읽음|삭제|잘못 보낸|잘못 온|전송|발송|짤|장문|문자|메시지|보낸|읽씹|답장|캡처|오타|스피커폰|delete_fast|kakao',
    ),
  ];

  /// [text] 에 걸리는 첫 종류. 없으면 null.
  static String? _match(String? text) {
    if (text == null || text.isEmpty) return null;
    for (final (kind, words) in _rules) {
      for (final w in words.split('|')) {
        if (text.contains(w)) return kind;
      }
    }
    return null;
  }

  /// 흑역사 [title] 의 도장. [source] 가 있으면 그 이벤트·선택도 본다.
  static String classify(String title, {ShameSource? source}) =>
      _match(title) ??
      _match(source?.event.title) ??
      _match(
        [
          source?.event.id,
          source?.choice.minigame,
        ].whereType<String>().join(' '),
      ) ??
      awkward;
}
