import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 이용 약관 및 정책 (메뉴 → 이용 약관 및 정책)
/// TODO: 아래 본문은 초안입니다. 서비스 오픈 전 법률 검토를 거쳐 확정해주세요.
///       특히 개인정보 수집 항목·보유 기간·제3자 제공은 실제 구현과 일치해야 합니다.
/// 위치 권장: lib/features/settings/presentation/terms_screen.dart
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  int _tab = 0; // 0 이용약관 / 1 개인정보 처리방침

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
                    '이용 약관 및 정책',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  _tabButton('이용약관', 0),
                  const SizedBox(width: 8),
                  _tabButton('개인정보 처리방침', 1),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBG,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Text(
                      _tab == 0 ? _terms : _privacy,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '시행일: 2026년 2월 1일',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _tabButton(String label, int index) {
    final on = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = index),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.cardBG,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: on ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  static const String _terms = '''제1조 (목적)
이 약관은 플로고(이하 "회사")가 제공하는 플로깅 활동 기록 및 커뮤니티 서비스(이하 "서비스")의 이용 조건과 절차, 회원과 회사의 권리·의무를 정하는 것을 목적으로 합니다.

제2조 (회원가입)
① 회원가입은 이메일과 비밀번호를 입력하거나 구글 계정으로 진행합니다.
② 성별·나이·키·몸무게·지역은 선택 입력 항목이며, 입력하지 않아도 서비스를 이용할 수 있습니다.

제3조 (서비스의 내용)
회사는 다음 서비스를 제공합니다.
1. 플로깅 활동 기록(시간·거리·수거량)
2. 수거 인증 및 활동 통계 제공
3. 퀘스트·뱃지 등 참여 보상
4. 에코 포인트 적립 및 상품 교환
5. 지역 기반 그룹 활동 및 활동 공유

제4조 (회원의 의무)
① 회원은 실제 활동에 근거하지 않은 기록을 등록해서는 안 됩니다.
② 타인의 사진이나 활동을 자신의 것으로 등록해서는 안 됩니다.
③ 부정한 방법으로 포인트를 적립한 경우 회사는 해당 포인트를 회수하고 이용을 제한할 수 있습니다.

제5조 (에코 포인트)
① 포인트는 활동 및 퀘스트 달성으로 적립됩니다.
② 포인트는 현금으로 환급되지 않으며, 상점에서 제공하는 상품 교환에만 사용할 수 있습니다.
③ 회원 탈퇴 시 보유 포인트는 소멸되며 복구되지 않습니다.

제6조 (게시물의 관리)
회원이 그룹에 공유한 사진과 활동 기록은 해당 그룹 구성원에게 공개됩니다. 타인의 권리를 침해하거나 서비스 목적에 맞지 않는 게시물은 사전 통지 없이 삭제될 수 있습니다.

제7조 (서비스의 중단)
회사는 시스템 점검, 천재지변 등 부득이한 사유가 있는 경우 서비스 제공을 일시적으로 중단할 수 있습니다.

제8조 (면책)
① 회사는 회원이 플로깅 활동 중 발생한 사고나 부상에 대해 책임을 지지 않습니다. 활동 시 교통안전과 위생에 유의해주세요.
② 회사는 기기의 GPS 정확도에 따른 기록 오차에 대해 책임을 지지 않습니다.

제9조 (약관의 변경)
회사는 필요한 경우 약관을 변경할 수 있으며, 변경 시 공지사항을 통해 사전에 안내합니다.''';

  static const String _privacy =
      '''플로고(이하 "회사")는 이용자의 개인정보를 중요하게 생각하며, 관련 법령을 준수합니다.

1. 수집하는 개인정보 항목
[필수] 이메일, 비밀번호(암호화 저장)
[선택] 닉네임, 성별, 나이, 키, 몸무게, 지역
[자동수집] 위치정보, 활동 기록(시간·거리·수거량), 기기 정보

2. 개인정보의 수집 및 이용 목적
· 회원 식별 및 로그인
· 활동 기록 저장 및 통계 제공
· 이동 거리 계산 및 주변 정화 거점 안내
· 칼로리 추정(키·몸무게 입력 시)
· 포인트 적립 및 상품 교환

3. 위치정보의 이용
위치정보는 플로깅 활동 중에만 수집하며, 활동을 종료하면 수집을 중단합니다. 수집된 경로 정보는 활동 기록 확인 용도로만 사용됩니다.

4. 개인정보의 보유 및 이용 기간
회원 탈퇴 시 지체 없이 파기합니다. 다만 관계 법령에 따라 보존할 필요가 있는 경우 해당 기간 동안 보관합니다.

5. 개인정보의 제3자 제공
회사는 이용자의 개인정보를 외부에 제공하지 않습니다. 다만 법령에 따른 요청이 있는 경우는 예외로 합니다.

6. 개인정보 처리 위탁
· Google Firebase: 회원 인증 및 데이터 보관
· Google Maps / Naver Maps: 지도 표시 및 위치 서비스

7. 이용자의 권리
이용자는 언제든지 메뉴 > 프로필에서 자신의 정보를 조회·수정할 수 있으며, 회원 탈퇴를 통해 개인정보 수집·이용 동의를 철회할 수 있습니다.

8. 개인정보 보호책임자
문의: (TODO: 담당자 이메일 기재)''';
}
