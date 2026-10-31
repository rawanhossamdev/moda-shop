import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

class DemoCatalogNotice extends StatelessWidget {
  const DemoCatalogNotice({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Text(
      'PORTFOLIO DEMO · AI-generated imagery; sample products and USD prices. No real merchandise.',
      style: TextStyle(fontSize: 12, height: 1.5, color: ModaStyle.muted),
    ),
  );
}
