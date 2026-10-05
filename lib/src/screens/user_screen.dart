import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only practice teacher. No accounts, network clients, cloud sync,
/// or remote model calls.
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

enum _Tab { home, walk, four, range, tablet }

class _Note {
  const _Note({required this.body, required this.time});

  final String body;
  final DateTime time;

  Map<String, String> toJson() => {
        'body': body,
        'time': time.toIso8601String(),
      };

  static _Note fromJson(Map<String, dynamic> json) => _Note(
        body: json['body'] as String? ?? '',
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class _UserScreenState extends State<UserScreen> {
  static const _tide = Color(0xFF0E6E6A);
  static const _deep = Color(0xFF084E4C);
  static const _sand = Color(0xFFFFF6E8);
  static const _coral = Color(0xFFE86A4A);
  static const _foam = Color(0xFFD5EBE4);
  static const _ink = Color(0xFF143330);

  static const _ranges = [6, 12, 18, 30];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 12;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Pause',
      'Rest one hand on something solid.',
    ),
    (
      'Turn',
      'Turn to face a different wall.',
    ),
    (
      'Drift',
      'Take six slow steps in that direction.',
    ),
    (
      'Land',
      'Stop and name the next useful thing.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saltpaper_notes') ?? '[]';
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _notes = decoded
          .whereType<Map<String, dynamic>>()
          .map(_Note.fromJson)
          .toList();
    } catch (_) {
      _notes = [];
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _onboarded = prefs.getBool('saltpaper_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('saltpaper_range') ?? 12;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('saltpaper_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('saltpaper_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a line before you stamp it.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'saltpaper_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Stamped on this phone. Private journal.');
  }

  void _toast(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startBreath() {
    _breathTimer?.cancel();
    setState(() {
      _breathing = true;
      _breathPhase = 0;
      _breathSeconds = 4;
    });
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_breathSeconds > 1) {
          _breathSeconds--;
        } else {
          _breathPhase = (_breathPhase + 1) % 4;
          _breathSeconds = 4;
        }
      });
    });
  }

  void _stopBreath() {
    _breathTimer?.cancel();
    setState(() => _breathing = false);
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _noteController.dispose();
    _onboarding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saltpaper',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _tide,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.fromSeed(seedColor: _coral, surface: _tide),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _sand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentTextStyle: const TextStyle(
            color: _ink,
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _tide,
              body: Center(child: CircularProgressIndicator(color: _sand)),
            )
          : _onboarded
              ? _shell()
              : _onboardingScreen(),
    );
  }

  Widget _onboardingScreen() {
    const pages = [
      (
        'A paper teacher\nfor this phone.',
        'Saltpaper keeps the whole lesson on the device.',
      ),
      (
        'A walk, then\nfour columns.',
        'Walk is four steps. Four Columns is a rising-column breath.',
      ),
      (
        'Stamp the note\nand leave it.',
        'Tablet is a private journal. No account. No cloud. No remote AI.',
      ),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _tide,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _onboarding,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => _onboardingPage = value),
                  itemBuilder: (_, index) {
                    final page = pages[index];
                    return Column(
                      children: [
                        const Spacer(),
                        _ticket(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                            child: Column(
                              children: [
                                _stamp('0${index + 1}'),
                                const SizedBox(height: 18),
                                Text(
                                  page.$1,
                                  textAlign: TextAlign.center,
                                  style: _display(30, _ink),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  page.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: _deep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  final on = index == _onboardingPage;
                  return Container(
                    width: on ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: on ? _coral : _foam.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-advance'),
                  onPressed: last
                      ? _finishOnboarding
                      : () => _onboarding.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                          ),
                  style: _coralButton(),
                  child: Text(last ? 'Begin' : 'Next'),
                ),
              ),
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: _foam, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shell() {
    final pages = [_home(), _walk(), _four(), _range(), _tablet()];
    return Scaffold(
      backgroundColor: _tide,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: IndexedStack(index: _tab.index, children: pages)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _dock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock() {
    const items = [
      (_Tab.home, 'Home', 'tab-home'),
      (_Tab.walk, 'Walk', 'tab-walk'),
      (_Tab.four, 'Four', 'tab-four'),
      (_Tab.range, 'Range', 'tab-range'),
      (_Tab.tablet, 'Tablet', 'tab-tablet'),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: Key(item.$3),
                onTap: () => setState(() => _tab = item.$1),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == item.$1 ? _coral : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _tab == item.$1 ? _sand : _tide,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _home() {
    return _scroll(
      children: [
        Text('SALTPAPER', style: _kicker(_foam)),
        const SizedBox(height: 6),
        Text('Your next ticket.', style: _display(32, _sand)),
        const SizedBox(height: 8),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(color: _foam, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _ticket(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('THIS SITTING', style: _kicker(_coral)),
                          const SizedBox(height: 4),
                          Text('$_rangeMinutes min ticket', style: _display(24, _ink)),
                        ],
                      ),
                    ),
                    _stamp('HERE'),
                  ],
                ),
              ),
              _tear(),
              _link(
                title: 'Walk',
                body: 'Four steps, one direction.',
                onTap: () => setState(() => _tab = _Tab.walk),
              ),
              _tear(),
              _link(
                title: 'Four Columns',
                body: 'A rising-column breath.',
                onTap: () => setState(() => _tab = _Tab.four),
              ),
              _tear(),
              _link(
                title: 'Range',
                body: 'Pick the length of the ticket.',
                onTap: () => setState(() => _tab = _Tab.range),
              ),
              _tear(),
              _link(
                title: 'Tablet',
                body: 'Stamp a private note.',
                onTap: () => setState(() => _tab = _Tab.tablet),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('WALK', style: _kicker(_foam)),
        const SizedBox(height: 6),
        Text('One direction.', style: _display(32, _sand)),
        const SizedBox(height: 14),
        Row(
          children: List.generate(_walkSteps.length, (index) {
            final on = index == _walkStep;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == _walkSteps.length - 1 ? 0 : 6),
                height: 8,
                decoration: BoxDecoration(
                  color: on ? _coral : _foam.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        _ticket(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STUB 0${_walkStep + 1}', style: _kicker(_coral)),
                const SizedBox(height: 8),
                Text(step.$1, style: _display(34, _ink)),
                const SizedBox(height: 8),
                Text(
                  step.$2,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: _deep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _tear(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('walk-advance'),
                    onPressed: () => setState(
                      () => _walkStep = (_walkStep + 1) % _walkSteps.length,
                    ),
                    style: _coralButton(),
                    child: Text(
                      _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Inhale', 'Hold', 'Exhale', 'Rest'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker(_foam)),
        const SizedBox(height: 6),
        Text('Let one rise.', style: _display(32, _sand)),
        const SizedBox(height: 14),
        _ticket(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Four windows. The active column rises through four counts.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: _deep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(4, (index) {
                      final active = _breathing && index == _breathPhase;
                      final rise = active ? (5 - _breathSeconds) / 4 : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final height = active
                                        ? constraints.maxHeight * (0.16 + rise * 0.84)
                                        : constraints.maxHeight * 0.1;
                                    return Align(
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeOut,
                                        height: height,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: active ? _coral : _foam,
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(14),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                labels[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: active ? _coral : _deep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _breathing ? '${labels[_breathPhase]} · $_breathSeconds' : 'Ready',
                  style: _display(22, _ink),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('breath-toggle'),
                    onPressed: _breathing ? _stopBreath : _startBreath,
                    style: _coralButton(),
                    child: Text(_breathing ? 'End breath' : 'Start Four Columns'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker(_foam)),
        const SizedBox(height: 6),
        Text('Ticket length.', style: _display(32, _sand)),
        const SizedBox(height: 14),
        _ticket(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stored only on this device.',
                    style: TextStyle(color: _deep, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final minute in _ranges)
                InkWell(
                  key: Key('range-$minute'),
                  onTap: () => _saveRange(minute),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    color: _rangeMinutes == minute ? _coral : Colors.transparent,
                    child: Row(
                      children: [
                        Text(
                          '$minute',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _rangeMinutes == minute ? _sand : _ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'min',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _rangeMinutes == minute ? _sand : _deep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Text(
                  'A range is how long the ticket lasts, not a score.',
                  style: TextStyle(color: _deep, height: 1.4, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker(_foam)),
        const SizedBox(height: 6),
        Text('Private journal.', style: _display(32, _sand)),
        const SizedBox(height: 14),
        _ticket(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('tablet-field'),
                  controller: _noteController,
                  minLines: 4,
                  maxLines: 6,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: _coral,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What should this ticket remember?',
                    hintStyle: TextStyle(color: _deep.withValues(alpha: 0.55)),
                    filled: true,
                    fillColor: _foam.withValues(alpha: 0.45),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _coral, width: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('tablet-save'),
                    onPressed: _saveNote,
                    style: _coralButton(),
                    child: const Text('Save note'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_notes.isEmpty)
          const Text(
            'No stamp yet. The first note stays on this phone.',
            style: TextStyle(color: _foam, fontWeight: FontWeight.w600),
          )
        else
          for (final note in _notes.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ticket(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_stampTime(note.time), style: _kicker(_coral)),
                      const SizedBox(height: 6),
                      Text(
                        note.body,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      children: children,
    );
  }

  Widget _ticket({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _sand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _tear() {
    return SizedBox(
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              14,
              (_) => Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(color: _tide, shape: BoxShape.circle),
              ),
            ),
          ),
          Positioned(
            left: -9,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: _tide, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: -9,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: _tide, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stamp(String label) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _coral, width: 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _coral,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _link({
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _display(18, _ink)),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: const TextStyle(
                      color: _deep,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: _coral, size: 18),
          ],
        ),
      ),
    );
  }

  TextStyle _kicker(Color color) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: color,
      );

  TextStyle _display(double size, Color color) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w800,
        color: color,
      );

  ButtonStyle _coralButton() => FilledButton.styleFrom(
        backgroundColor: _coral,
        foregroundColor: _sand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );

  String _stampTime(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${months[time.month - 1]} ${time.day}  $h:$m';
  }
}
