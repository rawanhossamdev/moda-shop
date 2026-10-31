import 'package:flutter/material.dart';

class AccountPasswordField extends StatefulWidget {
  const AccountPasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.validator,
    this.nextFocus,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.newPassword = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final String label;
  final String? Function(String?) validator;
  final bool enabled;
  final bool newPassword;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  @override
  State<AccountPasswordField> createState() => _AccountPasswordFieldState();
}

class _AccountPasswordFieldState extends State<AccountPasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    focusNode: widget.focusNode,
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    textInputAction: widget.nextFocus == null
        ? TextInputAction.done
        : TextInputAction.next,
    onEditingComplete: widget.nextFocus == null
        ? null
        : () => widget.nextFocus!.requestFocus(),
    onFieldSubmitted: widget.nextFocus == null
        ? (_) => widget.onSubmitted?.call()
        : null,
    onChanged: widget.onChanged,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: _hidden
            ? 'Show ${widget.label.toLowerCase()}'
            : 'Hide ${widget.label.toLowerCase()}',
        onPressed: !widget.enabled
            ? null
            : () {
                setState(() => _hidden = !_hidden);
                widget.focusNode.requestFocus();
              },
        icon: Icon(
          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}
