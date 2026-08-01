import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/core/dev/dev_seed.dart'; // ⚠️ 개발용 — 배포 전 이 줄과 버튼 삭제
import 'group_detail_screen.dart';
import 'group_search_screen.dart';
import 'group_create_screen.dart';

/// 플로고 - 그룹 화면 (내 그룹 / 다른 동네 그룹)
/// 내 그룹 카드 탭 → 그룹 피드, 다른 그룹 탭 → 소개/가입 화면.
/// 위치 권장: lib/features/community/presentation/group_screen.dart
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  Group? _myGroup;
  List<Group> _others = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    Group? mine;
    List<Group> others = [];
    try {
      mine = await GroupService.myGroup();
      others = await GroupService.otherGroups();
    } catch (_) {
      // 네트워크/로그인 문제 → 빈 목록으로 표시
    }
    if (!mounted) return;
    setState(() {
      _myGroup = mine;
      _others = others;
      _loading = false;
    });
  }

  // ⚠️ 개발용 — 가짜 그룹 심기/지우기 (배포 전 삭제)
  Future<void> _runSeed({required bool seed}) async {
    try {
      final n = seed ? await DevSeed.seedGroups() : await DevSeed.clearGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${seed ? "심기" : "삭제"} $n건 완료')),
      );
      _load(); // 목록 갱신
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView(
                        // 하단 네비바 클리어런스
                        padding: EdgeInsets.fromLTRB(
                          20,
                          22,
                          20,
                          MediaQueryData.fromView(
                                View.of(context),
                              ).padding.bottom +
                              92,
                        ),
                        children: [
                          _sectionLabel('내 그룹'),
                          const SizedBox(height: 12),
                          if (_myGroup == null)
                            _emptyBox('아직 가입한 그룹이 없어요')
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _groupCard(
                                context,
                                _myGroup!,
                                isMine: true,
                              ),
                            ),
                          const SizedBox(height: 24),
                          _sectionLabel('다른 동네 그룹'),
                          const SizedBox(height: 12),
                          if (_others.isEmpty)
                            _emptyBox('아직 다른 그룹이 없어요')
                          else
                            ..._others.map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _groupCard(context, g, isMine: false),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '같이 쓰레기 줍고 포인트도 받아가자!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _iconButton(
                Icons.search,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupSearchScreen(alreadyInGroup: _myGroup != null),
                    ),
                  );
                  _load();
                },
              ),
              const SizedBox(width: 8),
              _iconButton(
                Icons.add,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GroupCreateScreen(alreadyInGroup: _myGroup != null),
                    ),
                  );
                  _load(); // 생성 후 목록 갱신
                },
              ),
              // ⚠️ 개발용 임시 버튼 — 가짜 그룹 심기/지우기
              //    배포 전 이 블록과 위 dev_seed import 를 삭제할 것
              const SizedBox(width: 8),
              _iconButton(
                Icons.science_outlined,
                onTap: () => _runSeed(seed: true),
              ),
              const SizedBox(width: 8),
              _iconButton(
                Icons.delete_outline,
                onTap: () => _runSeed(seed: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _groupCard(BuildContext context, Group g, {bool isMine = false}) {
    return GestureDetector(
      onTap: () async {
        if (isMine) {
          // 내 그룹 → 그룹 피드
          context.push('/group/feed', extra: {'id': g.id, 'name': g.name});
        } else {
          // 다른 동네 그룹 → 소개/가입 화면
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(
                groupId: g.id,
                name: g.name,
                region: g.region,
                meta: g.meta,
                alreadyInGroup: _myGroup != null,
              ),
            ),
          );
          _load(); // 가입했을 수 있으니 갱신
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // TODO: g.imageUrl 있으면 Image.network 로 교체
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    g.region,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.meta,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
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
}