import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication wrapper — keeps UI free of SDK details.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Email + password registration.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Deletes the signed-in user (rollback after failed Firestore write).
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }

  /// Maps Firebase errors to UI-safe messages (Auth, Firestore, Storage).
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Try signing in instead.';
        case 'weak-password':
          return 'Password is too weak. Use at least 8 characters with a mix of characters.';
        case 'invalid-email':
          return 'That email address doesn\'t look valid.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'user-not-found':
          return 'No account found for that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'invalid-operation':
        case 'operation-not-allowed':
          return 'Email/password sign-in is turned off. Enable it in Firebase Console → Authentication → Sign-in method.';
        case 'configuration-not-found':
          return 'Firebase Auth is not fully set up for this project. '
              'In Firebase Console open Authentication and finish setup: enable Email/Password. '
              'In Google Cloud Console enable API "Identity Toolkit API". '
              'If your Web API key has restrictions, allow Identity Toolkit API (or remove key restrictions for testing).';
        default:
          final m = error.message;
          if (m != null && m.isNotEmpty && m.toLowerCase() != 'error') {
            return '$m (${error.code})';
          }
          return 'Authentication failed (${error.code}).';
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore blocked this write (permission denied). Deploy your Firestore rules: firebase deploy --only firestore:rules';
        case 'unavailable':
          return 'Firestore is temporarily unavailable. Try again in a moment.';
        case 'failed-precondition':
          return 'Firestore request failed (${error.message ?? error.code}).';
        default:
          return error.message?.isNotEmpty == true
              ? '${error.message} (${error.plugin}/${error.code})'
              : '${error.plugin}: ${error.code}';
      }
    }
    return error.toString();
  }
}
