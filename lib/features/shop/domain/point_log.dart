/// 포인트 적립·사용 내역 한 건
/// 별도 원장(ledger) 없이 완료된 플로깅 활동(+적립)과 쿠폰 교환(-사용)에서 파생한다.
enum PointLogKind { plogging, exchange, quest }

class PointLog {
  final PointLogKind kind;
  final String title;
  final String subtitle;
  final int amount; // 양수=적립 / 음수=사용
  final DateTime at;

  const PointLog({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.at,
  });

  bool get isEarned => amount >= 0;
}
