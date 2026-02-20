import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ NEU: damit wir Login-Status erkennen

import 'core/app_logger.dart';
import 'firebase_options.dart';
import 'features/auth/auth_service.dart';

const Color uiBlue = Color(0xFF0A2D7A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i("Main: Firebase initialized successfully");
  } catch (e) {
    logger.e("Main: Failed to initialize Firebase", error: e);
  }

  runApp(const MyApp());
}

/* =========================
   APP ROOT
   ========================= */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ManagementPage(),
    );
  }
}

/* =========================
   MANAGEMENT PAGE
   ========================= */

class ManagementPage extends StatefulWidget {
  const ManagementPage({super.key});

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  // Demo-Daten: Geräte + Status
  List<Map<String, dynamic>> earbuds = [
    {'name': 'EarbudsGerät01', 'connected': true},
    {'name': 'EarbudsGerät02', 'connected': false},
  ];

  List<Map<String, dynamic>> belts = [
    {'name': 'GürtelGerät01', 'connected': true},
    {'name': 'GürtelGerät02', 'connected': false},
  ];

  // Löschen (X)
  void _removeEarbud(String deviceName) {
    setState(() => earbuds.removeWhere((d) => d['name'] == deviceName));
  }

  void _removeBelt(String deviceName) {
    setState(() => belts.removeWhere((d) => d['name'] == deviceName));
  }

  // Dialog: Gerät hinzufügen
  void _showAddDeviceDialog() {
    String? selectedType;
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gerät hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                hint: const Text('Typ auswählen'),
                items: const [
                  DropdownMenuItem(value: 'Earbuds', child: Text('Earbuds')),
                  DropdownMenuItem(value: 'Gürtel', child: Text('Gürtel')),
                ],
                onChanged: (value) => selectedType = value,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Gerätename',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final deviceName = nameController.text.trim();
                if (selectedType != null && deviceName.isNotEmpty) {
                  setState(() {
                    final newDevice = {'name': deviceName, 'connected': false};
                    if (selectedType == 'Earbuds') {
                      earbuds.add(newDevice);
                    } else {
                      belts.add(newDevice);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: uiBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top-Bar: + | Anmelden | Registrieren (✅ Buttons verschwinden wenn eingeloggt)
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final isLoggedIn = snapshot.data != null;

                  return Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: uiBlue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 28,
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: _showAddDeviceDialog,
                          tooltip: 'Gerät hinzufügen',
                        ),
                      ),
                      const Spacer(),

                      if (!isLoggedIn) ...[
                        _topButton(
                          text: 'Anmelden',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        _topButton(
                          text: 'Registrieren',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        _topButton(
                          text: 'Abmelden',
                          onPressed: () async {
                            await AuthService().logout();
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Titel
              const Text(
                'Verwaltung',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 16),

              // Inhalt scrollt nur wenn zu viele Geräte da sind
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategory(
                        title: 'Earbuds:',
                        items: earbuds,
                        onRemove: _removeEarbud,
                        onTap: (deviceName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EarbudCalibrationPage(deviceName: deviceName),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildCategory(
                        title: 'Gürtel:',
                        items: belts,
                        onRemove: _removeBelt,
                        onTap: (deviceName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BeltCalibrationPage(deviceName: deviceName),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _legendFullWidth(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Button-Stil (Top-Bar)
  Widget _topButton({required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: uiBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  // Kategorie (Earbuds/Gürtel)
  Widget _buildCategory({
    required String title,
    required List<Map<String, dynamic>> items,
    required Function(String) onRemove,
    required Function(String) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...items.map((device) {
          final name = device['name'] as String;
          final connected = device['connected'] as bool;
          return _buildDeviceTile(name, connected, onRemove, onTap);
        }),
      ],
    );
  }

  // Geräte-Kachel (Tap -> Kalibrierung, X -> löschen)
  Widget _buildDeviceTile(
    String deviceName,
    bool connected,
    Function(String) onRemove,
    Function(String) onTap,
  ) {
    return GestureDetector(
      onTap: () => onTap(deviceName),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: uiBlue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 6),
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                deviceName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: connected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onRemove(deviceName),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '×',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Legende: volle Breite, große Schrift
  Widget _legendFullWidth() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              CircleAvatar(radius: 18, backgroundColor: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '- bedeutet, dass das Gerät verbunden ist',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              CircleAvatar(radius: 18, backgroundColor: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '- bedeutet, dass das Gerät nicht verbunden ist',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* =========================
   EAR BUD CALIBRATION PAGE
   ========================= */

class EarbudCalibrationPage extends StatefulWidget {
  final String deviceName;

  const EarbudCalibrationPage({super.key, required this.deviceName});

  @override
  State<EarbudCalibrationPage> createState() => _EarbudCalibrationPageState();
}

class _EarbudCalibrationPageState extends State<EarbudCalibrationPage> {
  int leftValue = 7;
  int rightValue = 7;

  late final FixedExtentScrollController _leftCtrl;
  late final FixedExtentScrollController _rightCtrl;

  @override
  void initState() {
    super.initState();
    _leftCtrl = FixedExtentScrollController(initialItem: leftValue - 1);
    _rightCtrl = FixedExtentScrollController(initialItem: rightValue - 1);
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Weiß + Back (zurück zur Verwaltungsseite)
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '< Back',
            style: TextStyle(
              color: uiBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: const Text(
          'Kalibrierung',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: uiBlue,
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),

      // Kein Scrollen. Nur Picker scrollt.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kalibrierung',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Linke Seite:',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _volumeRow(
                label: 'Lautstärke:',
                controller: _leftCtrl,
                value: leftValue,
                onChanged: (v) => setState(() => leftValue = v),
              ),
              const SizedBox(height: 18),
              const Text(
                'Rechte Seite:',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _volumeRow(
                label: 'Lautstärke:',
                controller: _rightCtrl,
                value: rightValue,
                onChanged: (v) => setState(() => rightValue = v),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 76,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TestUebungPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: uiBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(44),
                    ),
                  ),
                  child: const Text(
                    'Test-Übung',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _volumeRow({
    required String label,
    required FixedExtentScrollController controller,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: uiBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.light),
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 32,
                    useMagnifier: true,
                    magnification: 1.1,
                    selectionOverlay: const SizedBox.shrink(),
                    onSelectedItemChanged: (index) => onChanged(index + 1),
                    children: List.generate(100, (i) {
                      final v = i + 1;
                      final isSelected = v == value;
                      return Center(
                        child: Text(
                          v.toString(),
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 16,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* =========================
   TEST ÜBUNG PAGE
   ========================= */

class TestUebungPage extends StatelessWidget {
  const TestUebungPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Weiß + Back (zurück zur Kalibrierung)
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '< Back',
            style: TextStyle(
              color: uiBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: const Text(
          'Test-Übung',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: uiBlue,
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),

      // Kein Scrollen
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Test-Übung',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 16 / 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _bigBlueButton(text: 'Start', onPressed: () {}),
              const SizedBox(height: 8),
              _bigBlueButton(text: 'Stop', onPressed: () {}),
              const SizedBox(height: 10),
              const Text(
                'Beschreibung',
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: const Text(
                        'In diesem Video wird eine Übung\n'
                        'im Sitzen bzw im Stehen gezeigt.\n'
                        'Pausiere das Video wenn du die\n'
                        'Übung verstanden hast und führe\n'
                        'sie aus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _bigBlueButton(
                text: 'Abschließen',
                onPressed: () {
                  // Zurück zur Verwaltungsseite
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bigBlueButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: uiBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/* =========================
   BELT CALIBRATION PAGE (wie gehabt)
   ========================= */

class BeltCalibrationPage extends StatefulWidget {
  final String deviceName;

  const BeltCalibrationPage({super.key, required this.deviceName});

  @override
  State<BeltCalibrationPage> createState() => _BeltCalibrationPageState();
}

class _BeltCalibrationPageState extends State<BeltCalibrationPage> {
  double rangeValue = 50;
  double intensityValue = 50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kalibrierung',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reichweite',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: rangeValue,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: rangeValue.round().toString(),
                            onChanged: (value) =>
                                setState(() => rangeValue = value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${rangeValue.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Intensität',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: intensityValue,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: intensityValue.round().toString(),
                            onChanged: (value) =>
                                setState(() => intensityValue = value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${intensityValue.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================
   LOGIN PAGE (Firebase Auth eingebaut)
   ========================= */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  final AuthService _authService = AuthService();

  String? _emailError;
  bool _isLoading = false;

  final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool _isValidEmail(String email) {
    if (!_emailRegex.hasMatch(email)) return false;

    final lower = email.toLowerCase();
    const allowedDomains = [
      'gmail.com',
      'gmx.com',
      'outlook.com',
      'hotmail.com',
      'icloud.com',
      'yahoo.com',
      'aol.com',
      'proton.me',
      'protonmail.com',
    ];

    final parts = lower.split('@');
    if (parts.length != 2) return false;
    return allowedDomains.contains(parts[1]);
  }

  void _validateEmailOnly() {
    final email = _emailCtrl.text.trim();
    String? eErr;

    if (email.isEmpty) {
      eErr = 'Bitte E-Mail eingeben.';
    } else if (!_isValidEmail(email)) {
      eErr = 'Ungültige E-Mail (z.B. @gmail.com, @gmx.com).';
    }

    setState(() => _emailError = eErr);
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    _validateEmailOnly();
    final pw = _pwCtrl.text;

    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    final pwOk = pw.isNotEmpty && pw.length >= 8 && hasSpecial;

    if (_emailError != null || !pwOk) {
      if (!pwOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte ein gültiges Passwort eingeben.'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.loginWithEmail(
        _emailCtrl.text.trim(),
        _pwCtrl.text,
      );

      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anmelden fehlgeschlagen. Prüfe E-Mail/Passwort.'),
          ),
        );
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Es gab einen Fehler beim Anmelden.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '< Back',
            style: TextStyle(
              color: uiBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: const Text(
          'Anmelden',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: uiBlue,
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Anmelden',
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'E-Mail und\nPasswort eingeben:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Email:',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _validateEmailOnly(),
                decoration: _fieldDeco(),
                style: const TextStyle(fontSize: 20),
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _emailError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Passwort:',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: _fieldDeco(),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final email = _emailCtrl.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bitte E-Mail eingeben.')),
                      );
                      return;
                    }
                    final ok = await _authService.sendPasswordReset(email);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Reset-Link wurde gesendet.'
                              : 'Reset fehlgeschlagen.',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Passwort vergessen?',
                    style: TextStyle(
                      color: uiBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: uiBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text(
                          'Anmelden',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Noch kein Konto?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: const Text(
                    'Registrieren',
                    style: TextStyle(
                      color: uiBlue,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   REGISTER PAGE (Firebase Auth eingebaut)
   ========================= */

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  final AuthService _authService = AuthService();

  String _beltValue = 'JA';

  // Pflichtfeld-Fehler
  String? _firstNameError;
  String? _lastNameError;

  // Validierungs-Fehler
  String? _emailError;
  String? _pwError;

  bool _isLoading = false;

  final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool _isValidEmail(String email) {
    if (!_emailRegex.hasMatch(email)) return false;

    final lower = email.toLowerCase();
    const allowedDomains = [
      'gmail.com',
      'gmx.com',
      'outlook.com',
      'hotmail.com',
      'icloud.com',
      'yahoo.com',
      'aol.com',
      'proton.me',
      'protonmail.com',
    ];

    final parts = lower.split('@');
    if (parts.length != 2) return false;
    return allowedDomains.contains(parts[1]);
  }

  bool _hasSpecialCharNoSpaces(String s) {
    // Sonderzeichen ja, aber Leerzeichen zählen NICHT
    return RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];`~]').hasMatch(s);
  }

  void _validate({bool showRequiredErrors = true}) {
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;

    String? fnErr;
    String? lnErr;
    String? eErr;
    String? pErr;

    if (showRequiredErrors) {
      if (fn.isEmpty) fnErr = 'Bitte Vorname eingeben.';
      if (ln.isEmpty) lnErr = 'Bitte Nachname eingeben.';
    }

    if (email.isEmpty) {
      eErr = 'Bitte E-Mail eingeben.';
    } else if (!_isValidEmail(email)) {
      eErr = 'Ungültige E-Mail (z.B. @gmail.com, @gmx.com).';
    }

    if (pw.isEmpty) {
      pErr = 'Bitte Passwort eingeben.';
    } else if (pw.length < 8 || !_hasSpecialCharNoSpaces(pw)) {
      pErr = 'Mind. 8 Zeichen und 1 Sonderzeichen.';
    }

    setState(() {
      _firstNameError = fnErr;
      _lastNameError = lnErr;
      _emailError = eErr;
      _pwError = pErr;
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    _validate(showRequiredErrors: true);

    final ok =
        _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _pwError == null;

    if (!ok) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.registerWithEmail(
        _emailCtrl.text.trim(),
        _pwCtrl.text,
      );

      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrieren fehlgeschlagen.')),
        );
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Es gab einen Fehler beim Registrieren.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDeco({bool error = false}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: error ? Colors.red : Colors.black,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: error ? Colors.red : Colors.black,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text(
            '< Back',
            style: TextStyle(
              color: uiBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: const Text(
          'Registrieren',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: uiBlue,
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registrieren',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _label('Vorname:*'),
                      const SizedBox(height: 6),
                      _field(
                        controller: _firstNameCtrl,
                        errorText: _firstNameError,
                        onChanged: (_) => _validate(showRequiredErrors: false),
                      ),
                      const SizedBox(height: 10),

                      _label('Nachname:*'),
                      const SizedBox(height: 6),
                      _field(
                        controller: _lastNameCtrl,
                        errorText: _lastNameError,
                        onChanged: (_) => _validate(showRequiredErrors: false),
                      ),
                      const SizedBox(height: 10),

                      _label('E-Mail:*'),
                      const SizedBox(height: 6),
                      _field(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: (_) => _validate(showRequiredErrors: false),
                      ),
                      const SizedBox(height: 10),

                      _label('Passwort:*'),
                      const SizedBox(height: 6),
                      _field(
                        controller: _pwCtrl,
                        obscureText: true,
                        errorText: _pwError,
                        onChanged: (_) => _validate(showRequiredErrors: false),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),

                      _label('Gürtel?:*'),
                      const SizedBox(height: 6),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _beltValue,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'JA', child: Text('JA')),
                              DropdownMenuItem(
                                value: 'NEIN',
                                child: Text('NEIN'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _beltValue = v);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: uiBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(34),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Registrieren',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Center(
                        child: Text(
                          'Bereits registriert?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Anmelden',
                            style: TextStyle(
                              color: uiBlue,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
    );
  }

  Widget _field({
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? errorText,
  }) {
    final hasError = (errorText != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 18),
            decoration: _fieldDeco(error: hasError),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}
