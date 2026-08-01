import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// 인증샷 촬영 · 선택 · 업로드 담당
///
/// Storage 경로: activity_photos/{uid}/{timestamp}.jpg
///
/// 사진은 용량이 크므로 촬영 단계에서 미리 줄여 올린다.
/// (원본 그대로 올리면 업로드가 느리고 Storage 비용도 커진다)
class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  // 업로드 전 리사이즈 기준 — 피드 카드에 보이기 충분한 크기
  static const double _maxWidth = 1080;
  static const double _maxHeight = 1080;
  static const int _quality = 80; // JPEG 품질(0~100)

  /// 카메라로 촬영. 취소하면 null.
  static Future<XFile?> takePhoto() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        imageQuality: _quality,
      );
    } catch (e) {
      debugPrint('[사진] 촬영 실패: $e');
      return null;
    }
  }

  /// 갤러리에서 선택. 취소하면 null.
  static Future<XFile?> pickFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        imageQuality: _quality,
      );
    } catch (e) {
      debugPrint('[사진] 갤러리 선택 실패: $e');
      return null;
    }
  }

  /// Storage 에 업로드하고 다운로드 URL 반환. 실패하면 null.
  ///
  /// 실패해도 null 만 돌려주므로, 호출부는 "사진 없는 활동"으로 계속 진행하면 된다.
  static Future<String?> uploadActivityPhoto(XFile file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[사진] 업로드 취소 — 로그인 필요');
      return null;
    }

    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('activity_photos')
          .child(uid)
          .child(name);

      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();
      debugPrint('[사진] 업로드 완료');
      return url;
    } catch (e) {
      debugPrint('[사진] 업로드 실패: $e');
      return null; // 업로드 실패해도 흐름은 계속
    }
  }
}