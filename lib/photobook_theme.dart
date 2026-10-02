import 'package:flutter/material.dart';

const paper = Color(0xFFF7F2E8);
const ink = Color(0xFF263B35);
const moss = Color(0xFF496451);
const clay = Color(0xFFAB5841);

ThemeData photobookTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: moss)
      .copyWith(primary: moss, secondary: clay, surface: paper, onSurface: ink);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: paper,
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontFamily: 'serif',
        fontSize: 38,
        color: ink,
        height: 1.1,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'serif',
        fontSize: 30,
        color: ink,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'serif',
        fontSize: 25,
        color: ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'serif',
        fontSize: 23,
        color: ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFDF8),
      elevation: 1,
      shadowColor: const Color(0x30263B35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0D9CA)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEEE9DE),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
    ),
  );
}

class PhotoMount extends StatelessWidget {
  const PhotoMount({
    super.key,
    required this.child,
    required this.caption,
    this.note,
  });
  final Widget child;
  final String caption;
  final String? note;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(color: const Color(0xFFE9ECDD), child: child),
        ),
        const SizedBox(height: 10),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'serif', fontSize: 18, color: ink),
        ),
        if (note != null)
          Text(
            note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, letterSpacing: 1, color: moss),
          ),
      ],
    ),
  );
}
