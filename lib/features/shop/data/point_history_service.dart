import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/domain/point_log.dart';

/// 포인트 내역 파생 서비스
/// 별도 포인트 원장이 없어, 완료된 플로깅 활동(+적립)과 쿠폰 교환(-사용)을 합쳐
/// 최근 3개월 내역으로 만든다.
/// TODO: 포인트 증감이 잦아지면 users/{uid}/pointLogs 원장을 두고 여기서 읽도록 전환
class PointHistoryService {
  static Future<List<PointLog>> recent() async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - 3, now.day);
    final logs = <PointLog>[];

    // 적립 — 완료된 플로깅 활동
    try {
      final acts = await ActivityService.getRecentCompleted(limit: 100);
      for (final a in acts) {
        final at = a.endedAt ?? a.startedAt;
        if (at.isBefore(since) || a.pointsEarned <= 0) continue;
        final km = (a.distanceMeters / 1000).toStringAsFixed(1);
        logs.add(
          PointLog(
            kind: PointLogKind.plogging,
            title: '플로깅 활동 완료',
            subtitle: '${km}km · ${a.totalTrash}개 수거',
            amount: a.pointsEarned,
            at: at,
          ),
        );
      }
    } catch (_) {
      // 실패 시 적립 내역 생략
    }

    // 사용 — 쿠폰 교환 (차감액은 카탈로그 가격으로 산출)
    try {
      final coupons = await ShopService.myCoupons();
      for (final c in coupons) {
        if (c.createdAt.isBefore(since)) continue;
        logs.add(
          PointLog(
            kind: PointLogKind.exchange,
            title: '${c.name} 교환',
            subtitle: '${c.brand} · 쿠폰함에 담김',
            amount: -_priceOf(c.itemId),
            at: c.createdAt,
          ),
        );
      }
    } catch (_) {
      // 실패 시 사용 내역 생략
    }

    logs.sort((a, b) => b.at.compareTo(a.at));
    return logs;
  }

  static int _priceOf(String itemId) {
    for (final it in ShopService.catalog) {
      if (it.id == itemId) return it.price;
    }
    return 0;
  }
}
