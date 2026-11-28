import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_controls.dart';
import '../widgets/glass_panel.dart';
import '../widgets/patak.dart';

/// Remembers on this phone that the intro was seen, so it shows only once.
class IntroMemory {
  static const _key = 'aedex_intro_seen_v1';

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}

class _Card {
  const _Card(this.word, this.meaning, this.line, this.pose);

  final String word;
  final String meaning;
  final String line;
  final PatakPose pose;
}

/// The four steps of the "Taob, Taktak, Tuyo, Takip" clean-up campaign.
const _cards = [
  _Card(
    'Taob',
    'Tip it over',
    'Turn over pails, cups, tires and bottles so rain cannot collect in them.',
    PatakPose.wave,
  ),
  _Card(
    'Taktak',
    'Tap it',
    'Tap out the last drops and scrub the inside, where mosquitoes lay eggs.',
    PatakPose.searching,
  ),
  _Card(
    'Tuyo',
    'Dry it',
    'Dry anything that held water, then keep it somewhere the rain cannot reach.',
    PatakPose.happy,
  ),
  _Card(
    'Takip',
    'Cover it',
    'Cover water drums and jars tightly so mosquitoes cannot get in.',
    PatakPose.sleepy,
  ),
];

/// First-run intro: four swipeable cards with Patak, a Skip button and a
/// Next / Get started button. [onDone] runs on Skip and on Get started.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  bool get _last => _page == _cards.length - 1;

  void _goTo(int i) {
    // With reduce motion on, jump instead of sliding.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PatakLogo(height: 28),
                          SizedBox(height: 4),
                          Text(
                            'Find the water. Stop the bite.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AedexColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: AedexColors.ink,
                        minimumSize: const Size(56, 44),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  // Don't cut the card's soft shadow off in a straight line.
                  clipBehavior: Clip.none,
                  itemCount: _cards.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _IntroCard(card: _cards[i]),
                ),
              ),
              _CampaignLine(page: _page, onTap: _goTo),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TintButton(
                  label: _last ? 'Get started' : 'Next',
                  icon: _last ? Icons.check : Icons.arrow_forward,
                  height: 50,
                  onPressed: _last ? widget.onDone : () => _goTo(_page + 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.card});

  final _Card card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GlassPanel(
        // No blur: behind the card are only soft glows, so blurring them
        // costs work and shows nothing.
        blur: 0,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: LayoutBuilder(
          builder: (context, box) {
            // Patak shrinks on short phones so the words always fit.
            final size = (box.maxHeight * 0.45).clamp(88.0, 168.0);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Every card moves from the start: switching motion on when
                // a card arrives would swap the art and flash empty.
                Patak(pose: card.pose, size: size, animate: true),
                const SizedBox(height: 10),
                Text(
                  card.word,
                  style: aedexHeading(context, const TextStyle(fontSize: 40)),
                ),
                Text(
                  card.meaning,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AedexColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card.line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Taob · Taktak · Tuyo · Takip" as the page indicator: the current word
/// is bold ink, the others muted. Tapping a word jumps to its card.
class _CampaignLine extends StatelessWidget {
  const _CampaignLine({required this.page, required this.onTap});

  final int page;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _cards.length; i++) ...[
          if (i > 0)
            const ExcludeSemantics(
              child: Text(' · ', style: TextStyle(color: AedexColors.muted)),
            ),
          Semantics(
            button: true,
            selected: i == page,
            label: '${_cards[i].word}, card ${i + 1} of ${_cards.length}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                child: Text(
                  _cards[i].word,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: i == page ? FontWeight.w900 : FontWeight.w600,
                    color: i == page ? AedexColors.ink : AedexColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
