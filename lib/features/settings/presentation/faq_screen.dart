import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/settings/presentation/inquiry_screen.dart';

/// 도움말 (메뉴 → 자주 묻는 질문) — Startline 목업 구조
/// 검색 박스(장식) + FAQ 리스트(인라인 펼침) + '해결되지 않았나요?' 문의 카드.
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
      '활동 중 앱을 닫으면 기록이 사라지나요?',
      '활동을 시작하면 진행 상황이 계속 저장되므로, 앱을 잠시 닫았다 다시 열어도 이어서 기록됩니다. '
          '다만 화면을 끄면 위치 수집이 중단될 수 있어 거리가 정확하지 않을 수 있으니 '
          '가능하면 앱을 켜둔 상태로 활동해주세요.',
    ),
    (
      '인증 사진은 왜 촬영만 가능한가요?',
      '실제 활동 중에 주운 쓰레기를 인증하기 위한 기능이라 그 자리에서 촬영한 사진만 사용할 수 있어요. '
          '앨범의 기존 사진은 등록할 수 없으며, 이는 기록의 신뢰도를 지키기 위한 정책입니다.',
    ),
    (
      '포인트는 언제 적립되나요?',
      '활동을 마치고 정산 화면을 거치면 포인트가 적립되고, 퀘스트를 달성하면 추가로 받습니다. '
          '모은 포인트는 메뉴 > 포인트 샵에서 상품으로 교환할 수 있어요.',
    ),
    (
      '그룹 리더를 넘길 수 있나요?',
      '리더는 그룹 관리 화면에서 다른 구성원에게 리더 권한을 넘길 수 있어요. '
          '권한을 넘기면 그룹 정보 수정과 구성원 관리 권한도 함께 이전됩니다.',
    ),
    (
      '수거량은 어떻게 계산되나요?',
      '활동 중 카메라로 촬영한 쓰레기를 AI가 종류별로 분류해 개수를 세고, '
          '종류별 평균 무게로 환산해 수거량을 계산합니다. 인증한 만큼 수거량 퀘스트가 올라가요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                children: [
                  _searchBox(),
                  const SizedBox(height: 20),
                  const Text(
                    '자주 묻는 질문',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (int i = 0; i < _faqs.length; i++) _item(i),
                  const SizedBox(height: 22),
                  _inquiryCard(),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          const SizedBox(width: 4),
          const Text(
            '도움말',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 장식용 검색 박스 (실제 검색은 미구현 — 시각 요소)
  Widget _searchBox() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(TablerIcons.search, size: 20, color: AppColors.gray500),
          SizedBox(width: 11),
          Text(
            '무엇이 궁금하세요?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.gray350,
            ),
          ),
        ],
      ),
    );
  }

  // FAQ 항목 한 줄 (질문 + 셰브론, 탭하면 답변 인라인 펼침)
  Widget _item(int i) {
    final open = _open == i;
    final (q, a) = _faqs[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = open ? null : i),
      child: Container(
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: open ? 0.5 : 0,
                  child: const Icon(
                    TablerIcons.chevronRight,
                    size: 19,
                    color: AppColors.gray300,
                  ),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 12),
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

  // '해결되지 않았나요?' 카드 → 1:1 문의
  Widget _inquiryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '해결되지 않았나요?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '평일 10시–18시, 보통 2시간 안에 답장해요',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InquiryScreen()),
            ),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(TablerIcons.messages, size: 20, color: AppColors.lime),
                  SizedBox(width: 9),
                  Text(
                    '1:1 문의하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
