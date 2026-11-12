import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class TotpEnrollment {
  const TotpEnrollment({
    required this.secret,
    required this.qrCodeUrl,
  });

  final TotpSecret secret;
  final String qrCodeUrl;

  String get secretKey => secret.secretKey;
}

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

  Future<bool> isTotpEnabled() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.any((factor) => factor is TotpMultiFactorInfo);
  }

  Future<TotpEnrollment> beginTotpEnrollment({
    required String accountName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    if (!user.emailVerified) {
      throw StateError(
        'Verify your email address before enabling two-factor authentication.',
      );
    }
    final session = await user.multiFactor.getSession();
    final secret = await TotpMultiFactorGenerator.generateSecret(session);
    final qrCodeUrl = await secret.generateQrCodeUrl(
      accountName: accountName,
      issuer: 'COTS Monitor',
    );
    return TotpEnrollment(secret: secret, qrCodeUrl: qrCodeUrl);
  }

  Future<void> confirmTotpEnrollment({
    required TotpEnrollment enrollment,
    required String code,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      enrollment.secret,
      code,
    );
    await user.multiFactor.enroll(
      assertion,
      displayName: 'Authenticator app',
    );
  }

  Future<void> disableTotp() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    final factors = await user.multiFactor.getEnrolledFactors();
    for (final factor in factors) {
      if (factor is TotpMultiFactorInfo) {
        await user.multiFactor.unenroll(factorUid: factor.uid);
        return;
      }
    }
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
    if (error is supabase.AuthException) {
      switch (error.code) {
        case 'user_already_exists':
        case 'email_exists':
          return 'This email is already registered. Try signing in instead.';
        case 'weak_password':
          return 'Password is too weak. Use at least 8 characters with a mix of characters.';
        case 'email_not_confirmed':
          return 'Enter the code we emailed you to verify your email.';
        case 'otp_expired':
        case 'flow_state_expired':
          return 'This code is incorrect or has expired. Check the newest email or send a new code.';
        case 'flow_state_not_found':
        case 'bad_code_verifier':
        case 'validation_failed':
          return 'This code is invalid or was already used. Send a new code and try again.';
        case 'request_timeout':
        case 'network_error':
          return 'Network error. Check your connection and try again.';
        case 'invalid_credentials':
          return 'Incorrect email or password.';
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return 'Too many attempts. Try again later.';
        case 'signup_disabled':
        case 'email_provider_disabled':
          return 'Account registration is currently unavailable. Contact the Administrator.';
      }
      return 'Authentication could not be completed. Try again or contact the Administrator.';
    }
    if (error is supabase.PostgrestException) {
      if (error.message.contains('Expert required')) {
        return 'Only the Expert account can record review decisions.';
      }
      if (error.message.contains('review-band COTS')) {
        return 'Review every uncertain COTS (20–84%) first. COTS below 20% '
            'can only be rejected.';
      }
      if (error.message.contains('Invalid capture decision')) {
        return 'This detection can no longer be reviewed. Reload and try again.';
      }
      if (error.message.contains('device_verification_required')) {
        return 'Verify this device with the code sent to your email. Sign in again to receive a code.';
      }
      if (error.code == '42501') {
        return 'You are not authorized to perform this action.';
      }
      return 'Could not access account data. Check your connection and try again.';
    }
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
    if (error is StateError) return error.message;
    return error.toString();
  }
}
