import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/settings/presentation/inquiry_screen.dart';

/// 자주 묻는 질문 (메뉴 → FAQ)
/// 위치 권장: lib/features/settings/presentation/faq_screen.dart
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _open; // 펼쳐진 항목 (하나만 열림)

  // TODO: 운영하면서 실제 문의 많은 항목으로 보강
  static const List<(String q, String a)> _faqs = [
    (
      '플로깅이 뭔가요?',
      '조깅(walking)을 하면서 쓰레기를 줍는(plocka upp) 활동이에요. '
          '가볍게 걸으면서 눈에 띄는 쓰레기를 주우면 됩니다. '
          '무리하지 않고 산책하듯 즐기시면 돼요.',
    ),
    (
      '활동 기록은 어떻게 저장되나요?',
      '플로깅을 시작하면 시간과 이동 거리가 자동으로 기록되고, '
          '종료 후 정산 화면을 거치면 저장됩니다. '
          '기록은 내 활동 > 기록 탭에서 확인할 수 있어요.',
    ),
    (
      '쓰레기 인증은 어떻게 하나요?',
      '활동 중 카메라 버튼을 눌러 주운 쓰레기를 촬영하면, '
          'AI가 종류를 분류해 자동으로 개수를 세어줍니다. '
          '인증한 만큼 수거량 퀘스트가 올라가요.',
    ),
    (
      '에코 포인트는 어떻게 모으나요?',
      '활동을 마칠 때마다 포인트가 적립되고, 퀘스트를 달성하면 추가로 받습니다. '
          '모은 포인트는 메뉴 > 에코포인트 상점에서 상품으로 교환할 수 있어요.',
    ),
    (
      '뱃지는 어떻게 얻나요?',
      '퀘스트를 달성하면 그에 해당하는 뱃지와 줍댕이 꾸미기 아이템을 받습니다. '
          '내 활동 > 뱃지 탭에서 각 뱃지를 눌러 획득 조건을 확인할 수 있어요.',
    ),
    (
      '그룹은 여러 개 가입할 수 있나요?',
      '한 번에 하나의 그룹에만 속할 수 있어요. '
          '다른 그룹에 가입하려면 기존 그룹에서 먼저 탈퇴해주세요. '
          '탈퇴는 그룹 피드 화면에서 할 수 있습니다.',
    ),
    (
      '위치 권한은 왜 필요한가요?',
      '이동 거리를 계산하고 주변 정화 거점을 안내하기 위해 사용해요. '
          '활동 중에만 위치를 사용하며, 활동을 종료하면 수집하지 않습니다.',
    ),
    (
      '활동 중 화면을 꺼도 되나요?',
      '화면을 끄면 위치 수집이 중단될 수 있어 거리가 정확하지 않을 수 있어요. '
          '가능하면 앱을 켜둔 상태로 활동해주세요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          children: [
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
                    '자주 묻는 질문',
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
                  for (int i = 0; i < _faqs.length; i++) ...[
                    _item(i),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  _inquiryBox(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 원하는 답변이 없을 때 → 문의 및 신고
  Widget _inquiryBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            '찾는 답변이 없으신가요?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '이용 중 불편한 점이나 신고할 내용을 알려주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InquiryScreen()),
            ),
            child: Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '문의 및 신고하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int i) {
    final open = _open == i;
    final (q, a) = _faqs[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = open ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Q',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    q,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: open ? 0.5 : 0,
                  child: const Icon(
                    Icons.expand_more,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 14),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 14),
              Text(
                a,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
