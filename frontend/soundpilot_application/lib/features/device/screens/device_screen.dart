import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'calibration.dart';
import 'belt_warning_distance_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final List<_DeviceItem> _earbuds = [
    _DeviceItem(name: 'Earbuds01', isConnected: true),
    _DeviceItem(name: 'Earbuds02', isConnected: false),
  ];

  final List<_DeviceItem> _belts = [
    _DeviceItem(name: 'Gürtel01', isConnected: true),
    _DeviceItem(name: 'Gürtel02', isConnected: false),
  ];

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  Future<void> _logout() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(
          text: 'Wird abgemeldet...',
        ),
      ),
    );

    await FirebaseAuth.instance.signOut();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pop(context);

    setState(() {});
  }

  void _removeDevice(String category, int index) {
    setState(() {
      if (category == 'Earbuds') {
        _earbuds.removeAt(index);
      } else {
        _belts.removeAt(index);
      }
    });
  }

  Future<void> _openCalibrationForEarbud(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CalibrationScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true && index >= 0 && index < _earbuds.length) {
      setState(() {
        _earbuds[index].isConnected = true;
      });
    }
  }

  Future<void> _openBeltSetup(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const BeltWarningDistanceScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true && index >= 0 && index < _belts.length) {
      setState(() {
        _belts[index].isConnected = true;
      });
    }
  }

  Future<void> _openAddDeviceDialog() async {
    String selectedType = 'Earbuds';
    final TextEditingController nameController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.background(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gerät hinzufügen',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.text(context),
                          width: 1.2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.text(context),
                            size: 28,
                          ),
                          dropdownColor: AppColors.background(context),
                          borderRadius: BorderRadius.circular(16),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Earbuds',
                              child: Text('Earbuds'),
                            ),
                            DropdownMenuItem(
                              value: 'Gürtel',
                              child: Text('Gürtel'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedType = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 68,
                      child: TextField(
                        controller: nameController,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Gerätename',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedText(context),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.legendBorder(context),
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.legendBorder(context),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Abbrechen',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary(context),
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              final enteredName = nameController.text.trim();
                              if (enteredName.isEmpty) return;

                              Navigator.of(dialogContext).pop({
                                'type': selectedType,
                                'name': enteredName,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary(context),
                              foregroundColor: AppColors.onPrimary(context),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            child: Text(
                              'Hinzufügen',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onPrimary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();

    if (!mounted || result == null) return;

    final selectedTypeResult = result['type'];
    final enteredNameResult = result['name'];

    if (selectedTypeResult == null || enteredNameResult == null) return;

    setState(() {
      if (selectedTypeResult == 'Earbuds') {
        _earbuds.add(
          _DeviceItem(
            name: enteredNameResult,
            isConnected: false,
          ),
        );
      } else {
        _belts.add(
          _DeviceItem(
            name: enteredNameResult,
            isConnected: false,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalDevices = _earbuds.length + _belts.length;
    final shouldScroll = totalDevices > 4;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          child: shouldScroll
              ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildScrollableContent(),
          )
              : _buildFixedContent(),
        ),
      ),
    );
  }

  Widget _buildFixedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopButtons(),
        const SizedBox(height: 16),
        Text(
          'Geräte',
          style: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Earbuds',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          _earbuds.length,
              (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DeviceCard(
              name: _earbuds[index].name,
              isConnected: _earbuds[index].isConnected,
              onDelete: () => _removeDevice('Earbuds', index),
              onTap: () => _openCalibrationForEarbud(index),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Gürtel',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          _belts.length,
              (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DeviceCard(
              name: _belts[index].name,
              isConnected: _belts[index].isConnected,
              onDelete: () => _removeDevice('Gürtel', index),
              onTap: () => _openBeltSetup(index),
            ),
          ),
        ),
        const Spacer(),
        const _LegendBox(),
      ],
    );
  }

  Widget _buildScrollableContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopButtons(),
        const SizedBox(height: 20),
        Text(
          'Geräte',
          style: GoogleFonts.poppins(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Earbuds',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _earbuds.length,
              (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeviceCard(
              name: _earbuds[index].name,
              isConnected: _earbuds[index].isConnected,
              onDelete: () => _removeDevice('Earbuds', index),
              onTap: () => _openCalibrationForEarbud(index),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Gürtel',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.text(context),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _belts.length,
              (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeviceCard(
              name: _belts[index].name,
              isConnected: _belts[index].isConnected,
              onDelete: () => _removeDevice('Gürtel', index),
              onTap: () => _openBeltSetup(index),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _LegendBox(),
      ],
    );
  }

  Widget _buildTopButtons() {
    if (_isLoggedIn) {
      return Row(
        children: [
          Expanded(
            flex: 7,
            child: _TopActionButton(
              text: 'Abmelden',
              onPressed: _logout,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _IconSquareButton(
              backgroundColor: AppColors.primary(context),
              icon: Icons.add,
              iconColor: AppColors.onPrimary(context),
              onPressed: _openAddDeviceDialog,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _TopActionButton(
            text: 'Login',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(
                    returnToDeviceOnBack: true,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: _TopActionButton(
            text: 'Registrieren',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterScreen(
                    returnToDeviceOnBack: true,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _IconSquareButton(
            backgroundColor: AppColors.primary(context),
            icon: Icons.add,
            iconColor: AppColors.onPrimary(context),
            onPressed: _openAddDeviceDialog,
          ),
        ),
      ],
    );
  }
}

class _DeviceItem {
  final String name;
  bool isConnected;

  _DeviceItem({
    required this.name,
    required this.isConnected,
  });
}

class _TopActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _TopActionButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary(context),
          foregroundColor: AppColors.onPrimary(context),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _IconSquareButton({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: 34,
          color: iconColor,
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String name;
  final bool isConnected;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _DeviceCard({
    required this.name,
    required this.isConnected,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 74,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primary(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary(context),
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.connectedGreen
                  : AppColors.disconnectedRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              color: AppColors.onPrimary(context),
              size: 32,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  const _LegendBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.legendBackground(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.legendBorder(context),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.connectedGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Verbunden',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.disconnectedRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Nicht verbunden',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}