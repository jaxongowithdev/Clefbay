import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only teacher for parlor instrument games. No accounts, network
/// clients, cloud sync, or remote model calls.
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
  static const _cream = Color(0xFFFFF4E0);
  static const _ink = Color(0xFF24160C);
  static const _walnut = Color(0xFF3A2415);
  static const _gold = Color(0xFFE8A317);
  static const _coral = Color(0xFFE24B3B);
  static const _teal = Color(0xFF1C8C78);
  static const _navy = Color(0xFF243E73);
  static const _ivory = Color(0xFFFFFDF8);
  static const _mute = Color(0xFF8A7360);

  static const _ranges = [3, 7, 11, 21];
  static const _barColors = [_coral, _gold, _teal, _navy];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _drillTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 7;
  int _columnPhase = 0;
  int _columnSeconds = 4;
  bool _setting = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Pluck',
      'Pinch one string and count four rings before it fades.',
    ),
    (
      'Tap',
      'Strike the drum head once, then lift your hand away.',
    ),
    (
      'Reed',
      'Cover one hole and play a short note on the pipe.',
    ),
    (
      'Shake',
      'Shake the bell twice and set it down on the table.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bandkit_notes') ?? '[]';
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
      _onboarded = prefs.getBool('bandkit_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('bandkit_range') ?? 7;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('bandkit_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('bandkit_range', minutes);
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
      'bandkit_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Kept in the band book. Private journal.');
  }

  void _toast(String message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startColumns() {
    _drillTimer?.cancel();
    setState(() {
      _setting = true;
      _columnPhase = 0;
      _columnSeconds = 4;
    });
    _drillTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_columnSeconds > 1) {
          _columnSeconds--;
        } else {
          _columnPhase = (_columnPhase + 1) % 4;
          _columnSeconds = 4;
        }
      });
    });
  }

  void _stopColumns() {
    _drillTimer?.cancel();
    setState(() => _setting = false);
  }

  @override
  void dispose() {
    _drillTimer?.cancel();
    _noteController.dispose();
    _onboarding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bandkit',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        fontFamily: 'Fredoka',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.light(
          surface: _cream,
          primary: _walnut,
          onPrimary: Colors.white,
          onSurface: _ink,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _walnut,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'Fredoka',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _cream,
              body: Center(child: CircularProgressIndicator(color: _coral)),
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
        'A band of games\non this phone.',
        'Bandkit teaches four instrument games and stores the score only on the device.',
      ),
      (
        '02',
        'Walk the games.\nRaise four bars.',
        'Walk plays four instruments. Four Columns lifts four wooden bars.',
      ),
      (
        '03',
        'Keep the score\nin the book.',
        'Tablet is a private band book. No account. No cloud. No remote AI.',
      ),
    ];
    final page = pages[_onboardingPage];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'BANDKIT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _walnut,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    page.$1,
                    style: const TextStyle(color: _coral, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _card(
                  child: PageView.builder(
                    controller: _onboarding,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _onboardingPage = value),
                    itemBuilder: (_, index) {
                      final item = pages[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bars(height: 28),
                            const SizedBox(height: 16),
                            Text(item.$2, style: _display(30)),
                            const SizedBox(height: 12),
                            Text(
                              item.$3,
                              style: const TextStyle(fontSize: 16, height: 1.4, color: _mute),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _block(
                key: const Key('onboarding-advance'),
                label: last ? 'Begin' : 'Next',
                onTap: last
                    ? _finishOnboarding
                    : () => _onboarding.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        ),
              ),
              Center(
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: _walnut, fontWeight: FontWeight.w600),
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
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: IndexedStack(index: _tab.index, children: pages)),
            _keybed(),
          ],
        ),
      ),
    );
  }

  Widget _keybed() {
    const items = [
      (_Tab.home, 'Home', 'tab-home', _walnut),
      (_Tab.walk, 'Walk', 'tab-walk', _coral),
      (_Tab.four, 'Four', 'tab-four', _gold),
      (_Tab.range, 'Range', 'tab-range', _teal),
      (_Tab.tablet, 'Tablet', 'tab-tablet', _navy),
    ];
    return Container(
      color: _walnut,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: Key(item.$3),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = item.$1),
                child: Container(
                  height: _tab == item.$1 ? 62 : 50,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _tab == item.$1 ? item.$4 : _ivory,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border.all(color: _ink, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _tab == item.$1 ? _ivory : _ink,
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
        Text('ROUND', style: _kicker()),
        const SizedBox(height: 4),
        Text('Open the band.', style: _display(34)),
        const SizedBox(height: 4),
        Text(
          'Round of $_rangeMinutes minutes',
          style: const TextStyle(fontSize: 16, color: _coral, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _link('Walk', 'Four instrument games, one after another.', _coral, () {
          setState(() => _tab = _Tab.walk);
        }),
        _link('Four Columns', 'Lift four wooden bars in turn.', _gold, () {
          setState(() => _tab = _Tab.four);
        }),
        _link('Range', 'How long this round of games lasts.', _teal, () {
          setState(() => _tab = _Tab.range);
        }),
        _link('Tablet', 'A private note in the band book.', _navy, () {
          setState(() => _tab = _Tab.tablet);
        }),
        const SizedBox(height: 6),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(fontWeight: FontWeight.w600, color: _ink),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    final color = _barColors[_walkStep];
    return _scroll(
      children: [
        Text('GAME  0${_walkStep + 1} / 04', style: _kicker()),
        const SizedBox(height: 8),
        _card(
          stripe: color,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.$1, style: _display(36)),
                const SizedBox(height: 8),
                Text(
                  step.$2,
                  style: const TextStyle(fontSize: 17, height: 1.4, color: _ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(4, (index) {
            final on = index == _walkStep;
            return Container(
              width: on ? 28 : 12,
              height: 12,
              margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
              decoration: BoxDecoration(
                color: index <= _walkStep ? _barColors[index] : const Color(0xFFE7D7C0),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        _block(
          key: const Key('walk-advance'),
          label: _walkStep == _walkSteps.length - 1 ? 'Play again' : 'Next game',
          onTap: () => setState(() => _walkStep = (_walkStep + 1) % _walkSteps.length),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Cue', 'Strike', 'Ring', 'Cut'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 6),
        Text('Lift the bars.', style: _display(32)),
        const SizedBox(height: 6),
        const Text(
          'Four wooden bars. The live bar rises for four counts.',
          style: TextStyle(fontSize: 15, height: 1.4, color: _mute),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final active = _setting && index == _columnPhase;
              final rise = active ? (5 - _columnSeconds) / 4 : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final height = active
                                ? constraints.maxHeight * (0.18 + rise * 0.82)
                                : constraints.maxHeight * 0.16;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                height: height,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _barColors[index],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active ? _ink : _barColors[index],
                                    width: active ? 2 : 0,
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
                          fontSize: 13,
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
        const SizedBox(height: 12),
        Text(
          _setting ? '${labels[_columnPhase]} · $_columnSeconds' : 'Ready',
          style: _display(24),
        ),
        const SizedBox(height: 14),
        _block(
          key: const Key('columns-toggle'),
          label: _setting ? 'Stop columns' : 'Start Four Columns',
          onTap: _setting ? _stopColumns : _startColumns,
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker()),
        const SizedBox(height: 6),
        Text('Round length.', style: _display(32)),
        const SizedBox(height: 6),
        const Text(
          'Stored only on this device.',
          style: TextStyle(color: _mute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
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
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _rangeMinutes == minute ? _teal : _ivory,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _ink, width: 1.3),
                      ),
                      child: Text(
                        '$minute',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _rangeMinutes == minute ? _ivory : _ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'A range is how long you keep the instrument games going.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _ink),
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
        const SizedBox(height: 12),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 4,
          maxLines: 6,
          style: const TextStyle(color: _ink, fontSize: 16, height: 1.4),
          cursorColor: _coral,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Which game did you play?',
            hintStyle: const TextStyle(color: _mute),
            filled: true,
            fillColor: _ivory,
            contentPadding: const EdgeInsets.all(14),
            border: _fieldBorder(_walnut),
            enabledBorder: _fieldBorder(_walnut),
            focusedBorder: _fieldBorder(_coral),
          ),
        ),
        const SizedBox(height: 12),
        _block(
          key: const Key('tablet-save'),
          label: 'Save note',
          onTap: _saveNote,
        ),
        const SizedBox(height: 18),
        if (_notes.isEmpty)
          const Text(
            'The band book is empty. The first note stays on this phone.',
            style: TextStyle(color: _mute, fontSize: 15),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7D7C0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(color: _coral, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(note.body, style: const TextStyle(fontSize: 15, height: 1.35, color: _ink)),
                ],
              ),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: children,
    );
  }

  Widget _card({required Widget child, Color? stripe}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink, width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: stripe == null
          ? child
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 10, color: stripe),
                  Expanded(child: child),
                ],
              ),
            ),
    );
  }

  Widget _bars({required double height}) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 18,
              height: height * (0.45 + i * 0.15),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _barColors[i],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _link(String title, String body, Color stripe, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _card(
          stripe: stripe,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(body, style: const TextStyle(color: _mute, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _block({
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
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _coral,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ivory,
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.4),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: _gold,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Fredoka',
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: _ink,
      );

  String _stamp(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${months[time.month - 1]} ${time.day}  $h:$m';
  }
}
