import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only instrument tile game. No accounts, network clients, cloud
/// sync, or remote model calls. This widget is the app entry.
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

enum _Tab { home, walk, four, range, tablet }

enum _Mark { violin, flute, harp, piano, horn, drum, sax, guitar }

class _Kit {
  const _Kit(this.name, this.tile, this.mark);

  final String name;
  final Color tile;
  final _Mark mark;
}

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
  static const _stage = Color(0xFF3A1468);
  static const _stageDeep = Color(0xFF240E48);
  static const _ink = Color(0xFF3A2412);
  static const _cream = Color(0xFFFFF6E4);
  static const _wood = Color(0xFFC4844A);
  static const _woodDark = Color(0xFF8A4E22);
  static const _gold = Color(0xFFFFD15C);
  static const _green = Color(0xFF3CBF4A);
  static const _pink = Color(0xFFFF4D8D);
  static const _dim = Color(0xFF8D6A45);

  static const _kits = <_Kit>[
    _Kit('Violin', Color(0xFFFFD56A), _Mark.violin),
    _Kit('Flute', Color(0xFF8FD4FF), _Mark.flute),
    _Kit('Harp', Color(0xFFD7B4FF), _Mark.harp),
    _Kit('Piano', Color(0xFFFFB3D1), _Mark.piano),
    _Kit('Horn', Color(0xFFFFC56E), _Mark.horn),
    _Kit('Drum', Color(0xFFFF9B8A), _Mark.drum),
    _Kit('Sax', Color(0xFFB8E986), _Mark.sax),
    _Kit('Guitar', Color(0xFFFFE08A), _Mark.guitar),
  ];

  static const _ranges = [8, 12, 20, 40];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _random = Random();
  Timer? _drillTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  List<int?> _cells = [];
  List<int> _target = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 12;
  int _columnPhase = 0;
  int _columnSeconds = 4;
  int _step = 0;
  int _level = 1;
  int _score = 0;
  int _coins = 120;
  final int _gems = 40;
  final int _lives = 5;
  int _hints = 3;
  int? _hintAt;
  int? _missAt;
  bool _setting = false;
  bool _ready = false;
  bool _onboarded = false;
  bool _pop = false;
  bool _sound = true;
  final _taps = _TapAudio();

  final _walkSteps = const [
    (
      'Pick',
      'Tap the instrument that matches the first mark.',
    ),
    (
      'Pair',
      'Tap a second tile of the same instrument.',
    ),
    (
      'Order',
      'Follow the three marks from left to right.',
    ),
    (
      'Score',
      'Clear the row and take the points.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _deal();
    _loadLocalState();
    _taps.prepare();
  }

  void _deal({bool nextLevel = false}) {
    if (nextLevel) _level++;
    final bag = <int>[for (var i = 0; i < _kits.length; i++) ...[i, i]];
    bag.shuffle(_random);
    _cells = List<int?>.from(bag);
    _hintAt = null;
    _missAt = null;
    _step = 0;
    final present = <int>[];
    for (final id in bag) {
      if (!present.contains(id)) present.add(id);
    }
    present.shuffle(_random);
    _target = present.take(3).toList();
  }

  void _pickTarget() {
    final present = <int>[];
    for (final id in _cells) {
      if (id != null && !present.contains(id)) present.add(id);
    }
    _missAt = null;
    _hintAt = null;
    if (present.length < 3) {
      _deal(nextLevel: true);
      return;
    }
    present.shuffle(_random);
    _target = present.take(3).toList();
    _step = 0;
  }

  void _onTile(int index) {
    final id = _cells[index];
    if (id == null || _target.isEmpty || _step >= _target.length) return;
    if (!_cells.contains(_target[_step])) {
      setState(_pickTarget);
      return;
    }
    if (id != _target[_step]) {
      _taps.play(hit: false, enabled: _sound);
      setState(() {
        _pop = false;
        _missAt = index;
      });
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _cells[index] = null;
      _score += 200;
      _coins += 25;
      _pop = true;
      _missAt = null;
      _hintAt = null;
      _step++;
      if (_step >= _target.length) _pickTarget();
    });
  }

  void _useHint() {
    if (_hints <= 0 || _target.isEmpty) return;
    final want = _target[_step];
    final at = _cells.indexOf(want);
    setState(() {
      _hints--;
      _hintAt = at == -1 ? null : at;
    });
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notehall_notes') ?? '[]';
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _notes = decoded.whereType<Map<String, dynamic>>().map(_Note.fromJson).toList();
    } catch (_) {
      _notes = [];
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _onboarded = prefs.getBool('notehall_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('notehall_range') ?? 12;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('notehall_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('notehall_range', minutes);
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
      'notehall_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Kept in the hall book. Private journal.');
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
    _taps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notehall',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _stage,
        fontFamily: 'Baloo2',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.dark(
          surface: _stage,
          primary: _gold,
          onPrimary: _ink,
          onSurface: _cream,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _woodDark,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: _cream,
            fontFamily: 'Baloo2',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _stage,
              body: Center(child: CircularProgressIndicator(color: _gold)),
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
        'Match the instruments\non this phone.',
        'Notehall is an instrument tile game. The board stays on this device.',
      ),
      (
        '02',
        'Collect in order.\nFill four columns.',
        'Walk shows four moves. Four Columns stacks tiles in four pits.',
      ),
      (
        '03',
        'Keep the score\nin the hall book.',
        'Tablet is a private hall book. No account. No cloud. No remote AI.',
      ),
    ];
    final page = pages[_onboardingPage];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _stage,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_stage, _stageDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NOTEHALL',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: _gold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    Text(page.$1, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _wood,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _woodDark, width: 3),
                    ),
                    child: PageView.builder(
                      controller: _onboarding,
                      itemCount: pages.length,
                      onPageChanged: (value) => setState(() => _onboardingPage = value),
                      itemBuilder: (_, index) {
                        final item = pages[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 58,
                                child: Row(
                                  children: [
                                    for (var i = 0; i < 4; i++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: _face(_kits[i + index].mark, _kits[i + index].tile),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(item.$2, style: _display(28, _ink)),
                              const SizedBox(height: 8),
                              Text(
                                item.$3,
                                style: const TextStyle(fontSize: 16, height: 1.35, color: _ink),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                    child: const Text('Skip', style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell() {
    final pages = [_home(), _walk(), _four(), _range(), _tablet()];
    return Scaffold(
      backgroundColor: _stage,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A2494), _stageDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _purse(),
              Expanded(child: IndexedStack(index: _tab.index, children: pages)),
              _dock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purse() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          _chip(Icons.monetization_on, '$_coins', const Color(0xFFFFC44D)),
          const SizedBox(width: 8),
          _chip(Icons.diamond, '$_gems', const Color(0xFF7AD0FF)),
          const Spacer(),
          _chip(Icons.favorite, '$_lives/5', _pink),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1248),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: _wood,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _woodDark, width: 2),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                key: Key(item.$3),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = item.$1),
                child: SizedBox(
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 18,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _tab == item.$1 ? _green : _woodDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _tab == item.$1 ? _ink : _woodDark,
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

  Widget _home() {
    final clock = '${_rangeMinutes.toString().padLeft(2, '0')}:00';
    return _scroll(
      children: [
        _woodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'LEVEL $_level · ORCHESTRA HALL',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                'Round of $_rangeMinutes minutes',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat(Icons.timer, clock),
                  const Spacer(),
                  Text('$_score', style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w700)),
                  if (_pop) const Text('  +200', style: TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _stat(Icons.lightbulb, '$_hints'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _sound = !_sound);
                      if (_sound) _taps.play(hit: true, enabled: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _sound ? Icons.volume_up : Icons.volume_off,
                        color: _cream,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _target.isEmpty ? 'Tap a tile' : 'Tap the ${_kits[_target[_step]].name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (_missAt != null)
                const Text(
                  'That tile is not next.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF7A2E16), fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 8),
              _boardGrid(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _woodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COLLECT & ORDER',
                style: TextStyle(color: _cream, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _target.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          height: 64,
                          child: _face(
                            _kits[_target[i]].mark,
                            i < _step ? _green : _kits[_target[i]].tile,
                            hot: i == _step,
                            label: _kits[_target[i]].name,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _tool(Icons.shuffle, () => setState(_deal)),
            _tool(Icons.ac_unit, () => setState(() => _pop = false)),
            _tool(Icons.lightbulb_outline, _useHint),
            _tool(Icons.hardware, () {
              final spare = _cells.indexWhere((id) => id != null && id != _target[_step]);
              if (spare == -1) return;
              setState(() => _cells[spare] = null);
            }),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _useHint,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E7A28), width: 2),
                ),
                child: const Text(
                  'HINT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    final kit = _kits[_walkStep];
    return _scroll(
      children: [
        Text('MOVE  0${_walkStep + 1} / 04', style: _kicker()),
        const SizedBox(height: 8),
        _woodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 72, width: 72, child: _face(kit.mark, kit.tile)),
              const SizedBox(height: 8),
              Text(step.$1, style: _display(32, _cream)),
              const SizedBox(height: 6),
              Text(step.$2, style: const TextStyle(fontSize: 17, height: 1.35, color: _cream)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _block(
          key: const Key('walk-advance'),
          label: _walkStep == _walkSteps.length - 1 ? 'Play again' : 'Next move',
          onTap: () => setState(() => _walkStep = (_walkStep + 1) % _walkSteps.length),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Pick', 'Pair', 'Order', 'Score'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 4),
        Text(
          _setting ? '${labels[_columnPhase]} · $_columnSeconds' : 'Ready',
          style: _display(28, _cream),
        ),
        const SizedBox(height: 6),
        const Text(
          'Four columns of tiles. The live column fills for four counts.',
          style: TextStyle(color: Color(0xFFE6D2F2), fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final active = _setting && index == _columnPhase;
              final filled = active ? (5 - _columnSeconds) : 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _woodDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active ? _gold : _wood, width: 2),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(4, (slot) {
                                  final on = slot >= 4 - filled;
                                  final kit = _kits[(index + slot) % _kits.length];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      height: 22,
                                      width: double.infinity,
                                      child: on ? _face(kit.mark, kit.tile) : const SizedBox.shrink(),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? _gold : const Color(0xFFE6D2F2),
                          fontSize: 12,
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
        _block(
          key: const Key('columns-toggle'),
          label: _setting ? 'Stop the match' : 'Start the match',
          onTap: _setting ? _stopColumns : _startColumns,
        ),
      ],
    );
  }

  Widget _range() {
    return _scroll(
      children: [
        Text('RANGE', style: _kicker()),
        const SizedBox(height: 4),
        Text('Hall clock.', style: _display(30, _cream)),
        const SizedBox(height: 6),
        const Text(
          'Stored only on this device.',
          style: TextStyle(color: Color(0xFFE6D2F2), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
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
                        color: _rangeMinutes == minute ? _gold : _wood,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _woodDark, width: 2),
                      ),
                      child: Text(
                        '$minute',
                        style: const TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'A range is how long this hall match stays open.',
          style: TextStyle(fontSize: 16, height: 1.35, color: _cream),
        ),
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker()),
        const SizedBox(height: 4),
        Text('Hall book.', style: _display(30, _cream)),
        const SizedBox(height: 10),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: _ink, fontSize: 16, height: 1.35),
          cursorColor: _woodDark,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Which instrument did you match?',
            hintStyle: const TextStyle(color: _dim),
            filled: true,
            fillColor: _cream,
            contentPadding: const EdgeInsets.all(14),
            border: _fieldBorder(_wood),
            enabledBorder: _fieldBorder(_wood),
            focusedBorder: _fieldBorder(_gold),
          ),
        ),
        const SizedBox(height: 12),
        _block(
          key: const Key('tablet-save'),
          label: 'Save note',
          onTap: _saveNote,
        ),
        const SizedBox(height: 14),
        if (_notes.isEmpty)
          const Text(
            'The hall book is empty. The first note stays on this phone.',
            style: TextStyle(color: Color(0xFFE6D2F2), fontSize: 15),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(color: _woodDark, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(note.body, style: const TextStyle(fontSize: 15, height: 1.35, color: _ink)),
                ],
              ),
            ),
      ],
    );
  }

  Widget _boardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = (constraints.maxWidth - 24) / 4;
        return Column(
          children: [
            for (var row = 0; row < 4; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == 3 ? 0 : 8),
                child: Row(
                  children: [
                    for (var col = 0; col < 4; col++)
                      Padding(
                        padding: EdgeInsets.only(left: col == 0 ? 0 : 8),
                        child: SizedBox(
                          width: tile,
                          height: tile,
                          child: _boardCell(row * 4 + col),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _boardCell(int index) {
    final id = index < _cells.length ? _cells[index] : null;
    if (id == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x33FFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );
    }
    final wanted = _target.isNotEmpty && _step < _target.length && id == _target[_step];
    return GestureDetector(
      key: ValueKey(wanted ? 'good-$index' : 'tile-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTile(index),
      child: _face(
        _kits[id].mark,
        _kits[id].tile,
        hot: wanted || index == _hintAt,
        miss: index == _missAt,
        label: _kits[id].name,
      ),
    );
  }

  Widget _face(_Mark mark, Color tile, {bool hot = false, bool miss = false, String? label}) {
    final border = miss ? const Color(0xFFE23B3B) : hot ? Colors.white : const Color(0xFFFFFFFF);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: hot || miss ? 4 : 2),
        boxShadow: [
          if (hot) const BoxShadow(color: _gold, spreadRadius: 3),
          const BoxShadow(color: Color(0x33000000), blurRadius: 0, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: CustomPaint(painter: _GlyphPainter(mark))),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label,
                style: const TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _woodPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _wood,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _woodDark, width: 3),
      ),
      child: child,
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: _cream, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _tool(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2A6FE0),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF184A9A), width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      children: children,
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
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E7A28), width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Baloo2',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.6),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _gold,
      );

  TextStyle _display(double size, Color color) => TextStyle(
        fontFamily: 'Baloo2',
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: color,
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

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.mark);

  final _Mark mark;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xFF5C3418)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF5C3418)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final s = size.shortestSide / 64;
    canvas.scale(s);
    switch (mark) {
      case _Mark.violin:
        canvas.drawOval(const Rect.fromLTWH(-10, -4, 20, 26), ink);
        canvas.drawLine(const Offset(0, -4), const Offset(0, -24), stroke);
        canvas.drawLine(const Offset(-7, -22), const Offset(7, -22), stroke);
      case _Mark.flute:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -5, 48, 10), const Radius.circular(6)),
          ink,
        );
        final hole = Paint()..color = const Color(0xFFFFF6E4);
        for (final x in [-12.0, -4.0, 4.0, 12.0]) {
          canvas.drawCircle(Offset(x, 0), 2.2, hole);
        }
      case _Mark.harp:
        final path = Path()
          ..moveTo(-14, 18)
          ..lineTo(12, 18)
          ..lineTo(4, -20)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF5C3418)..style = PaintingStyle.stroke..strokeWidth = 3);
        for (final x in [-6.0, 0.0, 6.0]) {
          canvas.drawLine(Offset(x, 14), Offset(x * 0.3, -8), stroke);
        }
      case _Mark.piano:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-22, -14, 44, 28), const Radius.circular(4)),
          ink,
        );
        final key = Paint()..color = const Color(0xFFFFF6E4);
        for (var i = 0; i < 5; i++) {
          canvas.drawRect(Rect.fromLTWH(-18 + i * 8, -10, 6, 20), key);
        }
      case _Mark.horn:
        canvas.drawCircle(const Offset(-6, 2), 10, ink);
        final bell = Path()
          ..moveTo(2, -2)
          ..lineTo(20, -12)
          ..lineTo(20, 10)
          ..close();
        canvas.drawPath(bell, ink);
      case _Mark.drum:
        canvas.drawOval(const Rect.fromLTWH(-16, -6, 32, 22), ink);
        canvas.drawLine(const Offset(-18, -16), const Offset(4, 2), stroke);
        canvas.drawLine(const Offset(18, -16), const Offset(-2, 2), stroke);
      case _Mark.sax:
        final sax = Path()
          ..moveTo(8, -20)
          ..quadraticBezierTo(16, -4, 6, 8)
          ..quadraticBezierTo(-2, 20, -12, 16);
        canvas.drawPath(sax, stroke..strokeWidth = 5);
        canvas.drawCircle(const Offset(8, -20), 4, ink);
      case _Mark.guitar:
        canvas.drawCircle(const Offset(0, 10), 12, ink);
        canvas.drawCircle(const Offset(0, -2), 8, ink);
        canvas.drawLine(const Offset(0, -8), const Offset(0, -24), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) => oldDelegate.mark != mark;
}

class _TapAudio {
  _TapAudio() {
    if (_inTest) return;
    final cache = AudioCache(prefix: 'packages/user_screen/assets/sounds/');
    _hit = AudioPlayer()..audioCache = cache;
    _miss = AudioPlayer()..audioCache = cache;
  }

  static bool get _inTest => Platform.environment['FLUTTER_TEST'] == 'true';

  static final _session = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  AudioPlayer? _hit;
  AudioPlayer? _miss;
  Future<void>? _preparing;

  void prepare() {
    _preparing ??= _openSession();
  }

  Future<void> _openSession() async {
    if (_inTest) return;
    try {
      await AudioPlayer.global.setAudioContext(_session);
    } catch (_) {}
  }

  void play({required bool hit, required bool enabled}) {
    if (!enabled || _inTest) return;
    prepare();
    final pending = _preparing;
    if (pending == null) return;
    pending.then((_) => _start(hit ? _hit : _miss, hit ? 'hit.wav' : 'miss.wav'));
  }

  Future<void> _start(AudioPlayer? player, String file) async {
    if (player == null) return;
    try {
      if (player.state == PlayerState.playing) {
        await player.stop();
      }
      await player.play(AssetSource(file), volume: 1, ctx: _session);
    } catch (_) {}
  }

  void dispose() {
    _hit?.dispose();
    _miss?.dispose();
  }
}
