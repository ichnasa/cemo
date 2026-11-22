import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// Send feedback, then a short thank-you state.
/// Nothing is sent anywhere yet: wire `_send` to your backend or an email API.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const List<String> _kinds = <String>['Problem', 'Idea', 'Praise', 'Something else'];
  static const int _maxLength = 1000;

  final TextEditingController _text = TextEditingController();
  final TextEditingController _email = TextEditingController();
  int _kind = 1;
  bool _includeDevice = true;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _email.dispose();
    super.dispose();
  }

  void _send() {
    // TODO: send _kinds[_kind], _text.text, _email.text and _includeDevice to your backend.
    FocusScope.of(context).unfocus();
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    if (_sent) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const MemoImage(14, size: 190, label: 'Memo winking, holding an envelope with a green check'),
                      const SizedBox(height: 20),
                      Text('Thanks, we got it.', textAlign: TextAlign.center, style: Tx.serifTitle(context, size: 28)),
                      const SizedBox(height: 8),
                      Text(
                        'We read every message. If you left an email, we will reply there.',
                        textAlign: TextAlign.center,
                        style: Tx.excerpt(context),
                      ),
                    ],
                  ),
                ),
                PillButton(label: 'Back to Cemo', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      );
    }

    final bool canSend = _text.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: <Widget>[
                  Text('Tell us what would make Cemo better.', style: Tx.serifTitle(context, size: 28)),
                  const SizedBox(height: 20),
                  Text('What is it about?', style: Tx.caption(context)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (int i = 0; i < _kinds.length; i++)
                        Semantics(
                          selected: i == _kind,
                          button: true,
                          child: GestureDetector(
                            onTap: () => setState(() => _kind = i),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == _kind ? c.primaryFill : null,
                                border: i == _kind ? null : Border.all(color: c.border),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _kinds[i],
                                style: Tx.ui(context).copyWith(color: i == _kind ? c.primaryText : c.t1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Your feedback', style: Tx.caption(context)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _text,
                    maxLines: 6,
                    maxLength: _maxLength,
                    style: Tx.bodySerif(context),
                    decoration: InputDecoration(
                      hintText: 'What happened, or what would you like to see?',
                      hintStyle: Tx.bodySerif(context).copyWith(color: c.t3),
                      filled: true,
                      fillColor: c.bg2,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Email for a reply (optional)', style: Tx.caption(context)),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: Tx.ui(context).copyWith(fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      hintStyle: Tx.ui(context).copyWith(fontSize: 17, color: c.t3),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.t1)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(child: Text('Include app version and device model', style: Tx.ui(context))),
                      Switch(
                        value: _includeDevice,
                        activeTrackColor: c.accent,
                        onChanged: (bool v) => setState(() => _includeDevice = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider, width: 0.5))),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: PillButton(label: 'Send feedback', onPressed: canSend ? _send : null),
            ),
          ],
        ),
      ),
    );
  }
}
