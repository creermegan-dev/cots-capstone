import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase_bootstrap.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_user_service.dart';
import '../services/scan_record_repository.dart';
import '../services/windows_auth_rest_service.dart';

/// Holds auth session, Firestore profile, and async auth operations for the app.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    FirestoreUserService? firestoreUserService,
    WindowsAuthRestService? windowsAuthRestService,
  })  : _authOverride = authService,
        _usersOverride = firestoreUserService,
        _windowsAuth = windowsAuthRestService ?? WindowsAuthRestService() {
    if (deferFirebaseUntilFirstUse) {
      return;
    }
    _authSub = _authService.authStateChanges().listen(_onAuthStateChanged);
  }

  final AuthService? _authOverride;
  final FirestoreUserService? _usersOverride;
  final WindowsAuthRestService _windowsAuth;

  AuthService? _auth;
  FirestoreUserService? _users;

  AuthService get _authService => _authOverride ?? (_auth ??= AuthService());
  FirestoreUserService get _userService =>
      _usersOverride ?? (_users ??= FirestoreUserService());

  StreamSubscription<User?>? _authSub;
  WindowsAuthSession? _windowsSession;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _loadingProfile = false;
  bool _busy = false;
  String? _lastError;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;

  bool get effectiveIsAdmin {
    final m = userModel;
    if (m == null) return false;
    if (m.isAdmin) return true;
    if (kReleaseMode) return false;
    const override = String.fromEnvironment('ADMIN_EMAIL', defaultValue: '');
    if (override.isEmpty) return false;
    return m.email.trim().toLowerCase() == override.trim().toLowerCase();
  }

  bool get effectiveIsExpert {
    final m = userModel;
    if (m == null) return false;
    return m.isExpert;
  }

  bool get isAuthenticated =>
      deferFirebaseUntilFirstUse ? _windowsSession != null : _firebaseUser != null;

  bool get isLoadingProfile => _loadingProfile;
  bool get isBusy => _busy;
  String? get lastError => _lastError;

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
      debugPrint('AuthProvider: failed to load profile (Windows REST): $e\n$st');
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
        _firebaseUser?.uid ??
        _windowsSession?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }

    _setBusy(true);
    _lastError = null;
    try {
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

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    _lastError = null;

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
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _lastError = AuthService.messageFor(e);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    if (!isAuthenticated) return;
    _setBusy(true);
    try {
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

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
