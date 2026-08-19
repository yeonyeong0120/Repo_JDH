import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// 상점 카테고리
enum ShopCategory { eco, cafe, food, convenience, culture }

extension ShopCategoryX on ShopCategory {
  String get label => switch (this) {
    ShopCategory.eco => '에코 아이템',
    ShopCategory.cafe => '카페/디저트',
    ShopCategory.food => '외식/푸드',
    ShopCategory.convenience => '편의점/마트',
    ShopCategory.culture => '문화/상품권',
  };

  IconData get icon => switch (this) {
    ShopCategory.eco => TablerIcons.leaf,
    ShopCategory.cafe => TablerIcons.coffee,
    ShopCategory.food => TablerIcons.toolsKitchen2,
    ShopCategory.convenience => TablerIcons.buildingStore,
    ShopCategory.culture => TablerIcons.gift,
  };
}

/// 교환 가능한 상품
class ShopItem {
  final String id;
  final String brand; // '인천 에코'
  final String name; // '지구 지킴이 에코백'
  final int price; // 에코 포인트
  final ShopCategory category;
  final String? imageUrl;

  const ShopItem({
    required this.id,
    required this.brand,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
  });
}

/// 교환한 쿠폰
/// Firestore: users/{uid}/coupons/{couponId}
class Coupon {
  final String id;
  final String itemId;
  final String brand;
  final String name;
  final String? imageUrl;
  final String code; // 바코드 번호
  final DateTime expiresAt;
  final bool used;
  final DateTime createdAt;

  Coupon({
    required this.id,
    required this.itemId,
    required this.brand,
    required this.name,
    this.imageUrl,
    required this.code,
    required this.expiresAt,
    this.used = false,
    required this.createdAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);

  /// 미사용 = 사용 안 했고 기한도 남음
  bool get usable => !used && !expired;

  /// '2026.12.31 까지'
  String get expiresText =>
      '${expiresAt.year}.${expiresAt.month.toString().padLeft(2, '0')}'
      '.${expiresAt.day.toString().padLeft(2, '0')} 까지';

  String get statusText => used ? '사용 완료' : (expired ? '기간 만료' : '');

  factory Coupon.fromJson(Map<String, dynamic> json) {
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return Coupon(
      id: json['id'] as String,
      itemId: (json['itemId'] as String?) ?? '',
      brand: (json['brand'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      code: (json['code'] as String?) ?? '',
      expiresAt: toDate(json['expiresAt']),
      used: (json['used'] as bool?) ?? false,
      createdAt: toDate(json['createdAt']),
    );
  }
}
