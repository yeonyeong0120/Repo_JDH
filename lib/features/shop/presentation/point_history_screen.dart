import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/shop/domain/point_log.dart';
import 'package:repo_jdh/features/shop/data/point_history_service.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';

/// SHOP-05 포인트 내역 (Startline 목업 구조)
/// 적립/차감 한 줄 리스트. 아이콘 타일 + 라벨/날짜 + 금액(차감은 accent #E4573D).
/// 위치 권장: lib/features/shop/presentation/point_history_screen.dart
class PointHistoryScreen extends StatefulWidget {
  const PointHistoryScreen({super.key});

  @override
  State<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen> {
  List<PointLog> _logs = [];
  int _points = 0; // 상단 우측 현재 보유 포인트
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PointLog> list = [];
    int points = 0;
    try {
      list = await PointHistoryService.recent();
    } catch (_) {
      // 실패 시 빈 목록
    }
    try {
      points = await ShopService.myPoints();
    } catch (_) {
      // 실패 시 0
    }
    if (!mounted) return;
    setState(() {
      _logs = list;
      _points = points;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.actionPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '내역이 없어요',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => _logRow(_logs[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.chevronLeft,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '포인트 내역',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 우측 현재 보유 포인트 (목업 상단 우측 1,240P)
          Text(
            _loading ? '' : '${_fmtPlain(_points)}P',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 내역 한 줄 (아이콘 타일 + 라벨/날짜 + 금액) ──
  Widget _logRow(PointLog log) {
    final earned = log.isEarned;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
      ),
      child: Row(
        children: [
          // 적립=라임 틴트 / 차감=소프트 그레이
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: earned
                  ? AppColors.tint(AppColors.lime, 0.28)
                  : AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _kindIcon(log.kind),
              size: 19,
              color: earned ? AppColors.ink : AppColors.gray700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  log.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(log.amount)}P',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              // 차감은 accent(#E4573D), 적립은 잉크
              color: earned ? AppColors.ink : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(PointLogKind k) => switch (k) {
    PointLogKind.plogging => TablerIcons.run,
    PointLogKind.exchange => TablerIcons.gift,
    PointLogKind.quest => TablerIcons.award,
  };

  // 천단위 콤마만 (상단 보유 포인트 표기용)
  String _fmtPlain(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // 부호 + 천단위 콤마 (예: +2,490 / -4,500)
  String _fmt(int v) {
    final sign = v >= 0 ? '+' : '-';
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign$buf';
  }
}
