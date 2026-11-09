import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../core/device_identity.dart';
import '../core/firebase_bootstrap.dart';
import '../core/supabase_auth_callback.dart';
import '../core/supabase_config.dart';
import '../models/pending_email_verification.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/offline_profile_store.dart';
import '../services/firestore_user_service.dart';
import '../services/scan_record_repository.dart';
import '../services/supabase_auth_service.dart';
import '../services/windows_auth_rest_service.dart';

/// Holds the active auth session, profile, and async auth operations for the app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    FirestoreUserService? firestoreUserService,
    WindowsAuthRestService? windowsAuthRestService,
    SupabaseAuthService? supabaseAuthService,
    DeviceSecretSource? deviceSecretSource,
    OfflineProfileStore? offlineProfileStore,
    // Tests only: forces the Supabase code path without --dart-define.
    bool? useSupabaseForTesting,
  })  : _authOverride = authService,
        _usersOverride = firestoreUserService,
        _windowsAuth = windowsAuthRestService ?? WindowsAuthRestService(),
        _supabaseOverride = supabaseAuthService,
        _deviceSecrets = deviceSecretSource ?? const DeviceIdentity(),
        _offlineProfiles = offlineProfileStore ?? const OfflineProfileStore(),
        _useSupabaseOverride = useSupabaseForTesting {
    if (usesSupabase) {
      _startSupabase();
      return;
    }
    if (deferFirebaseUntilFirstUse) {
      return;
    }
    _authSub = _authService.authStateChanges().listen(_onAuthStateChanged);
  }

  final AuthService? _authOverride;
  final FirestoreUserService? _usersOverride;
  final WindowsAuthRestService _windowsAuth;
  final SupabaseAuthService? _supabaseOverride;
  final DeviceSecretSource _deviceSecrets;
  final OfflineProfileStore _offlineProfiles;
  bool _usingOfflineProfile = false;
  bool get usingOfflineProfile => _usingOfflineProfile;
  final bool? _useSupabaseOverride;

  AuthService? _auth;
  FirestoreUserService? _users;

  AuthService get _authService => _authOverride ?? (_auth ??= AuthService());
  FirestoreUserService get _userService =>
      _usersOverride ?? (_users ??= FirestoreUserService());
  SupabaseAuthService get _supabaseAuthService =>
      _supabaseOverride ?? (_supabaseAuth ??= SupabaseAuthService());

  StreamSubscription<User?>? _authSub;
  StreamSubscription<supabase.AuthState>? _supabaseSub;
  StreamSubscription<SupabaseConfirmationNotice>? _confirmationSub;
  WindowsAuthSession? _windowsSession;
  SupabaseAuthService? _supabaseAuth;
  supabase.Session? _supabaseSession;
  int _supabaseProfileGeneration = 0;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _loadingProfile = false;
  bool _busy = false;
  String? _lastError;
  MultiFactorResolver? _pendingMfaResolver;
  bool _signupRequiresEmailConfirmation = false;
  SupabaseConfirmationNotice? _signupConfirmationNotice;
  PendingEmailVerification? _pendingEmailVerification;
  // Held in memory only while a first sign-in waits for its email code, so
  // the password proof can be completed after the code. Never persisted.
  String? _pendingFirstLoginPassword;
  // True while sign-in / code verification drives session changes itself.
  bool _supabaseFlowActive = false;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get usesSupabase => _useSupabaseOverride ?? SupabaseConfig.isConfigured;

  bool get effectiveIsAdmin {
    final m = userModel;
    if (m == null) return false;
    if (m.isAdmin) return true;
    if (usesSupabase || kReleaseMode) return false;
    const override = String.fromEnvironment('ADMIN_EMAIL', defaultValue: '');
    if (override.isEmpty) return false;
    return m.email.trim().toLowerCase() == override.trim().toLowerCase();
  }

  bool get effectiveIsExpert {
    final m = userModel;
    if (m == null) return false;
    return m.isExpert;
  }

  bool get isAuthenticated => usesSupabase
      ? _supabaseSession != null
      : deferFirebaseUntilFirstUse
          ? _windowsSession != null
          : _firebaseUser != null;

  bool get isLoadingProfile => _loadingProfile;
  bool get isBusy => _busy;
  String? get lastError => _lastError;
  bool get requiresTotpCode => _pendingMfaResolver != null;
  bool get signupRequiresEmailConfirmation => _signupRequiresEmailConfirmation;
  SupabaseConfirmationNotice? get signupConfirmationNotice =>
      _signupConfirmationNotice;

  /// Non-null while the app is waiting for an email code (first sign-in or
  /// new device).
  PendingEmailVerification? get pendingEmailVerification =>
      _pendingEmailVerification;
  bool get supportsTotpMfa => !usesSupabase && !deferFirebaseUntilFirstUse;

  void _startSupabase() {
    _signupConfirmationNotice = SupabaseAuthCallback.latest;
    _confirmationSub = SupabaseAuthCallback.notices.listen((notice) {
      _signupConfirmationNotice = notice;
      notifyListeners();
    });
    _supabaseSession = _supabaseAuthService.currentSession;
    _supabaseSub = _supabaseAuthService.authStateChanges().listen((state) {
      if (_supabaseFlowActive) return;
      if (_pendingEmailVerification != null && state.session != null) return;
      final session = state.event == supabase.AuthChangeEvent.signedOut
          ? null
          : _supabaseAuthService.currentSession ?? state.session;
      unawaited(
        _applySupabaseSession(
          session,
          allowOffline: true,
          completeConfirmedSignup: _isConfirmationSession(session),
        ),
      );
    }, onError: (Object error, StackTrace _) {
      // Callback errors can contain one-time URL data. Keep them out of logs.
      SupabaseAuthCallback.markFailure(AuthService.messageFor(error));
    });
    final initial = _supabaseSession;
    if (initial != null) {
      unawaited(
        _applySupabaseSession(
          initial,
          allowOffline: true,
          completeConfirmedSignup: _isConfirmationSession(initial),
        ),
      );
    }
  }

  bool _isConfirmationSession(supabase.Session? session) =>
      SupabaseAuthCallback.latest?.phase ==
          SupabaseConfirmationPhase.processing &&
      session?.user.emailConfirmedAt != null;

  Future<void> _applySupabaseSession(
    supabase.Session? session, {
    bool completeConfirmedSignup = false,
    bool deviceAlreadyTrusted = false,
    bool allowOffline = false,
  }) async {
    final generation = ++_supabaseProfileGeneration;
    _supabaseSession = session;
    _usingOfflineProfile = false;
    _firebaseUser = null;
    _windowsSession = null;
    ScanRecordRepository.setWindowsIdToken(null);
    if (session == null) {
      await _clearOfflineProfile();
      if (generation != _supabaseProfileGeneration) return;
      _userModel = null;
      _loadingProfile = false;
      notifyListeners();
      return;
    }

    _loadingProfile = true;
    _lastError = null;
    notifyListeners();
    try {
      if (!deviceAlreadyTrusted) {
        // A restored or refreshed session must still come from a trusted
        // device. The server refuses data otherwise, so sign out cleanly and
        // let the person sign in again to receive a verification code.
        final trust = await _registerThisDevice();
        if (generation != _supabaseProfileGeneration) return;
        if (trust != SupabaseAuthService.deviceTrusted) {
          await _clearOfflineProfile();
          _userModel = null;
          _supabaseSession = null;
          _lastError =
              'For your security, sign in again to verify this device.';
          if (completeConfirmedSignup) {
            // An older confirmation link verified the email; finish its banner.
            SupabaseAuthCallback.markConfirmed();
          }
          _supabaseFlowActive = true;
          try {
            await _supabaseAuthService.signOut();
          } catch (_) {
            // The local session is cleared below regardless.
          } finally {
            _supabaseFlowActive = false;
          }
          return;
        }
      }
      if (completeConfirmedSignup) {
        try {
          await _supabaseAuthService.completeSignupProfile();
          SupabaseAuthCallback.markConfirmed();
        } catch (error, stack) {
          debugPrint(
            'AuthProvider: confirmation profile completion failed: '
            '$error\n$stack',
          );
          SupabaseAuthCallback.markFailure(
            'Your email was confirmed, but profile completion could not finish. '
            '${AuthService.messageFor(error)}',
          );
        }
      }
      final profile = await _supabaseAuthService.loadProfile(session.user);
      if (generation != _supabaseProfileGeneration) return;
      if (!profile.isActive) {
        await _clearOfflineProfile();
        _userModel = null;
        _lastError =
            'This account has been disabled. Contact the Administrator.';
      } else {
        _userModel = profile;
        try {
          await _offlineProfiles.save(
              profile, await _deviceSecrets.readOrCreate());
        } catch (_) {
          // A storage failure must not prevent a valid online login.
        }
      }
    } catch (error) {
      if (generation != _supabaseProfileGeneration) return;
      final connectionFailure = OfflineProfileStore.isConnectionFailure(error);
      UserModel? cached;
      if (allowOffline && connectionFailure && !completeConfirmedSignup) {
        try {
          cached = await _offlineProfiles.restore(
              session.user.id, await _deviceSecrets.readOrCreate());
        } catch (_) {}
      }
      if (generation != _supabaseProfileGeneration) return;
      if (!connectionFailure) await _clearOfflineProfile();
      _userModel = cached;
      _usingOfflineProfile = cached != null;
      _lastError = cached != null
          ? null
          : connectionFailure
              ? 'You are offline. Connect once to load and save your profile on this device, then you can reopen the app offline.'
              : 'Your profile could not be loaded. Reconnect and retry.';
    } finally {
      if (generation == _supabaseProfileGeneration) {
        _loadingProfile = false;
        notifyListeners();
      }
    }
  }

  Future<void> _clearOfflineProfile() async {
    try {
      await _offlineProfiles.clear();
    } catch (_) {}
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _lastError = null;
    ScanRecordRepository.setWindowsIdToken(null);

    if (user == null) {
      _userModel = null;
      _loadingProfile = false;
      notifyListeners();
      return;
    }

    _loadingProfile = true;
    notifyListeners();

    try {
      _userModel = await _userService.getUser(user.uid);
      _lastError = null;
    } catch (e, st) {
      debugPrint('AuthProvider: failed to load profile: $e\n$st');
      _lastError = 'Could not load your profile. ${_hintFirestoreRules()}';
      _userModel = null;
    }

    _loadingProfile = false;
    notifyListeners();
  }

  Future<void> _applyWindowsSession(WindowsAuthSession session) async {
    _windowsSession = session;
    _firebaseUser = null;
    _lastError = null;
    ScanRecordRepository.setWindowsIdToken(session.idToken);
    _loadingProfile = true;
    notifyListeners();

    try {
      _userModel = await _windowsAuth.fetchUserProfile(
        uid: session.uid,
        idToken: session.idToken,
      );
      _lastError = null;
    } catch (e, st) {
      debugPrint(
          'AuthProvider: failed to load profile (Windows REST): $e\n$st');
      _lastError = 'Could not load your profile. ${_hintFirestoreRules()}';
      _userModel = null;
    }

    _loadingProfile = false;
    notifyListeners();
  }

  String _hintFirestoreRules() {
    return 'Check your connection and Firestore security rules.';
  }

  Future<void> refreshProfile() async {
    if (usesSupabase) {
      final session = _supabaseSession;
      if (session == null) return;
      await _applySupabaseSession(session, allowOffline: true);
      return;
    }
    if (deferFirebaseUntilFirstUse) {
      final session = _windowsSession;
      if (session == null) return;
      _loadingProfile = true;
      notifyListeners();
      try {
        _userModel = await _windowsAuth.fetchUserProfile(
          uid: session.uid,
          idToken: session.idToken,
        );
        _lastError = null;
      } catch (e) {
        _lastError = e.toString();
      }
      _loadingProfile = false;
      notifyListeners();
      return;
    }

    final uid = _firebaseUser?.uid;
    if (uid == null) return;
    _loadingProfile = true;
    notifyListeners();
    try {
      _userModel = await _userService.getUser(uid);
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    }
    _loadingProfile = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String role,
    required String organization,
    required String assignedArea,
  }) async {
    final uid = _userModel?.uid ??
        _supabaseSession?.user.id ??
        _firebaseUser?.uid ??
        _windowsSession?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }

    _setBusy(true);
    _lastError = null;
    _signupRequiresEmailConfirmation = false;
    try {
      if (usesSupabase) {
        await _supabaseAuthService.updateProfile(
          fullName: fullName,
          phoneNumber: phoneNumber,
          positionRole: role,
          organization: organization,
        );
        await refreshProfile();
        return;
      }
      if (deferFirebaseUntilFirstUse) {
        final session = _windowsSession;
        if (session == null) {
          throw StateError('Not signed in.');
        }
        await _windowsAuth.updateUserProfile(
          uid: uid,
          idToken: session.idToken,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
          organization: organization,
          assignedArea: assignedArea,
        );
      } else {
        await _userService.updateUserProfile(
          uid: uid,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
          organization: organization,
          assignedArea: assignedArea,
        );
      }
      await refreshProfile();
    } on WindowsAuthRestException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setBusy(true);
    _lastError = null;
    try {
      if (usesSupabase) {
        await _supabaseAuthService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        return;
      }
      if (deferFirebaseUntilFirstUse) {
        final session = _windowsSession;
        final email = _userModel?.email ?? session?.email;
        if (session == null || email == null || email.isEmpty) {
          throw StateError('Not signed in.');
        }
        await _windowsAuth.changePassword(
          email: email,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      } else {
        await _authService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }
    } on WindowsAuthRestException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String positionRole,
    String? organization,
    required String password,
  }) async {
    _setBusy(true);
    _lastError = null;

    if (usesSupabase) {
      try {
        final response = await _supabaseAuthService.signUp(
          fullName: fullName,
          email: email,
          phoneNumber: phoneNumber,
          positionRole: positionRole,
          organization: organization ?? '',
          password: password,
        );
        _signupRequiresEmailConfirmation = response.session == null;
        if (response.session != null) {
          await _applySupabaseSession(response.session);
        }
      } catch (error) {
        _lastError = AuthService.messageFor(error);
        rethrow;
      } finally {
        _setBusy(false);
      }
      return;
    }

    if (deferFirebaseUntilFirstUse) {
      try {
        final session = await _windowsAuth.signUp(
          email: email,
          password: password,
        );
        final model = UserModel(
          uid: session.uid,
          fullName: fullName.trim(),
          email: email.trim(),
          phoneNumber: phoneNumber.trim(),
          role: positionRole.trim(),
          accountRole: UserModel.defaultAccountRole,
          organization: organization?.trim() ?? '',
          assignedArea: '',
          createdAt: null,
          profileImage: '',
          isActive: true,
        );
        await _windowsAuth.createUserProfile(
          model: model,
          idToken: session.idToken,
        );
        await _applyWindowsSession(session);
      } on WindowsAuthRestException catch (e) {
        _lastError = e.message;
        rethrow;
      } catch (e) {
        _lastError = e.toString();
        rethrow;
      } finally {
        _setBusy(false);
      }
      return;
    }

    UserCredential? cred;
    try {
      cred = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final model = UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        role: positionRole.trim(),
        accountRole: UserModel.defaultAccountRole,
        organization: organization?.trim() ?? '',
        assignedArea: '',
        createdAt: null,
        profileImage: '',
        isActive: true,
      );
      await _userService.createUserProfile(model);
    } catch (e) {
      if (cred?.user != null) {
        try {
          await _authService.deleteCurrentUser();
        } catch (_) {}
      }
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> resendSignupConfirmation(String email) async {
    if (!usesSupabase) {
      throw UnsupportedError(
        'Signup confirmation resend is available with Supabase Auth.',
      );
    }
    _setBusy(true);
    _lastError = null;
    try {
      await _supabaseAuthService.resendSignupConfirmation(email);
    } catch (error) {
      _lastError = AuthService.messageFor(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    _lastError = null;

    if (usesSupabase) {
      _supabaseFlowActive = true;
      _pendingEmailVerification = null;
      _pendingFirstLoginPassword = null;
      try {
        final response = await _passwordSignInOrFirstLogin(email, password);
        if (response == null) return; // First sign-in: code screen is shown.
        final session = response.session;
        if (session == null) {
          throw StateError('Sign-in did not return a session.');
        }
        final trust = await _registerThisDevice();
        if (trust != SupabaseAuthService.deviceTrusted) {
          // Correct password on an unknown device: email a one-time code.
          _supabaseSession = session;
          _userModel = null;
          _pendingEmailVerification = PendingEmailVerification(
            email: email.trim(),
            reason: EmailVerificationReason.newDevice,
          );
          await _sendPendingCode();
          return;
        }
        await _applySupabaseSession(session, deviceAlreadyTrusted: true);
        if (_userModel == null) {
          throw StateError(_lastError ?? 'Profile unavailable.');
        }
      } catch (error) {
        _lastError ??= AuthService.messageFor(error);
        rethrow;
      } finally {
        _supabaseFlowActive = false;
        _setBusy(false);
      }
      return;
    }

    if (deferFirebaseUntilFirstUse) {
      try {
        final session = await _windowsAuth.signIn(
          email: email,
          password: password,
        );
        await _applyWindowsSession(session);
      } on WindowsAuthRestException catch (e) {
        _lastError = e.message;
        rethrow;
      } catch (e) {
        _lastError = e.toString();
        rethrow;
      } finally {
        _setBusy(false);
      }
      return;
    }

    try {
      _pendingMfaResolver = null;
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      final hasTotp =
          error.resolver.hints.any((hint) => hint is TotpMultiFactorInfo);
      if (!hasTotp) {
        _lastError = 'This account requires an unsupported second factor.';
        rethrow;
      }
      _pendingMfaResolver = error.resolver;
      _lastError = 'Enter the 6-digit code from your authenticator app.';
      rethrow;
    } catch (e) {
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> completeTotpSignIn(String code) async {
    final resolver = _pendingMfaResolver;
    if (resolver == null) throw StateError('No two-factor sign-in is pending.');
    final normalized = code.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw const FormatException('Enter the 6-digit authenticator code.');
    }
    _setBusy(true);
    _lastError = null;
    try {
      final hint = resolver.hints.whereType<TotpMultiFactorInfo>().first;
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        hint.uid,
        normalized,
      );
      await resolver.resolveSignIn(assertion);
      _pendingMfaResolver = null;
    } catch (error) {
      _lastError = AuthService.messageFor(error);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void cancelTotpSignIn() {
    _pendingMfaResolver = null;
    _lastError = null;
    notifyListeners();
  }

  Future<bool> isTotpEnabled() {
    if (!supportsTotpMfa) return Future<bool>.value(false);
    return _authService.isTotpEnabled();
  }

  Future<TotpEnrollment> beginTotpEnrollment() {
    if (!supportsTotpMfa) {
      throw UnsupportedError(
        'Authenticator two-factor authentication requires the Firebase Android, iOS, macOS, or web build.',
      );
    }
    return _authService.beginTotpEnrollment(
      accountName: _userModel?.email ?? _firebaseUser?.email ?? 'COTS account',
    );
  }

  Future<void> confirmTotpEnrollment(
    TotpEnrollment enrollment,
    String code,
  ) {
    return _authService.confirmTotpEnrollment(
      enrollment: enrollment,
      code: code.replaceAll(RegExp(r'\s+'), ''),
    );
  }

  Future<void> disableTotp() {
    if (!supportsTotpMfa) {
      throw UnsupportedError('Two-factor authentication is unavailable.');
    }
    return _authService.disableTotp();
  }

  /// Verifies the code from the email and, when the device is then trusted,
  /// loads the account. Throws with [lastError] set on failure.
  Future<void> verifyEmailCode(String code) async {
    final pending = _pendingEmailVerification;
    if (pending == null) {
      throw StateError('No email verification is pending.');
    }
    if (!SupabaseAuthService.isValidCode(code)) {
      _lastError = 'Enter the code from your email (numbers only).';
      notifyListeners();
      throw FormatException(_lastError!);
    }
    _setBusy(true);
    _lastError = null;
    _supabaseFlowActive = true;
    try {
      var trust = SupabaseAuthService.deviceVerificationRequired;
      if (pending.reason == EmailVerificationReason.firstLogin) {
        await _supabaseAuthService.verifySignupCode(
          email: pending.email,
          code: code,
        );
        trust = await _registerThisDevice();
        if (trust != SupabaseAuthService.deviceTrusted) {
          final password = _pendingFirstLoginPassword;
          if (password == null) {
            throw StateError(
              'Your email is verified. Sign in again to finish verifying this device.',
            );
          }
          await _supabaseAuthService.signIn(
            email: pending.email,
            password: password,
          );
          trust = await _registerThisDevice();
        }
      } else {
        await _supabaseAuthService.verifyLoginCode(
          email: pending.email,
          code: code,
        );
        trust = await _registerThisDevice();
      }
      if (trust != SupabaseAuthService.deviceTrusted) {
        throw StateError(_deviceNotVerifiedMessage());
      }
      if (pending.reason == EmailVerificationReason.firstLogin) {
        try {
          await _supabaseAuthService.completeSignupProfile();
        } catch (error, stack) {
          // Profile fields can still be edited later; do not block sign-in.
          debugPrint('AuthProvider: profile completion failed: $error\n$stack');
        }
      }
      _pendingEmailVerification = null;
      _pendingFirstLoginPassword = null;
      await _applySupabaseSession(
        _supabaseAuthService.currentSession,
        deviceAlreadyTrusted: true,
      );
    } catch (error) {
      _lastError = error is StateError
          ? error.message.toString()
          : AuthService.messageFor(error);
      rethrow;
    } finally {
      _supabaseFlowActive = false;
      _setBusy(false);
    }
  }

  /// Emails a new code. Never throws; check [lastError].
  Future<void> resendEmailCode() async {
    final pending = _pendingEmailVerification;
    if (pending == null) return;
    if (pending.secondsUntilResend(DateTime.now()) > 0) return;
    _setBusy(true);
    try {
      await _sendPendingCode();
    } finally {
      _setBusy(false);
    }
  }

  /// Abandons the email-code step and signs out any partial session.
  Future<void> cancelEmailVerification() async {
    _pendingEmailVerification = null;
    _pendingFirstLoginPassword = null;
    _lastError = null;
    _supabaseFlowActive = true;
    try {
      if (_supabaseAuthService.currentSession != null) {
        await _supabaseAuthService.signOut();
      }
    } catch (_) {
      // Local state is cleared below regardless.
    } finally {
      _supabaseFlowActive = false;
    }
    _supabaseSession = null;
    _userModel = null;
    notifyListeners();
  }

  /// Returns null when the email has never been verified; the first-login
  /// code step is then pending.
  Future<supabase.AuthResponse?> _passwordSignInOrFirstLogin(
    String email,
    String password,
  ) async {
    try {
      return await _supabaseAuthService.signIn(
        email: email,
        password: password,
      );
    } on supabase.AuthException catch (error) {
      if (!SupabaseAuthService.isEmailNotConfirmed(error)) rethrow;
      // The code from the signup email verifies the email on first sign-in.
      _pendingFirstLoginPassword = password;
      _pendingEmailVerification = PendingEmailVerification(
        email: email.trim(),
        reason: EmailVerificationReason.firstLogin,
      );
      return null;
    }
  }

  Future<String> _registerThisDevice() async {
    final secret = await _deviceSecrets.readOrCreate();
    return _supabaseAuthService.registerDevice(secret);
  }

  Future<void> _sendPendingCode() async {
    final pending = _pendingEmailVerification;
    if (pending == null) return;
    try {
      if (pending.reason == EmailVerificationReason.firstLogin) {
        await _supabaseAuthService.resendSignupConfirmation(pending.email);
      } else {
        await _supabaseAuthService.sendLoginCode(pending.email);
      }
      if (identical(_pendingEmailVerification, pending)) {
        _pendingEmailVerification = pending.withCodeSentAt(DateTime.now());
      }
      _lastError = null;
    } catch (error) {
      _lastError = AuthService.messageFor(error);
    }
    notifyListeners();
  }

  String _deviceNotVerifiedMessage() {
    final methods = SupabaseAuthService.sessionMethods(
      _supabaseAuthService.currentSession,
    );
    final detail =
        methods.isEmpty ? '' : ' (sign-in methods: ${methods.join(', ')})';
    return 'This device could not be verified. Sign in again and enter the '
        'newest code within 10 minutes.$detail';
  }

  Future<void> signOut() async {
    _pendingEmailVerification = null;
    _pendingFirstLoginPassword = null;
    if (!isAuthenticated) return;
    _setBusy(true);
    try {
      if (usesSupabase) {
        await _clearOfflineProfile();
        await _supabaseAuthService.signOut();
        _supabaseSession = null;
        _userModel = null;
        notifyListeners();
        return;
      }
      if (deferFirebaseUntilFirstUse) {
        ScanRecordRepository.setWindowsIdToken(null);
        _windowsSession = null;
        _userModel = null;
        notifyListeners();
        return;
      }
      await _authService.signOut();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _setBusy(true);
    _lastError = null;
    try {
      if (usesSupabase) {
        throw StateError(
          'Password recovery is supervised by the Administrator. '
          'No recovery email is sent.',
        );
      }
      if (deferFirebaseUntilFirstUse) {
        await _windowsAuth.sendPasswordResetEmail(email);
        return;
      }
      await _authService.sendPasswordResetEmail(email);
    } on WindowsAuthRestException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void clearLastError() {
    _lastError = null;
    notifyListeners();
  }

  void clearSignupConfirmationNotice() {
    SupabaseAuthCallback.clear();
    _signupConfirmationNotice = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _supabaseSub?.cancel();
    _confirmationSub?.cancel();
    super.dispose();
  }
}
