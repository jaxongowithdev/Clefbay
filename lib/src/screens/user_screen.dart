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
  static const _heat = Color(0xFFFF8A5B);
  static const _ink = Color(0xFF1C140F);
  static const _slip = Color(0xFFFFF6EE);
  static const _glaze = Color(0xFF1F6F68);

  static const _ranges = [8, 16, 22, 40];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 8;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Set',
      'Stand so your weight is even.',
    ),
    (
      'Aim',
      'Find the farthest corner you can see.',
    ),
    (
      'Cross',
      'Walk there, counting eight steps.',
    ),
    (
      'Hold',
      'Stay for one breath and name what is next.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kilnslip_notes') ?? '[]';
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
      _onboarded = prefs.getBool('kilnslip_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('kilnslip_range') ?? 8;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('kilnslip_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('kilnslip_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a line before you press it.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'kilnslip_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Pressed on this phone. Private journal.');
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
      title: 'Kilnslip',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _heat,
        fontFamily: 'Newsreader',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.light(
          surface: _heat,
          primary: _ink,
          onPrimary: _slip,
          onSurface: _ink,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: _heat,
            fontFamily: 'Newsreader',
            fontSize: 16,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _heat,
              body: Center(child: CircularProgressIndicator(color: _ink)),
            )
          : _onboarded
              ? _shell()
              : _onboardingScreen(),
    );
  }

  Widget _onboardingScreen() {
    const pages = [
      (
        '01',
        'A kiln for\nattention.',
        'Kilnslip fires a short lesson and keeps it on this phone.',
      ),
      (
        '02',
        'Walk, then\nraise the clay.',
        'Walk is four steps. Four Columns is a rising-column breath.',
      ),
      (
        '03',
        'Press a note\ninto the slip.',
        'Tablet is a private journal. No account. No cloud. No remote AI.',
      ),
    ];
    final page = pages[_onboardingPage];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _heat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KILNSLIP  ${page.$1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 2, color: _ink),
              Expanded(
                child: PageView.builder(
                  controller: _onboarding,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => _onboardingPage = value),
                  itemBuilder: (_, index) {
                    final item = pages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(item.$2, style: _display(42)),
                        const SizedBox(height: 14),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    );
                  },
                ),
              ),
              _press(
                key: const Key('onboarding-advance'),
                label: last ? 'Begin' : 'Next',
                onTap: last
                    ? _finishOnboarding
                    : () => _onboarding.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        ),
              ),
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
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
      backgroundColor: _heat,
      body: SafeArea(
        child: Column(
          children: [
            _tabs(),
            Expanded(child: IndexedStack(index: _tab.index, children: pages)),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    const items = [
      (_Tab.home, 'Home', 'tab-home'),
      (_Tab.walk, 'Walk', 'tab-walk'),
      (_Tab.four, 'Four', 'tab-four'),
      (_Tab.range, 'Range', 'tab-range'),
      (_Tab.tablet, 'Tablet', 'tab-tablet'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ink, width: 2)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: Key(item.$3),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = item.$1),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == item.$1 ? _ink : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 14,
                      fontWeight: _tab == item.$1 ? FontWeight.w700 : FontWeight.w500,
                      color: _ink,
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
        Text('KILNSLIP', style: _kicker()),
        const SizedBox(height: 8),
        Text('Fire the next slip.', style: _display(36)),
        const SizedBox(height: 6),
        Text(
          'Slip of $_rangeMinutes minutes',
          style: const TextStyle(fontSize: 16, color: _ink),
        ),
        const SizedBox(height: 18),
        _poster(
          title: 'Walk',
          body: 'Four steps across the room.',
          onTap: () => setState(() => _tab = _Tab.walk),
        ),
        _poster(
          title: 'Four Columns',
          body: 'A rising-column breath.',
          onTap: () => setState(() => _tab = _Tab.four),
        ),
        _poster(
          title: 'Range',
          body: 'How long the firing lasts.',
          onTap: () => setState(() => _tab = _Tab.range),
        ),
        _poster(
          title: 'Tablet',
          body: 'A note pressed into the clay.',
          onTap: () => setState(() => _tab = _Tab.tablet),
        ),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('WALK  0${_walkStep + 1}', style: _kicker()),
        const SizedBox(height: 8),
        Text(step.$1, style: _display(48)),
        const SizedBox(height: 8),
        Text(
          step.$2,
          style: const TextStyle(fontSize: 20, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 22),
        Row(
          children: List.generate(_walkSteps.length, (index) {
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: index == _walkSteps.length - 1 ? 0 : 6),
                color: index <= _walkStep ? _ink : _slip,
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        _press(
          key: const Key('walk-advance'),
          label: _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
          onTap: () => setState(
            () => _walkStep = (_walkStep + 1) % _walkSteps.length,
          ),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Inhale', 'Hold', 'Exhale', 'Rest'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 8),
        Text('Raise the clay.', style: _display(36)),
        const SizedBox(height: 8),
        const Text(
          'Four forms. The active one fills from the base, four counts each.',
          style: TextStyle(fontSize: 16, height: 1.35, color: _ink),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 190,
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
                            final fill = active
                                ? constraints.maxHeight * (0.14 + rise * 0.86)
                                : constraints.maxHeight * 0.08;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: _ink, width: 2),
                                  color: _slip,
                                ),
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                  height: fill,
                                  width: double.infinity,
                                  color: active ? _glaze : _ink.withValues(alpha: 0.18),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[index],
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _breathing ? '${labels[_breathPhase]} · $_breathSeconds' : 'Ready',
          style: _display(26),
        ),
        const SizedBox(height: 14),
        _press(
          key: const Key('breath-toggle'),
          label: _breathing ? 'End breath' : 'Start Four Columns',
          onTap: _breathing ? _stopBreath : _startBreath,
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker()),
        const SizedBox(height: 8),
        Text('Firing length.', style: _display(36)),
        const SizedBox(height: 6),
        const Text(
          'Stored only on this device.',
          style: TextStyle(fontSize: 16, color: _ink),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (final minute in _ranges)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('range-$minute'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _saveRange(minute),
                    child: Container(
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _rangeMinutes == minute ? _ink : _slip,
                        border: Border.all(color: _ink, width: 2),
                      ),
                      child: Text(
                        '$minute',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _rangeMinutes == minute ? _heat : _ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'A range is the time you give the firing, not a mark to beat.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _ink),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker()),
        const SizedBox(height: 8),
        Text('Private journal.', style: _display(36)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: _ink, fontSize: 18, height: 1.35),
          cursorColor: _ink,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What did the firing leave?',
            hintStyle: TextStyle(color: Color(0xFF6A5348)),
            filled: true,
            fillColor: _slip,
            contentPadding: EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _ink, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _ink, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _glaze, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _press(
          key: const Key('tablet-save'),
          label: 'Save note',
          onTap: _saveNote,
        ),
        const SizedBox(height: 18),
        if (_notes.isEmpty)
          const Text(
            'Nothing pressed yet. The first note stays on this phone.',
            style: TextStyle(fontSize: 16, color: _ink),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: _sticker(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(
                      color: _glaze,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.body,
                    style: const TextStyle(fontSize: 16, height: 1.3, color: _ink),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: children,
    );
  }

  Widget _poster({
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: _sticker(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _display(22)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 15, color: _ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _press({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _ink,
          boxShadow: [BoxShadow(color: _glaze, offset: Offset(4, 4))],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _slip,
            fontFamily: 'Newsreader',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  BoxDecoration _sticker() => const BoxDecoration(
        color: _slip,
        border: Border.fromBorderSide(BorderSide(color: _ink, width: 2)),
        boxShadow: [BoxShadow(color: _ink, offset: Offset(4, 4))],
      );

  TextStyle _kicker() => const TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: _ink,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Newsreader',
        fontSize: size,
        height: 0.98,
        fontWeight: FontWeight.w700,
        color: _ink,
      );

  String _stamp(DateTime time) {
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
