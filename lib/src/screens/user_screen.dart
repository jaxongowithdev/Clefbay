import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only instrument bay. No accounts, network clients, cloud sync, or
/// remote model calls. This widget is the app entry.
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

enum _Tab { home, walk, four, range, tablet }

enum _Hall { map, fit, shelf, shop, card, board }

class _UserScreenState extends State<UserScreen> {
  static const _bg = Color(0xFF0B4F5C);
  static const _deep = Color(0xFF083E49);
  static const _panel = Color(0xFF167E86);
  static const _gold = Color(0xFFF6C453);
  static const _cream = Color(0xFFFFF6E8);
  static const _ink = Color(0xFF14343A);
  static const _purple = Color(0xFF7A4DCC);
  static const _mint = Color(0xFF2BB5A0);
  static const _wood = Color(0xFFE7B56A);

  static const _parts = ['Bell', 'Valve', 'Slide', 'Mouth'];
  static const _tune = ['C', 'E', 'G', 'C'];
  static const _phases = ['Fit', 'Tune', 'Check', 'Keep'];
  static const _ranges = [5, 9, 14, 22];
  static const _looks = [
    Color(0xFFE7B56A),
    Color(0xFF7AD0FF),
    Color(0xFFE25B9A),
    Color(0xFFB8E986),
  ];
  static const _walk = <(String, String)>[
    ('Open', 'Open String Forest on the map.'),
    ('Tap', 'Tap Bell, Valve, Slide, then Mouth.'),
    ('Score', 'A finished horn turns gold and scores.'),
    ('Next', 'Clear the build to open the next bay.'),
  ];
  static const _kit = <(String, IconData)>[
    ('Violin', Icons.music_note),
    ('Trumpet', Icons.campaign),
    ('Sax', Icons.graphic_eq),
    ('Harp', Icons.queue_music),
    ('Drum', Icons.album),
    ('Guitar', Icons.audiotrack),
    ('Flute', Icons.waves),
    ('Horn', Icons.volume_up),
  ];

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pages = PageController();
  final _noteCtrl = TextEditingController();
  final _taps = _TapAudio();

  _Tab _tab = _Tab.home;
  _Hall _hall = _Hall.fit;
  bool _onboarded = false;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 9;
  int _stars = 120;
  int _hints = 3;
  int _level = 1;
  int _score = 0;
  int _placed = 0;
  int _look = 0;
  int _phase = 0;
  int _count = 4;
  bool _running = false;
  bool _sound = true;
  bool _reedOpen = false;
  bool _tookStars = false;
  bool _hat = false;
  String _status = 'Ready';
  String _miss = '';
  String _instrument = 'Violin';
  String _mapNote = 'Pick a bay on this phone.';
  String _shelfNote = 'Tap an instrument.';
  String _shopNote = 'Stars stay on this phone.';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _taps.prepare();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboarded = prefs.getBool('clefbay_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('clefbay_range') ?? 9;
      _noteCtrl.text = prefs.getString('clefbay_notes') ?? '';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    _noteCtrl.dispose();
    _taps.dispose();
    super.dispose();
  }

  Future<void> _advanceOnboarding() async {
    if (_onboardingPage < 2) {
      await _pages.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clefbay_onboarded', true);
    if (!mounted) return;
    setState(() => _onboarded = true);
  }

  Future<void> _setRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clefbay_range', minutes);
  }

  void _tapPart(int index) {
    if (_placed >= _parts.length) return;
    if (index != _placed) {
      _taps.play(hit: false, enabled: _sound);
      setState(() => _miss = 'That part is not next.');
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _placed += 1;
      _miss = '';
      if (_placed == _parts.length) {
        _score += 200;
        _stars += 40;
      }
    });
  }

  void _focusNext() {
    if (_placed >= _parts.length) return;
    _taps.play(hit: true, enabled: _sound);
    setState(() => _miss = 'Next is ${_parts[_placed]}.');
  }

  void _useHint() {
    if (_placed >= _parts.length) return;
    if (_hints <= 0) {
      setState(() => _miss = 'No hints left on this phone.');
      _taps.play(hit: false, enabled: _sound);
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _hints -= 1;
      _miss = 'Next is ${_parts[_placed]}.';
    });
  }

  void _nextBay() {
    if (_placed < _parts.length) return;
    setState(() {
      _placed = 0;
      _miss = '';
      _level += 1;
    });
  }

  void _toggleColumns() {
    if (_running) {
      _timer?.cancel();
      _timer = null;
      setState(() {
        _running = false;
        _phase = 0;
        _count = 4;
        _status = 'Ready';
      });
      return;
    }
    setState(() {
      _running = true;
      _phase = 0;
      _count = 4;
      _status = 'Fit · 4';
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _count -= 1;
        if (_count <= 0) {
          _phase = (_phase + 1) % _phases.length;
          _count = 4;
        }
        _status = '${_phases[_phase]} · $_count';
      });
    });
  }

  void _takeStars() {
    if (_tookStars) {
      setState(() => _shopNote = 'Star pack already on this phone.');
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _tookStars = true;
      _stars += 40;
      _shopNote = 'Star pack kept on this phone.';
    });
  }

  void _buyHints() {
    if (_stars < 20) {
      setState(() => _shopNote = 'Need 20 stars on this phone.');
      _taps.play(hit: false, enabled: _sound);
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _stars -= 20;
      _hints += 3;
      _shopNote = 'Hint bundle kept on this phone.';
    });
  }

  void _buyHat() {
    if (_hat) {
      setState(() => _shopNote = 'Hat already on this phone.');
      return;
    }
    if (_stars < 30) {
      setState(() => _shopNote = 'Need 30 stars on this phone.');
      _taps.play(hit: false, enabled: _sound);
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _stars -= 30;
      _hat = true;
      _look = 3;
      _shopNote = 'Hat kept on this phone.';
    });
  }

  void _unlockBay() {
    if (_reedOpen) {
      setState(() => _mapNote = 'Reed Lock is open.');
      return;
    }
    if (_stars < 40) {
      setState(() => _mapNote = 'Need 40 stars on this phone.');
      _taps.play(hit: false, enabled: _sound);
      return;
    }
    _taps.play(hit: true, enabled: _sound);
    setState(() {
      _stars -= 40;
      _reedOpen = true;
      _mapNote = 'Reed Lock is open.';
    });
  }

  Future<void> _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clefbay_notes', _noteCtrl.text.trim());
    if (!mounted) return;
    _messenger.currentState?.showSnackBar(
      const SnackBar(content: Text('Kept in the field book. Private journal.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(
        fontFamily: 'Baloo2',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
      ),
      home: _onboarded ? _shell() : _onboarding(),
    );
  }

  Widget _onboarding() {
    const pages = <(String, String)>[
      ('Fit the horn\nin the bay.', 'A bay of brass and strings. Every part stays on this phone.'),
      ('Map, shelf, and shop.', 'Open a region, fit the horn, then keep the tune in your notes.'),
      ('Private by design.', 'No account. No cloud. No remote AI.'),
    ];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              const Text(
                'CLEFBAY',
                style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 28),
              ),
              Text(
                '${_onboardingPage + 1} / 3',
                style: const TextStyle(color: _cream, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _onboardingPage = index),
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          page.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _cream, fontSize: 32, fontWeight: FontWeight.w700, height: 1.05),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _gold, fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
              ),
              GestureDetector(
                key: const Key('onboarding-advance'),
                behavior: HitTestBehavior.opaque,
                onTap: _advanceOnboarding,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    last ? 'Begin' : 'Next',
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 20),
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
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _purse(),
            if (_tab == _Tab.home) _hallBar(),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  _home(),
                  _walkPage(),
                  _fourPage(),
                  _rangePage(),
                  _tabletPage(),
                ],
              ),
            ),
            _dock(),
          ],
        ),
      ),
    );
  }

  Widget _purse() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              _chip(Icons.star, '$_stars', _gold),
              const SizedBox(width: 8),
              _chip(Icons.lightbulb, '$_hints', const Color(0xFFD7B4FF)),
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
            'Bay of $_rangeMinutes minutes',
            style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _deep, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _hallBar() {
    const items = <(_Hall, String, String)>[
      (_Hall.map, 'Map', 'hall-map'),
      (_Hall.fit, 'Fit', 'hall-fit'),
      (_Hall.shelf, 'Shelf', 'hall-shelf'),
      (_Hall.shop, 'Shop', 'hall-shop'),
      (_Hall.card, 'Card', 'hall-card'),
      (_Hall.board, 'Board', 'hall-board'),
    ];
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: GestureDetector(
                  key: Key(item.$3),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _hall = item.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _hall == item.$1 ? _gold : _deep,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            color: _hall == item.$1 ? _ink : _cream,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
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
    );
  }

  Widget _home() {
    return switch (_hall) {
      _Hall.map => _map(),
      _Hall.fit => _fit(),
      _Hall.shelf => _shelf(),
      _Hall.shop => _shop(),
      _Hall.card => _card(),
      _Hall.board => _board(),
    };
  }

  Widget _fit() {
    final status = _placed == _parts.length
        ? 'built'
        : (_miss.isEmpty ? 'Tap Bell, then Valve, Slide, and Mouth.' : _miss);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          const Text(
            'LẮP GHÉP',
            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          Text(
            'LEVEL $_level · $_score',
            style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: DecoratedBox(
              decoration: _cardDec(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Expanded(
                      child: IgnorePointer(child: CustomPaint(painter: _HornPainter())),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'GHI NHỚ GIAI ĐIỆU',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _tune.length; i++)
                                Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i < _placed ? _gold : _deep,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _tune[i],
                                    style: TextStyle(
                                      color: i < _placed ? _ink : _cream,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = ((constraints.maxWidth - 24) / 4).clamp(44.0, 64.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (var i = 0; i < _parts.length; i++) _partTile(i, size)],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _goldButton('fit-focus', 'LẮP GHÉP\nCÁC PHẦN', _focusNext)),
              const SizedBox(width: 8),
              Expanded(
                child: _mintButton('try-sound', 'CHƠI THỬ\nÂM THANH', () {
                  _taps.play(hit: true, enabled: _sound);
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_placed == _parts.length)
                GestureDetector(
                  key: const Key('next-bay'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _nextBay,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Next bay', style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                  ),
                ),
              for (var i = 0; i < 3; i++)
                GestureDetector(
                  key: ValueKey('hint-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _useHint,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                    child: const Icon(Icons.lightbulb, color: _cream, size: 16),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partTile(int index, double size) {
    final done = index < _placed;
    final next = index == _placed && _placed < _parts.length;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        key: ValueKey('part-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapPart(index),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: done ? _mint : _wood,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: next ? _cream : const Color(0xFFC4893E), width: next ? 3 : 1),
          ),
          child: Center(
            child: Text(
              _parts[index],
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  Widget _map() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          _profile(),
          const SizedBox(height: 8),
          _region('String Forest', 'LEVEL 1', Icons.park, true, 'region-string'),
          _region('Brass Canyon', 'LEVEL 5', Icons.landscape, true, 'region-brass'),
          _region('Reed Lock', _reedOpen ? 'Open' : 'Locked', Icons.lock, _reedOpen, 'region-reed'),
          Text(_mapNote, style: const TextStyle(color: _gold, fontSize: 12)),
          const Spacer(),
          _goldButton('unlock-bay', 'MỞ KHÓA KHU VỰC MỚI', _unlockBay),
        ],
      ),
    );
  }

  Widget _profile() {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: _cardDec(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _looks[_look],
            child: Icon(_hat ? Icons.school : Icons.person, color: _ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Player1', style: TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                Text('Stars $_stars · Level $_level', style: const TextStyle(color: _gold, fontSize: 12)),
                Text('Most played $_instrument', style: const TextStyle(color: _cream, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            key: const Key('look-swap'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _look = (_look + 1) % _looks.length),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                'ĐỔI\nNGOẠI HÌNH',
                textAlign: TextAlign.center,
                style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _region(String name, String sub, IconData icon, bool open, String keyName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        key: Key(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!open) {
            setState(() => _mapNote = 'This bay is still locked.');
            _taps.play(hit: false, enabled: _sound);
            return;
          }
          setState(() => _hall = _Hall.fit);
          _taps.play(hit: true, enabled: _sound);
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _cardDec(gold: open),
          child: Row(
            children: [
              Icon(icon, color: _gold),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                    Text(sub, style: const TextStyle(color: _gold, fontSize: 11)),
                  ],
                ),
              ),
              Icon(open ? Icons.star : Icons.lock, color: open ? _gold : _cream, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shelf() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SƯU TẬP',
            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          Text(_shelfNote, style: const TextStyle(color: _gold, fontSize: 12)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 18) / 4;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in _kit)
                    SizedBox(
                      width: width,
                      height: 72,
                      child: GestureDetector(
                        key: ValueKey('shelf-${item.$1.toLowerCase()}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _taps.play(hit: true, enabled: _sound);
                          setState(() {
                            _instrument = item.$1;
                            _shelfNote = '${item.$1} is in the bay.';
                            _hall = _Hall.card;
                          });
                        },
                        child: DecoratedBox(
                          decoration: _cardDec(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.$2, color: _gold, size: 22),
                              Text(item.$1, style: const TextStyle(color: _cream, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          const Text(
            'TÌM KIẾM NHẠC CỤ',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text(
            _instrument.toUpperCase(),
            style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 28),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: _cardDec(),
              child: const Center(
                child: IgnorePointer(
                  child: SizedBox(width: 180, height: 120, child: CustomPaint(painter: _HornPainter())),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A bay tune kept on this phone.',
            style: TextStyle(color: _cream, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _mintButton('replay-tune', 'NGHE LẠI GIAI ĐIỆU', () {
            _taps.play(hit: true, enabled: _sound);
          }),
        ],
      ),
    );
  }

  Widget _shop() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CỬA HÀNG',
            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          Text(_shopNote, style: const TextStyle(color: _gold, fontSize: 12)),
          const SizedBox(height: 8),
          _pack('STAR PACK', '+40 stars', 'NHẬN SAO', _takeStars, 'take-stars'),
          _pack('HINT PACK', '+3 hints · 20 stars', 'MUA NGAY', _buyHints, 'buy-hints'),
          _pack('SPECIAL HAT', '30 stars', 'MUA MŨ', _buyHat, 'buy-hat'),
        ],
      ),
    );
  }

  Widget _pack(String title, String detail, String action, VoidCallback onTap, String keyName) {
    return Container(
      height: 72,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _cardDec(),
      child: Row(
        children: [
          const Icon(Icons.star, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(color: _gold, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            key: Key(keyName),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(12)),
              child: Text(action, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    final rows = [
      ('1', 'BrassCaptain', '11', '350'),
      ('2', 'StringWarden', '8', '240'),
      ('3', 'Player1', '$_level', '$_stars'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'BẢNG XẾP HẠNG',
            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          const Text('On this phone only.', style: TextStyle(color: _gold, fontSize: 12)),
          const SizedBox(height: 8),
          for (final row in rows)
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _cardDec(gold: row.$2 == 'Player1'),
              child: Row(
                children: [
                  Text('#${row.$1}', style: const TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  const CircleAvatar(radius: 14, backgroundColor: _wood, child: Icon(Icons.person, size: 16, color: _ink)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.$2, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700))),
                  Text('Lv ${row.$3}', style: const TextStyle(color: _gold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(row.$4, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _walkPage() {
    final step = _walk[_walkStep];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(step.$1, style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Text(step.$2, style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22)),
          const Spacer(),
          _goldButton('walk-advance', _walkStep == _walk.length - 1 ? 'Done' : 'Next move', () {
            if (_walkStep >= _walk.length - 1) return;
            setState(() => _walkStep += 1);
          }),
        ],
      ),
    );
  }

  Widget _fourPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 28),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(
              children: [
                for (var i = 0; i < _phases.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _running && i == _phase ? _gold : _panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _phases[i],
                        style: TextStyle(color: _running && i == _phase ? _ink : _cream, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          _goldButton('columns-toggle', _running ? 'Stop the bay' : 'Start the bay', _toggleColumns),
        ],
      ),
    );
  }

  Widget _rangePage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How long is this bay?',
            style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 8),
          for (final minutes in _ranges) ...[
            SizedBox(
              height: 64,
              child: GestureDetector(
                key: Key('range-$minutes'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _setRange(minutes),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _rangeMinutes == minutes ? _gold : _panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$minutes min',
                      style: TextStyle(
                        color: _rangeMinutes == minutes ? _ink : _cream,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _tabletPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Field book', style: TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 22)),
          const Text('Private journal on this phone.', style: TextStyle(color: _gold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('tablet-field'),
            controller: _noteCtrl,
            style: const TextStyle(color: _cream),
            decoration: InputDecoration(
              hintText: 'Which part did you fit?',
              hintStyle: const TextStyle(color: Color(0x99FFF6E8)),
              filled: true,
              fillColor: _deep,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          _goldButton('tablet-save', 'Save', _saveNote),
        ],
      ),
    );
  }

  Widget _dock() {
    return Container(
      color: _deep,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _dockItem(Icons.map, 'Home', _Tab.home, 'tab-home'),
          _dockItem(Icons.directions_walk, 'Walk', _Tab.walk, 'tab-walk'),
          _dockItem(Icons.view_column, 'Four', _Tab.four, 'tab-four'),
          _dockItem(Icons.timelapse, 'Range', _Tab.range, 'tab-range'),
          _dockItem(Icons.menu_book, 'Tablet', _Tab.tablet, 'tab-tablet'),
        ],
      ),
    );
  }

  Widget _dockItem(IconData icon, String label, _Tab tab, String keyName) {
    final on = _tab == tab;
    return Expanded(
      child: GestureDetector(
        key: Key(keyName),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = tab),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: on ? _gold : _cream, size: 22),
            Text(label, style: TextStyle(color: on ? _gold : _cream, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _goldButton(String keyName, String label, VoidCallback onTap) {
    return GestureDetector(
      key: Key(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(14)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13, height: 1.1),
        ),
      ),
    );
  }

  Widget _mintButton(String keyName, String label, VoidCallback onTap) {
    return GestureDetector(
      key: Key(keyName),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(14)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _cream, fontWeight: FontWeight.w700, fontSize: 13, height: 1.1),
        ),
      ),
    );
  }

  BoxDecoration _cardDec({bool gold = true}) {
    return BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: gold ? _gold : const Color(0xFF0E6270), width: 1.5),
    );
  }
}

class _HornPainter extends CustomPainter {
  const _HornPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final brass = Paint()..color = const Color(0xFFF6C453);
    final body = RRect.fromLTRBR(4, size.height * 0.42, size.width * 0.62, size.height * 0.64, Radius.circular(size.height * 0.08));
    canvas.drawRRect(body, brass);
    final bell = Path()
      ..moveTo(size.width * 0.55, size.height * 0.32)
      ..lineTo(size.width * 0.94, size.height * 0.12)
      ..lineTo(size.width * 0.94, size.height * 0.90)
      ..lineTo(size.width * 0.55, size.height * 0.72)
      ..close();
    canvas.drawPath(bell, Paint()..color = const Color(0xFFE8A317));
    final valve = Paint()..color = const Color(0xFFFFF6E8);
    for (final x in [0.18, 0.32, 0.46]) {
      canvas.drawCircle(Offset(size.width * x, size.height * 0.40), size.height * 0.07, valve);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
