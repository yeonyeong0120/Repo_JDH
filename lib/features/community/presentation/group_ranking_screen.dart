import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';

/// 주간 랭킹 전체보기 — 그룹 상세의 '전체보기' 링크로 진입.
/// 그룹 상세 랭킹과 동일한 로우 스타일로 전체 순위를 보여준다.
///
/// ⚠️ 랭킹 집계 소스가 아직 없어 placeholder 값이다. (TODO) 서버 집계 연결.
class GroupRankingScreen extends StatelessWidget {
  final String groupName;
  const GroupRankingScreen({super.key, required this.groupName});

  static const Color _charcoal = Color(0xFF3A403C);
  static const Color _track = Color(0xFFEDEFEE);
  static const Color _hairline = Color(0xFFF1F3F2);
  static const Color _rowLime = Color(0xFFF7FBE4);
  static const Color _crown = Color(0xFFE9C21A);

  static const List<({int rank, String name, double kg, bool me})> _ranking = [
    (rank: 1, name: '민서', kg: 5.2, me: false),
    (rank: 2, name: '지호 (나)', kg: 3.7, me: true),
    (rank: 3, name: '준호', kg: 3.1, me: false),
    (rank: 4, name: '유진', kg: 2.4, me: false),
    (rank: 5, name: '서준', kg: 2.1, me: false),
    (rank: 6, name: '하윤', kg: 1.8, me: false),
    (rank: 7, name: '도현', kg: 1.5, me: false),
    (rank: 8, name: '지우', kg: 1.2, me: false),
    (rank: 9, name: '수아', kg: 0.9, me: false),
    (rank: 10, name: '민준', kg: 0.6, me: false),
  ];

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(TablerIcons.chevronLeft,
                          size: 27, color: AppColors.ink),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '주간 랭킹',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray500,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: _ranking.length,
                itemBuilder: (context, i) {
                  final r = _ranking[i];
                  return _rankRow(r.rank, r.name, r.kg,
                      top: r.rank == 1, me: r.me, showDivider: r.rank != 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(int rank, String name, double kg,
      {bool top = false, bool me = false, bool showDivider = false}) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1);
    final double avatar = top ? 56 : 38;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: top ? 16 : 13),
      decoration: BoxDecoration(
        color: top ? _rowLime : Colors.transparent,
        borderRadius: top ? BorderRadius.circular(18) : BorderRadius.zero,
        border: showDivider
            ? const Border(top: BorderSide(color: _hairline, width: 1))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (top) ...[
                  const Icon(TablerIcons.crownFilled, size: 17, color: _crown),
                  const SizedBox(height: 1),
                ],
                Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: top ? 26 : (rank == 2 ? 16 : 15),
                        fontWeight: FontWeight.w800,
                        color: rank <= 2 ? AppColors.ink : AppColors.gray500)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: top ? AppColors.lime : _track, shape: BoxShape.circle),
            child: Text(initial,
                style: TextStyle(
                    fontSize: top ? 21 : 14,
                    fontWeight: FontWeight.w700,
                    color: top
                        ? AppColors.ink
                        : (rank == 2 ? AppColors.ink : AppColors.gray700))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: top ? 20 : 15.5,
                    fontWeight: (top || me) ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.ink)),
          ),
          Text('${_fmt(kg)}kg',
              style: TextStyle(
                  fontSize: top ? 20 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}
