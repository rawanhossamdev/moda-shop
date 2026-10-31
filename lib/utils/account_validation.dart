import 'package:flutter/material.dart';

abstract final class AccountValidation {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length <= 254 &&
            text.split('@').first.length <= 64 &&
            RegExp(
              r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$",
            ).hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    return text.length >= 2 &&
            text.length <= 120 &&
            !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value ?? '')
        ? null
        : 'Enter a name between 2 and 120 characters.';
  }

  static void focusInvalid(List<(FocusNode, String?)> fields) {
    for (final (node, problem) in fields) {
      if (problem == null) continue;
      node.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = node.context;
        if (context != null && context.mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 180),
            alignment: .25,
          );
        }
      });
      return;
    }
  }
}
