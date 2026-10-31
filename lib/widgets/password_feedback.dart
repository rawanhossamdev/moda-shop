import 'package:flutter/material.dart';
import '../models/password_policy.dart';
import '../theme/moda_theme.dart';

class PasswordFeedback extends StatelessWidget {
  const PasswordFeedback({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final score = PasswordPolicy.strength(value.text);
      final label = value.text.isEmpty
          ? 'Choose a password'
          : 'Password strength: ${['Weak', 'Medium', 'Strong'][score - 1]}';
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Semantics(
          label: label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: ModaStyle.muted),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LinearProgressIndicator(
                  value: value.text.isEmpty ? 0 : score / 3,
                  minHeight: 3,
                  color: ModaStyle.gold,
                  backgroundColor: ModaStyle.beige,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '8+ characters. Longer is better; symbols are optional.',
                style: TextStyle(fontSize: 12, color: ModaStyle.muted),
              ),
            ],
          ),
        ),
      );
    },
  );
}
