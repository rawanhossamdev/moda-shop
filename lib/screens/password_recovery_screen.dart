import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../models/password_policy.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/password_feedback.dart';
import '../utils/account_validation.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _confirmField = GlobalKey<FormFieldState<String>>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _reset = false;
  bool _busy = false;
  bool _hidden = true;
  bool _confirmHidden = true;
  bool _done = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirm]) {
      controller.dispose();
    }
    for (final node in [
      _emailFocus,
      _codeFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: ModaStyle.cream,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    errorMaxLines: 3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ModaStyle.beige),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ModaStyle.gold, width: 1.3),
    ),
  );

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      AccountValidation.focusInvalid(
        _reset
            ? [
                (
                  _codeFocus,
                  RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(_code.text.trim())
                      ? null
                      : 'Invalid code',
                ),
                (_passwordFocus, PasswordPolicy.problem(_password.text)),
                (
                  _confirmFocus,
                  _confirm.text.isEmpty || _confirm.text != _password.text
                      ? 'Mismatch'
                      : null,
                ),
              ]
            : [(_emailFocus, AccountValidation.email(_email.text))],
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (_reset) {
        await widget.auth.resetPassword(
          token: _code.text,
          password: _password.text,
          confirmPassword: _confirm.text,
        );
        if (!mounted) return;
        TextInput.finishAutofillContext(shouldSave: false);
        _code.clear();
        _password.clear();
        _confirm.clear();
        setState(() {
          _done = true;
        });
      } else {
        await widget.auth.requestPasswordReset(_email.text);
        if (!mounted) return;
        setState(
          () => _message =
              'If an account exists, we will attempt to send a reset code. Check your inbox and spam folder. If it does not arrive, try again later.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to complete your request. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _passwordField({bool confirm = false}) => TextFormField(
    key: confirm ? _confirmField : const Key('recovery-password'),
    controller: confirm ? _confirm : _password,
    focusNode: confirm ? _confirmFocus : _passwordFocus,
    onEditingComplete: confirm ? null : () => _confirmFocus.requestFocus(),
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    enabled: !_busy,
    obscureText: confirm ? _confirmHidden : _hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: const [AutofillHints.newPassword],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    textInputAction: confirm ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: confirm ? (_) => _submit() : null,
    onChanged: confirm
        ? null
        : (_) {
            if (_confirm.text.isNotEmpty) {
              _confirmField.currentState?.validate();
            }
          },
    decoration: _field(confirm ? 'Confirm password' : 'New password').copyWith(
      suffixIcon: IconButton(
        tooltip: (confirm ? _confirmHidden : _hidden)
            ? 'Show ${confirm ? 'confirm password' : 'password'}'
            : 'Hide ${confirm ? 'confirm password' : 'password'}',
        onPressed: _busy
            ? null
            : () => setState(() {
                if (confirm) {
                  _confirmHidden = !_confirmHidden;
                } else {
                  _hidden = !_hidden;
                }
                (confirm ? _confirmFocus : _passwordFocus).requestFocus();
              }),
        icon: Icon(
          (confirm ? _confirmHidden : _hidden)
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    ),
    validator: confirm
        ? (value) => value == null || value.isEmpty
              ? 'Confirm your password.'
              : value != _password.text
              ? 'Passwords do not match.'
              : null
        : PasswordPolicy.problem,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ModaWordmark()),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ModaStyle.ivory, Color(0xFFF5EFE7)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('YOUR MODA ACCOUNT', style: ModaStyle.label),
                        const SizedBox(height: 14),
                        Text(
                          _done
                              ? 'A fresh start.'
                              : _reset
                              ? 'Reset your password.'
                              : 'A little help signing in.',
                          style: ModaStyle.editorial.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _done
                              ? 'Your password has been updated. Sign in with your new password.'
                              : _reset
                              ? 'Paste the code from your email. Codes expire in 15 minutes and can be used once.'
                              : 'Request a private reset code for your MODA account.',
                          style: const TextStyle(color: ModaStyle.muted),
                        ),
                        const SizedBox(height: 28),
                        if (!_done && !_reset)
                          TextFormField(
                            key: const Key('recovery-email'),
                            controller: _email,
                            focusNode: _emailFocus,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: _field('Email'),
                            validator: AccountValidation.email,
                          ),
                        if (!_done && _reset) ...[
                          TextFormField(
                            key: const Key('recovery-code'),
                            controller: _code,
                            focusNode: _codeFocus,
                            onEditingComplete: () =>
                                _passwordFocus.requestFocus(),
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            enabled: !_busy,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            decoration: _field('Reset code'),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(
                                      r'^[A-Za-z0-9_-]{43}$',
                                    ).hasMatch(value.trim())
                                ? 'Paste the complete reset code from your email.'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _passwordField(),
                          PasswordFeedback(controller: _password),
                          const SizedBox(height: 20),
                          KeyedSubtree(
                            key: const Key('recovery-confirm'),
                            child: _passwordField(confirm: true),
                          ),
                        ],
                        if (_error != null || _message != null) ...[
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ?? _message!,
                              style: TextStyle(
                                color: _error != null
                                    ? Theme.of(context).colorScheme.error
                                    : ModaStyle.muted,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        FilledButton(
                          key: const Key('recovery-submit'),
                          onPressed: _busy
                              ? null
                              : _done
                              ? () => Navigator.of(context).pop()
                              : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ModaStyle.ivory,
                                  ),
                                )
                              : Text(
                                  _done
                                      ? 'BACK TO SIGN IN'
                                      : _reset
                                      ? 'RESET PASSWORD'
                                      : 'REQUEST RESET CODE',
                                ),
                        ),
                        if (!_done)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    _form.currentState?.reset();
                                    setState(() {
                                      _reset = !_reset;
                                      _error = null;
                                      _message = null;
                                    });
                                  },
                            child: Text(
                              _reset
                                  ? 'Request a new code'
                                  : 'I have a reset code',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
