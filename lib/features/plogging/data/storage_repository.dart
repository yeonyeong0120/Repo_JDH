import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageRepository {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환
  /// 경로: users/{uid}/plogging_images/{timestamp}.{ext}
  static Future<String?> uploadImage(
    File imageFile, {
    String folder = 'plogging_images',
  }) async {
    try {
      if (!await imageFile.exists()) {
        print('[Storage] 에러: 파일이 존재하지 않습니다 - ${imageFile.path}');
        return null;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('[Storage] 에러: 로그인된 사용자가 없습니다 - 업로드 불가');
        return null;
      }

      final String timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();
      final String extension =
          imageFile.path.split('.').last.toLowerCase();
      final String fileName = '$timestamp.$extension';
      final String filePath = 'users/$uid/$folder/$fileName';

      print('[Storage] 업로드 시작: $filePath');

      final Reference ref = _storage.ref().child(filePath);

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
        customMetadata: {
          'uploaded_at': DateTime.now().toIso8601String(),
          'user_id': uid,
          'app': 'plogging_app',
        },
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);

      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final double progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('[Storage] 진행률: ${progress.toStringAsFixed(1)}%');
        },
        onError: (error) {
          print('[Storage] 진행률 에러: $error');
        },
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('[Storage] 업로드 완료 ✅');
      print('[Storage] URL: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      print('[Storage] Firebase 에러 코드: ${e.code}');
      print('[Storage] Firebase 에러 메시지: ${e.message}');
      return null;
    } catch (e, stackTrace) {
      print('[Storage] 일반 에러: $e');
      print('[Storage] 스택: $stackTrace');
      return null;
    }
  }

  /// URL로부터 이미지 삭제
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('[Storage] 삭제 완료: $imageUrl');
      return true;
    } on FirebaseException catch (e) {
      print('[Storage] 삭제 Firebase 에러: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('[Storage] 삭제 에러: $e');
      return false;
    }
  }
}