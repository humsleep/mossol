import 'package:flutter/material.dart';

import '../engine/models.dart';
import '../engine/story_repository.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'widgets.dart';

/// 새 게임의 선호 선택. "누구를 만나고 싶나요?" 에 여성 캐릭터 / 남성 캐릭터 두 장.
///
/// 규격: docs/DESIGN_SYSTEM.md §2.9. 홈의 `새 게임`(세이브가 있으면 지우기 확인 뒤)에서
/// 열리고, 카드를 누르면 확인 없이 그 값으로 닫힌다([show] 가 고른 값을 돌려준다).
/// 뒤로 가면 null — 새 게임을 시작하지 않는다.
///
/// 캐릭터 데이터가 한쪽에 아직 없으면 그 카드는 `준비 중` 으로 비활성이다. 캐스트가 3+3 이든
/// 6+6 이든 characters.json 만 보고 그린다.
class PreferenceScreen extends StatelessWidget {
  final StoryBundle bundle;

  /// 고른 값을 받는 곳. 기본은 `Navigator.pop(context, 값)`.
  final ValueChanged<String>? onPicked;

  const PreferenceScreen({super.key, required this.bundle, this.onPicked});

  static const title = '누구를 만나고 싶나요?';
  static const note = '나중에 새 게임에서 바꿀 수 있어요';

  /// 화면을 띄우고 고른 선호([Preference.female] | [Preference.male])를 돌려준다.
  static Future<String?> show(BuildContext context, StoryBundle bundle) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => PreferenceScreen(bundle: bundle)),
      );

  /// 카드의 아바타 줄. characters.json 순, 히든은 맨 뒤 실루엣.
  static List<CastEntry> castOf(StoryBundle bundle, String gender) {
    final side = bundle.characters.where((c) => c.gender == gender);
    return [
      for (final c in side)
        if (!c.hidden) CastEntry(id: c.id, name: c.name),
      for (final c in side)
        if (c.hidden) CastEntry(id: c.id, name: c.name, mystery: true),
    ];
  }

  /// 한 줄 소개. 히든이 아닌 사람들의 역할 이름(역할 순서).
  static String introOf(StoryBundle bundle, String gender) {
    final roles = {
      for (final c in bundle.characters)
        if (c.gender == gender && !c.hidden) c.role,
    };
    return [
      for (final r in CastRole.values)
        if (roles.contains(r)) CastRole.label(r),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    void pick(String pref) {
      final cb = onPicked;
      if (cb != null) {
        cb(pref);
      } else {
        Navigator.of(context).pop(pref);
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      // 제목은 본문 헤드라인이 맡는다. AppBar 는 뒤로 가기만.
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screenX,
            AppSpace.xs,
            AppSpace.screenX,
            AppSpace.xxl,
          ),
          children: [
            Text(keepAll(title), style: context.text.headlineMedium),
            const SizedBox(height: AppSpace.sectionGap),
            for (final (i, g) in Preference.genders.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpace.gap),
              Builder(
                builder: (context) {
                  final cast = castOf(bundle, g);
                  return PreferenceCard(
                    key: Key('preference-$g'),
                    title: Preference.label(g),
                    intro: introOf(bundle, g),
                    cast: cast,
                    onTap: cast.isEmpty ? null : () => pick(g),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xxs),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(keepAll(note), style: context.text.bodySmall),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
