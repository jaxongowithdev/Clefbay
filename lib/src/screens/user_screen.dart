import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only word hunt. No accounts, network clients, cloud sync, or remote
/// model calls. This widget is the app entry.
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

enum _Tab { home, walk, four, range, tablet }

class _HuntWord {
  _HuntWord(this.text, this.cells);

  final String text;
  final List<int> cells;
  bool found = false;
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
  static const _forest = Color(0xFF146B3A);
  static const _forestDeep = Color(0xFF0C4A28);
  static const _panel = Color(0xFF1E7A42);
  static const _wood = Color(0xFFE7B56A);
  static const _woodDark = Color(0xFFC4893E);
  static const _ink = Color(0xFF4A2E14);
  static const _cream = Color(0xFFFFF6E4);
  static const _gold = Color(0xFFFFD15C);
  static const _leaf = Color(0xFF7DDE6A);
  static const _find = Color(0xFF2EAE45);

  static const _ranges = [5, 9, 14, 22];
  static const _cols = 5;

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _taps = _TapAudio();
  Timer? _drillTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  List<String> _letters = [];
  List<_HuntWord> _words = [];
  List<int> _picked = [];
  Set<int> _hintCells = {};
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 9;
  int _columnPhase = 0;
  int _columnSeconds = 4;
  int _level = 1;
  int _score = 0;
  int _coins = 240;
  final int _gems = 18;
  int _hints = 3;
  bool _setting = false;
  bool _ready = false;
  bool _onboarded = false;
  bool _sound = true;
  bool _miss = false;

  final _walkSteps = const [
    (
      'Scan',
      'Read the target words under the grid.',
    ),
    (
      'Trace',
      'Tap the letters of one word from left to right.',
    ),
    (
      'Mark',
      'A finished word turns green and scores.',
    ),
    (
      'Hunt',
      'Clear the list to open the next glade.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBoard(0);
    _loadLocalState();
    _taps.prepare();
  }

  void _loadBoard(int index) {
    const boards = [
      (
        'PATHYFINDRLORESQUESTMOSSA',
        [
          ('PATH', [0, 1, 2, 3]),
          ('FIND', [5, 6, 7, 8]),
          ('LORE', [10, 11, 12, 13]),
          ('QUEST', [15, 16, 17, 18, 19]),
        ],
      ),
      (
        'QUESTPATHMFINDRLORESBRAKE',
        [
          ('QUEST', [0, 1, 2, 3, 4]),
          ('PATH', [5, 6, 7, 8]),
          ('FIND', [10, 11, 12, 13]),
          ('LORE', [15, 16, 17, 18]),
        ],
      ),
    ];
    final board = boards[index % boards.length];
    _letters = board.$1.split('');
    _words = [
      for (final word in board.$2) _HuntWord(word.$1, word.$2),
    ];
    _picked = [];
    _hintCells = {};
    _miss = false;
  }

  void _tapCell(int index) {
    if (_words.any((word) => word.found && word.cells.contains(index))) return;
    setState(() {
      _miss = false;
      if (_picked.isEmpty) {
        _picked = [index];
      } else if (_picked.last == index) {
        return;
      } else if (index == _picked.last + 1 && index ~/ _cols == _picked.last ~/ _cols) {
        _picked = [..._picked, index];
      } else {
        _picked = [index];
      }
      final spelled = _picked.map((cell) => _letters[cell]).join();
      final match = _words.where((word) => !word.found && word.text == spelled);
      if (match.isNotEmpty) {
        match.first.found = true;
        _score += 200;
        _coins += 40;
        _picked = [];
        _hintCells = {};
        _taps.play(hit: true, enabled: _sound);
        if (_words.every((word) => word.found)) {
          _level++;
          _loadBoard(_level - 1);
        }
        return;
      }
      final prefix = _words.any((word) => !word.found && word.text.startsWith(spelled));
      if (!prefix) {
        _picked = [];
        _miss = true;
        _taps.play(hit: false, enabled: _sound);
      }
    });
  }

  void _showFind() {
    final next = _words.where((word) => !word.found);
    if (next.isEmpty || _hints <= 0) return;
    setState(() {
      _hints--;
      _hintCells = next.first.cells.toSet();
    });
    _taps.play(hit: true, enabled: _sound);
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('fernquest_notes') ?? '[]';
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _notes = decoded.whereType<Map<String, dynamic>>().map(_Note.fromJson).toList();
    } catch (_) {
      _notes = [];
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _onboarded = prefs.getBool('fernquest_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('fernquest_range') ?? 9;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('fernquest_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('fernquest_range', minutes);
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
      'fernquest_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Kept in the field book. Private journal.');
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

  int get _foundCount => _words.where((word) => word.found).length;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fernquest',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _forest,
        fontFamily: 'Baloo2',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.dark(
          surface: _forest,
          primary: _gold,
          onPrimary: _ink,
          onSurface: _cream,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _forestDeep,
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
              backgroundColor: _forest,
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
        'Find the words\nin the glade.',
        'Fernquest is a word hunt. The grid stays on this device.',
      ),
      (
        '02',
        'Trace four moves.\nFill four columns.',
        'Walk shows how to trace a word. Four Columns stacks four letter rows.',
      ),
      (
        '03',
        'Keep the find\nin the book.',
        'Tablet is a private field book. No account. No cloud. No remote AI.',
      ),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _forest,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_forest, _forestDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FERNQUEST',
                  style: TextStyle(color: _gold, fontWeight: FontWeight.w700, letterSpacing: 1.4, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _leaf, width: 2),
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
                              Text(item.$1, style: const TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(item.$2, style: _display(28, _cream)),
                              const SizedBox(height: 8),
                              Text(item.$3, style: const TextStyle(fontSize: 16, height: 1.35, color: _cream)),
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
      backgroundColor: _forest,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E8A48), _forestDeep],
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              _chip(Icons.monetization_on, '$_coins', _gold),
              const SizedBox(width: 8),
              _chip(Icons.diamond, '$_gems', const Color(0xFF7AD0FF)),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _sound = !_sound);
                  if (_sound) _taps.play(hit: true, enabled: true);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(_sound ? Icons.volume_up : Icons.volume_off, color: _cream, size: 20),
                ),
              ),
            ],
          ),
          Text(
            'Trail of $_rangeMinutes minutes',
            style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _forestDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _forestDeep,
        borderRadius: BorderRadius.circular(16),
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
                  height: 44,
                  child: Center(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _tab == item.$1 ? _gold : const Color(0xFFB7D8C0),
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
        Text(
          'LEVEL $_level · FERN GLADE',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                i < _foundCount.clamp(0, 3) ? Icons.star : Icons.star_border,
                color: _gold,
                size: 22,
              ),
            const SizedBox(width: 8),
            Text(
              '$_foundCount/${_words.length} words',
              style: const TextStyle(color: _cream, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text('$_score', style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        if (_miss)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'That is not a word on the list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFFD0D0), fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 8),
        _board(),
        const SizedBox(height: 10),
        _targetCard(),
        const SizedBox(height: 10),
        Row(
          children: [
            _roundTool(Icons.search, 'Hint', _showFind),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showFind,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _find,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF166B28), width: 2),
                  ),
                  child: const Text(
                    'FIND',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = ((constraints.maxWidth - 32) / _cols).clamp(44.0, 64.0);
        return Center(
          child: SizedBox(
            width: tile * _cols + 32,
            child: Column(
              children: [
                for (var row = 0; row < _cols; row++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var col = 0; col < _cols; col++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: SizedBox(
                              width: tile,
                              height: tile,
                              child: _cell(row * _cols + col),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(int index) {
    final found = _words.any((word) => word.found && word.cells.contains(index));
    final picked = _picked.contains(index);
    final hinted = _hintCells.contains(index);
    final color = found ? _leaf : _wood;
    return GestureDetector(
      key: ValueKey(found ? 'found-$index' : 'cell-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapCell(index),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: picked || hinted ? Colors.white : _woodDark,
            width: picked || hinted ? 3 : 1.4,
          ),
          boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            _letters[index],
            style: TextStyle(
              color: _ink,
              fontFamily: 'Baloo2',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _forestDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _leaf),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TARGET', style: TextStyle(color: _gold, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 6),
          for (final word in _words)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(word.text, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  Text(
                    word.found ? 'found' : '${word.text.length} left',
                    style: TextStyle(
                      color: word.found ? _leaf : _gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundTool(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2A6FE0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('MOVE  0${_walkStep + 1} / 04', style: _kicker()),
        const SizedBox(height: 8),
        Text(step.$1, style: _display(34, _cream)),
        const SizedBox(height: 8),
        Text(step.$2, style: const TextStyle(fontSize: 17, height: 1.35, color: _cream)),
        const SizedBox(height: 16),
        _block(
          key: const Key('walk-advance'),
          label: _walkStep == _walkSteps.length - 1 ? 'Hunt again' : 'Next move',
          onTap: () => setState(() => _walkStep = (_walkStep + 1) % _walkSteps.length),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Seek', 'Trace', 'Mark', 'Keep'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 4),
        Text(
          _setting ? '${labels[_columnPhase]} · $_columnSeconds' : 'Ready',
          style: _display(28, _cream),
        ),
        const SizedBox(height: 8),
        const Text(
          'Four letter rows. The live row fills for four counts.',
          style: TextStyle(color: _cream, fontSize: 15, height: 1.35),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
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
                            color: _forestDeep,
                            borderRadius: BorderRadius.circular(12),
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
                                  return Container(
                                    height: 16,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: on ? _wood : const Color(0xFF1A5C34),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[index], style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 12)),
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
          label: _setting ? 'Stop the hunt' : 'Start the hunt',
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
        Text('Trail clock.', style: _display(30, _cream)),
        const SizedBox(height: 6),
        const Text('Stored only on this device.', style: TextStyle(color: _cream, fontWeight: FontWeight.w600)),
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
      ],
    );
  }

  Widget _tablet() {
    return _scroll(
      children: [
        Text('TABLET', style: _kicker()),
        const SizedBox(height: 4),
        Text('Field book.', style: _display(30, _cream)),
        const SizedBox(height: 10),
        TextField(
          key: const Key('tablet-field'),
          controller: _noteController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: _ink, fontSize: 16),
          cursorColor: _forestDeep,
          decoration: InputDecoration(
            hintText: 'Which word did you find?',
            filled: true,
            fillColor: _cream,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        _block(key: const Key('tablet-save'), label: 'Save note', onTap: _saveNote),
        const SizedBox(height: 14),
        if (_notes.isEmpty)
          const Text(
            'The field book is empty. The first note stays on this phone.',
            style: TextStyle(color: _cream),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(14)),
              child: Text(note.body, style: const TextStyle(color: _ink, fontSize: 15)),
            ),
      ],
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
          color: _find,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontFamily: 'Baloo2', fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
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
      if (player.state == PlayerState.playing) await player.stop();
      await player.play(AssetSource(file), volume: 1, ctx: _session);
    } catch (_) {}
  }

  void dispose() {
    _hit?.dispose();
    _miss?.dispose();
  }
}
