import 'package:flutter/material.dart';

import 'auth_wrapper.dart';

/// Clears the nav stack and returns to [AuthWrapper], which routes guests to the
/// landing page and signed-in users to the correct dashboard.
void resetToAuthRoot(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
    (_) => false,
  );
}
