import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

// These screens are UI only. Wire the buttons to your auth provider
// (Firebase Auth, Supabase, your own API) where the TODOs are.

void _enter(BuildContext context) {
  AppScope.of(context).signIn();
  Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
}

class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return FScaffold(
      childPad: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const MemoImage(15, size: 190, label: 'Memo waving beside an open door'),
                        const SizedBox(height: 20),
                        Text('Join Cemo.', style: Tx.serifTitle(context, size: 32)),
                        const SizedBox(height: 10),
                        Text(
                          'Create an account to keep your notes and reminders on every device.',
                          textAlign: TextAlign.center,
                          style: Tx.excerpt(context).copyWith(fontSize: 17, height: 26 / 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // TODO: Sign in with Apple / Google.
              PillButton(label: 'Continue with Apple', kind: PillKind.secondary, onPressed: () => _enter(context)),
              const SizedBox(height: 12),
              PillButton(label: 'Continue with Google', kind: PillKind.secondary, onPressed: () => _enter(context)),
              const SizedBox(height: 12),
              PillButton(
                label: 'Sign up with email',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const AccountFormScreen(signUp: true))),
              ),
              _SwitchLine(
                text: 'Already have an account?',
                link: 'Log in',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const AccountFormScreen(signUp: false))),
              ),
              Text(
                'By continuing you agree to the Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: Tx.meta(context).copyWith(color: c.t2),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({required this.text, required this.link, required this.onTap});
  final String text;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(text, style: Tx.ui(context).copyWith(color: context.c.t2)),
          FButton(
            variant: FButtonVariant.ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: onTap,
            child: Text(link, style: TextStyle(color: context.c.accent)),
          ),
        ],
      ),
    );
  }
}

/// Create account (signUp: true) or Log in (signUp: false).
class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({super.key, required this.signUp});
  final bool signUp;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    // TODO: call your auth backend with _email.text and _password.text.
    _enter(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool signUp = widget.signUp;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        prefixes: <Widget>[FHeaderAction.back(semanticsLabel: 'Back', onPress: () => Navigator.of(context).pop())],
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: <Widget>[
              Text(signUp ? 'Create your account.' : 'Welcome back.', style: Tx.serifTitle(context, size: 32)),
              const SizedBox(height: 8),
              Text(signUp ? 'It takes less than a minute.' : 'Log in to pick up where you left off.',
                  style: Tx.excerpt(context)),
              const SizedBox(height: 24),
              if (signUp) ...<Widget>[
                FTextFormField(
                  control: FTextFieldControl.managed(controller: _name),
                  label: const Text('Name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: Space.lg),
              ],
              FTextFormField.email(
                control: FTextFieldControl.managed(controller: _email),
                label: const Text('Email'),
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (String? v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: Space.lg),
              FTextFormField.password(
                control: FTextFieldControl.managed(controller: _password),
                label: const Text('Password'),
                description: signUp ? const Text('At least 8 characters') : null,
                textInputAction: TextInputAction.done,
                onSubmit: (_) => _submit(),
                validator: (String? v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
              ),
              const SizedBox(height: 28),
              PillButton(label: signUp ? 'Create account' : 'Log in', onPressed: _submit),
              _SwitchLine(
                text: signUp ? 'Already have an account?' : 'New to Cemo?',
                link: signUp ? 'Log in' : 'Create an account',
                onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => AccountFormScreen(signUp: !signUp))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
