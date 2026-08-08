import 'package:firebase_auth/firebase_auth.dart';

/// ⚠️ 개발용 — Firebase Auth 연동이 막혀 있는 동안 쓰는 임시 사용자
///
/// 로그인이 안 되면 uid 가 null 이라 Firestore 읽기/쓰기가 전부 무시된다.
/// 그래서 로그인 상태가 아니면 아래 고정 uid 를 대신 사용해 화면을 확인할 수 있게 한다.
///
/// 배포 전 [enabled] 를 false 로 바꾸거나 이 파일을 삭제할 것.
/// 위치 권장: lib/core/dev/dev_user.dart
class DevUser {
  /// false 로 바꾸면 실제 로그인 사용자만 사용 (운영 동작)
  static const bool enabled = false;

  /// 로그인 없이 사용할 고정 uid
  static const String uid = 'dev_user';

  /// 실제 로그인 uid 가 있으면 그것을, 없으면 개발용 uid 를 돌려준다.
  static String? resolve() {
    final real = FirebaseAuth.instance.currentUser?.uid;
    if (real != null) return real;
    return enabled ? uid : null;
  }

  /// 표시 이름 (로그인 정보가 없을 때 대비)
  static String get displayName =>
      FirebaseAuth.instance.currentUser?.displayName ?? '플로거';

  static String get email => FirebaseAuth.instance.currentUser?.email ?? '';
}
