import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design system « pro » NYCTA : bleu structurel + vert menthe,
/// surfaces douces, ombres feutrées, typographie hiérarchisée.
/// Règles anti-overflow conservées (pas de débordement).
class AppTheme {
  // ============================================================
  // CHARTE (voir assets/images/nycta/LIRE-MOI.txt)
  // ============================================================
  /// Bleu structurel — utilisé pour l'AppBar, les titres, le focus,
  /// le FAB et la navigation. Sert aussi de `primary` dans le scheme.
  static const encre = Color(0xFF0D47A1);

  static const menthe = Color(0xFF10B981); // vert menthe — accent
  static const seed = Color(0xFF3D6FB4);
  static const success = Color(0xFF3E9D8F);
  static const danger = Color(0xFFD97706);
  static const surfaceSoft = Color(0xFFF3F5F9);
  static const bordure = Color(0xFFE5EAF1);
  static const texteSecondaire = Color(0xFF64748B);
  static const erreur = Color(0xFFDC2626);

  // Couleurs dédiées au mode sombre
  static const _darkBackground = Color(0xFF0B1220);
  static const _darkSurface = Color(0xFF111A2E);
  static const _darkSurfaceSoft = Color(0xFF16203A);
  static const _darkBordure = Color(0xFF243049);
  static const _darkTexteSecondaire = Color(0xFF94A3B8);
  static const _darkErreur = Color(0xFFF87171);

  // ============================================================
  // LIGHT
  // ============================================================
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: encre,
      primary: encre,
      onPrimary: Colors.white,
      secondary: menthe,
      onSecondary: Colors.white,
      tertiary: seed,
      error: erreur,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: encre, // 🔑 évite le texte gris pâle auto-généré par M3
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceSoft,

      // ----------------------------------------------------------
      // Typographie hiérarchisée (anti-overflow : tailles bornées,
      // ellipses gérées écran par écran via maxLines + Flexible).
      // ----------------------------------------------------------
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: encre,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: encre),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: encre,
        ),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),

      // ----------------------------------------------------------
      // AppBar
      // ----------------------------------------------------------
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: encre,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // 🔑 évite la teinte M3
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),

      // ----------------------------------------------------------
      // Cartes
      // ----------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: bordure),
        ),
        margin: EdgeInsets.zero,
      ),

      // ----------------------------------------------------------
      // Champs : fond blanc + bordure visible
      // ----------------------------------------------------------
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
          borderSide: const BorderSide(color: erreur),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: erreur, width: 1.6),
        ),
        prefixIconColor: texteSecondaire,
        suffixIconColor: texteSecondaire,
        labelStyle: const TextStyle(color: texteSecondaire),
        floatingLabelStyle:
            const TextStyle(color: encre, fontWeight: FontWeight.w600),
        helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),

      // ----------------------------------------------------------
      // Boutons
      // ----------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: bordure),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      // ----------------------------------------------------------
      // FAB / Chips / Dialog / BottomSheet
      // ----------------------------------------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: StadiumBorder(),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: bordure)),
        side: BorderSide(color: bordure),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

      // ----------------------------------------------------------
      // Onglets dans AppBar bleue : libellés blancs (le primary bleu
      // serait illisible sur fond bleu).
      // ----------------------------------------------------------
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: menthe,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // ----------------------------------------------------------
      // Navigation
      // ----------------------------------------------------------
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

      // ----------------------------------------------------------
      // Menus / Search / ListTile / Divider / SnackBar / Progress
      // ----------------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, color: encre),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
        side: const WidgetStatePropertyAll(BorderSide(color: bordure)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: texteSecondaire,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  // ============================================================
  // DARK
  // ============================================================
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: encre,
      brightness: Brightness.dark,
      primary: menthe, // en dark, l'accent menthe ressort mieux
      onPrimary: encre,
      secondary: menthe,
      onSecondary: encre,
      tertiary: seed,
      error: _darkErreur,
      onError: Colors.white,
      surface: _darkSurface,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Colors.white,
        ),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),

      // ----------------------------------------------------------
      // AppBar — sombre
      // ----------------------------------------------------------
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // 🔑 évite la teinte M3
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _darkBordure),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceSoft,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkBordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkBordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: menthe, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkErreur),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkErreur, width: 1.6),
        ),
        prefixIconColor: _darkTexteSecondaire,
        suffixIconColor: _darkTexteSecondaire,
        labelStyle: const TextStyle(color: _darkTexteSecondaire),
        floatingLabelStyle:
            const TextStyle(color: menthe, fontWeight: FontWeight.w600),
        helperStyle: const TextStyle(color: _darkTexteSecondaire, fontSize: 12),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: _darkBordure),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: StadiumBorder(),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: _darkBordure)),
        side: BorderSide(color: _darkBordure),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        elevation: 2,
        indicatorColor: menthe.withValues(alpha: 0.22),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: Colors.white),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(_darkSurfaceSoft),
        elevation: const WidgetStatePropertyAll(0),
        side: const WidgetStatePropertyAll(BorderSide(color: _darkBordure)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: _darkTexteSecondaire, fontSize: 14),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _darkTexteSecondaire,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme:
          const DividerThemeData(space: 1, thickness: 1, color: _darkBordure),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: menthe,
      ),
    );
  }
}
