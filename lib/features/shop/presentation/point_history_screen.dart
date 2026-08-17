import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/shop/domain/point_log.dart';
import 'package:repo_jdh/features/shop/data/point_history_service.dart';

/// SHOP-05 포인트 내역 (이번 달 요약 + 전체/적립/사용 필터 + 날짜별 리스트)
/// 위치 권장: lib/features/shop/presentation/point_history_screen.dart
class PointHistoryScreen extends StatefulWidget {
  const PointHistoryScreen({super.key});

  @override
  State<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen> {
  List<PointLog> _logs = [];
  bool _loading = true;
  int _filter = 0; // 0 전체 / 1 적립 / 2 사용

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PointLog> list = [];
    try {
      list = await PointHistoryService.recent();
    } catch (_) {
      // 실패 시 빈 목록
    }
    if (!mounted) return;
    setState(() {
      _logs = list;
      _loading = false;
    });
  }

  // 이번 달 적립·사용 합계
  int get _monthEarned {
    final now = DateTime.now();
    return _logs
        .where(
          (l) =>
              l.amount > 0 && l.at.year == now.year && l.at.month == now.month,
        )
        .fold(0, (s, l) => s + l.amount);
  }

  int get _monthUsed {
    final now = DateTime.now();
    return _logs
        .where(
          (l) =>
              l.amount < 0 && l.at.year == now.year && l.at.month == now.month,
        )
        .fold(0, (s, l) => s + l.amount);
  }

  List<PointLog> get _visible {
    if (_filter == 1) return _logs.where((l) => l.amount >= 0).toList();
    if (_filter == 2) return _logs.where((l) => l.amount < 0).toList();
    return _logs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _summaryCard(),
                        const SizedBox(height: 18),
                        _filterChips(),
                        const SizedBox(height: 8),
                        ..._buildGroupedList(),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text(
                            '최근 3개월 내역만 보여드려요',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(TablerIcons.chevronLeft, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '포인트 내역',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 이번 달 적립 / 사용 요약 ──
  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCol(
              '이번 달 적립',
              _monthEarned,
              AppColors.actionPrimary,
              AppColors.textBrandOnLight,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          const SizedBox(width: 20),
          Expanded(
            child: _summaryCol(
              '이번 달 사용',
              _monthUsed,
              AppColors.neutral400,
              AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(String label, int value, Color dot, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: _fmt(value),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            children: const [
              TextSpan(
                text: ' P',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 전체 / 적립 / 사용 필터 ──
  Widget _filterChips() {
    const labels = ['전체', '적립', '사용'];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _filter = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _filter == i
                      ? AppColors.actionPrimary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _filter == i
                        ? AppColors.actionPrimary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _filter == i ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── 날짜별 그룹 리스트 ──
  List<Widget> _buildGroupedList() {
    final items = _visible;
    if (items.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 40),
          alignment: Alignment.center,
          child: const Text(
            '내역이 없어요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    String? lastKey;
    for (final log in items) {
      final key = _dayKey(log.at);
      if (key != lastKey) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: lastKey == null ? 8 : 20, bottom: 10),
            child: Text(
              _dayLabel(log.at),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
        lastKey = key;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _logCard(log),
        ),
      );
    }
    return widgets;
  }

  Widget _logCard(PointLog log) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _kindIcon(log.kind),
              size: 22,
              color: AppColors.textBrandOnLight,
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
                    fontSize: 15,
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
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_fmt(log.amount)} P',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: log.isEarned
                  ? AppColors.textBrandOnLight
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(PointLogKind k) => switch (k) {
    PointLogKind.plogging => TablerIcons.walk,
    PointLogKind.exchange => TablerIcons.coffee,
    PointLogKind.quest => TablerIcons.trophy,
  };

  // 오늘이면 '오늘', 아니면 'M월 D일'
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '오늘';
    }
    return '${d.month}월 ${d.day}일';
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

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
