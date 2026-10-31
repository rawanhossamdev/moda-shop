import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../models/password_policy.dart';
import '../widgets/password_feedback.dart';
import 'password_recovery_screen.dart';
import '../utils/account_validation.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.auth, this.onBrowse});
  final AuthController auth;
  final VoidCallback? onBrowse;
  @override
  Widget build(BuildContext context) =>
      _AuthScreen(auth: auth, register: false, onBrowse: onBrowse);
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => _AuthScreen(auth: auth, register: true);
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen({
    required this.auth,
    required this.register,
    this.onBrowse,
  });
  final AuthController auth;
  final bool register;
  final VoidCallback? onBrowse;
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmField = GlobalKey<FormFieldState<String>>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _hidden = true;
  bool _confirmHidden = true;
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    for (final node in [
      _nameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_form.currentState?.validate() ?? false)) {
      AccountValidation.focusInvalid([
        if (widget.register) (_nameFocus, AccountValidation.name(_name.text)),
        (_emailFocus, AccountValidation.email(_email.text)),
        (
          _passwordFocus,
          widget.register
              ? PasswordPolicy.problem(_password.text)
              : _password.text.isEmpty
              ? 'Required'
              : null,
        ),
        if (widget.register)
          (
            _confirmFocus,
            _confirm.text != _password.text || _confirm.text.isEmpty
                ? 'Mismatch'
                : null,
          ),
      ]);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.auth.authenticate(
        register: widget.register,
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Unable to complete your request. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  InputDecoration field(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: ModaStyle.muted, fontSize: 14),
    floatingLabelStyle: const TextStyle(
      color: ModaStyle.charcoal,
      fontSize: 14,
    ),
    filled: true,
    fillColor: ModaStyle.cream,
    border: _border(ModaStyle.beige),
    enabledBorder: _border(ModaStyle.beige.withValues(alpha: .7)),
    disabledBorder: _border(ModaStyle.beige.withValues(alpha: .45)),
    focusedBorder: _border(ModaStyle.gold.withValues(alpha: .85), width: 1.3),
    errorBorder: _border(
      Theme.of(context).colorScheme.error.withValues(alpha: .7),
    ),
    focusedErrorBorder: _border(
      Theme.of(context).colorScheme.error,
      width: 1.3,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    errorMaxLines: 3,
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                          widget.register
                              ? 'Make yourself at home.'
                              : 'Welcome back.',
                          style: ModaStyle.editorial.copyWith(fontSize: 34),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.register
                              ? 'A considered wardrobe. A space of your own.'
                              : 'Sign in and continue your MODA story.',
                          style: const TextStyle(color: ModaStyle.muted),
                        ),
                        const SizedBox(height: 28),
                        if (widget.register) ...[
                          TextFormField(
                            key: const Key('auth-name'),
                            controller: _name,
                            focusNode: _nameFocus,
                            onEditingComplete: () => _emailFocus.requestFocus(),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            enabled: !_submitting,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: field('Name'),
                            validator: AccountValidation.name,
                          ),
                          const SizedBox(height: 20),
                        ],
                        TextFormField(
                          key: const Key('auth-email'),
                          controller: _email,
                          focusNode: _emailFocus,
                          onEditingComplete: () =>
                              _passwordFocus.requestFocus(),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          enabled: !_submitting,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: field('Email'),
                          validator: AccountValidation.email,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const Key('auth-password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          onEditingComplete: widget.register
                              ? () => _confirmFocus.requestFocus()
                              : null,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) {
                            if (_confirm.text.isNotEmpty) {
                              _confirmField.currentState?.validate();
                            }
                          },
                          enabled: !_submitting,
                          obscureText: _hidden,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: [
                            widget.register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: widget.register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!widget.register) _submit();
                          },
                          decoration: field('Password').copyWith(
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() => _hidden = !_hidden);
                                      _passwordFocus.requestFocus();
                                    },
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => widget.register
                              ? PasswordPolicy.problem(value)
                              : value == null ||
                                    value.isEmpty ||
                                    utf8.encode(value).length > 72 ||
                                    value.contains('\u0000')
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (widget.register) ...[
                          PasswordFeedback(controller: _password),
                          const SizedBox(height: 20),
                          KeyedSubtree(
                            key: const Key('auth-confirm'),
                            child: TextFormField(
                              key: _confirmField,
                              controller: _confirm,
                              focusNode: _confirmFocus,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              textInputAction: TextInputAction.done,
                              enabled: !_submitting,
                              obscureText: _confirmHidden,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: field('Confirm password').copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _confirmHidden
                                      ? 'Show confirm password'
                                      : 'Hide confirm password',
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          setState(
                                            () => _confirmHidden =
                                                !_confirmHidden,
                                          );
                                          _confirmFocus.requestFocus();
                                        },
                                  icon: Icon(
                                    _confirmHidden
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Confirm your password.'
                                  : value != _password.text
                                  ? 'Passwords do not match.'
                                  : null,
                            ),
                          ),
                        ],
                        if (!widget.register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PasswordRecoveryScreen(
                                          auth: widget.auth,
                                        ),
                                      ),
                                    ),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        const SizedBox(height: 28),
                        ListenableBuilder(
                          listenable: widget.auth,
                          builder: (context, _) =>
                              widget.auth.accountMessage == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      widget.auth.accountMessage!,
                                      style: const TextStyle(
                                        color: ModaStyle.muted,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        if (_error != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        FilledButton(
                          key: const Key('auth-submit'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ModaStyle.ivory,
                                  ),
                                )
                              : Text(
                                  widget.register
                                      ? 'CREATE ACCOUNT'
                                      : 'SIGN IN',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.onBrowse != null)
                          TextButton(
                            onPressed: _submitting ? null : widget.onBrowse,
                            child: const Text('Explore as a guest'),
                          ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => widget.register
                                        ? LoginScreen(auth: widget.auth)
                                        : SignUpScreen(auth: widget.auth),
                                  ),
                                ),
                          child: Text(
                            widget.register
                                ? 'Already a member? Sign in'
                                : 'New to MODA? Create an account',
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
