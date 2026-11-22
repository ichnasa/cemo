import 'package:flutter/material.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
          TextButton(
            onPressed: onTap,
            child: Text(link, style: Tx.uiStrong(context).copyWith(color: context.c.accent)),
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
  bool _hide = true;

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

  InputDecoration _decoration(String label, {Widget? suffix, String? helper}) {
    final CemoColors c = context.c;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      labelStyle: Tx.ui(context).copyWith(color: c.t2),
      helperStyle: Tx.meta(context),
      suffixIcon: suffix,
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.t1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool signUp = widget.signUp;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
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
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Name'),
                  validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: _decoration('Email'),
                validator: (String? v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _decoration(
                  'Password',
                  helper: signUp ? 'At least 8 characters' : null,
                  suffix: TextButton(
                    onPressed: () => setState(() => _hide = !_hide),
                    child: Text(_hide ? 'Show' : 'Hide', style: Tx.ui(context).copyWith(color: context.c.t2)),
                  ),
                ),
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
