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
  static const _leaf = Color(0xFFE7F3E2);
  static const _moss = Color(0xFF1B4332);
  static const _berry = Color(0xFFD83A66);
  static const _cream = Color(0xFFFFFBF4);
  static const _stem = Color(0xFF5E7F62);
  static const _track = Color(0xFFD3E6CC);

  static const _ranges = [2, 6, 9, 15];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 6;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Settle',
      'Stand or sit. Let the shoulders drop away from the ears.',
    ),
    (
      'Look',
      'Find one color nearby and say its name once.',
    ),
    (
      'Cross',
      'Walk to the far side of the room, then walk back.',
    ),
    (
      'Choose',
      'Pick the next small task and start it before you sit again.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('orchardbell_notes') ?? '[]';
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
      _onboarded = prefs.getBool('orchardbell_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('orchardbell_range') ?? 6;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('orchardbell_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('orchardbell_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) {
      _toast('Write a line before you save.');
      return;
    }
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'orchardbell_notes',
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
      title: 'Orchard Bell',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _leaf,
        fontFamily: 'Fraunces',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _berry,
          surface: _leaf,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _moss,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentTextStyle: const TextStyle(color: _cream, fontSize: 14),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _leaf,
              body: Center(child: CircularProgressIndicator(color: _berry)),
            )
          : _onboarded
              ? _shell()
              : _onboardingScreen(),
    );
  }

  Widget _onboardingScreen() {
    const pages = [
      (
        Icons.notifications_none_rounded,
        'A teacher\nin your pocket.',
        'Orchard Bell keeps the whole lesson on this phone.',
      ),
      (
        Icons.park_rounded,
        'Walk, then\nfill the columns.',
        'Walk is four steps across the room. Four Columns is a rising-column breath.',
      ),
      (
        Icons.draw_rounded,
        'The journal\nstays here.',
        'Tablet notes never leave the device. No account. No cloud. No remote AI.',
      ),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _leaf,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
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
                        Container(
                          width: 108,
                          height: 108,
                          decoration: const BoxDecoration(
                            color: _berry,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.$1, color: _cream, size: 48),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.$2,
                          textAlign: TextAlign.center,
                          style: _display(36),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: _stem,
                            fontWeight: FontWeight.w500,
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
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: on ? 10 : 8,
                    height: on ? 10 : 8,
                    decoration: BoxDecoration(
                      color: on ? _berry : _track,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
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
                  style: _pill(),
                  child: Text(last ? 'Begin' : 'Next'),
                ),
              ),
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: _stem, fontWeight: FontWeight.w600),
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
      backgroundColor: _leaf,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: _nav(),
            ),
            Expanded(child: IndexedStack(index: _tab.index, children: pages)),
          ],
        ),
      ),
    );
  }

  Widget _nav() {
    const items = [
      (_Tab.home, 'Home', 'tab-home'),
      (_Tab.walk, 'Walk', 'tab-walk'),
      (_Tab.four, 'Four', 'tab-four'),
      (_Tab.range, 'Range', 'tab-range'),
      (_Tab.tablet, 'Tablet', 'tab-tablet'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: Key(item.$3),
                onTap: () => setState(() => _tab = item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == item.$1 ? _berry : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FittedBox(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _tab == item.$1 ? _cream : _moss,
                      ),
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
        Text('ORCHARD BELL', style: _kicker(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Ring the practice.', style: _display(34), textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cream,
              border: Border.all(color: _moss, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_rangeMinutes min', style: _display(28)),
                const Text(
                  'window',
                  style: TextStyle(color: _stem, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _tile(
                icon: Icons.directions_walk_rounded,
                title: 'Walk',
                body: 'Four steps across the room.',
                onTap: () => setState(() => _tab = _Tab.walk),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tile(
                icon: Icons.water_drop_rounded,
                title: 'Four Columns',
                body: 'A rising-column breath.',
                onTap: () => setState(() => _tab = _Tab.four),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _tile(
                icon: Icons.timer_outlined,
                title: 'Range',
                body: 'Choose the minutes.',
                onTap: () => setState(() => _tab = _Tab.range),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tile(
                icon: Icons.draw_rounded,
                title: 'Tablet',
                body: 'A private journal.',
                onTap: () => setState(() => _tab = _Tab.tablet),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'No account. No cloud. No remote AI. Notes stay on this phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _stem, height: 1.4, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('WALK', style: _kicker(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Cross the room.', style: _display(34), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_walkSteps.length, (index) {
            final on = index == _walkStep;
            final done = index < _walkStep;
            return Container(
              width: on ? 18 : 12,
              height: on ? 18 : 12,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: on || done ? _berry : _track,
                shape: BoxShape.circle,
                border: Border.all(color: on ? _moss : Colors.transparent, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              Text(step.$1, style: _display(32), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Step ${_walkStep + 1} of ${_walkSteps.length}',
                style: const TextStyle(color: _berry, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                step.$2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.45, color: _stem),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('walk-advance'),
            onPressed: () => setState(
              () => _walkStep = (_walkStep + 1) % _walkSteps.length,
            ),
            style: _pill(),
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
        Text('FOUR COLUMNS', style: _kicker(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Let them rise.', style: _display(34), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Four vessels. The active one fills from the bottom, four counts each phase.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4, color: _stem),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 230,
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
                            final fill = active
                                ? constraints.maxHeight * (0.22 + rise * 0.78)
                                : constraints.maxHeight * 0.16;
                            return Container(
                              decoration: BoxDecoration(
                                color: _track,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                height: fill,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: active ? _berry : const Color(0xFF8FB58A),
                                  borderRadius: BorderRadius.circular(28),
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
                          fontWeight: FontWeight.w700,
                          color: active ? _berry : _stem,
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
          textAlign: TextAlign.center,
          style: _display(26),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('breath-toggle'),
            onPressed: _breathing ? _stopBreath : _startBreath,
            style: _pill(),
            child: Text(_breathing ? 'End breath' : 'Start Four Columns'),
          ),
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('How long to ring.', style: _display(34), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'This choice is stored only on your device.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _stem, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            for (final minute in _ranges)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: _rangeMinutes == minute ? _berry : _cream,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: Key('range-$minute'),
                        customBorder: const CircleBorder(),
                        onTap: () => _saveRange(minute),
                        child: Center(
                          child: Text(
                            '$minute',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _rangeMinutes == minute ? _cream : _moss,
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
        const SizedBox(height: 22),
        Text(
          '$_rangeMinutes minutes',
          textAlign: TextAlign.center,
          style: _display(22),
        ),
        const SizedBox(height: 8),
        const Text(
          'A range is permission to stop. It is not a score.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.45, color: _stem),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker(), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Private journal.', style: _display(34), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: _moss, fontSize: 16, height: 1.45),
          cursorColor: _berry,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'What did the walk leave with you?',
            hintStyle: const TextStyle(color: _stem),
            filled: true,
            fillColor: _cream,
            contentPadding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _moss, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _moss, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: _berry, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('tablet-save'),
            onPressed: _saveNote,
            style: _pill(),
            child: const Text('Save note'),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _notes.isEmpty ? 'Nothing kept yet' : '${_notes.length} on this phone',
          style: _kicker(),
        ),
        const SizedBox(height: 10),
        if (_notes.isEmpty)
          const Text(
            'The first note stays on this device.',
            style: TextStyle(color: _stem, fontSize: 15),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(
                      color: _berry,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.body,
                    style: const TextStyle(color: _moss, fontSize: 15, height: 1.35),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: children,
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cream,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _leaf,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _moss, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _moss,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12.5, height: 1.3, color: _stem),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: _berry,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        height: 1.02,
        fontWeight: FontWeight.w700,
        color: _moss,
      );

  ButtonStyle _pill() => FilledButton.styleFrom(
        backgroundColor: _berry,
        foregroundColor: _cream,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Fraunces',
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
    return '${months[time.month - 1]} ${time.day} · $h:$m';
  }
}
