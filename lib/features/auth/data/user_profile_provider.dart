import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/providers/auth_provider.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/auth/domain/user_profile.dart';

/// 현재 로그인 사용자의 Firestore 프로필을 비동기로 제공
///
/// - 로그인 상태가 바뀌면 자동으로 재평가
/// - 닉네임 저장 후 강제 갱신이 필요하면:
///     ref.invalidate(userProfileProvider);
///
/// 라우터 redirect 에서 닉네임 입력 화면 분기에 사용됨
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;
  return UserService.getCurrentProfile();
});