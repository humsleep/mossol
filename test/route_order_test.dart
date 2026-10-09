// 루트 이벤트 선후 관계 검증. docs/ROUTE_ORDER.md 의 감사 표를 코드로 옮긴 것이다.
// `flutter test test/route_order_test.dart` 로 실행한다.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mossol/engine/ending_resolver.dart';
import 'package:mossol/engine/event_engine.dart';
import 'package:mossol/engine/mbti.dart';
import 'package:mossol/engine/models.dart';
import 'package:mossol/engine/story_repository.dart';
import 'package:mossol/minigames/registry.dart';

import 'sim_balance_test.dart'
    show
        loadBundle,
        simTop,
        simAbsent,
        kMinigameSuccess,
        Strategy,
        FirstStrategy,
        MaxAffectionStrategy,
        FocusStrategy,
        RandomStrategy,
        DoubleTimerStrategy;

/// (뒤, 앞): 뒤 이벤트는 앞 이벤트를 **반드시** 먼저 본 뒤에만 나온다.
/// 앞이 main 이벤트(mNN)면 day 고정이라 day 하한이나 main 이 세우는 플래그로 보장한다.
/// 앞이 'a|b' 면 둘 중 하나를 먼저 본다(첫 접촉 r00 은 opening_test 가 호감 15 이하로 고정해
/// 놓쳐도 r01 이 첫 접촉을 대신한다).
const prerequisites = [
  // ---- 서연: 첫 접촉은 r00(단톡 호명) 또는 r01(개인톡). 'a|b' 는 둘 중 하나가 먼저라는 뜻 ----
  ('seoyeon_r02', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r03', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r04', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r05', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r06', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r07', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r08', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r09', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r10', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r11', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r12', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r13', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r14', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r15', 'seoyeon_r00|seoyeon_r01'),
  ('seoyeon_r04', 'seoyeon_r02'), // "오늘 발표 잘했더라" ← 발표 준비
  ('seoyeon_r11', 'seoyeon_r07'), // "그 사람도 딱 그렇게 말했어" ← 전 남친 얘기
  ('seoyeon_r09', 'seoyeon_r08'), // 지방행 D-30 ← 짐 정리
  ('seoyeon_r10', 'seoyeon_r09'), // 장거리 얘기 ← "너 나 좋아해?"
  ('seoyeon_r11', 'seoyeon_r09'),
  ('seoyeon_r12', 'seoyeon_r09'), // 이사 전날 ← D-30
  ('seoyeon_r15', 'seoyeon_r12'), // "여기 내려오니까" ← 이사
  ('seoyeon_r03', 'm07'), // 뒤풀이 자리 ← 첫 뒤풀이(17일차)
  ('seoyeon_r08', 'm16'), // 짐 뺀다 ← 지방행 고백(40일차)
  ('seoyeon_r09', 'm16'),
  // ---- 하늘: (r00 출근 전날) → r01(첫날) → r02(반말) ----
  ('haneul_r02', 'haneul_r01'),
  ('haneul_r03', 'haneul_r01'),
  ('haneul_r14', 'haneul_r01'),
  ('haneul_r04', 'haneul_r02'),
  ('haneul_r05', 'haneul_r02'),
  ('haneul_r06', 'haneul_r02'),
  ('haneul_r07', 'haneul_r02'),
  ('haneul_r08', 'haneul_r02'),
  ('haneul_r09', 'haneul_r02'),
  ('haneul_r10', 'haneul_r02'),
  ('haneul_r11', 'haneul_r02'),
  ('haneul_r12', 'haneul_r02'),
  ('haneul_r13', 'haneul_r02'),
  ('haneul_r15', 'haneul_r02'),
  ('haneul_r09', 'haneul_r04'), // "맨날 알바 끝나고 국밥만" ← 국밥집
  ('haneul_r15', 'haneul_r01'), // "너 처음엔 진짜 느렸는데"
  // ---- 지우: m03 수락 → r01 첫 메시지 → (m10 D-1) r02 첫 만남 → (m11 애프터) 나머지 ----
  ('jiwoo_r01', 'm03'),
  ('jiwoo_r02', 'jiwoo_r01'),
  ('jiwoo_r02', 'm10'),
  ('jiwoo_r03', 'm11'),
  ('jiwoo_r04', 'm11'), // "첫 만남 때는 별로였어요"
  ('jiwoo_r05', 'm11'),
  ('jiwoo_r06', 'm11'),
  ('jiwoo_r07', 'm11'),
  ('jiwoo_r08', 'm11'),
  ('jiwoo_r09', 'm11'),
  ('jiwoo_r10', 'm11'),
  ('jiwoo_r11', 'm11'),
  ('jiwoo_r12', 'm11'), // "처음 만났을 때… 두 시간 앉아 있었죠"
  ('jiwoo_r13', 'm11'),
  ('jiwoo_r14', 'm11'),
  ('jiwoo_r15', 'm11'),
  ('jiwoo_r15', 'jiwoo_r10'), // "두 달짜리" ← "두 달은 주말이 없을 거예요"
  // ---- 민재: 첫 접촉은 r00(듀오 신청) 또는 r01(음성 채널) ----
  ('minjae_r02', 'minjae_r00|minjae_r01'),
  ('minjae_r03', 'minjae_r00|minjae_r01'),
  ('minjae_r04', 'minjae_r00|minjae_r01'),
  ('minjae_r05', 'minjae_r00|minjae_r01'),
  ('minjae_r06', 'minjae_r00|minjae_r01'),
  ('minjae_r07', 'minjae_r00|minjae_r01'),
  ('minjae_r08', 'minjae_r00|minjae_r01'),
  ('minjae_r09', 'minjae_r00|minjae_r01'),
  ('minjae_r10', 'minjae_r00|minjae_r01'),
  ('minjae_r11', 'minjae_r00|minjae_r01'),
  ('minjae_r12', 'minjae_r00|minjae_r01'),
  ('minjae_r13', 'minjae_r00|minjae_r01'),
  ('minjae_r14', 'minjae_r00|minjae_r01'),
  ('minjae_r15', 'minjae_r00|minjae_r01'),
  ('minjae_r15', 'minjae_r02'), // "이거 이기면 플래야" ← "이번 시즌에 플래 찍자"
  ('minjae_r10', 'm24'), // "그 편의점 앞" ← 민재의 정체(60일차)
  ('minjae_r11', 'minjae_r10'),
  ('minjae_r12', 'minjae_r11'),
  // ---- 예은: 첫 접촉은 r00(모르는 번호) 또는 r01(동창회 재회) ----
  ('yeeun_r02', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r03', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r04', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r05', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r06', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r07', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r08', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r09', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r10', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r11', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r12', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r13', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r14', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r15', 'yeeun_r00|yeeun_r01'),
  ('yeeun_r08', 'yeeun_r01'), // "너 그때랑 별로 안 변했어" ← 동창회에서 봄
  ('yeeun_r11', 'yeeun_r01'), // "너 동창회 때 딱 그 얼굴이었어"
  ('yeeun_r13', 'yeeun_r01'),
  ('yeeun_r09', 'yeeun_r06'),
  ('yeeun_r15', 'yeeun_r04'), // "폐교 전 마지막 개방일" ← 학교 없어진대
  ('yeeun_r03', 'm08'),
  ('yeeun_r07', 'm08'),
  // ---- 도윤: r01(자세 교정)이 첫 만남 ----
  ('doyun_r02', 'doyun_r01'),
  ('doyun_r03', 'doyun_r01'),
  ('doyun_r04', 'doyun_r01'),
  ('doyun_r06', 'doyun_r01'),
  ('doyun_r07', 'doyun_r01'),
  ('doyun_r08', 'doyun_r01'),
  ('doyun_r09', 'doyun_r01'),
  ('doyun_r10', 'doyun_r01'),
  ('doyun_r11', 'doyun_r01'),
  ('doyun_r12', 'doyun_r01'),
  ('doyun_r13', 'doyun_r01'),
  ('doyun_r14', 'doyun_r01'),
  ('doyun_r15', 'doyun_r01'), // "처음 왔을 땐 빈 봉도 못 들었어요"
  ('doyun_r06', 'doyun_r02'), // 식단 관리 ← PT
  ('doyun_r08', 'doyun_r02'), // "처음 오셨을 때 찍은 사진" ← PT
  ('doyun_r12', 'doyun_r02'), // "3개월 PT 끝났어요"
  ('doyun_r10', 'doyun_r07'), // "그래서 회원님한테 그렇게 말한 거예요"
  ('doyun_r13', 'doyun_r03'),
  ('doyun_r14', 'doyun_r07'),
  ('doyun_r05', 'm32'),
  ('doyun_r08', 'm04'), // "8일차에 거울 앞에 섰던 그 몸"
  // ---- 정우 (tool/new_content/jeongwoo_order.json) ----
  ('jeongwoo_r02', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r03', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r04', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r05', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r06', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r07', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r08', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r09', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r10', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r11', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r12', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r13', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r14', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r15', 'jeongwoo_r00|jeongwoo_r01'),
  ('jeongwoo_r03', 'jeongwoo_r02'),
  ('jeongwoo_r09', 'jeongwoo_r06'),
  ('jeongwoo_r10', 'jeongwoo_r09'),
  ('jeongwoo_r11', 'jeongwoo_r09'),
  ('jeongwoo_r11', 'jeongwoo_r07'),
  ('jeongwoo_r12', 'jeongwoo_r09'),
  ('jeongwoo_r15', 'jeongwoo_r12'),
  ('mo_jeongwoo_photo_shutter', 'jeongwoo_r06'),
  ('mo_jeongwoo_call_iron', 'jeongwoo_r09'),
  ('jeongwoo_r11', 'm16'),
  // ---- 다은 (tool/new_content/daeun_order.json) ----
  ('daeun_r02', 'daeun_r01'),
  ('daeun_r03', 'daeun_r01'),
  ('daeun_r04', 'daeun_r02'),
  ('daeun_r05', 'daeun_r02'),
  ('daeun_r06', 'daeun_r02'),
  ('daeun_r07', 'daeun_r02'),
  ('daeun_r08', 'daeun_r07'),
  ('daeun_r09', 'daeun_r07'),
  ('daeun_r10', 'daeun_r07'),
  ('daeun_r11', 'daeun_r07'),
  ('daeun_r12', 'daeun_r07'),
  ('daeun_r13', 'daeun_r07'),
  ('daeun_r14', 'daeun_r07'),
  ('daeun_r15', 'daeun_r07'),
  ('daeun_r09', 'daeun_r08'),
  ('daeun_r11', 'daeun_r08'),
  ('daeun_r15', 'daeun_r08'),
  ('daeun_r12', 'daeun_r11'),
  ('daeun_r15', 'daeun_r01'),
  ('mo_daeun_photo_receipt', 'daeun_r02'),
  ('mo_daeun_preview_hair', 'daeun_r01'),
  ('mo_daeun_call_pencil', 'daeun_r07'),
  ('mo_daeun_photo_canvas', 'daeun_r08'),
  // ---- 승현 (tool/new_content/seunghyun_order.json) ----
  ('seunghyun_r00', 'm03_m'),
  ('seunghyun_r01', 'm03_m'),
  ('seunghyun_r02', 'seunghyun_r01'),
  ('seunghyun_r02', 'm10'),
  ('seunghyun_r03', 'm11_m'),
  ('seunghyun_r04', 'm11_m'),
  ('seunghyun_r05', 'm11_m'),
  ('seunghyun_r06', 'm11_m'),
  ('seunghyun_r07', 'm11_m'),
  ('seunghyun_r08', 'm11_m'),
  ('seunghyun_r09', 'm11_m'),
  ('seunghyun_r10', 'm11_m'),
  ('seunghyun_r11', 'm11_m'),
  ('seunghyun_r12', 'm11_m'),
  ('seunghyun_r13', 'm11_m'),
  ('seunghyun_r14', 'm11_m'),
  ('seunghyun_r15', 'm11_m'),
  ('seunghyun_r10', 'seunghyun_r09'),
  ('seunghyun_r11', 'seunghyun_r04'),
  ('seunghyun_r15', 'seunghyun_r10'),
  // ---- 소희 (tool/new_content/sohee_order.json) ----
  ('sohee_r02', 'sohee_r00|sohee_r01'),
  ('sohee_r03', 'sohee_r00|sohee_r01'),
  ('sohee_r04', 'sohee_r00|sohee_r01'),
  ('sohee_r05', 'sohee_r00|sohee_r01'),
  ('sohee_r06', 'sohee_r00|sohee_r01'),
  ('sohee_r07', 'sohee_r00|sohee_r01'),
  ('sohee_r08', 'sohee_r00|sohee_r01'),
  ('sohee_r09', 'sohee_r00|sohee_r01'),
  ('sohee_r10', 'sohee_r00|sohee_r01'),
  ('sohee_r11', 'sohee_r00|sohee_r01'),
  ('sohee_r12', 'sohee_r00|sohee_r01'),
  ('sohee_r13', 'sohee_r00|sohee_r01'),
  ('sohee_r14', 'sohee_r00|sohee_r01'),
  ('sohee_r15', 'sohee_r00|sohee_r01'),
  ('sohee_r15', 'sohee_r02'),
  ('sohee_r11', 'sohee_r02'),
  ('sohee_r09', 'sohee_r05'),
  ('sohee_r10', 'm24_f'),
  ('sohee_r11', 'sohee_r10'),
  ('sohee_r12', 'sohee_r11'),
  ('mo_sohee_photo_skewer', 'sohee_r09'),
  // ---- 건우 (tool/new_content/geonwoo_order.json) ----
  ('geonwoo_r02', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r03', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r04', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r05', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r06', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r07', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r08', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r09', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r10', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r11', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r12', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r13', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r14', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r15', 'geonwoo_r00|geonwoo_r01'),
  ('geonwoo_r02', 'geonwoo_r01'),
  ('geonwoo_r03', 'm08'),
  ('geonwoo_r07', 'm08'),
  ('geonwoo_r09', 'geonwoo_r08'),
  ('geonwoo_r12', 'geonwoo_r11'),
  ('geonwoo_r15', 'geonwoo_r04'),
  ('geonwoo_r15', 'geonwoo_r11'),
  ('mo_geonwoo_photo_note', 'geonwoo_r08'),
  // ---- 유나 (tool/new_content/yuna_order.json) ----
  ('yuna_r02', 'yuna_r01'),
  ('yuna_r03', 'yuna_r01'),
  ('yuna_r04', 'yuna_r01'),
  ('yuna_r06', 'yuna_r01'),
  ('yuna_r07', 'yuna_r01'),
  ('yuna_r08', 'yuna_r01'),
  ('yuna_r09', 'yuna_r01'),
  ('yuna_r10', 'yuna_r01'),
  ('yuna_r11', 'yuna_r01'),
  ('yuna_r12', 'yuna_r01'),
  ('yuna_r13', 'yuna_r01'),
  ('yuna_r14', 'yuna_r01'),
  ('yuna_r15', 'yuna_r01'),
  ('yuna_r06', 'yuna_r02'),
  ('yuna_r08', 'yuna_r02'),
  ('yuna_r08', 'yuna_r04'),
  ('yuna_r08', 'yuna_r06'),
  ('yuna_r08', 'yuna_r07'),
  ('yuna_r08', 'yuna_r13'),
  ('yuna_r05', 'm32'),
  ('yuna_r05', 'yuna_r08'),
  ('yuna_r09', 'yuna_r08'),
  ('yuna_r10', 'yuna_r08'),
  ('yuna_r10', 'yuna_r07'),
  ('yuna_r11', 'yuna_r10'),
  ('yuna_r11', 'yuna_r04'),
  ('yuna_r12', 'yuna_r10'),
  ('yuna_r12', 'yuna_r08'),
  ('yuna_r15', 'yuna_r12'),
  ('yuna_r15', 'yuna_r02'),
  ('yuna_r15', 'yuna_r08'),
  ('mo_yuna_photo_tteok', 'yuna_r04'),
  ('mo_yuna_preview_mood', 'yuna_r02'),
  ('mo_yuna_preview_mood', 'yuna_r08'),
  ('mo_yuna_call_offer', 'yuna_r10'),
  ('mo_yuna_photo_journal', 'yuna_r12'),
  ('mo_yuna_photo_journal', 'yuna_r06'),
];

/// (뒤, 앞): 둘 다 나온다면 앞이 먼저다. 앞은 건너뛸 수 있다(선택적 장면).
/// notFlags 나 day 상한으로 "뒤 사건 이후에는 앞 장면이 안 나오게" 막은 것.
const orderOnly = [
  // r00(첫 접촉, 호감 ≤15)은 r01 이후엔 나오지 않는다. r01 도 같은 첫 접촉 플래그를 세운다.
  ('seoyeon_r01', 'seoyeon_r00'),
  ('haneul_r01', 'haneul_r00'),
  ('minjae_r01', 'minjae_r00'),
  ('yeeun_r01', 'yeeun_r00'),
  // 지우 r02(첫 만남)는 소개팅 당일 장면이라 m11(29일차 "소개팅은 끝났다") 전에만 나온다.
  ('m11', 'jiwoo_r02'),
  ('jiwoo_r03', 'jiwoo_r02'),
  ('jiwoo_r04', 'jiwoo_r02'),
  ('jiwoo_r12', 'jiwoo_r02'),
  // 지우 r01(첫 메시지)는 소개팅 전날(m10) 전에만.
  ('m10', 'jiwoo_r01'),
  // 민재: 오프라인으로 만난(r11) 뒤에는 "얼굴도 모른다"류 장면이 안 나온다.
  ('minjae_r11', 'minjae_r01'),
  ('minjae_r11', 'minjae_r04'),
  ('minjae_r11', 'minjae_r06'),
  ('minjae_r11', 'minjae_r07'),
  ('minjae_r11', 'minjae_r08'),
  ('minjae_r11', 'minjae_r09'),
  // 하늘: 반말 전환(r02) 뒤에는 존댓말 장면(r00, r01)이 안 나온다.
  ('haneul_r02', 'haneul_r00'),
  ('haneul_r02', 'haneul_r01'),
  // 정우
  ('jeongwoo_r01', 'jeongwoo_r00'),
  // 다은
  ('daeun_r01', 'daeun_r00'),
  ('daeun_r07', 'daeun_r00'),
  ('daeun_r07', 'daeun_r01'),
  ('daeun_r07', 'daeun_r03'),
  ('daeun_r07', 'daeun_r04'),
  ('daeun_r07', 'daeun_r05'),
  ('daeun_r07', 'daeun_r06'),
  ('daeun_r07', 'mo_daeun_photo_receipt'),
  ('daeun_r07', 'mo_daeun_preview_hair'),
  // 승현
  ('seunghyun_r01', 'seunghyun_r00'),
  ('m10', 'seunghyun_r00'),
  ('m10', 'seunghyun_r01'),
  ('m11_m', 'seunghyun_r02'),
  ('seunghyun_r03', 'seunghyun_r02'),
  ('seunghyun_r04', 'seunghyun_r02'),
  ('seunghyun_r12', 'seunghyun_r02'),
  // 소희
  ('sohee_r01', 'sohee_r00'),
  ('sohee_r09', 'sohee_r01'),
  ('m24_f', 'sohee_r07'),
  ('m24_f', 'mo_sohee_preview_tutorial'),
  ('sohee_r15', 'sohee_r11'),
  ('sohee_r15', 'sohee_r12'),
  // 건우
  ('geonwoo_r01', 'geonwoo_r00'),
  ('geonwoo_r15', 'geonwoo_r12'),
  // 유나
  ('yuna_r01', 'yuna_r00'),
  ('yuna_r08', 'yuna_r03'),
  ('yuna_r08', 'yuna_r14'),
  ('yuna_r08', 'mo_yuna_photo_tteok'),
];

/// 기준 측정치. 캐릭터 → 전략 → 마지막 루트 이벤트(r15)에 도달한 회차 비율.
/// focus 류는 그 캐릭터를 대상으로 한 회차만 센다. 선호별(f·m 각각, 그 쪽 6명만 등장) 1200시드,
/// 미니게임 성공률 60%, 2026-09-19 12명 병합·밸런스 조정 뒤 엔진 기준.
/// 캐릭터마다 최소 한 전략에서 5%p 넘게 떨어지지 않아야 한다.
/// (이전 기준은 선호 도입 전 6명 전원 등장 회차였다. 그때보다 크게 낮아진 것: 하늘 focus .890→.825,
/// 민재 focus .675→.620·random .142→.083 — 남성 쪽 경쟁자가 서연·지우·예은에서 정우·승현·건우로 바뀌었고,
/// 건우가 예은보다 호감이 빨리 쌓여 r09 이후 "다른 캐릭터 ≤55" 상한에 더 자주 걸린다.)
const baselineReach = <String, Map<String, double>>{
  'seoyeon': {
    'first': .015,
    'maxAff': .383,
    'focus': .855,
    'focus+hint': .660,
    'random': .019,
    'doubleTimer': .266,
  },
  'haneul': {
    'first': .158,
    'maxAff': .439,
    'focus': .825,
    'focus+hint': .530,
    'random': .052,
    'doubleTimer': .330,
  },
  'jiwoo': {
    'first': .022,
    'maxAff': .023,
    'focus': .470,
    'focus+hint': .055,
    'random': .105,
    'doubleTimer': .165,
  },
  'minjae': {
    'first': .047,
    'maxAff': .053,
    'focus': .620,
    'focus+hint': .105,
    'random': .083,
    'doubleTimer': .053,
  },
  'yeeun': {
    'first': .243,
    'maxAff': .057,
    'focus': .760,
    'focus+hint': .155,
    'random': .212,
    'doubleTimer': .198,
  },
  'doyun': {
    'first': .362,
    'maxAff': .985,
    'focus': .925,
    'focus+hint': .885,
    'random': .463,
    'doubleTimer': .443,
  },
  'jeongwoo': {
    'first': .010,
    'maxAff': .347,
    'focus': .895,
    'focus+hint': .670,
    'random': .013,
    'doubleTimer': .185,
  },
  'daeun': {
    'first': .102,
    'maxAff': .509,
    'focus': .870,
    'focus+hint': .640,
    'random': .025,
    'doubleTimer': .326,
  },
  'seunghyun': {
    'first': .007,
    'maxAff': .013,
    'focus': .515,
    'focus+hint': .080,
    'random': .090,
    'doubleTimer': .167,
  },
  'sohee': {
    'first': .021,
    'maxAff': .026,
    'focus': .635,
    'focus+hint': .120,
    'random': .066,
    'doubleTimer': .038,
  },
  'geonwoo': {
    'first': .193,
    'maxAff': .142,
    'focus': .905,
    'focus+hint': .310,
    'random': .258,
    'doubleTimer': .261,
  },
  'yuna': {
    'first': .137,
    'maxAff': .990,
    'focus': .915,
    'focus+hint': .920,
    'random': .201,
    'doubleTimer': .325,
  },
};

/// 선택에 따라 갈리는 분기 플래그. 진행 플래그가 아니라서 "모든 경로에서 세워져야" 검사와
/// 막다른 길 검사에서 뺀다(그 분기를 안 고르면 뒤 이벤트를 못 보는 게 의도).
const branchFlags = {
  'yeeun_avoid_1',
  'fake_record',
  'overtraining',
  'minjae_promised',
  'minjae_met',
  'haneul_banmal',
  'seoyeon_banmal',
  'minjae_meet_asked',
  'told_junho',
  'taehyun_hint',
  'haneul_next_date', 'yeeun_avoid_2', 'yeeun_avoid_3', 'yeeun_letter_told',
  // 신규 캐스트: 소희 r10 대본 상대역을 거절하면 r11(길드 해체)·r12 가 열리지 않는다.
  // 작가 보고의 나머지(daeun_playlist, geonwoo_joke_1, sohee_met, sohee_told, yuna_noticed,
  // yuna_body_comment)는 어떤 루트 트리거도 flags 로 요구하지 않아(엔딩·notFlags·모먼트 전용) 빼도
  // 정적 검사가 그대로라 넣지 않았다(2026-09-19 하나씩 빼 보며 확인).
  'sohee_script',
};

/// 선택적 장면. 앞 이벤트를 놓치면 이 장면만 건너뛰고, 이 장면을 전제하는 뒤 이벤트는 없다
/// (orderOnly 로만 묶임, prerequisites 의 앞으로 쓰이지 않음 — 테스트가 확인). 그래서 막다른 길 검사에서 뺀다.
/// - day 창이 좁은 소개팅 당일 장면: jiwoo_r02, seunghyun_r02
/// - 반말 전환(yuna_r08) 전에만 나오는 장면: yuna_r14
/// - 루트 이벤트 플래그로 열리는 모먼트(전화·사진). 모먼트는 형식을 깨는 덤이라 놓쳐도 진행이 막히지 않는다.
const optionalScenes = {
  'jiwoo_r02',
  'seunghyun_r02',
  'yuna_r14',
  'mo_jeongwoo_photo_shutter',
  'mo_jeongwoo_call_iron',
  'mo_daeun_call_pencil',
  'mo_daeun_photo_canvas',
  'mo_sohee_photo_skewer',
  'mo_geonwoo_photo_note',
};

const kRouteSeeds = int.fromEnvironment('ROUTE_SEEDS', defaultValue: 300);

/// 단계 역행 검사용 시드 수(전략 2개 × 선호 2쪽). 진단은 300시드에서 f 290/300 회차가
/// 역행이었으므로, 60이면 수정 전 코드가 확실히 걸린다.
const kStageSeeds = int.fromEnvironment('STAGE_SEEDS', defaultValue: 60);

/// MBTI 도달성(16유형 + 모름 × 선호): 유형·선호마다 focus 봇 시드 수. 대상 캐릭터를 시드로
/// 돌리므로 캐릭터마다 이 수 ÷ 인원만큼 돈다(기본 144 → 6명이면 24회씩).
/// 17 × 2 × 144 ≈ 4,900회라 스위트 시간을 지키려고 focus 전략만 쓴다(docs/MBTI_SPEC.md §2.4).
const kMbtiRouteSeeds = int.fromEnvironment(
  'MBTI_ROUTE_SEEDS',
  defaultValue: 144,
);

/// 시뮬레이션할 선호(`--dart-define=ROUTE_PREF=f|m|all`). 기본은 f 와 m 을 각각 돈다.
/// 캐릭터가 한 명도 없는 쪽은 건너뛴다(신규 캐스트가 들어오기 전 데이터에서도 돈다).
const kRoutePref = String.fromEnvironment('ROUTE_PREF', defaultValue: 'each');

/// [kRoutePref] 에 해당하는, 캐릭터가 있는 선호 목록.
List<String> routePrefs(StoryBundle b) {
  final wanted = kRoutePref == 'each' ? Preference.genders : [kRoutePref];
  for (final p in wanted) {
    if (!Preference.values.contains(p)) throw ArgumentError('ROUTE_PREF: $p');
  }
  return [
    for (final p in wanted)
      if (b.charactersFor(p).isNotEmpty) p,
  ];
}

// ---------------------------------------------------------------------------

class _Run {
  final List<String> order = [];
  final Map<String, int> index = {};
  String? target;
}

_Run _simulate(
  StoryBundle b,
  Strategy strat,
  int seed,
  String pref, {
  String? mbti,
}) {
  final engine = EventEngine(b);
  final resolver = EndingResolver(b.endings, characters: b.characters);
  final s = GameState.fresh(
    b.config,
    b.characters,
    seed: seed,
    preference: pref,
    mbti: mbti,
  );
  simAbsent = engine.absentFor(s);
  final r = Random(seed * 7919 + strat.name.hashCode);
  final run = _Run()..target = strat is FocusStrategy ? strat.target : null;

  void saw(StoryEvent e) {
    run.index.putIfAbsent(e.id, () => run.order.length);
    run.order.add(e.id);
  }

  while (!engine.isFinished(s)) {
    final slot = engine.spinRoulette(s);
    s.rouletteDay = s.day;
    engine.applyRoulette(s, slot);
    engine.applyAction(s, strat.action(s, b.config.actions, r, b));
    final queue = engine.planDay(s);
    while (queue.isNotEmpty) {
      // 화면과 같이 이 회차 MBTI 로 거른 사본.
      final ev = engine.viewFor(s, queue.removeAt(0));
      saw(ev);
      for (final l in ev.lines) {
        if (l.isWait) {
          s.stats[Stat.esteem] = (s.stat(Stat.esteem) - 1).clamp(0, 100);
        }
      }
      final views = engine.choicesFor(s, ev);
      final open = views.where((v) => !v.locked).toList();
      simTop = engine.topCharacter(s);
      if (open.isEmpty) {
        s.seen.add(ev.id);
        continue;
      }
      final c = ev.choices[strat.pick(s, ev, open, r, engine)];
      bool? forced;
      if (c.minigame != null) forced = r.nextDouble() < kMinigameSuccess;
      final out = engine.applyChoice(s, ev, c, forcedSuccess: forced);
      final next = out.nextEventId;
      if (next != null) {
        final ne = engine.byId(next);
        if (ne != null) queue.insert(0, ne);
      }
    }
    engine.endDay(s);
    if (resolver.immediate(s) != null) break;
  }
  return run;
}

// ---------------------------------------------------------------------------
// 정적 분석

/// 선택 하나를 고른 뒤 반드시 세워지는 플래그(성공·실패 공통).
Set<String> _flagsOnChoice(Choice c) {
  final ok = c.effects.setFlags.toSet();
  final canFail = c.minigame != null || c.chance != null;
  return canFail ? ok.intersection(c.fail.setFlags.toSet()) : ok;
}

/// 이벤트를 보고 나면 어떤 선택을 했든 세워지는 플래그.
Set<String> guaranteedFlags(StoryEvent e) {
  if (e.choices.isEmpty) return {};
  return e.choices.map(_flagsOnChoice).reduce((a, b) => a.intersection(b));
}

/// 어떤 경로로든 이 플래그를 세울 수 있는 이벤트들.
Map<String, Set<String>> setters(StoryBundle b) {
  final m = <String, Set<String>>{};
  for (final e in b.events) {
    for (final c in e.choices) {
      for (final f in [...c.effects.setFlags, ...c.fail.setFlags]) {
        m.putIfAbsent(f, () => {}).add(e.id);
      }
    }
  }
  return m;
}

/// 이벤트 e 가 나오기 전에 반드시 본 이벤트 집합.
/// - trigger.flags 의 각 플래그 f 에 대해, f 를 세우는 이벤트 모두가 공통으로 가진 선행 집합
/// - day 하한보다 이른 main 이벤트(무조건 나온다)
Set<String> mustPrecede(
  StoryBundle b,
  String id, [
  Map<String, Set<String>>? memo,
  Set<String>? stack,
]) {
  memo ??= {};
  stack ??= {};
  if (memo.containsKey(id)) return memo[id]!;
  if (!stack.add(id)) return {};
  final e = b.eventById[id]!;
  final out = <String>{};
  final set = setters(b);
  for (final f in e.trigger.flags) {
    final xs = set[f] ?? {};
    if (xs.isEmpty) continue;
    Set<String>? common;
    for (final x in xs) {
      final p = {x, ...mustPrecede(b, x, memo, stack)};
      common = common == null ? p : common.intersection(p);
    }
    out.addAll(common ?? {});
  }
  final lo = e.trigger.day?.min ?? 1;
  for (final m in b.events.where(
    (m) =>
        m.layer == EventLayer.main && m.day != null && m.trigger.flags.isEmpty,
  )) {
    if (m.day! < lo) out.add(m.id);
  }
  stack.remove(id);
  return memo[id] = out;
}

/// [alts] 중 하나가 [id] 보다 반드시 먼저 나오는지.
/// 요구 플래그 하나라도, 그 플래그를 세우는 모든 이벤트가 alts 에 속하거나 alts 뒤에 온다면 참.
bool precedesAny(
  StoryBundle b,
  String id,
  Set<String> alts, [
  Set<String>? stack,
]) {
  stack ??= {};
  if (!stack.add(id)) return false;
  final e = b.eventById[id]!;
  final set = setters(b);
  var ok = false;
  for (final f in e.trigger.flags) {
    final xs = set[f] ?? {};
    if (xs.isNotEmpty &&
        xs.every((x) => alts.contains(x) || precedesAny(b, x, alts, stack))) {
      ok = true;
    }
  }
  if (!ok) ok = alts.any(mustPrecede(b, id).contains);
  stack.remove(id);
  return ok;
}

/// 앞(earlier)이 뒤(later) 이후에는 나올 수 없는지.
bool cannotFollow(StoryBundle b, String later, String earlier) {
  final l = b.eventById[later]!;
  final e = b.eventById[earlier]!;
  final lDay = l.day ?? l.trigger.day?.min ?? 1;
  final eMax = e.day ?? e.trigger.day?.max ?? 1 << 30;
  if (eMax < lDay) return true;
  // 뒤를 보고 나면(또는 뒤보다 반드시 먼저 오는 이벤트를 보고 나면) 세워지는 플래그가 앞을 막는다.
  final chain = {later, ...mustPrecede(b, later)};
  for (final x in chain) {
    if (guaranteedFlags(b.eventById[x]!).any(e.trigger.notFlags.contains)) {
      return true;
    }
  }
  return false;
}

void main() {
  late StoryBundle bundle;
  setUpAll(() {
    registerMinigames();
    bundle = loadBundle();
  });

  test('선언 목록의 id 가 모두 존재한다', () {
    for (final (a, b) in [...prerequisites, ...orderOnly]) {
      for (final id in [a, ...b.split('|')]) {
        expect(bundle.eventById.containsKey(id), isTrue, reason: id);
      }
    }
  });

  test('선택적 장면은 다른 이벤트의 필수 선행이 아니다', () {
    for (final (later, earlier) in prerequisites) {
      for (final id in earlier.split('|')) {
        expect(
          optionalScenes,
          isNot(contains(id)),
          reason: '$later 가 선택적 장면 $id 를 전제함',
        );
      }
    }
    for (final id in optionalScenes) {
      expect(bundle.eventById.containsKey(id), isTrue, reason: id);
    }
  });

  test('정적 검사: 뒤 이벤트 트리거가 앞 이벤트를 보장한다', () {
    final bad = <String>[];
    final memo = <String, Set<String>>{};
    for (final (later, earlier) in prerequisites) {
      final alts = earlier.split('|').toSet();
      final ok = alts.length == 1
          ? mustPrecede(bundle, later, memo).contains(earlier)
          : precedesAny(bundle, later, alts);
      if (!ok) {
        final l = bundle.eventById[later]!;
        bad.add(
          '$later ← $earlier (flags ${l.trigger.flags}, day ${l.trigger.day})',
        );
      }
    }
    for (final (later, earlier) in orderOnly) {
      if (!cannotFollow(bundle, later, earlier)) {
        bad.add('$later 뒤에 $earlier 가 나올 수 있음');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('정적 검사: 루트 진행 플래그는 모든 선택지(실패 포함)에서 세워진다', () {
    // 루트 이벤트가 요구하는 플래그 중, 루트 이벤트가 세우는 것은
    // 그 이벤트의 모든 선택지·실패 경로에서 세워져야 한다. 아니면 앞을 보고도 뒤가 막힌다.
    // 선택에 따라 갈리는 분기 플래그(yeeun_avoid_1, fake_record 등)는 제외한다.
    final set = setters(bundle);
    final bad = <String>[];
    final required = bundle.events
        .where((e) => e.layer == EventLayer.route)
        .expand((e) => e.trigger.flags)
        .toSet();
    for (final f in required.difference(branchFlags)) {
      for (final x in set[f] ?? <String>{}) {
        final e = bundle.eventById[x]!;
        if (e.layer != EventLayer.route) continue;
        if (!guaranteedFlags(e).contains(f)) bad.add('$x 가 $f 를 일부 경로에서만 세움');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('정적 검사: 한 선택지 안에서 진행 플래그가 실패로 사라지지 않는다', () {
    // 위 검사는 "이벤트의 **모든 선택지**가 세우는가" 를 본다. 이번 사고는 한 칸 아래,
    // **같은 선택지 안**에서 일어났다: `applyChoice` 는 실패하면 `c.fail` 만 적용하고
    // `c.effects.setFlags` 를 건너뛴다(event_engine.dart:474). 그래서 확률·미니게임이
    // 붙은 선택지를 고르고 지면, 장면은 겪었는데 겪은 적 없는 사람이 된다.
    //
    // `m07` "자기소개를 한다"(미니게임)·"안주만 먹는다"(확률 60)가 그랬고, 무작위
    // 200회차 중 50회차가 `club_afterparty` 를 못 얻어 서연 장면 2편을 영구히 잃었다.
    // 세터가 main 층이라 위 검사는 이걸 볼 수 없었다(docs/review/11_claims_audit.md).
    //
    // 성공해야만 서는 게 맞는 플래그는 여기 적는다 — 실패하면 안 일어난 일이다.
    const successOnly = {
      'stranger_laugh', // 모르는 사람이 웃어 줬다 — 지면 안 웃은 것이다
      'seoyeon_banmal', // 반말하기로 했다 — 지면 서연이 안 받아 준 것이다
      // "AI 합성이에요" 가 먹혔다(개편 2 sc_clip_d1). 지면 다들 알아챈 것이다 —
      // 그 갈래의 위기(c_clip_truth)는 거짓말이 통했을 때만 온다.
      'sc_clip_deny',
    };
    final required = bundle.events.expand((e) => e.trigger.flags).toSet();
    final bad = <String>[];
    for (final e in bundle.events) {
      for (var i = 0; i < e.choices.length; i++) {
        final c = e.choices[i];
        if (c.minigame == null && c.chance == null) continue;
        for (final f in c.effects.setFlags) {
          if (!required.contains(f) || successOnly.contains(f)) continue;
          if (!c.fail.setFlags.contains(f)) {
            bad.add('${e.id}[$i] 이 지면 $f 를 잃는다 (fail.setFlags 에 없음)');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('정적 검사: 막다른 길 없음 (앞 이벤트 상한이 뒤 이벤트 상한 이상)', () {
    final set = setters(bundle);
    // 앞 하나가 뒤를 막지 않는지. 문제가 있으면 이유 목록.
    List<String> issues(String later, String earlier, Set<String> alts) {
      final bad = <String>[];
      final l = bundle.eventById[later]!;
      final e = bundle.eventById[earlier]!;
      if (e.layer != EventLayer.route || optionalScenes.contains(later)) {
        return bad;
      }
      // 뒤가 앞의 분기 플래그로만 이어지면(거짓 기록 → 발각 등) 진행 경로가 아니다.
      final link = l.trigger.flags.where(
        (f) => set[f]?.contains(earlier) == true,
      );
      if (link.isNotEmpty && link.every(branchFlags.contains)) return bad;
      // 호감·신뢰 상한: 앞의 상한이 뒤의 상한보다 낮으면, 앞을 못 본 채 상한을 넘을 때 뒤가 영영 막힌다.
      for (final dim in ['affection', 'trust']) {
        final em = dim == 'affection' ? e.trigger.affection : e.trigger.trust;
        final lm = dim == 'affection' ? l.trigger.affection : l.trigger.trust;
        em.forEach((k, r) {
          final lMax = lm[k]?.max ?? 100;
          if (r.max < min(lMax, 100)) {
            bad.add('$earlier $dim[$k] 상한 ${r.max} < $later 상한 $lMax');
          }
        });
      }
      final eDayMax = e.trigger.day?.max ?? 100;
      final lDayMax = l.trigger.day?.max ?? 100;
      if (eDayMax < lDayMax) {
        bad.add('$earlier day 상한 $eDayMax < $later day 상한 $lDayMax');
      }
      // 앞 이벤트의 notFlags 가 앞 이벤트보다 먼저 세워질 수 있으면 막다른 길.
      for (final f in e.trigger.notFlags) {
        for (final x in set[f] ?? <String>{}) {
          // 같은 첫 접촉 그룹(r00|r01)이 먼저 나온 뒤에만 세워지는 플래그면 앞은 이미 필요 없다.
          if (alts.contains(x) || precedesAny(bundle, x, alts)) continue;
          // 뒤 이벤트도 x 이후엔 나오지 않게 막혀 있으면(예: 소희 r11·r12 둘 다 r15 의 sohee_final 을
          // notFlags 로 가짐) 막다른 길이 아니라 의도된 마감이다.
          if (cannotFollow(bundle, x, later)) continue;
          bad.add('$earlier 의 notFlags $f 를 $x 가 먼저 세울 수 있음');
        }
      }
      return bad;
    }

    final bad = <String>{};
    for (final (later, earlier) in prerequisites) {
      // 대안 중 하나라도 막히지 않으면 된다.
      final alts = earlier.split('|').toSet();
      final all = alts.map((x) => issues(later, x, alts)).toList();
      if (all.every((xs) => xs.isNotEmpty)) bad.addAll(all.expand((x) => x));
    }
    expect(bad.toList(), isEmpty, reason: bad.join('\n'));
  });

  // ---- 단계 역행 금지 (docs/review/07_story_flow.md (c)#3) ----
  //
  // 진단: 루트 이벤트 6000개 중 번호가 뒤로 간 경우 선호 f 9.9% · m 18.1%,
  // 한 번 이상 역행한 회차는 f 290/300 · m 300/300 이었다
  // (seoyeon r13 → r5 가 219회, yeeun r14 → r4 가 45회 …).
  // 수정 전 `_pickRoute` 는 그 캐릭터의 후보 전체에서 가중치 추첨만 했으므로
  // 아래 두 테스트는 **수정 전 코드에서 반드시 실패한다**.

  test('단계 유도: 루트 id 의 _rNN 이 곧 단계, 모먼트 루트는 단계 없음', () {
    final numbered = bundle.events.where(
      (e) => e.layer == EventLayer.route && e.stage != null,
    );
    expect(numbered.length, 189, reason: '<캐릭터>_rNN 루트');
    expect(bundle.eventById['seoyeon_r03']!.stage, 3);
    expect(bundle.eventById['seoyeon_r13']!.stage, 13);
    expect(bundle.eventById['mo_seoyeon_call_dawn']!.stage, isNull);
  });

  test('단계 규칙: 오늘 후보 중 가장 낮은 단계부터 나간다', () {
    final engine = EventEngine(bundle);
    final s = GameState.fresh(bundle.config, bundle.characters, seed: 1);
    List<StoryEvent> ev(List<String> ids) => [
      for (final id in ids) bundle.eventById[id]!,
    ];
    final pool = ev([
      'seoyeon_r03',
      'seoyeon_r05',
      'seoyeon_r13',
      'seoyeon_r14',
      'mo_seoyeon_call_dawn',
    ]);
    // r05 와 r13 이 같이 올라와도 낮은 쪽이 먼저다(= 진단의 seoyeon r13 → r5 219회).
    expect(engine.nextStageEvents(s, pool).map((e) => e.id).toSet(), {
      'seoyeon_r03',
      'mo_seoyeon_call_dawn',
    }, reason: '번호 없는 모먼트는 단계 밖이라 늘 함께 남는다');
    // 앞 단계를 보고 나면(= candidates 에서 빠지면) 다음으로 낮은 단계가 나간다.
    final next = ev([
      'seoyeon_r05',
      'seoyeon_r13',
      'seoyeon_r14',
      'mo_seoyeon_call_dawn',
    ]);
    expect(
      engine.nextStageEvents(s, next).map((e) => e.id).toSet(),
      {'seoyeon_r05', 'mo_seoyeon_call_dawn'},
    );
    // 뒤 단계를 이미 봤다고 해서 앞 단계를 **잠그지는 않는다** — 잠그면 r15(엔딩 조건)에
    // 아무도 못 닿는다. 자세한 이유는 EventEngine.nextStageEvents 주석.
    s.seen.add('seoyeon_r13');
    expect(engine.highestSeenStage(s, 'seoyeon'), 13);
    expect(
      engine.nextStageEvents(s, next).map((e) => e.id),
      contains('seoyeon_r05'),
    );
  });

  for (final pref in Preference.genders) {
    test('시뮬레이션[$pref]: 더 낮은 단계를 두고 뒤 단계가 먼저 나간 적 0번', () {
      if (!routePrefs(bundle).contains(pref)) {
        markTestSkipped('ROUTE_PREF=$kRoutePref 이거나 $pref 쪽 캐릭터가 없음');
        return;
      }
      final chars = bundle.charactersFor(pref).map((c) => c.id).toList();
      // 그날 루트 후보를 직접 들여다봐야 해서 _simulate 대신 짧은 시뮬레이터를 쓴다.
      // 하루: (후보 기록) → planDay → 각 이벤트를 첫 선택지로 넘김 → endDay.
      final jumps = <String, int>{}; // 후보에 더 낮은 단계가 있었는데 뒤 단계가 나간 경우
      final regress = <String, int>{}; // 이미 본 단계보다 번호가 낮은 장면이 나온 경우(데이터 몫)
      var routeSeen = 0;
      for (var seed = 1; seed <= kStageSeeds; seed++) {
        final target = chars[seed % chars.length];
        final engine = EventEngine(bundle);
        final s = GameState.fresh(
          bundle.config,
          bundle.characters,
          seed: seed,
          preference: pref,
        );
        simAbsent = engine.absentFor(s);
        final r = Random(seed * 7919);
        final strat = seed.isEven
            ? MaxAffectionStrategy()
            : FocusStrategy(target);
        final top = <String, int>{};
        while (!engine.isFinished(s)) {
          // 오늘 루트 후보의 캐릭터별 최소 단계.
          final low = <String, int>{};
          for (final e in engine.candidates(s, EventLayer.route)) {
            final st = e.stage;
            if (st == null) continue;
            final c = e.character ?? '';
            if (!low.containsKey(c) || st < low[c]!) low[c] = st;
          }
          final queue = engine.planDay(s);
          for (final planned in queue) {
            final ev = engine.viewFor(s, planned);
            final st = ev.stage;
            if (ev.layer == EventLayer.route && st != null) {
              routeSeen++;
              final c = ev.character ?? '';
              final lowest = low[c];
              if (lowest != null && st > lowest) {
                final k = '$c r$lowest 두고 r$st';
                jumps[k] = (jumps[k] ?? 0) + 1;
              }
              final seenMax = top[c];
              if (seenMax != null && st < seenMax) {
                final k = '$c r$seenMax → r$st';
                regress[k] = (regress[k] ?? 0) + 1;
              }
              top[c] = seenMax == null || st > seenMax ? st : seenMax;
            }
            final views = engine.choicesFor(s, ev);
            final open = views.where((v) => !v.locked).toList();
            if (open.isEmpty) {
              s.seen.add(ev.id);
              continue;
            }
            final c = ev.choices[strat.pick(s, ev, open, r, engine)];
            engine.applyChoice(s, ev, c, forcedSuccess: true);
          }
          engine.endDay(s);
        }
      }
      final rs = regress.entries.toList()..sort((a, b) => b.value - a.value);
      print(
        '[$pref] 루트 $routeSeen개 / $kStageSeeds회차 — 후보 건너뜀 ${jumps.values.fold(0, (a, b) => a + b)}개, '
        '번호 역행 ${regress.values.fold(0, (a, b) => a + b)}개'
        '${rs.isEmpty ? '' : ' (최다: ${rs.first.key} ${rs.first.value}회)'}',
      );
      // 엔진이 책임지는 것: 같은 날 후보에 더 낮은 단계가 있으면 그것부터 나간다.
      expect(
        jumps,
        isEmpty,
        reason: '후보를 건너뛴 경우:\n${jumps.entries.map((e) => '${e.key} ${e.value}회').join('\n')}',
      );
      // 남은 역행은 "앞 단계가 그날 아직 안 열려 있던" 경우뿐이다(예: daeun r14 → r8 —
      // r08 의 day·호감 하한이 r14 보다 늦게 열린다). 트리거를 고치는 건 데이터 몫이라
      // (09_engine_handoff.md §3) 여기서는 숫자만 남기고, 수정 전 수준으로 되돌아가면
      // 알아채도록 상한을 둔다. 측정값: 수정 전 회차당 f 29.5 · m 28.3 → 지금 f 17.7 · m 15.9.
      final total = regress.values.fold(0, (a, b) => a + b);
      expect(
        total / kStageSeeds,
        lessThan(22),
        reason: '회차당 번호 역행이 22개를 넘으면 단계 우선순위가 안 먹고 있다',
      );
    }, timeout: const Timeout(Duration(minutes: 15)));
  }

  // 선호마다 따로 돈다. 데이터가 없는 쪽(캐릭터 0명)은 routePrefs 가 뺀다.
  for (final pref in Preference.values) {
    test('시뮬레이션[$pref]: 뒤 이벤트가 앞 이벤트보다 먼저 나온 적 0번 + 도달성', () {
      if (!routePrefs(bundle).contains(pref)) {
        markTestSkipped('ROUTE_PREF=$kRoutePref 이거나 $pref 쪽 캐릭터가 없음');
        return;
      }
      // 봇은 이 선호 쪽 캐릭터만 대상으로 삼는다.
      final roster = bundle.charactersFor(pref);
      final chars = roster.map((c) => c.id).toList();
      final strategies = <String, Strategy Function(int seed)>{
        'first': (_) => FirstStrategy(),
        'maxAff': (_) => MaxAffectionStrategy(),
        'focus': (seed) => FocusStrategy(chars[seed % chars.length]),
        'focus+hint': (seed) =>
            FocusStrategy(chars[seed % chars.length], useHint: true),
        'random': (_) => RandomStrategy(),
        'doubleTimer': (seed) => DoubleTimerStrategy(
          chars[seed % chars.length],
          chars[(seed + 2) % chars.length],
        ),
      };
      // 이 선호에서 나올 수 없는 이벤트가 걸린 쌍은 건너뛴다(예: 남성 쪽 회차의 m10 ← jiwoo_r01).
      bool inPref(String id) =>
          bundle.eventInPreference(bundle.eventById[id]!, pref);
      final prereq = [
        for (final (later, earlier) in prerequisites)
          if (inPref(later) && earlier.split('|').any(inPref)) (later, earlier),
      ];
      final order = [
        for (final (later, earlier) in orderOnly)
          if (inPref(later) && inPref(earlier)) (later, earlier),
      ];
      final violations = <String, int>{};
      final examples = <String, String>{};
      // 전략 → 캐릭터 → (도달, 분모)
      final reach = <String, Map<String, List<int>>>{};
      // focus 대상별 루트 이벤트 열람 수 (r00~r15)
      final seenBy = <String, Map<String, int>>{};
      final focusN = <String, int>{};

      for (final entry in strategies.entries) {
        final rr = reach.putIfAbsent(
          entry.key,
          () => {
            for (final c in chars) c: [0, 0],
          },
        );
        for (var seed = 1; seed <= kRouteSeeds; seed++) {
          final run = _simulate(bundle, entry.value(seed), seed, pref);
          for (final (later, earlier) in prereq) {
            final li = run.index[later];
            if (li == null) continue;
            final eis = earlier
                .split('|')
                .map((x) => run.index[x])
                .whereType<int>();
            final ei = eis.isEmpty ? null : eis.reduce(min);
            if (ei == null || ei > li) {
              final k = '$later ← $earlier';
              violations[k] = (violations[k] ?? 0) + 1;
              examples.putIfAbsent(k, () => '${entry.key}#$seed');
            }
          }
          for (final (later, earlier) in order) {
            final li = run.index[later];
            final ei = run.index[earlier];
            if (li != null && ei != null && ei > li) {
              final k = '$earlier 가 $later 뒤에';
              violations[k] = (violations[k] ?? 0) + 1;
              examples.putIfAbsent(k, () => '${entry.key}#$seed');
            }
          }
          if (entry.key == 'focus' && run.target != null) {
            final t = run.target!;
            focusN[t] = (focusN[t] ?? 0) + 1;
            final m = seenBy.putIfAbsent(t, () => {});
            for (final id in run.index.keys.where(
              (k) => k.startsWith('${t}_r'),
            )) {
              m[id] = (m[id] ?? 0) + 1;
            }
          }
          for (final c in chars) {
            if (run.target != null && run.target != c) continue;
            rr[c]![1]++;
            if (run.index.containsKey('${c}_r15')) rr[c]![0]++;
          }
        }
      }

      final out = StringBuffer(
        '=== 루트 r15 도달 비율 (선호 $pref, 시드 $kRouteSeeds) ===\n',
      );
      out.writeln('전략'.padRight(12) + chars.map((c) => c.padLeft(9)).join());
      for (final e in reach.entries) {
        out.writeln(
          e.key.padRight(12) +
              chars.map((c) {
                final v = e.value[c]!;
                return (v[1] == 0 ? '-' : (v[0] / v[1]).toStringAsFixed(3))
                    .padLeft(9);
              }).join(),
        );
      }
      out.writeln('\n=== focus 대상별 루트 이벤트 열람률 % (r00..r15) ===');
      for (final c in chars) {
        final n = focusN[c] ?? 0;
        if (n == 0) continue;
        final row = List.generate(16, (i) {
          final id = '${c}_r${i.toString().padLeft(2, '0')}';
          if (!bundle.eventById.containsKey(id)) return '   -';
          return (100 * (seenBy[c]?[id] ?? 0) / n).round().toString().padLeft(
            4,
          );
        }).join();
        out.writeln('${c.padRight(8)} $row');
      }
      out.writeln('\n=== 순서 위반 ===');
      final vs = violations.entries.toList()..sort((a, b) => b.value - a.value);
      for (final v in vs) {
        out.writeln('${v.key}: ${v.value}회 (예: ${examples[v.key]})');
      }
      print(out);
      Directory('tool/sim_out').createSync(recursive: true);
      File(
        pref == Preference.all
            ? 'tool/sim_out/route_order_report.txt'
            : 'tool/sim_out/route_order_report_$pref.txt',
      ).writeAsStringSync(out.toString());

      // 도달성: 캐릭터마다 최소 한 전략에서 수정 전보다 5%p 넘게 떨어지지 않는다.
      final reachBad = <String>[];
      for (final c in chars) {
        final base = baselineReach[c];
        if (base == null) continue;
        final ok = base.entries.any((b) {
          final v = reach[b.key]?[c];
          if (v == null || v[1] == 0) return false;
          return v[0] / v[1] >= b.value - 0.05;
        });
        if (!ok) reachBad.add(c);
      }
      expect(
        violations,
        isEmpty,
        reason: '순서 위반:\n${vs.map((v) => '${v.key} ${v.value}').join('\n')}',
      );
      expect(reachBad, isEmpty, reason: 'r15 도달성이 크게 떨어진 캐릭터: $reachBad');
      // 어떤 전략으로도 도달 못 하는 캐릭터가 있으면 막다른 길이다.
      for (final c in chars) {
        final best = reach.values
            .map((m) => m[c]![1] == 0 ? 0.0 : m[c]![0] / m[c]![1])
            .reduce(max);
        expect(best, greaterThan(0), reason: '$c r15 도달 0');
      }
    }, timeout: const Timeout(Duration(minutes: 15)));
  }

  // MBTI 16유형 + 모름 각각에서 막다른 길이 없는지(docs/MBTI_SPEC.md §2.4). 선호마다 한 테스트.
  // 전략은 focus 하나(시간 예산), 시드는 kMbtiRouteSeeds. 캐릭터마다 r15 에 한 번 이상 닿고
  // 선후 위반이 0 이어야 한다.
  for (final pref in Preference.genders) {
    test('MBTI 17종[$pref]: 캐릭터마다 focus 로 r15 도달 + 선후 위반 0', () {
      if (!routePrefs(bundle).contains(pref)) {
        markTestSkipped('ROUTE_PREF=$kRoutePref 이거나 $pref 쪽 캐릭터가 없음');
        return;
      }
      final chars = bundle.charactersFor(pref).map((c) => c.id).toList();
      bool inPref(String id) =>
          bundle.eventInPreference(bundle.eventById[id]!, pref);
      final prereq = [
        for (final (later, earlier) in prerequisites)
          if (inPref(later) && earlier.split('|').any(inPref)) (later, earlier),
      ];
      final dead = <String>[];
      final violations = <String, int>{};
      final table = StringBuffer(
        '=== MBTI 17종 focus r15 도달 비율 (선호 $pref, 시드 $kMbtiRouteSeeds) ===\n'
        '${'MBTI'.padRight(6)}${chars.map((c) => c.padLeft(10)).join()}\n',
      );
      for (final m in Mbti.playerCases) {
        final reach = {
          for (final c in chars) c: [0, 0],
        };
        for (var seed = 1; seed <= kMbtiRouteSeeds; seed++) {
          final t = chars[seed % chars.length];
          final run = _simulate(bundle, FocusStrategy(t), seed, pref, mbti: m);
          reach[t]![1]++;
          if (run.index.containsKey('${t}_r15')) reach[t]![0]++;
          for (final (later, earlier) in prereq) {
            final li = run.index[later];
            if (li == null) continue;
            final eis = earlier
                .split('|')
                .map((x) => run.index[x])
                .whereType<int>();
            final ei = eis.isEmpty ? null : eis.reduce(min);
            if (ei == null || ei > li) {
              final k = '${m ?? '모름'} $later ← $earlier';
              violations[k] = (violations[k] ?? 0) + 1;
            }
          }
        }
        table.writeln(
          (m ?? '모름').padRight(6) +
              chars.map((c) {
                final v = reach[c]!;
                return (v[1] == 0 ? '-' : (v[0] / v[1]).toStringAsFixed(2))
                    .padLeft(10);
              }).join(),
        );
        for (final c in chars) {
          if (reach[c]![1] > 0 && reach[c]![0] == 0) {
            dead.add('${m ?? '모름'} $c');
          }
        }
      }
      print(table);
      Directory('tool/sim_out').createSync(recursive: true);
      File('tool/sim_out/route_order_mbti_$pref.txt')
          .writeAsStringSync(table.toString());
      expect(violations, isEmpty, reason: '선후 위반: $violations');
      expect(dead, isEmpty, reason: 'focus 로 r15 에 한 번도 못 닿음: $dead');
    }, timeout: const Timeout(Duration(minutes: 15)));
  }
}
