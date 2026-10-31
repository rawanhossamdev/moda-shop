import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../utils/account_validation.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.auth, this.resend = false});
  final AuthController auth;
  final bool resend;
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _codeFocus = FocusNode();
  bool _busy = false;
  String? _error;
  String? _message;
  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!widget.resend && !_form.currentState!.validate()) {
      AccountValidation.focusInvalid([
        (_codeFocus, 'Enter the six-digit code.'),
      ]);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.resend) {
        await widget.auth.sendVerification();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await widget.auth.verifyEmail(_code.text.trim());
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to verify your email. Please try again.',
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
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('YOUR MODA ACCOUNT', style: ModaStyle.label),
                  const SizedBox(height: 14),
                  Text(
                    widget.resend ? 'A fresh code.' : 'Verify your email.',
                    style: ModaStyle.editorial.copyWith(fontSize: 34),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.resend
                        ? 'Request a verification code for ${widget.auth.user?.email ?? 'your email'}. Requests are limited to once per minute.'
                        : 'Enter the six-digit code for ${widget.auth.user?.email ?? 'your email'}. It expires in 15 minutes. Verification is required before checkout.',
                    style: const TextStyle(color: ModaStyle.muted),
                  ),
                  const SizedBox(height: 24),
                  if (!widget.resend)
                    TextFormField(
                      key: const Key('verification-code'),
                      controller: _code,
                      focusNode: _codeFocus,
                      autocorrect: false,
                      enableSuggestions: false,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^\d{6}$').hasMatch(value.trim())
                          ? 'Enter the six-digit code.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  if (_message != null || _error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error ?? _message!,
                          style: TextStyle(
                            color: _error == null
                                ? ModaStyle.muted
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('verify-submit'),
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
                        : Text(widget.resend ? 'SEND CODE' : 'VERIFY EMAIL'),
                  ),
                  if (!widget.resend)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final sent = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => VerifyEmailScreen(
                                        auth: widget.auth,
                                        resend: true,
                                      ),
                                    ),
                                  );
                              if (mounted && sent == true) {
                                setState(() {
                                  _error = null;
                                  _message =
                                      'The email provider accepted the request. Check your inbox and spam folder.';
                                });
                              }
                            },
                      child: const Text('Request or resend code'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
