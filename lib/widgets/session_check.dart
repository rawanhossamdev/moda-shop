import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

/// Startup does not build either authenticated content or an authentication
/// form until secure storage and the backend have resolved the saved session.
class SessionCheck extends StatelessWidget {
  const SessionCheck({
    super.key,
    this.loading = true,
    this.message,
    this.onRetry,
    this.onSignIn,
  });
  final bool loading;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AnimatedBrand(),
                const SizedBox(height: 32),
                if (loading) ...[
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: ModaStyle.gold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checking your session',
                    style: TextStyle(color: ModaStyle.muted),
                  ),
                ] else ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message ?? 'Unable to verify your saved session.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ModaStyle.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('RETRY'),
                  ),
                  if (onSignIn != null)
                    TextButton(
                      onPressed: onSignIn,
                      child: const Text('SIGN IN INSTEAD'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AnimatedBrand extends StatelessWidget {
  const _AnimatedBrand();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.scale(scale: .97 + .03 * value, child: child),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModaWordmark(),
        SizedBox(height: 18),
        SizedBox(
          width: 32,
          child: Divider(color: ModaStyle.gold, thickness: 1),
        ),
      ],
    ),
  );
}
