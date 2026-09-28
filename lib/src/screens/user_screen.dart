import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A private, device-only practice teacher. It deliberately has no accounts,
/// network clients, cloud sync, or remote model integration.
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
        time:
            DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class _UserScreenState extends State<UserScreen> {
  static const _navy = Color(0xFF182B3A);
  static const _paper = Color(0xFFF7F5EF);
  static const _sand = Color(0xFFE9E4D7);
  static const _copper = Color(0xFFE9774F);
  static const _sky = Color(0xFFB9DCE3);
  static const _sage = Color(0xFFABC6A6);

  final _noteController = TextEditingController();
  final _onboarding = PageController();
  Timer? _breathTimer;
  SharedPreferences? _prefs;
  List<_Note> _notes = [];
  _Tab _tab = _Tab.home;
  int _onboardingPage = 0;
  int _walkStep = 0;
  int _rangeMinutes = 5;
  int _breathPhase = 0;
  int _breathSeconds = 4;
  bool _breathing = false;
  bool _ready = false;
  bool _onboarded = false;

  final _walkSteps = const [
    (
      'Arrive',
      'Set both feet on the floor. Let your shoulders fall.',
      Icons.chair_alt_outlined,
    ),
    (
      'Notice',
      'Name three things you can see, without judging them.',
      Icons.visibility_outlined,
    ),
    (
      'Move',
      'Take four slow steps. Feel heel, foot, then ground.',
      Icons.directions_walk_outlined,
    ),
    (
      'Return',
      'Choose one useful next action for this moment.',
      Icons.arrow_outward_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('quiet_columns_notes') ?? '[]';
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
      _onboarded = prefs.getBool('quiet_columns_onboarded') ?? false;
      _rangeMinutes = prefs.getInt('quiet_columns_range') ?? 5;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding() async {
    await _prefs?.setBool('quiet_columns_onboarded', true);
    if (mounted) setState(() => _onboarded = true);
  }

  Future<void> _saveRange(int minutes) async {
    setState(() => _rangeMinutes = minutes);
    await _prefs?.setInt('quiet_columns_range', minutes);
  }

  Future<void> _saveNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty) return;
    final note = _Note(body: body, time: DateTime.now());
    setState(() {
      _notes = [note, ..._notes];
      _noteController.clear();
    });
    await _prefs?.setString(
      'quiet_columns_notes',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved privately on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      title: 'Morrow Steps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _navy, surface: _paper),
        fontFamily: 'Roboto',
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _onboarded
              ? _shell()
              : _onboardingScreen(),
    );
  }

  Widget _onboardingScreen() {
    const pages = [
      (
        'A private teacher\nfor your attention.',
        'A calm practice space that lives entirely on this device.',
        Icons.waves_rounded,
        _sky,
      ),
      (
        'Small practices,\nclear steps.',
        'Walk when you need to arrive. Use Four Columns when you need to reset.',
        Icons.route_outlined,
        _sage,
      ),
      (
        'Your words stay\nwith you.',
        'Tablet notes are saved locally. No account. No cloud. No remote AI.',
        Icons.edit_note_rounded,
        Color(0xFFF4C8A8),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _onboarding,
                itemCount: pages.length,
                onPageChanged: (value) =>
                    setState(() => _onboardingPage = value),
                itemBuilder: (_, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(30, 20, 30, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: page.$4,
                            borderRadius: BorderRadius.circular(38),
                          ),
                          child: Icon(page.$3, size: 56, color: _navy),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.$1,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 1.04,
                            letterSpacing: -1.5,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.$2,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.45,
                            color: Color(0xFF53626B),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 6),
                        height: 7,
                        width: index == _onboardingPage ? 26 : 7,
                        decoration: BoxDecoration(
                          color: index == _onboardingPage ? _navy : _sand,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _onboardingPage == pages.length - 1
                        ? _finishOnboarding
                        : () => _onboarding.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 15,
                      ),
                    ),
                    child: Text(
                      _onboardingPage == pages.length - 1 ? 'Begin' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell() {
    final pages = [_home(), _walk(), _four(), _range(), _tablet()];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab.index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: _sky,
        selectedIndex: _tab.index,
        onDestinationSelected: (index) =>
            setState(() => _tab = _Tab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon: Icon(Icons.directions_walk_rounded),
            label: 'Walk',
          ),
          NavigationDestination(
            icon: Icon(Icons.vertical_align_center_rounded),
            selectedIcon: Icon(Icons.vertical_align_center_rounded),
            label: 'Four',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Range',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.edit_note_rounded),
            label: 'Tablet',
          ),
        ],
      ),
    );
  }

  Widget _home() => _pageFrame(
        eyebrow: 'MORROW STEPS',
        title: 'What would\nhelp right now?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _practiceCard(
              color: _sky,
              icon: Icons.directions_walk_rounded,
              title: 'Walk',
              body: 'A four-step return to the room.',
              action: 'Start walking',
              onTap: () => setState(() => _tab = _Tab.walk),
            ),
            const SizedBox(height: 14),
            _practiceCard(
              color: _sage,
              icon: Icons.vertical_align_center_rounded,
              title: 'Four Columns',
              body: 'A rising-column breath for steady attention.',
              action: 'Breathe now',
              onTap: () => setState(() => _tab = _Tab.four),
            ),
            const SizedBox(height: 22),
            _offlineMark(),
          ],
        ),
      );

  Widget _walk() {
    final step = _walkSteps[_walkStep];
    return _pageFrame(
      eyebrow: 'WALK · ${_walkStep + 1} OF ${_walkSteps.length}',
      title: 'A short way\nback to here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _sand),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _sky,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(step.$3, color: _navy, size: 30),
                ),
                const SizedBox(height: 32),
                Text(
                  step.$1,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.$2,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    color: Color(0xFF53626B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LinearProgressIndicator(
            value: (_walkStep + 1) / _walkSteps.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(12),
            backgroundColor: _sand,
            color: _copper,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(
                () => _walkStep = (_walkStep + 1) % _walkSteps.length,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
              icon: Icon(
                _walkStep == _walkSteps.length - 1
                    ? Icons.replay_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(
                _walkStep == _walkSteps.length - 1 ? 'Walk again' : 'Next step',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _four() {
    const labels = ['Inhale', 'Hold', 'Exhale', 'Rest'];
    return _pageFrame(
      eyebrow: 'FOUR COLUMNS',
      title: 'Let the breath\nrise and fall.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Text(
            'Follow one column at a time. Every phase is four soft counts.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF53626B),
            ),
          ),
          const SizedBox(height: 34),
          SizedBox(
            height: 224,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (index) {
                final active = index == _breathPhase;
                final height = [92.0, 145.0, 196.0, 124.0][index];
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 360),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: active && _breathing ? height + 18 : height,
                    decoration: BoxDecoration(
                      color: active ? _copper : _sand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : _navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              _breathing
                  ? '${labels[_breathPhase]} · $_breathSeconds'
                  : 'Ready when you are',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _breathing ? _stopBreath : _startBreath,
              icon: Icon(
                _breathing
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded,
              ),
              label: Text(_breathing ? 'End practice' : 'Begin four breaths'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _range() => _pageFrame(
        eyebrow: 'RANGE',
        title: 'Make room\nfor the moment.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _sky,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Practice window',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_rangeMinutes minutes',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      color: _navy,
                    ),
                  ),
                  const Text(
                    'This choice is stored only on your device.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF53626B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Choose a range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [3, 5, 7, 10]
                  .map(
                    (minute) => ChoiceChip(
                      label: Text('$minute min'),
                      selected: _rangeMinutes == minute,
                      onSelected: (_) => _saveRange(minute),
                      selectedColor: _sage,
                      side: BorderSide(
                        color: _rangeMinutes == minute ? _sage : _sand,
                      ),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 30),
            const Text(
              'A range is a permission, not a target. Take the time you have; leave the rest.',
              style: TextStyle(
                  fontSize: 17, height: 1.5, color: Color(0xFF53626B)),
            ),
          ],
        ),
      );

  Widget _tablet() => _pageFrame(
        eyebrow: 'TABLET · PRIVATE NOTE',
        title: 'Put it down\nin your own words.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 21),
            TextField(
              controller: _noteController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What are you noticing?',
                hintStyle: const TextStyle(color: Color(0xFF818C92)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(18),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: _sand),
                  borderRadius: BorderRadius.circular(20),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _sand),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _navy, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Save on this device'),
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Text(
                  'Saved notes',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_notes.length} local',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF53626B)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  'Nothing saved yet. Your first note will appear here.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF53626B)),
                ),
              )
            else
              ..._notes.take(4).map(
                    (note) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _sand),
                      ),
                      child: Text(
                        note.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: _navy,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      );

  Widget _pageFrame({
    required String eyebrow,
    required String title,
    required Widget child,
  }) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.35,
                color: _copper,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                height: 1.04,
                letterSpacing: -1.3,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            child,
          ],
        ),
      );

  Widget _practiceCard({
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _navy, size: 32),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF465963),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: _navy),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _offlineMark() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _sand),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: _navy),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Private by design\nNo account · No cloud · No remote AI',
                style: TextStyle(fontSize: 14, height: 1.35, color: _navy),
              ),
            ),
          ],
        ),
      );
}
