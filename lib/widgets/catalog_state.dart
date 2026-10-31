import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

class CatalogState extends StatelessWidget {
  const CatalogState({super.key, this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message == null)
          Semantics(
            label: 'Loading products',
            child: const CircularProgressIndicator(),
          )
        else ...[
          const Icon(
            Icons.cloud_off_outlined,
            color: ModaStyle.muted,
            size: 32,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ModaStyle.muted),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ],
    ),
  );
}
