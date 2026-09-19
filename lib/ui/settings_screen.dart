import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../app_meta.dart';
import '../engine/models.dart';
import '../game_controller.dart';
import 'design_system.dart';
import 'keep_all.dart';
import 'onboarding_gender_screen.dart';
import 'widgets.dart';

/// 설정. 규격은 docs/HOME_REDESIGN.md §2.
///
/// 게임 장면이 아니라 목록이다. 행은 전부 [AppListRow], 아이콘은 원형 배경 없이
/// 22 크기 한 종류. 파괴적인 행(초기화)만 [AppTone.danger] 로 제목·아이콘 색을 바꾼다.
class SettingsScreen extends StatefulWidget {
  final GameController c;
  const SettingsScreen({super.key, required this.c});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GameController get c => widget.c;

  /// UMP 가 개인정보 옵션을 요구하는 지역인지. 한 번만 묻는다.
  late final Future<bool> _privacyRequired =
      AdManager.instance.privacyOptionsRequired;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screenX,
          AppSpace.screenY,
          AppSpace.screenX,
          AppSpace.xxl,
        ),
        children: [
          const SectionHeader(title: '게임'),
          ListenableBuilder(
            listenable: c,
            builder: (context, _) => AppListRow(
              key: const Key('settings-gender'),
              title: '내 성별',
              subtitle: '새 게임에서 먼저 소개할 캐릭터가 정해져요',
              leading: const Icon(Icons.person_outline, size: 22),
              trailing: Text(
                PlayerGender.label(c.playerGender),
                style: context.text.labelMedium,
              ),
              onTap: () => _pickGender(context),
            ),
          ),
          const SizedBox(height: AppSpace.sectionGap),
          const SectionHeader(title: '개인정보'),
          FutureBuilder<bool>(
            future: _privacyRequired,
            builder: (context, snap) => snap.data == true
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.listGap),
                    child: AppListRow(
                      title: '개인정보 설정',
                      subtitle: '광고 개인 맞춤 동의를 바꿉니다',
                      leading: const Icon(Icons.shield_outlined, size: 22),
                      onTap: AdManager.instance.showPrivacyOptions,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          AppListRow(
            title: '개인정보처리방침',
            subtitle: '외부 브라우저에서 열립니다',
            leading: const Icon(Icons.policy_outlined, size: 22),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openPrivacyPolicy(context),
          ),
          const SizedBox(height: AppSpace.sectionGap),
          const SectionHeader(title: '정보'),
          AppListRow(
            title: '오픈소스 라이선스',
            subtitle: '사용한 라이브러리와 서체의 라이선스',
            leading: const Icon(Icons.description_outlined, size: 22),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '모쏠 키우기',
              applicationVersion: AppMeta.versionLabel,
            ),
          ),
          const SizedBox(height: AppSpace.listGap),
          AppListRow(
            title: '서체',
            subtitle: 'Pretendard · SIL Open Font License 1.1',
            leading: const Icon(Icons.text_fields, size: 22),
            trailing: Text('OFL', style: context.text.labelMedium),
            showChevron: false,
          ),
          const SizedBox(height: AppSpace.listGap),
          AppListRow(
            title: '앱 버전',
            leading: const Icon(Icons.info_outline, size: 22),
            trailing: Text(
              AppMeta.versionLabel,
              style: context.tokens.numericSmall,
            ),
            showChevron: false,
          ),
          const SizedBox(height: AppSpace.sectionGap),
          const SectionHeader(title: '데이터'),
          AppListRow(
            title: '저장 데이터 초기화',
            subtitle: '회차 · 하트 · 출석 · 엔딩 앨범 · 내 성별이 모두 지워집니다',
            leading: const Icon(Icons.delete_outline, size: 22),
            tone: AppTone.danger,
            onTap: () => _confirmReset(context),
          ),
          const SizedBox(height: AppSpace.xxl),
          Text(
            '© 2026 모쏠 키우기',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: const BannerSlot(),
    );
  }

  /// "내 성별" 고르기. 온보딩 1단계와 같은 세 가지. 기기 메타에만 저장한다.
  Future<void> _pickGender(BuildContext context) async {
    final current = c.playerGender;
    final picked = await showAppDialog<String>(
      context,
      builder: (ctx) => SimpleDialog(
        title: const Text('내 성별'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              0,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(
              keepAll(OnboardingGenderScreen.note),
              style: ctx.text.bodySmall?.copyWith(
                color: ctx.scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final (g, icon, label, hint) in OnboardingGenderScreen.options)
            ListTile(
              key: Key('settings-gender-$g'),
              leading: Icon(icon),
              title: Text(label),
              subtitle: Text(keepAll(hint)),
              trailing: g == current ? const Icon(Icons.check) : null,
              selected: g == current,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xxl,
              ),
              onTap: () => Navigator.pop(ctx, g),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await c.setPlayerGender(picked);
  }

  /// 외부 브라우저로. 못 열면 주소를 복사할 수 있게 보여 준다.
  Future<void> _openPrivacyPolicy(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(AppLinks.privacyPolicy),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    await showAppDialog<void>(
      context,
      builder: (ctx) => AlertDialog(
        title: const Text('링크를 열 수 없어요'),
        content: const SelectableText(AppLinks.privacyPolicy),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 되돌릴 수 없는 일이라 한 번 묻는다. 취소·뒤로가기·바깥 탭은 전부 취소.
  Future<void> _confirmReset(BuildContext context) async {
    final n = c.endingAlbum.length;
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장 데이터를 지울까요?'),
        content: Text(
          '진행 중인 회차, 하트, 출석 기록, 엔딩 앨범($n개)과 흑역사가 모두 지워집니다. '
          '되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            // DS §5.7 예외 ③: 파괴적 확인 버튼 한 곳.
            style: FilledButton.styleFrom(
              backgroundColor: ctx.scheme.error,
              foregroundColor: ctx.scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // 설정 화면이 닫힌 뒤에도 스낵바를 띄워야 하므로 메신저를 먼저 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    await c.resetAllData();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('저장 데이터를 지웠어요')));
  }
}
