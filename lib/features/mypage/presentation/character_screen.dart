import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/badge_dialog.dart';

/// 줍댕이 꾸미기 화면
/// 뱃지 획득 시 얻은 아이템으로 캐릭터를 꾸민다.
/// TODO: 캐릭터/아이템 아트 완성되면 이모지·아이콘 → Image.asset 으로 교체
/// 위치 권장: lib/features/mypage/presentation/character_screen.dart
class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  ItemSlot _slot = ItemSlot.hat;

  // 부위별 착용 중인 아이템 (뱃지 id). null 이면 미착용
  // TODO: Firestore users/{uid}/character 에 저장/복원
  final Map<ItemSlot, String?> _equipped = {
    ItemSlot.hat: null,
    ItemSlot.face: null,
    ItemSlot.body: null,
    ItemSlot.hand: null,
  };

  List<BadgeData> get _itemsOfSlot =>
      kBadges.where((b) => b.slot == _slot).toList();

  void _tapItem(BadgeData b) {
    if (!BadgeRepo.isEarned(b.id)) {
      // 미획득 → 획득조건 안내 (상세 모달 재사용)
      showBadgeDetail(context, b);
      return;
    }
    setState(() {
      final already = _equipped[b.slot] == b.id;
      _equipped[b.slot] = already ? null : b.id;
    });
    final on = _equipped[b.slot] == b.id;
    AppSnackBar.show(context, on ? '${b.reward} 착용했어요' : '${b.reward} 벗었어요');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '줍댕이 꾸미기',
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                children: [
                  _preview(),
                  const SizedBox(height: 20),
                  _slotTabs(),
                  const SizedBox(height: 16),
                  _itemGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 캐릭터 미리보기 ──
  Widget _preview() {
    final worn = _equipped.entries
        .where((e) => e.value != null)
        .map((e) => BadgeRepo.byId(e.value!))
        .toList();

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // TODO: 줍댕이(물개) 2D 캐릭터 이미지로 교체
          const Text('🦭', style: TextStyle(fontSize: 120)),
          // 착용 아이템 (임시 표시 — 실제 아트에서는 캐릭터 위에 레이어로 합성)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: worn.isEmpty
                ? const Text(
                    '아이템을 골라 꾸며보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  )
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in worn)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBG,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(b.icon, size: 14, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text(
                                b.reward,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── 부위 탭 (모자/얼굴/몸/손) ──
  Widget _slotTabs() {
    return Row(
      children: [
        for (final s in ItemSlot.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _slot = s),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _slot == s ? AppColors.primary : AppColors.cardBG,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _slot == s ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _slot == s ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (s != ItemSlot.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  // ── 아이템 그리드 ──
  Widget _itemGrid() {
    final items = _itemsOfSlot;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: [for (final b in items) _itemTile(b)],
    );
  }

  Widget _itemTile(BadgeData b) {
    final owned = BadgeRepo.isEarned(b.id);
    final on = _equipped[b.slot] == b.id;
    return GestureDetector(
      onTap: () => _tapItem(b),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: owned ? AppColors.cardBG : AppColors.divider,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.cardBorder,
                    width: on ? 2 : 1,
                  ),
                ),
                // TODO: 실제 2D 아이템 이미지로 교체
                child: Icon(
                  owned ? b.icon : Icons.lock_outline,
                  size: 28,
                  color: owned ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            owned ? b.reward : '???',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: owned ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
