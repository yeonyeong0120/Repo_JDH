import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 오픈소스 및 아이콘 출처 (메뉴 → 저작권 표기)
/// 무료 아이콘·폰트는 대부분 "출처 표기(attribution)"가 사용 조건이라
/// 앱 안에 이 화면을 두고 표기해야 합니다.
///
/// TODO: 실제 사용한 아이콘의 제작자명·출처를 아래 목록에 맞춰 채워주세요.
///       Flaticon 기준 표기 형식: "Icon made by {제작자} from www.flaticon.com"
/// 위치 권장: lib/features/settings/presentation/licenses_screen.dart
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  // ── 아이콘 출처 ──
  // TODO: 제작자명(author)을 실제 다운로드한 페이지 기준으로 교체
  static const List<_Credit> _icons = [
    _Credit('플라스틱 아이콘', 'TODO: 제작자명', 'Flaticon'),
    _Credit('캔 아이콘', 'TODO: 제작자명', 'Flaticon'),
    _Credit('종이 아이콘', 'TODO: 제작자명', 'Flaticon'),
    _Credit('유리병 아이콘', 'TODO: 제작자명', 'Flaticon'),
    _Credit('일반쓰레기 아이콘', 'TODO: 제작자명', 'Flaticon'),
  ];

  // ── 폰트 ──
  static const List<_Credit> _fonts = [
    _Credit('Pretendard', 'Kil Hyung-jin', 'SIL Open Font License 1.1'),
    _Credit('휴먼범석네오', 'TODO: 제공처 확인', 'TODO: 라이선스 확인'),
  ];

  // ── 지도·서비스 ──
  static const List<_Credit> _services = [
    _Credit('네이버 지도', 'NAVER Corp.', '네이버 지도 API 이용약관'),
    _Credit('Firebase', 'Google LLC', 'Google API 서비스 약관'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '오픈소스 및 출처',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const Text(
                    '플로고는 아래 리소스를 사용하고 있으며, 제작자분들께 감사드립니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section('아이콘', _icons),
                  const SizedBox(height: 16),
                  _section('폰트', _fonts),
                  const SizedBox(height: 16),
                  _section('지도 및 서비스', _services),
                  const SizedBox(height: 16),
                  // Flutter 내장 라이선스 화면 (패키지 오픈소스 전체)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: '플로고',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 Ploggo',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '오픈소스 라이선스 전체 보기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            TablerIcons.chevronRight,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<_Credit> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (int i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == items.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: AppColors.border,
                          width: 0.8,
                        ),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[i].name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${items[i].author} · ${items[i].source}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Credit {
  final String name;
  final String author;
  final String source;
  const _Credit(this.name, this.author, this.source);
}
