// lib/features/auth/auth_flow.dart
//
// Shared sign-in flow of the login and the registration screen.

import 'package:flutter/material.dart';

import '../../core/widgets/loading_screen.dart';
import 'auth_service.dart';
import 'guest_devices_offer.dart';

/// Runs [signIn] behind a full-screen [LoadingScreen] that shows [loadingText],
/// and reports the result to the user.
///
/// On success the guest devices stored on this phone, if any, are offered for
/// the account ([offerGuestDevices]). Then every route above the first one is
/// popped: AppEntryPoint already shows the DeviceScreen for the signed-in
/// user, so the auth screens only have to get out of the way.
///
/// A failure is shown in a SnackBar with the German message of the
/// [AuthResult]. A cancelled sign-in — the user closed the Google dialog —
/// carries no message and shows nothing, because the user aborted it on
/// purpose.
///
/// Used by the login and the registration screen for both ways of signing in
/// (e-mail and Google), so the four of them cannot drift apart.
Future<void> runSignIn(
  BuildContext context, {
  required String loadingText,
  required Future<AuthResult> Function() signIn,
}) async {
  if (!context.mounted) return;

  // Loading route on top of the calling screen; it is popped again below.
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LoadingScreen(text: loadingText),
    ),
  );

  final result = await signIn();

  if (!context.mounted) return;

  Navigator.pop(context);

  final user = result.user;
  if (user != null) {
    await offerGuestDevices(context, uid: user.id);
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    return;
  }

  final error = result.errorMessage;
  if (error == null) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error)),
  );
}
