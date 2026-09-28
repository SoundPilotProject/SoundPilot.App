// lib/features/device/widgets/device_card.dart
//
// Card of one device in the device list, plus the legend that explains its
// connection state.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'device_type.dart';

/// Card for one device: type icon, name, connection state and a delete button.
/// Tapping the card calls [onTap] (calibration/setup).
///
/// The connection state is shown by a coloured dot *and* the icon inside it,
/// and it is part of the card's screen-reader label — it is never carried by
/// the colour alone.
class DeviceCard extends StatelessWidget {
  final String name;
  final DeviceType type;

  /// Green dot with a check if `true`, red dot with a cross otherwise (see
  /// [LegendBox]).
  final bool isConnected;

  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.name,
    required this.type,
    required this.isConnected,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.onPrimary(context);
    final stateText = isConnected ? 'verbunden' : 'nicht verbunden';

    final card = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 26, color: onPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onPrimary,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          StatusDot(isConnected: isConnected, borderColor: onPrimary),
          // 48x48 dp tap target instead of the bare 32 dp icon it used to be.
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: onDelete,
              tooltip: '$name entfernen',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close_rounded, color: onPrimary, size: 30),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: '$name, $stateText', child: card);
    }

    return Semantics(
      button: true,
      label: '$name, $stateText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

/// Coloured dot with a check/cross icon that shows the connection state.
///
/// Green and red alone do not separate reliably from the card behind them (red
/// on the blue card reaches only 2.1:1, green on the yellow dark-mode card
/// 1.5:1). The dot therefore carries a ring in [borderColor], which the caller
/// picks to contrast with its own background, and a white icon that contrasts
/// with the fill.
class StatusDot extends StatelessWidget {
  final bool isConnected;

  /// Colour of the ring around the dot. Pass a colour that contrasts with the
  /// surface the dot sits on (e.g. `AppColors.onPrimary` on a coloured card).
  final Color borderColor;

  const StatusDot({
    super.key,
    required this.isConnected,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              isConnected ? AppColors.connectedGreen : AppColors.disconnectedRed,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Icon(
          isConnected ? Icons.check_rounded : Icons.close_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Legend that explains the connection dots of the [DeviceCard]s.
class LegendBox extends StatelessWidget {
  const LegendBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.legendBackground(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.legendBorder(context), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(isConnected: true, text: 'Verbunden'),
          SizedBox(height: 10),
          _LegendRow(isConnected: false, text: 'Nicht verbunden'),
        ],
      ),
    );
  }
}

/// One line of the [LegendBox].
class _LegendRow extends StatelessWidget {
  final bool isConnected;
  final String text;

  const _LegendRow({required this.isConnected, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusDot(
          isConnected: isConnected,
          borderColor: AppColors.text(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
