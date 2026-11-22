import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class _Page {
  const _Page(this.scene, this.imageLabel, this.title, this.text, this.primary, {this.secondary});
  final int scene;
  final String imageLabel;
  final String title;
  final String text;
  final String primary;
  final String? secondary;
}

const List<_Page> _pages = <_Page>[
  _Page(1, 'Memo waving hello', 'Keep what you find.',
      'Cemo saves links and notes into conversations, so the good things you come across are easy to find again.', 'Get started'),
  _Page(2, 'A link flying from a browser page to Memo', 'Save from any app.',
      'Tap Share in your browser, YouTube or anywhere else, then choose Cemo.', 'Continue'),
  _Page(3, 'Memo beside three conversation rows', 'Every category is a conversation.',
      'Reading list, Work, Recipes. Each one keeps its notes in order, like messages to yourself.', 'Continue'),
  _Page(4, 'Memo writing on a note card', 'Write it down in seconds.',
      'Tap the button in the bottom bar to add text, a link or a checklist.', 'Continue'),
  _Page(5, 'Memo holding a bell next to a notification', 'Get reminded at the right time.',
      'Set a reminder on any note and Cemo will notify you when it is due.', 'Allow notifications',
      secondary: 'Not now'),
  _Page(6, 'Memo pointing at a starred note', 'Star what matters.',
      'Press and hold a note to star it. Starred notes get their own tab in the conversation.', 'Continue'),
  _Page(7, 'Memo with a magnifying glass over highlighted text', 'Find anything again.',
      'Search across every note, link and conversation. Matches are highlighted.', 'Continue'),
  _Page(8, 'Memo pointing at the Cemo widget on a phone', 'Start from your Home Screen.',
      'Add the Cemo widget to open a conversation in one tap and see today’s reminders.', 'Start using Cemo'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => AppScope.of(context).finishOnboarding();

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    // TODO: on the Reminders page, request notification permission here.
    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final _Page page = _pages[_index];
    final bool last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Semantics(
                      label: 'Step ${_index + 1} of ${_pages.length}',
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < _pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _index ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _index ? c.t1 : c.t3,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: _finish,
                        child: Text('Skip', style: Tx.ui(context).copyWith(color: c.t2)),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) {
                  final _Page p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints box) {
                                final double side = box.biggest.shortestSide.clamp(120.0, 330.0).toDouble();
                                return MemoImage(p.scene, size: side, label: p.imageLabel);
                              },
                            ),
                          ),
                        ),
                        Text(p.title, style: Tx.serifTitle(context, size: 30)),
                        const SizedBox(height: 10),
                        Text(p.text, style: Tx.excerpt(context).copyWith(fontSize: 17, height: 26 / 17)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: <Widget>[
                  PillButton(label: page.primary, onPressed: _next),
                  SizedBox(
                    height: 44,
                    child: page.secondary == null
                        ? null
                        : TextButton(
                            onPressed: _next,
                            child: Text(page.secondary!, style: Tx.ui(context)),
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
}
