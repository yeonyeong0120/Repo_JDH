import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase 인증 상태를 실시간으로 감지하는 Provider
/// User가 있으면 로그인, null이면 로그아웃 상태
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});