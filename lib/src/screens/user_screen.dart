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
  static const _paper = Color(0xFFE7EBF2);
  static const _sheet = Color(0xFFF4F6FA);
  static const _ink = Color(0xFF16181D);
  static const _amber = Color(0xFFF0A202);
  static const _rule = Color(0xFFC5CCD6);
  static const _mute = Color(0xFF5C6570);

  static const _ranges = [5, 10, 15, 25];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 10;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Still',
      'Stop where you are. Let both feet go quiet.',
    ),
    (
      'Frame',
      'Choose one rectangle: a window, a door, or a picture.',
    ),
    (
      'Travel',
      'Walk the edge of that rectangle, then return.',
    ),
    (
      'Note',
      'Name one thing that is different now that you are back.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('amberwick_notes') ?? '[]';
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
      _onboarded = prefs.getBool('amberwick_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('amberwick_range') ?? 10;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('amberwick_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('amberwick_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a line before you file it.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'amberwick_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Filed on this device. Private journal.');
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
      title: 'Amberwick',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        fontFamily: 'IBM Plex Mono',
        colorScheme: ColorScheme.fromSeed(seedColor: _amber, surface: _paper),
        splashFactory: NoSplash.splashFactory,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: _amber,
            fontFamily: 'IBM Plex Mono',
            fontSize: 13,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _paper,
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
        'A teacher\non this phone.',
        'Amberwick files the whole lesson on the device. Nothing is sent away.',
      ),
      (
        '02',
        'Walk, then\nraise a column.',
        'Walk is four steps. Four Columns is a rising-column breath.',
      ),
      (
        '03',
        'File the note\nhere.',
        'Tablet is a private journal. No account. No cloud. No remote AI.',
      ),
    ];
    final page = pages[_onboardingPage];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'AMBERWICK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    page.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _mute),
                  ),
                ],
              ),
              const SizedBox(height: 18),
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
                        Container(width: 42, height: 8, color: _amber),
                        const SizedBox(height: 18),
                        Text(item.$2, style: _display(36)),
                        const SizedBox(height: 14),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: _mute,
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
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                  style: _block(),
                  child: Text(last ? 'Begin' : 'Next'),
                ),
              ),
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: _mute, fontWeight: FontWeight.w500),
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
      backgroundColor: _paper,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 8, color: _amber),
                  Expanded(
                    child: IndexedStack(index: _tab.index, children: pages),
                  ),
                ],
              ),
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _footer() {
    const items = [
      (_Tab.home, 'Home', 'tab-home'),
      (_Tab.walk, 'Walk', 'tab-walk'),
      (_Tab.four, 'Four', 'tab-four'),
      (_Tab.range, 'Range', 'tab-range'),
      (_Tab.tablet, 'Tablet', 'tab-tablet'),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: _sheet,
        border: Border(top: BorderSide(color: _ink, width: 1.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                key: Key(items[i].$3),
                onTap: () => setState(() => _tab = items[i].$1),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == items[i].$1 ? _amber : _sheet,
                    border: Border(
                      left: BorderSide(
                        color: i == 0 ? Colors.transparent : _rule,
                      ),
                    ),
                  ),
                  child: Text(
                    items[i].$2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
        Text('AMBERWICK', style: _kicker()),
        const SizedBox(height: 8),
        Text('Open the ledger.', style: _display(32)),
        const SizedBox(height: 6),
        Text(
          'Window $_rangeMinutes min · on this phone',
          style: const TextStyle(color: _mute, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _row(
          code: '01',
          title: 'Walk',
          body: 'Four steps around one frame.',
          onTap: () => setState(() => _tab = _Tab.walk),
        ),
        _row(
          code: '02',
          title: 'Four Columns',
          body: 'A rising-column breath.',
          onTap: () => setState(() => _tab = _Tab.four),
        ),
        _row(
          code: '03',
          title: 'Range',
          body: 'Set the minutes for this sitting.',
          onTap: () => setState(() => _tab = _Tab.range),
        ),
        _row(
          code: '04',
          title: 'Tablet',
          body: 'File a private note.',
          onTap: () => setState(() => _tab = _Tab.tablet),
        ),
        const SizedBox(height: 16),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _walk() {
    return _scroll(
      children: [
        Text('WALK', style: _kicker()),
        const SizedBox(height: 8),
        Text('Follow the edge.', style: _display(32)),
        const SizedBox(height: 16),
        for (var i = 0; i < _walkSteps.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            color: i == _walkStep ? _amber : _sheet,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '0${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _walkSteps[i].$1,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      if (i == _walkStep) ...[
                        const SizedBox(height: 4),
                        Text(
                          _walkSteps[i].$2,
                          style: const TextStyle(fontSize: 14, height: 1.4, color: _ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('walk-advance'),
            onPressed: () => setState(
              () => _walkStep = (_walkStep + 1) % _walkSteps.length,
            ),
            style: _block(),
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
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 8),
        Text('Raise one line.', style: _display(32)),
        const SizedBox(height: 8),
        const Text(
          'A plot of four columns. The active column rises for four counts.',
          style: TextStyle(fontSize: 14, height: 1.45, color: _mute),
        ),
        const SizedBox(height: 16),
        Container(
          height: 230,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          decoration: BoxDecoration(
            color: _sheet,
            border: Border.all(color: _ink, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final active = _breathing && index == _breathPhase;
              final rise = active ? (5 - _breathSeconds) / 4 : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final height = active
                                ? constraints.maxHeight * (0.12 + rise * 0.88)
                                : constraints.maxHeight * 0.08;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                height: height,
                                width: double.infinity,
                                color: active ? _amber : _rule,
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
                          fontWeight: FontWeight.w600,
                          color: active ? _ink : _mute,
                        ),
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
          style: _display(22),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('breath-toggle'),
            onPressed: _breathing ? _stopBreath : _startBreath,
            style: _block(),
            child: Text(_breathing ? 'End breath' : 'Start Four Columns'),
          ),
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker()),
        const SizedBox(height: 8),
        Text('Minutes on file.', style: _display(32)),
        const SizedBox(height: 8),
        const Text(
          'Stored only on this device.',
          style: TextStyle(color: _mute, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final minute in _ranges)
          InkWell(
            key: Key('range-$minute'),
            onTap: () => _saveRange(minute),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: _rangeMinutes == minute ? _amber : Colors.transparent,
                border: const Border(bottom: BorderSide(color: _rule)),
              ),
              child: Row(
                children: [
                  Text(
                    '$minute',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'minutes',
                    style: TextStyle(color: _mute, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_rangeMinutes == minute)
                    const Text(
                      'SET',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'A range is a limit you give yourself, not a mark to beat.',
          style: TextStyle(fontSize: 14, height: 1.45, color: _mute),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker()),
        const SizedBox(height: 8),
        Text('Private journal.', style: _display(32)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: _ink, fontSize: 15, height: 1.45),
          cursorColor: _ink,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'File what the walk left behind.',
            hintStyle: TextStyle(color: _mute),
            filled: true,
            fillColor: _sheet,
            contentPadding: EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _ink, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _ink, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _amber, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('tablet-save'),
            onPressed: _saveNote,
            style: _block(),
            child: const Text('Save note'),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _notes.isEmpty ? 'FILE EMPTY' : 'ON THIS DEVICE  ${_notes.length}',
          style: _kicker(),
        ),
        const SizedBox(height: 8),
        if (_notes.isEmpty)
          const Text(
            'The first line stays on this phone.',
            style: TextStyle(color: _mute, fontSize: 14),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _rule)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(fontSize: 11, color: _mute),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.body,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: _ink),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: children,
    );
  }

  Widget _row({
    required String code,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _ink, width: 1)),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 28, color: _amber),
            const SizedBox(width: 10),
            SizedBox(
              width: 28,
              child: Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 12, color: _mute),
                  ),
                ],
              ),
            ),
            const Text('>', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: _mute,
      );

  TextStyle _display(double size) => TextStyle(
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  ButtonStyle _block() => FilledButton.styleFrom(
        backgroundColor: _ink,
        foregroundColor: _amber,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontWeight: FontWeight.w600,
          fontSize: 15,
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
