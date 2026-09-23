import 'package:flutter/material.dart';

/// Design system « pro » NYCTA : charte bleu nuit + vert menthe,
/// surfaces blanches douces, ombres feutrées, typographie hiérarchisée.
/// Règles anti-overflow conservées (pas de débordement).
class AppTheme {
  // Charte (voir assets/images/nycta/LIRE-MOI.txt)
  static const encre = Color(0xFF0F172A); // bleu nuit — structure
  static const menthe = Color(0xFF10B981); // vert menthe — accent
  static const seed = Color(0xFF3D6FB4);
  static const success = Color(0xFF3E9D8F);
  static const danger = Color(0xFFD97706);
  static const surfaceSoft = Color(0xFFF3F5F9);
  static const bordure = Color(0xFFE5EAF1);
  static const texteSecondaire = Color(0xFF64748B);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: encre,
      primary: encre,
      onPrimary: Colors.white,
      secondary: menthe,
      onSecondary: Colors.white,
      tertiary: seed,
      error: const Color(0xFFDC2626),
      surface: Colors.white,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceSoft,
      // Typographie hiérarchisée (anti-overflow : tailles bornées,
      // ellipses gérées écran par écran via maxLines + Flexible).
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontWeight: FontWeight.w800, letterSpacing: -0.5, color: encre),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: encre),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 16, color: encre),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: encre,
        titleTextStyle: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 18, color: encre),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: bordure),
        ),
        margin: EdgeInsets.zero,
      ),
      // Champs : fond blanc + bordure visible (plus lisible et plus
      // professionnel que l'ancien remplissage gris sans contour).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: menthe, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.6),
        ),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        floatingLabelStyle: const TextStyle(
            color: encre, fontWeight: FontWeight.w600),
        helperStyle:
            TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: bordure),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        extendedTextStyle:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: StadiumBorder(),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: bordure)),
        side: BorderSide(color: bordure),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 17, color: encre),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: menthe.withValues(alpha: 0.18),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: encre),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, color: encre),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
        side: const WidgetStatePropertyAll(
            BorderSide(color: bordure)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16))),
        hintStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF64748B),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme:
          const DividerThemeData(space: 1, thickness: 1, color: bordure),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: encre,
      ),
    );
  }
}
