import 'package:flutter/material.dart';

abstract final class ModaStyle {
  static const ivory = Color(0xFFFAF7F2);
  static const cream = Color(0xFFF2ECE3);
  static const beige = Color(0xFFDED5C8);
  static const charcoal = Color(0xFF252320);
  static const muted = Color(0xFF716A61);
  static const gold = Color(0xFFA58A57);
  static const editorial = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w400,
    height: 1.15,
    color: charcoal,
  );
  static const label = TextStyle(
    fontSize: 11,
    letterSpacing: 2.2,
    fontWeight: FontWeight.w500,
    color: muted,
  );
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ivory,
    colorScheme: const ColorScheme.light(
      primary: charcoal,
      onPrimary: ivory,
      secondary: gold,
      surface: ivory,
      onSurface: charcoal,
      outline: beige,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: charcoal),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: muted),
    ),
    iconTheme: const IconThemeData(size: 22, color: charcoal),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cream,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: beige),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gold, width: 1.3),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ivory,
      foregroundColor: charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
    ),
    dividerTheme: const DividerThemeData(color: beige, thickness: 1, space: 1),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: charcoal,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        side: const BorderSide(color: beige),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: charcoal,
      actionTextColor: Colors.white,
      contentTextStyle: TextStyle(color: ivory),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class ModaWordmark extends StatelessWidget {
  const ModaWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Text(
    'MODA',
    style: TextStyle(
      fontFamily: 'serif',
      fontSize: 25,
      letterSpacing: 6,
      color: ModaStyle.charcoal,
    ),
  );
}
