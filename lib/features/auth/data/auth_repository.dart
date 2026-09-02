import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';

class AuthRepository {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('[Auth] 회원가입 성공: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      print('[Auth] 회원가입 실패: ${e.code}');
      return _getKoreanErrorMessage(e.code);
    } catch (e) {
      print('[Auth] 회원가입 일반 에러: $e');
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('[Auth] 로그인 성공: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      print('[Auth] 로그인 실패: ${e.code}');
      return _getKoreanErrorMessage(e.code);
    } catch (e) {
      print('[Auth] 로그인 일반 에러: $e');
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('[Auth] Google signOut 스킵: $e');
    }
    await _auth.signOut();
    BadgeRepo.clear();
    print('[Auth] 로그아웃 완료');
  }

  static Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('[Auth] Google 로그인 취소됨');
        return '로그인이 취소되었습니다.';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      print('[Auth] Google 로그인 성공: ${googleUser.email}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('[Auth] Google 로그인 Firebase 에러: ${e.code}');
      return _getKoreanErrorMessage(e.code);
    } catch (e) {
      print('[Auth] Google 로그인 일반 에러: $e');
      return 'Google 로그인에 실패했습니다.';
    }
  }

  static Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('[Auth] 비밀번호 재설정 이메일 전송: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      return _getKoreanErrorMessage(e.code);
    } catch (e) {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  static String _getKoreanErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다.';
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. (6자 이상)';
      case 'operation-not-allowed':
        return '이메일/비밀번호 로그인이 비활성화되어 있습니다.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'too-many-requests':
        return '잠시 후 다시 시도해주세요.';
      case 'account-exists-with-different-credential':
        return '다른 로그인 방식으로 이미 가입된 계정입니다.';
      default:
        return '오류가 발생했습니다: $code';
    }
  }
}