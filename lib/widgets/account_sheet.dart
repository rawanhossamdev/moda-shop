import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../screens/address_screens.dart';
import '../controllers/auth_controller.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../screens/verify_email_screen.dart';
import '../screens/order_screens.dart';
import '../screens/account_management_screen.dart';
import 'commerce_scope.dart';

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  String? _error;

  Future<void> _logout() async {
    if (widget.auth.busy) return;
    setState(() => _error = null);
    try {
      final message = await widget.auth.logout();
      if (mounted) Navigator.of(context).pop(message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Unable to sign out. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your account',
                  style: ModaStyle.editorial.copyWith(fontSize: 30),
                ),
              ),
              IconButton(
                tooltip: 'Close account',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(ModaIcons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: ListenableBuilder(
              listenable: widget.auth,
              builder: (context, _) {
                final user = widget.auth.user;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    if (user != null) ...[
                      Container(
                        color: ModaStyle.cream,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NAME',
                              style: ModaStyle.label.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.name,
                              style: ModaStyle.editorial.copyWith(fontSize: 24),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'EMAIL',
                              style: ModaStyle.label.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 15,
                                color: ModaStyle.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.auth.accountMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.auth.accountMessage!,
                              style: const TextStyle(color: ModaStyle.muted),
                            ),
                          ),
                        ),
                      TextButton(
                        key: const Key('edit-profile'),
                        onPressed: widget.auth.busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AccountManagementScreen(
                                    auth: widget.auth,
                                  ),
                                ),
                              ),
                        child: const Text('Edit profile'),
                      ),
                      TextButton(
                        key: const Key('change-password'),
                        onPressed: widget.auth.busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AccountManagementScreen(
                                    auth: widget.auth,
                                    changePassword: true,
                                  ),
                                ),
                              ),
                        child: const Text('Change password'),
                      ),
                      if (CommerceScope.maybeOf(context) != null) ...[
                        Text(
                          user.emailVerified
                              ? 'Email verified'
                              : 'Email verification required for checkout',
                          style: const TextStyle(color: ModaStyle.muted),
                        ),
                        if (!user.emailVerified)
                          TextButton(
                            onPressed: widget.auth.busy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          VerifyEmailScreen(auth: widget.auth),
                                    ),
                                  ),
                            child: const Text('Verify email'),
                          ),
                        OutlinedButton(
                          onPressed: widget.auth.busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const OrderHistoryScreen(),
                                  ),
                                ),
                          child: const Text('ORDER HISTORY'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const Key('shipping-addresses'),
                          onPressed: widget.auth.busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AddressBookScreen(),
                                  ),
                                ),
                          child: const Text('SHIPPING ADDRESSES'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ] else ...[
                      Text(
                        widget.auth.busy
                            ? 'Signing out…'
                            : 'Your session has ended.',
                        style: const TextStyle(color: ModaStyle.muted),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: ListenableBuilder(
            listenable: widget.auth,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (widget.auth.user != null || widget.auth.busy)
                  FilledButton.icon(
                    key: const Key('account-logout'),
                    onPressed: widget.auth.busy ? null : _logout,
                    icon: widget.auth.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ModaStyle.ivory,
                            ),
                          )
                        : const Icon(Icons.logout, size: 20),
                    label: const Text('LOGOUT'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CLOSE'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
