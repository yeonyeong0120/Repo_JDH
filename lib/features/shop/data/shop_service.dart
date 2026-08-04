import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/core/dev/dev_user.dart';
import 'package:repo_jdh/core/dev/dev_data.dart';

/// 에코 포인트 상점
/// Firestore
///   users/{uid}.points            보유 포인트
///   users/{uid}/coupons/{id}      교환한 쿠폰
class ShopService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ⚠️ 이 파일 전용 더미 스위치.
  /// 상점은 실제 Firestore 연동이 완료되어 false 로 둔다.
  /// 다시 더미로 보고 싶으면 이 한 줄만 `DevData.enabled` 로 바꾸면 된다.
  static const bool _useDummy = false;

  static String? get _uid => DevUser.resolve();

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>>? _coupons() =>
      _userDoc()?.collection('coupons');

  // ───────────────────────── 상품 목록 ─────────────────────────

  /// TODO: Firestore products 컬렉션 또는 운영 도구로 옮기기
  ///       imageUrl 은 상품 이미지가 준비되면 채우기
  static const List<ShopItem> catalog = [
    ShopItem(
      id: 'eco_bag',
      brand: '인천 에코',
      name: '지구 지킴이 에코백',
      price: 3000,
      category: ShopCategory.eco,
    ),
    ShopItem(
      id: 'tongs',
      brand: '친환경 도구',
      name: '스테인리스 집게',
      price: 2500,
      category: ShopCategory.eco,
    ),
    ShopItem(
      id: 'bamboo_brush',
      brand: '녹색 생활',
      name: '대나무 칫솔 4입',
      price: 1200,
      category: ShopCategory.eco,
    ),
    ShopItem(
      id: 'eco_bags_roll',
      brand: '지구를 돌아가는',
      name: '생분해 쓰레기봉투',
      price: 800,
      category: ShopCategory.eco,
    ),
    ShopItem(
      id: 'americano',
      brand: '카페',
      name: '아메리카노 1잔',
      price: 4500,
      category: ShopCategory.cafe,
    ),
    ShopItem(
      id: 'cake',
      brand: '카페',
      name: '조각 케이크',
      price: 6000,
      category: ShopCategory.cafe,
    ),
    ShopItem(
      id: 'burger_set',
      brand: '패스트푸드',
      name: '버거 세트',
      price: 7000,
      category: ShopCategory.food,
    ),
    ShopItem(
      id: 'cvs_3000',
      brand: '편의점',
      name: '편의점 금액권 3,000원',
      price: 3000,
      category: ShopCategory.convenience,
    ),
    ShopItem(
      id: 'mart_5000',
      brand: '마트',
      name: '마트 금액권 5,000원',
      price: 5000,
      category: ShopCategory.convenience,
    ),
    ShopItem(
      id: 'culture_10000',
      brand: '문화상품권',
      name: '문화상품권 10,000원',
      price: 10000,
      category: ShopCategory.culture,
    ),
  ];

  static List<ShopItem> byCategory(ShopCategory c) =>
      catalog.where((i) => i.category == c).toList();

  // ───────────────────────── 포인트 ─────────────────────────

  static Future<int> myPoints() async {
    if (_useDummy) return DevData.profile.points;
    final doc = _userDoc();
    if (doc == null) return 0;
    final snap = await doc.get();
    return (snap.data()?['points'] as num?)?.toInt() ?? 0;
  }

  // ───────────────────────── 교환 ─────────────────────────

  /// 상품 교환 — 포인트 차감과 쿠폰 발급을 트랜잭션으로 함께 처리
  /// 포인트가 모자라면 예외
  static Future<void> exchange(ShopItem item) async {
    if (_useDummy) {
      if (DevData.profile.points < item.price) {
        throw Exception('포인트가 부족합니다');
      }
      DevData.exchange(item);
      return;
    }
    final userDoc = _userDoc();
    final coupons = _coupons();
    if (userDoc == null || coupons == null) {
      throw Exception('로그인이 필요합니다');
    }

    final couponRef = coupons.doc();
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userDoc);
      final points = (snap.data()?['points'] as num?)?.toInt() ?? 0;
      if (points < item.price) {
        throw Exception('포인트가 부족합니다');
      }

      tx.set(userDoc, {'points': points - item.price}, SetOptions(merge: true));

      tx.set(couponRef, {
        'itemId': item.id,
        'brand': item.brand,
        'name': item.name,
        'imageUrl': item.imageUrl,
        'code': _generateCode(),
        // 유효기간 1년
        'expiresAt': Timestamp.fromDate(
          DateTime(now.year + 1, now.month, now.day),
        ),
        'used': false,
        'createdAt': Timestamp.fromDate(now),
      });
    });
  }

  /// 바코드 번호 (12자리)
  /// TODO: 실제 제휴사 발급 번호로 교체
  static String _generateCode() {
    final r = Random();
    return List.generate(12, (_) => r.nextInt(10)).join();
  }

  // ───────────────────────── 쿠폰함 ─────────────────────────

  static Future<List<Coupon>> myCoupons() async {
    if (_useDummy) return DevData.coupons;
    final col = _coupons();
    if (col == null) return [];
    final snap = await col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return Coupon.fromJson(data);
    }).toList();
  }

  /// 사용 완료 처리 / 되돌리기 (실수 방지용으로 복구 가능)
  static Future<void> setUsed(String couponId, bool used) async {
    if (_useDummy) {
      DevData.setCouponUsed(couponId, used);
      return;
    }
    final col = _coupons();
    if (col == null) return;
    await col.doc(couponId).update({
      'used': used,
      'usedAt': used ? Timestamp.fromDate(DateTime.now()) : null,
    });
  }
}
