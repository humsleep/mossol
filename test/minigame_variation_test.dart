// 미니게임 변주기(lib/minigames/variation.dart)의 성질을 못 박는다.
//
// 지켜야 할 약속 세 가지:
//   1. 씨앗·순번이 같으면 판도 같다 (시뮬레이션·위젯 테스트가 여기에 기댄다).
//   2. 첫 판은 언제나 목록 맨 앞 — "이 게임이 뭘 묻는지" 를 가르치는 기준 판.
//   3. 두 번째 판부터는 순열을 돌아, 한 바퀴 전에는 같은 판이 다시 나오지 않는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/minigames/variation.dart';

MinigameVariation v(int seed, int round, {int day = 1}) =>
    MinigameVariation(seed: seed, round: round, day: day);

void main() {
  group('같은 씨앗이면 같은 판', () {
    test('seed·round·salt 가 같으면 pick/take/shuffled 가 모두 같다', () {
      for (var seed = 1; seed <= 20; seed++) {
        for (var round = 0; round < 8; round++) {
          final a = v(seed, round);
          final b = v(seed, round);
          expect(a.pick('nerve_gauge', 6), b.pick('nerve_gauge', 6));
          expect(a.take('read_emotion', 12, 4), b.take('read_emotion', 12, 4));
          expect(
            a.shuffled('slot', const [0, 1, 2, 3, 4]),
            b.shuffled('slot', const [0, 1, 2, 3, 4]),
          );
          expect(a.some('outfit', const ['a', 'b', 'c', 'd', 'e'], 3),
              b.some('outfit', const ['a', 'b', 'c', 'd', 'e'], 3));
        }
      }
    });

    test('회차 씨앗이 다르면 순열도 다르다', () {
      final perms = {
        for (var seed = 1; seed <= 40; seed++)
          v(seed, 0).permutation('nerve_gauge', 6).join(','),
      };
      // 40개 씨앗이 6! 가지 순열 중 한 가지로 몰리면 안 된다.
      expect(perms.length, greaterThan(3));
    });

    test('salt 가 다르면 같은 씨앗·순번이어도 다른 자리를 본다', () {
      final a = v(7, 3).pick('nerve_gauge', 6);
      final b = v(7, 3).pick('reply_timing', 6);
      final c = v(7, 3).pick('call_rhythm', 6);
      expect({a, b, c}.length, greaterThan(1));
    });
  });

  group('첫 판은 기준 판', () {
    test('round 0 은 목록 맨 앞', () {
      for (var seed = 1; seed <= 30; seed++) {
        expect(v(seed, 0).pick('nerve_gauge', 6), 0);
        expect(v(seed, 0).take('read_emotion', 12, 4), [0, 1, 2, 3]);
        expect(v(seed, 0).one('x', const ['기본', '변주1', '변주2']), '기본');
      }
    });
  });

  group('연속으로 같은 판이 나오지 않는다', () {
    test('pick: n 판을 돌기 전에는 값이 겹치지 않는다', () {
      for (var seed = 1; seed <= 30; seed++) {
        const n = 6;
        // round 1..n 이 한 바퀴다(0 은 기준 판이라 따로 센다).
        final seen = [for (var r = 1; r <= n; r++) v(seed, r).pick('s', n)];
        expect(seen.toSet().length, n, reason: '씨앗 $seed 에서 한 바퀴가 안 돈다');
      }
    });

    test('pick: 이웃한 두 판이 같은 값일 수 없다', () {
      for (var seed = 1; seed <= 50; seed++) {
        for (var r = 1; r < 20; r++) {
          expect(
            v(seed, r).pick('s', 6) == v(seed, r + 1).pick('s', 6),
            isFalse,
            reason: '씨앗 $seed 의 $r → ${r + 1} 판이 같다',
          );
        }
      }
    });

    test('take: 이웃한 두 판이 통째로 같을 수 없다', () {
      for (var seed = 1; seed <= 50; seed++) {
        for (var r = 0; r < 12; r++) {
          expect(
            v(seed, r).take('s', 12, 4).join(',') ==
                v(seed, r + 1).take('s', 12, 4).join(','),
            isFalse,
            reason: '씨앗 $seed 의 $r → ${r + 1} 판 문제가 같다',
          );
        }
      }
    });
  });

  group('날짜 단계', () {
    test('phase 는 날이 갈수록 오르고 목록 밖으로 나가지 않는다', () {
      expect(v(1, 0, day: 1).phase, 0);
      expect(v(1, 0, day: 20).phase, 0);
      expect(v(1, 0, day: 21).phase, 1);
      expect(v(1, 0, day: 55).phase, 1);
      expect(v(1, 0, day: 56).phase, 2);
      expect(v(1, 0, day: 100).phase, 2);
      // 값이 모자라면 마지막 값을 쓴다.
      expect(v(1, 0, day: 100).byPhase(const [1, 2]), 2);
    });
  });

  group('등장 순번 세기', () {
    setUp(MinigameRotation.reset);

    test('같은 키는 0부터 1씩 오르고, 키가 다르면 따로 센다', () {
      expect(MinigameRotation.next('1:nerve_gauge'), 0);
      expect(MinigameRotation.next('1:nerve_gauge'), 1);
      expect(MinigameRotation.next('1:nerve_gauge'), 2);
      expect(MinigameRotation.next('1:reply_timing'), 0);
      // 회차가 바뀌면 처음부터.
      expect(MinigameRotation.next('2:nerve_gauge'), 0);
    });

    test('reset 하면 다시 0부터', () {
      MinigameRotation.next('1:x');
      MinigameRotation.next('1:x');
      MinigameRotation.reset();
      expect(MinigameRotation.next('1:x'), 0);
    });
  });
}
