// lib/core/widgets/app_snack_bar.dart
//
// The app's SnackBar: it waits for the user instead of disappearing on its own.

import 'package:flutter/material.dart';

/// SnackBar with [content] that stays until the user dismisses it.
///
/// Use this instead of building a `SnackBar` by hand, so no message in the app
/// is bound to a time limit.
///
/// NOTE: `persist` plus an action is what keeps it open. In Flutter 3.47 the
/// auto-dismiss timer only looks at `SnackBar.persist` (which defaults to
/// `action != null`, see `snack_bar.dart`); whether a screen reader is running
/// no longer plays a part, so a message without an action was gone after 4 s
/// even with TalkBack on. That breaks both "no time-limited interactions" and
/// the chance of ever hearing it (docs/PROJECT_CONTEXT.md §1).
SnackBar appSnackBar(Widget content) {
  return SnackBar(
    persist: true,
    // Pressing it closes the SnackBar; there is nothing else to do.
    action: SnackBarAction(label: 'OK', onPressed: () {}),
    content: content,
  );
}

/// [appSnackBar] for an error: an icon in front of the [message], so the
/// message is not carried by colour alone.
SnackBar appErrorSnackBar(String message) {
  return appSnackBar(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(child: Icon(Icons.error_outline)),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

/// Shows [message] in an [appSnackBar].
void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(appSnackBar(Text(message)));
}

/// Shows [message] in an [appErrorSnackBar].
void showAppError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(appErrorSnackBar(message));
}
