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
  static const _mist = Color(0xFFF4EEF8);
  static const _plum = Color(0xFF2C2142);
  static const _violet = Color(0xFF6D4AFF);
  static const _lilac = Color(0xFFE4D7FF);
  static const _card = Color(0xFFFFFFFF);
  static const _mute = Color(0xFF6E6480);

  static const _ranges = [4, 9, 14, 24];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 9;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Anchor',
      'Place both feet and name the floor.',
    ),
    (
      'Sweep',
      'Let your eyes cross the room once.',
    ),
    (
      'Pace',
      'Walk to the nearest doorway and back.',
    ),
    (
      'Pin',
      'Say the one task you will do next.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('plumline_notes') ?? '[]';
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
      _onboarded = prefs.getBool('plumline_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('plumline_range') ?? 9;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('plumline_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('plumline_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a line before you keep it.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'plumline_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Kept on this phone. Private journal.');
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
      title: 'Plumline',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _mist,
        fontFamily: 'Figtree',
        colorScheme: ColorScheme.fromSeed(seedColor: _violet, surface: _mist),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _plum,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontFamily: 'Figtree',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _mist,
              body: Center(child: CircularProgressIndicator(color: _violet)),
            )
          : _onboarded
              ? _shell()
              : _onboardingScreen(),
    );
  }

  Widget _onboardingScreen() {
    const pages = [
      (
        'A line to\nfollow.',
        'Plumline is a teacher that stays on this phone.',
      ),
      (
        'Walk the thread.\nThen breathe.',
        'Walk is four steps. Four Columns is a rising-column breath.',
      ),
      (
        'Pin a private\nnote.',
        'Tablet keeps a journal here. No account. No cloud. No remote AI.',
      ),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _bead(18, _violet),
                  const SizedBox(width: 8),
                  const Text(
                    'PLUMLINE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: _plum,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_onboardingPage + 1}/3',
                    style: const TextStyle(color: _mute, fontWeight: FontWeight.w700),
                  ),
                ],
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: 12,
                              top: -28,
                              child: _bead(72, _lilac),
                            ),
                            Text(page.$1, style: _display(40)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.$2,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: _mute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: _mute, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('onboarding-advance'),
                    onPressed: last
                        ? _finishOnboarding
                        : () => _onboarding.nextPage(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            ),
                    style: _violetButton(padH: 26),
                    child: Text(last ? 'Begin' : 'Next'),
                  ),
                ],
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
      backgroundColor: _mist,
      body: Row(
        children: [
          Expanded(
            child: SafeArea(
              right: false,
              child: IndexedStack(index: _tab.index, children: pages),
            ),
          ),
          _rail(),
        ],
      ),
    );
  }

  Widget _rail() {
    const items = [
      (_Tab.home, 'Home', Icons.hub_outlined, 'tab-home'),
      (_Tab.walk, 'Walk', Icons.straighten, 'tab-walk'),
      (_Tab.four, 'Four', Icons.linear_scale, 'tab-four'),
      (_Tab.range, 'Range', Icons.timelapse, 'tab-range'),
      (_Tab.tablet, 'Tablet', Icons.sticky_note_2_outlined, 'tab-tablet'),
    ];
    return Container(
      width: 76,
      color: _plum,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            for (final item in items)
              Expanded(
                child: GestureDetector(
                  key: Key(item.$4),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tab = item.$1),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$3,
                          size: 20,
                          color: _tab == item.$1 ? _lilac : Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontFamily: 'Figtree',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _tab == item.$1 ? _lilac : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: _tab == item.$1 ? 16 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _lilac,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _home() {
    return _scroll(
      children: [
        Text('PLUMLINE', style: _kicker()),
        const SizedBox(height: 6),
        Text('Pick a thread.', style: _display(34)),
        const SizedBox(height: 6),
        Text(
          'Thread of $_rangeMinutes minutes',
          style: const TextStyle(color: _mute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        _thread(
          offset: 0,
          title: 'Walk',
          body: 'Four steps along one line.',
          onTap: () => setState(() => _tab = _Tab.walk),
        ),
        _thread(
          offset: 36,
          title: 'Four Columns',
          body: 'A rising-column breath.',
          onTap: () => setState(() => _tab = _Tab.four),
        ),
        _thread(
          offset: 0,
          title: 'Range',
          body: 'How long this thread runs.',
          onTap: () => setState(() => _tab = _Tab.range),
        ),
        _thread(
          offset: 36,
          title: 'Tablet',
          body: 'A note pinned on this phone.',
          onTap: () => setState(() => _tab = _Tab.tablet),
        ),
        const SizedBox(height: 8),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(color: _plum, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('WALK', style: _kicker()),
        const SizedBox(height: 6),
        Text(step.$1, style: _display(40)),
        const SizedBox(height: 8),
        Text(
          step.$2,
          style: const TextStyle(
            fontSize: 17,
            height: 1.4,
            color: _mute,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: List.generate(_walkSteps.length, (index) {
            final on = index <= _walkStep;
            return Expanded(
              child: Row(
                children: [
                  _bead(on ? 14 : 10, on ? _violet : _lilac),
                  if (index != _walkSteps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: index < _walkStep ? _violet : _lilac,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_walkStep + 1} of ${_walkSteps.length}',
          style: const TextStyle(color: _violet, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('walk-advance'),
          onPressed: () => setState(
            () => _walkStep = (_walkStep + 1) % _walkSteps.length,
          ),
          style: _violetButton(padH: 22),
          child: Text(
            _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
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
        const SizedBox(height: 6),
        Text('Raise the bead.', style: _display(32)),
        const SizedBox(height: 8),
        const Text(
          'Four threads. The active bead rises for four counts.',
          style: TextStyle(fontSize: 15, height: 1.4, color: _mute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final active = _breathing && index == _breathPhase;
              final rise = active ? (5 - _breathSeconds) / 4 : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final thread = active
                                ? constraints.maxHeight * (0.18 + rise * 0.82)
                                : constraints.maxHeight * 0.12;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                height: thread,
                                width: 36,
                                child: Column(
                                  children: [
                                    _bead(16, active ? _violet : _lilac),
                                    Expanded(
                                      child: Center(
                                        child: Container(
                                          width: 3,
                                          color: active ? _violet : _lilac,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? _violet : _mute,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _breathing ? '${labels[_breathPhase]} · $_breathSeconds' : 'Ready',
          style: _display(24),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('breath-toggle'),
          onPressed: _breathing ? _stopBreath : _startBreath,
          style: _violetButton(padH: 22),
          child: Text(_breathing ? 'End breath' : 'Start Four Columns'),
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker()),
        const SizedBox(height: 6),
        Text('Length of the thread.', style: _display(30)),
        const SizedBox(height: 6),
        const Text(
          'Stored only on this device.',
          style: TextStyle(color: _mute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < _ranges.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (final minute in _ranges.skip(i).take(2))
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: Material(
                          color: _rangeMinutes == minute ? _violet : _card,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: Key('range-$minute'),
                            customBorder: const CircleBorder(),
                            onTap: () => _saveRange(minute),
                            child: Center(
                              child: Text(
                                '$minute',
                                style: TextStyle(
                                  fontFamily: 'Figtree',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: _rangeMinutes == minute ? Colors.white : _plum,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Text(
          'A range is how far the thread goes, not a score.',
          style: TextStyle(fontSize: 15, height: 1.4, color: _mute, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker()),
        const SizedBox(height: 6),
        Text('Private journal.', style: _display(32)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: _plum, fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
          cursorColor: _violet,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Pin what the thread left behind.',
            hintStyle: const TextStyle(color: _mute),
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _violet, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('tablet-save'),
            onPressed: _saveNote,
            style: _violetButton(padH: 22),
            child: const Text('Save note'),
          ),
        ),
        const SizedBox(height: 20),
        if (_notes.isEmpty)
          const Text(
            'Nothing pinned yet. The first note stays on this phone.',
            style: TextStyle(color: _mute, fontWeight: FontWeight.w600, height: 1.4),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bead(12, _violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stamp(note.time),
                          style: const TextStyle(
                            color: _violet,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.body,
                          style: const TextStyle(
                            color: _plum,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 24),
      children: children,
    );
  }

  Widget _thread({
    required double offset,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: offset, bottom: 10),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                _bead(12, _violet),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _plum)),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(fontSize: 13, color: _mute, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bead(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontFamily: 'Figtree',
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: _violet,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Figtree',
        fontSize: size,
        height: 1.02,
        fontWeight: FontWeight.w800,
        color: _plum,
      );

  ButtonStyle _violetButton({required double padH}) => FilledButton.styleFrom(
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.w800,
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
