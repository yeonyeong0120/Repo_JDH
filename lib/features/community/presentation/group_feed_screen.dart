//플로깅 활동 정산
import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 그룹 세부 화면 (활동 공유 피드)
/// 채팅 기능 없음. 멤버들의 플로깅 결과를 보고 '좋아요'만 누름.
/// 위치 권장: lib/features/community/presentation/group_feed_screen.dart
class GroupFeedScreen extends StatefulWidget {
  final String groupName;
  final int memberCount;

  const GroupFeedScreen({
    super.key,
    this.groupName = '00동 같이 주워봐요',
    this.memberCount = 12,
  });

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  // 피드 데이터 (placeholder — 실제 그룹 활동 공유로 교체)
  final List<_FeedItem> _items = [
    _FeedItem('김연영', '2시간 전', '2.1 km', 33, '00:42', likes: 5, liked: true),
    _FeedItem('박서연', '5시간 전', '1.4 km', 18, '00:31', likes: 3),
    _FeedItem('이준호', '어제', '3.0 km', 41, '00:58', likes: 8),
  ];

  void _toggleLike(int i) {
    setState(() {
      final it = _items[i];
      it.liked = !it.liked;
      it.likes += it.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryPale,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _feedCard(_items[i], i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 상단 바 ─────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.cardBG,
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '멤버 ${widget.memberCount}명',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.menu, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 공유 카드 ─────────────────────────
  Widget _feedCard(_FeedItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 + 시간
          Row(
            children: [
              // TODO: 실제 프로필 이미지로 교체
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryPale,
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 플로깅 결과 요약
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _resultStat('거리', item.distance),
                _divider(),
                _resultStat('수거', '${item.trash}개'),
                _divider(),
                _resultStat('시간', item.duration),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 좋아요 버튼 (오른쪽 하단)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _toggleLike(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: item.liked
                      ? AppColors.error.withValues(alpha: 0.10)
                      : AppColors.appBG,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.liked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: item.liked
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.likes}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.liked
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.primaryLight.withValues(alpha: 0.5),
    );
  }
}

class _FeedItem {
  final String name;
  final String time;
  final String distance;
  final int trash;
  final String duration;
  int likes;
  bool liked;
  _FeedItem(
    this.name,
    this.time,
    this.distance,
    this.trash,
    this.duration, {
    this.likes = 0,
    this.liked = false,
  });
}
