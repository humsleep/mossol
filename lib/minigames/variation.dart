import 'dart:math';

/// 같은 미니게임이 두 번째·세 번째 나올 때 **다른 판**이 되게 하는 장치.
///
/// 규칙 세 가지로 만들어져 있다.
///
/// 1. **씨앗이 같으면 결과도 같다.** 모든 난수는 회차 씨앗(`seed`)과 살(salt)에서
///    유도한다. `Random()` 을 그냥 부르는 자리는 하나도 없어야 한다 — 시뮬레이션과
///    위젯 테스트가 같은 판을 다시 돌릴 수 있어야 하기 때문이다.
/// 2. **연달아 같은 판이 나오지 않는다.** 등장 순번([round])이 한 판마다 정확히 1씩
///    오르고, 후보는 *맨 난수* 가 아니라 씨앗으로 섞은 **순열을 순회**해서 고른다.
///    그래서 한 바퀴를 다 돌기 전에는 같은 변주가 다시 나올 수 없다
///    (난수로 고르면 2연속 같은 값이 1/n 확률로 나온다 — 이게 "매번 비슷한 것만
///    나온다" 의 절반이었다).
/// 3. **날이 갈수록 조금 어려워진다.** [phase] 가 0→1→2 로 오른다.
class MinigameVariation {
  /// 회차 씨앗. 같은 회차 안에서는 바뀌지 않는다.
  final int seed;

  /// 이 미니게임이 이 회차에서 **몇 번째로** 등장했는지. 0 부터 1씩 오른다.
  final int round;

  /// 오늘이 며칠째인지. 난이도 단계([phase])를 정하는 데만 쓴다.
  final int day;

  const MinigameVariation({
    required this.seed,
    required this.round,
    required this.day,
  });

  /// 난이도 단계 0(초반) · 1(중반) · 2(후반). 100일 기준으로 끊는다.
  int get phase => day <= 20
      ? 0
      : day <= 55
      ? 1
      : 2;

  /// [salt] 마다 고정된 씨앗. 같은 회차·같은 salt 면 언제나 같은 값이다.
  int saltSeed(String salt) => _mix(seed, _hash(salt));

  /// [salt] 전용 난수. 판정용이 아니라 **판을 짜는 데** 쓴다
  /// (판을 짤 때만 쓰고, 플레이 도중에 다시 뽑지 않아야 재현이 된다).
  Random rng(String salt) => Random(_mix(saltSeed(salt), round));

  /// 0..n-1 을 씨앗으로 섞은 순열. 회차마다 순서가 다르고 회차 안에서는 고정이다.
  List<int> permutation(String salt, int n) {
    final idx = List<int>.generate(n, (i) => i);
    if (n > 1) idx.shuffle(Random(saltSeed(salt)));
    return idx;
  }

  /// n 개 중 하나를 고른다.
  ///
  /// **첫 판(round 0)은 목록 맨 앞을 준다.** 이 미니게임을 처음 만나는 자리는
  /// 무엇을 묻는 게임인지 가르치는 자리라 기준 판이 있어야 한다. 그래서 각
  /// 목록의 0번은 "설계된 기본 판" 으로 두고, 두 번째 등장부터 순열을 돈다.
  ///
  /// 두 번째 판부터는 **0번을 맨 뒤로 민 순열**을 순회한다. 그냥 섞으면 순열
  /// 앞머리에 0번이 올 수 있고, 그러면 첫 판과 둘째 판이 같은 판이 된다.
  /// 이 규칙 덕분에 (a) 이웃한 두 판은 절대 같지 않고 (b) n 판이면 한 바퀴를 돈다.
  int pick(String salt, int n) {
    if (n <= 1 || round == 0) return 0;
    return _cycle(salt, n, 1)[(round - 1) % n];
  }

  /// n 개 중 [count] 개를 고른다. 순열 위의 창을 [round] 만큼 밀어서 잘라 내므로
  /// 이어지는 등장끼리 겹치는 항목이 최소가 된다. 첫 판은 [pick] 과 같은 이유로
  /// 목록 맨 앞 [count] 개이고, 그 [count] 개는 순열 맨 뒤로 밀려 둘째 판과 겹치지
  /// 않는다.
  List<int> take(String salt, int n, int count) {
    if (count >= n) return List<int>.generate(n, (i) => i);
    if (round == 0) return List<int>.generate(count, (i) => i);
    final perm = _cycle(salt, n, count);
    final start = ((round - 1) * count) % n;
    return [for (var i = 0; i < count; i++) perm[(start + i) % n]];
  }

  /// 앞 [head] 개(= 기준 판)를 맨 뒤로 민 순열. 나머지는 씨앗으로 섞는다.
  List<int> _cycle(String salt, int n, int head) {
    final rest = List<int>.generate(n - head, (i) => i + head);
    if (rest.length > 1) rest.shuffle(Random(saltSeed(salt)));
    return [...rest, for (var i = 0; i < head; i++) i];
  }

  /// 목록에서 [count] 개를 [take] 규칙으로 뽑는다.
  List<T> some<T>(String salt, List<T> pool, int count) =>
      [for (final i in take(salt, pool.length, count)) pool[i]];

  /// 목록에서 하나를 [pick] 규칙으로 뽑는다.
  T one<T>(String salt, List<T> pool) => pool[pick(salt, pool.length)];

  /// 목록을 [salt]·[round] 기준으로 섞는다. 같은 판에서 두 번 부르면 같은 결과다.
  List<T> shuffled<T>(String salt, List<T> pool) {
    final out = List<T>.of(pool);
    out.shuffle(rng(salt));
    return out;
  }

  /// [values] 중 [phase] 에 해당하는 값. 값이 모자라면 마지막 값을 쓴다.
  T byPhase<T>(List<T> values) => values[phase.clamp(0, values.length - 1)];

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) * 0x01000193;
      h &= 0x3fffffff;
    }
    return h;
  }

  /// 두 정수를 섞는다. 작은 씨앗끼리 더하기만 하면 (seed 1, round 2) 와
  /// (seed 2, round 1) 이 같은 판이 되므로 자리를 흩어 준다.
  static int _mix(int a, int b) {
    var h = (a ^ 0x9e3779b9) & 0x3fffffff;
    h = (h * 0x85ebca6b + b) & 0x3fffffff;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0x3fffffff;
    return h ^ (h >> 16);
  }
}

/// 미니게임 id 별 등장 순번을 센다. [MinigameVariation.round] 의 출처다.
///
/// 프로세스가 살아 있는 동안만 센다. 앱을 껐다 켜면 0 부터 다시 세므로 그 회차의
/// 기본 판이 한 번 더 나올 수 있다 — 한 판 겹치는 대신 "첫 판은 언제나 같다" 를
/// 얻는 쪽을 택했다(테스트·시뮬레이션이 이 성질에 기대고 있다).
class MinigameRotation {
  MinigameRotation._();

  static final Map<String, int> _counts = {};

  /// `<회차>:<미니게임 id>` 의 다음 순번. 부를 때마다 정확히 1씩 오른다.
  /// 첫 판은 0 — 변주 없는 기본 판이다([MinigameVariation.pick]).
  static int next(String key) {
    final n = (_counts[key] ?? -1) + 1;
    _counts[key] = n;
    return n;
  }

  /// 새 회차를 시작하거나 테스트를 격리할 때.
  static void reset() => _counts.clear();
}
