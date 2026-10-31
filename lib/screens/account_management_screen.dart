import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/password_policy.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../utils/account_validation.dart';
import '../widgets/account_password_field.dart';
import '../widgets/password_feedback.dart';
import 'verify_email_screen.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({
    super.key,
    required this.auth,
    this.changePassword = false,
  });
  final AuthController auth;
  final bool changePassword;
  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _currentFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _busy = false;
  String? _error;
  String? _success;
  @override
  void initState() {
    super.initState();
    _name.text = widget.auth.user?.name ?? '';
    _email.text = widget.auth.user?.email ?? '';
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _current, _password, _confirm]) {
      controller.dispose();
    }
    for (final node in [
      _nameFocus,
      _emailFocus,
      _currentFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != widget.auth.user?.email.toLowerCase();
  String? _currentProblem(String? value) {
    if (!widget.changePassword && !_emailChanged) return null;
    return value == null ||
            value.isEmpty ||
            utf8.encode(value).length > 72 ||
            value.contains('\u0000')
        ? 'Enter your current password.'
        : null;
  }

  String? _newProblem(String? value) =>
      PasswordPolicy.problem(value) ??
      (value == _current.text
          ? 'Choose a password different from your current password.'
          : null);

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      AccountValidation.focusInvalid([
        if (!widget.changePassword) ...[
          (_nameFocus, AccountValidation.name(_name.text)),
          (_emailFocus, AccountValidation.email(_email.text)),
        ],
        (_currentFocus, _currentProblem(_current.text)),
        if (widget.changePassword) ...[
          (_passwordFocus, _newProblem(_password.text)),
          (
            _confirmFocus,
            _confirm.text != _password.text || _confirm.text.isEmpty
                ? 'Mismatch'
                : null,
          ),
        ],
      ]);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      if (widget.changePassword) {
        await widget.auth.changePassword(
          currentPassword: _current.text,
          password: _password.text,
          confirmPassword: _confirm.text,
        );
        if (!mounted) {
          return; // The app session gate normally replaced this route.
        }
        _current.clear();
        _password.clear();
        _confirm.clear();
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await widget.auth.updateProfile(
          name: _name.text,
          email: _email.text,
          currentPassword: _current.text,
        );
        if (!mounted) return;
        _current.clear();
        setState(
          () => _success =
              widget.auth.accountMessage ?? 'Your profile is updated.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to update your account. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ModaWordmark()),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        widget.changePassword
                            ? 'A little extra security.'
                            : 'Your details.',
                        style: ModaStyle.editorial.copyWith(fontSize: 34),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.changePassword
                            ? 'Use your current password to choose a new one. You will sign in again on all devices.'
                            : 'Keep your details up to date. Changing email requires your current password and verification of the new address.',
                        style: const TextStyle(color: ModaStyle.muted),
                      ),
                      const SizedBox(height: 28),
                      if (widget.auth.user == null)
                        const Text(
                          'Your session has ended. Please sign in to manage your account.',
                        )
                      else ...[
                        if (!widget.changePassword) ...[
                          TextFormField(
                            key: const Key('profile-name'),
                            controller: _name,
                            focusNode: _nameFocus,
                            enabled: !_busy,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () => _emailFocus.requestFocus(),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: AccountValidation.name,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('profile-email'),
                            controller: _email,
                            focusNode: _emailFocus,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            enableSuggestions: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () =>
                                _currentFocus.requestFocus(),
                            onChanged: (_) => setState(() => _success = null),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: AccountValidation.email,
                          ),
                          const SizedBox(height: 20),
                        ],
                        AccountPasswordField(
                          key: const Key('account-current-password'),
                          controller: _current,
                          focusNode: _currentFocus,
                          label: widget.changePassword
                              ? 'Current password'
                              : 'Current password (to change email)',
                          validator: _currentProblem,
                          nextFocus: widget.changePassword
                              ? _passwordFocus
                              : null,
                          enabled: !_busy,
                          onSubmitted: _submit,
                        ),
                        if (widget.changePassword) ...[
                          const SizedBox(height: 20),
                          AccountPasswordField(
                            key: const Key('account-new-password'),
                            controller: _password,
                            focusNode: _passwordFocus,
                            nextFocus: _confirmFocus,
                            enabled: !_busy,
                            newPassword: true,
                            label: 'New password',
                            validator: _newProblem,
                            onChanged: (_) {
                              if (_confirm.text.isNotEmpty) {
                                _form.currentState?.validate();
                              }
                            },
                          ),
                          PasswordFeedback(controller: _password),
                          const SizedBox(height: 20),
                          AccountPasswordField(
                            key: const Key('account-confirm-password'),
                            controller: _confirm,
                            focusNode: _confirmFocus,
                            enabled: !_busy,
                            newPassword: true,
                            label: 'Confirm password',
                            onSubmitted: _submit,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Confirm your password.'
                                : value != _password.text
                                ? 'Passwords do not match.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (_error != null || _success != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ?? _success!,
                              style: TextStyle(
                                color: _error == null
                                    ? ModaStyle.muted
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FilledButton(
                          key: const Key('account-save'),
                          onPressed: _busy ? null : _submit,
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
                                  widget.changePassword
                                      ? 'CHANGE PASSWORD'
                                      : 'SAVE CHANGES',
                                ),
                        ),
                        if (!widget.changePassword &&
                            widget.auth.user?.emailVerified == false)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => VerifyEmailScreen(
                                          auth: widget.auth,
                                        ),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                            child: const Text('Verify email'),
                          ),
                      ],
                    ],
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
