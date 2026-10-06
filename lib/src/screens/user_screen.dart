import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only layout teacher. No accounts, network clients, cloud sync,
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
  static const _sheet = Color(0xFFF3F6FA);
  static const _ink = Color(0xFF102033);
  static const _line = Color(0xFF1E4E7A);
  static const _rule = Color(0xFFD3DDE8);
  static const _reg = Color(0xFFD7263D);
  static const _paper = Color(0xFFFFFFFF);

  static const _ranges = [5, 15, 25, 45];

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _drillTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 15;
  int _columnPhase = 0;
  int _columnSeconds = 4;
  bool _setting = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Head',
      'Mark the top edge of the sheet, one finger in from the trim.',
    ),
    (
      'Gutter',
      'Draw the inner fold where the page will bend.',
    ),
    (
      'Foot',
      'Mark the bottom edge so the text block sits above it.',
    ),
    (
      'Fore',
      'Mark the outer edge and lock the page box.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cropmark_notes') ?? '[]';
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
      _onboarded = prefs.getBool('cropmark_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('cropmark_range') ?? 15;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('cropmark_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('cropmark_range', minutes);
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
      'cropmark_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    _toast('Kept on this sheet. Private journal.');
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
      title: 'Cropmark',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _sheet,
        fontFamily: 'Barlow',
        splashFactory: NoSplash.splashFactory,
        colorScheme: const ColorScheme.light(
          surface: _sheet,
          primary: _line,
          onPrimary: Colors.white,
          onSurface: _ink,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontFamily: 'Barlow',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: _sheet,
              body: Center(child: CircularProgressIndicator(color: _line)),
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
        'A press lesson\non this phone.',
        'Cropmark teaches a sheet layout and stores it only on the device.',
      ),
      (
        '02',
        'Walk the margins.\nSet four columns.',
        'Walk marks the page box. Four Columns raises four columns of type.',
      ),
      (
        '03',
        'Keep the note\non the sheet.',
        'Tablet is a private printer’s log. No account. No cloud. No remote AI.',
      ),
    ];
    final page = pages[_onboardingPage];
    final last = _onboardingPage == pages.length - 1;
    return Scaffold(
      backgroundColor: _sheet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _regDot(),
                  const SizedBox(width: 8),
                  const Text(
                    'CROPMARK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  Text(page.$1, style: const TextStyle(color: _line, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _frame(
                  child: PageView.builder(
                    controller: _onboarding,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _onboardingPage = value),
                    itemBuilder: (_, index) {
                      final item = pages[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2, style: _display(32)),
                            const SizedBox(height: 12),
                            Text(
                              item.$3,
                              style: const TextStyle(fontSize: 16, height: 1.4, color: _line),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text('Skip', style: TextStyle(color: _line, fontWeight: FontWeight.w600)),
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
      backgroundColor: _sheet,
      body: SafeArea(
        child: Column(
          children: [
            _titleBar(),
            Expanded(child: IndexedStack(index: _tab.index, children: pages)),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() {
    const items = [
      (_Tab.home, 'Home', 'tab-home'),
      (_Tab.walk, 'Walk', 'tab-walk'),
      (_Tab.four, 'Four', 'tab-four'),
      (_Tab.range, 'Range', 'tab-range'),
      (_Tab.tablet, 'Tablet', 'tab-tablet'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _paper,
        border: Border(bottom: BorderSide(color: _line, width: 1.5)),
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
                      if (_tab == item.$1) _regDot(size: 6) else const SizedBox(height: 6),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _tab == item.$1 ? _ink : _line,
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
    return _scroll(
      children: [
        Text('SHEET 01', style: _kicker()),
        const SizedBox(height: 6),
        Text('Open the sheet.', style: _display(34)),
        const SizedBox(height: 4),
        Text(
          'Sheet of $_rangeMinutes minutes',
          style: const TextStyle(fontSize: 16, color: _line, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _link('Walk', 'Four margin marks around the page.', () => setState(() => _tab = _Tab.walk)),
        _link('Four Columns', 'Raise four columns of type.', () => setState(() => _tab = _Tab.four)),
        _link('Range', 'How long this press run lasts.', () => setState(() => _tab = _Tab.range)),
        _link('Tablet', 'A private note on this sheet.', () => setState(() => _tab = _Tab.tablet)),
        const SizedBox(height: 8),
        const Text(
          'No account. No cloud. No remote AI.',
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    );
  }

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _scroll(
      children: [
        Text('WALK  0${_walkStep + 1} / 04', style: _kicker()),
        const SizedBox(height: 8),
        _frame(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.$1, style: _display(36)),
                const SizedBox(height: 8),
                Text(
                  step.$2,
                  style: const TextStyle(fontSize: 17, height: 1.4, color: _line),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                color: index <= _walkStep ? _reg : _rule,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        _block(
          key: const Key('walk-advance'),
          label: _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
          onTap: () => setState(() => _walkStep = (_walkStep + 1) % _walkSteps.length),
        ),
      ],
    );
  }

  Widget _four() {
    const labels = ['Set', 'Lead', 'Lock', 'Pull'];
    return _scroll(
      children: [
        Text('FOUR COLUMNS', style: _kicker()),
        const SizedBox(height: 6),
        Text('Raise the type.', style: _display(32)),
        const SizedBox(height: 6),
        const Text(
          'Four columns on the page. The active column rises for four counts.',
          style: TextStyle(fontSize: 15, height: 1.4, color: _line),
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
                                  color: active ? _line : _rule,
                                  border: Border.all(color: _ink, width: 1.2),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? _reg : _line,
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
        Text('Press run.', style: _display(32)),
        const SizedBox(height: 6),
        const Text(
          'Stored only on this device.',
          style: TextStyle(color: _line, fontWeight: FontWeight.w600),
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
                        color: _rangeMinutes == minute ? _ink : _paper,
                        border: Border.all(color: _ink, width: 1.4),
                      ),
                      child: Text(
                        '$minute',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _rangeMinutes == minute ? Colors.white : _ink,
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
          'A range is how long you keep the sheet on the board.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _line),
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
          cursorColor: _reg,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What did this sheet need?',
            hintStyle: TextStyle(color: Color(0xFF6D7C8C)),
            filled: true,
            fillColor: _paper,
            contentPadding: EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _line, width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _line, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _reg, width: 1.8),
            ),
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
            'The log is empty. The first note stays on this phone.',
            style: TextStyle(color: _line, fontSize: 15),
          )
        else
          for (final note in _notes.take(6))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: _rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stamp(note.time),
                    style: const TextStyle(color: _reg, fontSize: 12, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: children,
    );
  }

  Widget _frame({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: _line, width: 1.4),
      ),
      child: child,
    );
  }

  Widget _link(String title, String body, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _frame(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _regDot(size: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(body, style: const TextStyle(color: _line, fontSize: 13)),
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
        color: _ink,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Barlow',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _regDot({double size = 8}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _reg, shape: BoxShape.circle),
    );
  }

  TextStyle _kicker() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: _reg,
      );

  TextStyle _display(double size) => TextStyle(
        fontFamily: 'Barlow',
        fontSize: size,
        height: 1.02,
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
