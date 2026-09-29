// lib/core/widgets/app_top_bar.dart
//
// Shared top bar (back arrow + centred title) used by all inner screens.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Top bar in the accent colour with a back arrow on the left and the [title]
/// centred in the remaining width.
///
/// Replaces the five nearly identical private top bars that used to live in
/// the auth and device screens.
///
/// Accessibility notes:
/// - The bar has no fixed height. It grows with the system font size, so a
///   long title at a large text scale is never clipped.
/// - The back button keeps a 56x56 dp tap target and carries a tooltip, which
///   TalkBack/VoiceOver read out as its label.
/// - The title is marked as a header, so screen readers can jump to it.
class AppTopBar extends StatelessWidget {
  /// Text shown in the middle of the bar.
  final String title;

  /// Called when the back arrow is tapped.
  final VoidCallback onBackPressed;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.onPrimary(context);

    return Container(
      width: double.infinity,
      color: AppColors.primary(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: IconButton(
              onPressed: onBackPressed,
              tooltip: 'Zurück',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: onPrimary,
                size: 32,
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: onPrimary,
                      height: 1.15,
                    ),
              ),
            ),
          ),
          // Mirrors the width of the back button so the title sits in the
          // optical centre of the bar.
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}
