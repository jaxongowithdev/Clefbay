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
  static const _ink = Color(0xFF101318);
  static const _panel = Color(0xFF1A1F29);
  static const _line = Color(0xFF2C3342);
  static const _chalk = Color(0xFFF4F1E8);
  static const _mute = Color(0xFF8E97A8);
  static const _signal = Color(0xFFFF4D2E);
  static const _ice = Color(0xFF8FB4FF);

  static const _ranges = [4, 8, 12, 20];

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
      'Plant',
      'Put both feet flat. Unclench the jaw and let the hands hang.',
    ),
    (
      'Count',
      'Name three objects you can see. One word each, then stop.',
    ),
    (
      'Pace',
      'Take four steps. Feel the heel, then the front of the foot.',
    ),
    (
      'Mark',
      'Say the single next action for this moment, out loud.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sparglass_notes') ?? '[]';
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
      _onboarded = prefs.getBool('sparglass_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('sparglass_range') ?? 8;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('sparglass_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('sparglass_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a note before saving.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'sparglass_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Saved on this device. Private journal.');
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
      title: 'Sparglass',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        fontFamily: 'Syne',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.dark(
          surface: _ink,
          primary: _signal,
          onPrimary: Colors.white,
          onSurface: _chalk,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _panel,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(color: _chalk, fontSize: 14),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _ink,
              body: Center(child: CircularProgressIndicator(color: _signal)),
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
        'Sparglass is\nyour teacher.',
        'A complete practice that stays on this phone. Nothing leaves the device.',
      ),
      (
        '02',
        'Walk, then\nbreathe.',
        'Walk is four guided steps. Four Columns is a rising-column breath.',
      ),
      (
        '03',
        'Keep a private\njournal.',
        'Tablet notes stay here. No account. No cloud. No remote AI.',
      ),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('SPARGLASS', style: _kicker()),
                  const Spacer(),
                  Text(
                    pages[_onboardingPage].$1,
                    style: _kicker(color: _signal),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(pages.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: index == pages.length - 1 ? 0 : 6),
                      color: index <= _onboardingPage ? _signal : _line,
                    ),
                  );
                }),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _onboarding,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => _onboardingPage = value),
                  itemBuilder: (_, index) {
                    final page = pages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(page.$2, style: _display(42)),
                        const SizedBox(height: 18),
                        Text(
                          page.$3,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: _mute,
                            fontFamily: 'Syne',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-advance'),
                  onPressed: last
                      ? _finishOnboarding
                      : () => _onboarding.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                  style: _signalButton(),
                  child: Text(last ? 'Begin' : 'Next'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: const Text(
                    'Skip setup',
                    style: TextStyle(color: _mute, fontWeight: FontWeight.w600),
                  ),
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
      backgroundColor: _ink,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(index: _tab.index, children: pages),
            ),
          ),
          _dock(),
        ],
      ),
    );
  }

  Widget _dock() {
    const items = [
      (_Tab.home, 'Home', Icons.grid_view_rounded, 'tab-home'),
      (_Tab.walk, 'Walk', Icons.hiking_rounded, 'tab-walk'),
      (_Tab.four, 'Four', Icons.view_column_rounded, 'tab-four'),
      (_Tab.range, 'Range', Icons.timelapse_rounded, 'tab-range'),
      (_Tab.tablet, 'Tablet', Icons.menu_book_rounded, 'tab-tablet'),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                key: Key(item.$4),
                onTap: () => setState(() => _tab = item.$1),
                child: SizedBox(
                  height: 58,
                  child: Column(
                    children: [
                      Container(
                        height: 2,
                        color: _tab == item.$1 ? _signal : Colors.transparent,
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        item.$3,
                        size: 20,
                        color: _tab == item.$1 ? _signal : _mute,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _tab == item.$1 ? _chalk : _mute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _home() => _page(
        kicker: 'SPARGLASS',
        title: "Today's lesson.",
        children: [
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: _line)),
            child: const Text(
              'Private journal on this phone.\nNo account. No cloud. No remote AI.',
              style: TextStyle(
                color: _chalk,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _lesson(
            index: '01',
            title: 'Walk',
            body: 'Four steps back into the room.',
            onTap: () => setState(() => _tab = _Tab.walk),
          ),
          _lesson(
            index: '02',
            title: 'Four Columns',
            body: 'A rising-column breath.',
            onTap: () => setState(() => _tab = _Tab.four),
          ),
          _lesson(
            index: '03',
            title: 'Range',
            body: 'Window set to $_rangeMinutes minutes.',
            onTap: () => setState(() => _tab = _Tab.range),
          ),
          _lesson(
            index: '04',
            title: 'Tablet',
            body: 'A note that never leaves this phone.',
            onTap: () => setState(() => _tab = _Tab.tablet),
          ),
        ],
      );

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _page(
      kicker: 'WALK',
      title: 'Step ${_walkStep + 1} of ${_walkSteps.length}',
      children: [
        const SizedBox(height: 22),
        Text(
          '0${_walkStep + 1}',
          style: const TextStyle(
            fontFamily: 'Syne',
            fontSize: 64,
            height: 0.9,
            fontWeight: FontWeight.w800,
            color: _signal,
          ),
        ),
        const SizedBox(height: 8),
        Text(step.$1, style: _display(34)),
        const SizedBox(height: 12),
        Text(
          step.$2,
          style: const TextStyle(
            fontSize: 17,
            height: 1.45,
            color: _mute,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: List.generate(_walkSteps.length, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == _walkSteps.length - 1 ? 0 : 6),
                color: index <= _walkStep ? _signal : _line,
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('walk-advance'),
            onPressed: () => setState(
              () => _walkStep = (_walkStep + 1) % _walkSteps.length,
            ),
            style: _signalButton(),
            child: Text(
              _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
            ),
          ),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Inhale', 'Hold', 'Exhale', 'Rest'];
    return _page(
      kicker: 'FOUR COLUMNS',
      title: 'Rising breath.',
      children: [
        const SizedBox(height: 12),
        const Text(
          'One column for each phase. The active column rises through four counts.',
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: _mute,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 236,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final active = _breathing && index == _breathPhase;
              final rise = active ? (5 - _breathSeconds) / 4 : 0.0;
              final height = 28 + rise * 172;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        height: height,
                        decoration: BoxDecoration(
                          color: active ? _signal : _panel,
                          border: Border.all(color: active ? _signal : _line),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? _chalk : _mute,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _breathing ? '${labels[_breathPhase]} · $_breathSeconds' : 'Ready',
          style: _display(28),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('breath-toggle'),
            onPressed: _breathing ? _stopBreath : _startBreath,
            style: _signalButton(),
            child: Text(_breathing ? 'End breath' : 'Start Four Columns'),
          ),
        ),
      ],
    );
  }

  Widget _range() => _page(
        kicker: 'RANGE',
        title: 'Session window.',
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_rangeMinutes', style: _display(72)),
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 8),
                child: Text(
                  'MIN',
                  style: TextStyle(
                    color: _ice,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Stored only on this device.',
            style: TextStyle(color: _mute, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 22),
          for (final minute in _ranges)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: Key('range-$minute'),
                onTap: () => _saveRange(minute),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: _rangeMinutes == minute ? _panel : Colors.transparent,
                    border: Border.all(
                      color: _rangeMinutes == minute ? _signal : _line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$minute min',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _chalk,
                        ),
                      ),
                      const Spacer(),
                      if (_rangeMinutes == minute)
                        const Icon(Icons.check, color: _signal, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'A range is the time you allow, not a score to hit.',
            style: TextStyle(fontSize: 15, height: 1.45, color: _mute),
          ),
        ],
      );

  Widget _tablet() => _page(
        kicker: 'TABLET',
        title: 'Private journal.',
        children: [
          const SizedBox(height: 16),
          TextField(
            key: const Key('tablet-field'),
            controller: _noteController,
            minLines: 4,
            maxLines: 6,
            style: const TextStyle(color: _chalk, fontSize: 16, height: 1.4),
            cursorColor: _signal,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What did this session leave behind?',
              hintStyle: const TextStyle(color: _mute),
              filled: true,
              fillColor: _panel,
              contentPadding: const EdgeInsets.all(16),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: _line),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: _line),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: _ice, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('tablet-save'),
              onPressed: _saveNote,
              style: _signalButton(),
              child: const Text('Save note'),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text('ON THIS DEVICE', style: _kicker()),
              const Spacer(),
              Text(
                '${_notes.length}',
                style: const TextStyle(color: _mute, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_notes.isEmpty)
            const Text(
              'No notes yet. The first one stays on this phone.',
              style: TextStyle(fontSize: 15, color: _mute, height: 1.4),
            )
          else
            for (final note in _notes.take(6))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stamp(note.time),
                      style: const TextStyle(
                        color: _ice,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.body,
                      style: const TextStyle(color: _chalk, fontSize: 15, height: 1.35),
                    ),
                  ],
                ),
              ),
        ],
      );

  Widget _page({
    required String kicker,
    required String title,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        Text(kicker, style: _kicker()),
        const SizedBox(height: 8),
        Text(title, style: _display(36)),
        ...children,
      ],
    );
  }

  Widget _lesson({
    required String index,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  index,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _signal,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _chalk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: _mute,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: _mute),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _kicker({Color color = _ice}) => TextStyle(
        fontFamily: 'Syne',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: color,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Syne',
        fontSize: size,
        height: 0.96,
        fontWeight: FontWeight.w700,
        color: _chalk,
      );

  ButtonStyle _signalButton() => FilledButton.styleFrom(
        backgroundColor: _signal,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Syne',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
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
