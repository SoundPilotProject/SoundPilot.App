// lib/features/device/widgets/belt_setup_fields.dart
//
// Widgets shared by the two belt setup steps (recommendation card, number
// input).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Card with the recommended range, shown at the top of both belt setup steps.
class RecommendationCard extends StatelessWidget {
  /// Text of the card, e.g. 'Empfehlung\n200 – 500 cm'.
  final String text;

  const RecommendationCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.text(context),
          height: 1.25,
        ),
      ),
    );
  }
}

/// Large centred number input with a unit suffix.
///
/// The visible heading sits above the field, so [label] is invisible and only
/// serves screen readers: without it the field would be announced as an
/// unnamed text box.
///
/// NOTE: The label is attached with a [Semantics] wrapper, not with an
/// invisible `labelText`. These fields start pre-filled ('200' / '100'), and
/// an invisible `labelText` only reaches the semantics tree while the field is
/// empty — so they used to be announced as a nameless text box with the value
/// '200'.
class BeltNumberField extends StatelessWidget {
  final TextEditingController controller;

  /// Screen-reader label of the field.
  final String label;

  /// Unit shown at the right edge (e.g. 'cm', '%').
  final String suffix;

  const BeltNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.text(context),
    );

    return Semantics(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        // Only digits: the field is read back as a number, and a pasted word
        // would silently become an invalid setting.
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: textStyle,
        decoration: InputDecoration(
          suffixText: suffix,
          suffixStyle: textStyle.copyWith(color: AppColors.mutedText(context)),
          filled: true,
          fillColor: AppColors.surface(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 22,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.inputBorder(context),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.primary(context),
              width: 3.5,
            ),
          ),
        ),
      ),
    );
  }
}
