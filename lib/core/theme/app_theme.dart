import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta oficial da identidade visual do Awake
/// (ver ID_VISUAL_-_AWAKE.pdf fornecido pelo ministerio).
class AwakeColors {
  static const offWhite = Color(0xFFF7F7F6);
  static const yellow = Color(0xFFFFD21F);
  static const lightBlueGrey = Color(0xFFD9DFE6);
  static const navy = Color(0xFF0C192E);
  static const black = Color(0xFF000000);

  // Tons extras usados so no tema escuro
  static const darkSurface = Color(0xFF16233A);
  static const darkBackground = Color(0xFF0A1220);
}

/// Tema visual do app, baseado na identidade oficial do Awake.
///
/// NOTA SOBRE FONTE: a identidade usa "Canva Sans" para o corpo de texto e
/// uma fonte customizada ("awake shallom") só para o logotipo. Canva Sans e
/// uma fonte proprietaria da Canva e nao deve ser embutida/redistribuida no
/// app sem uma licenca especifica para isso. Por enquanto este tema usa
/// "Plus Jakarta Sans" (Google Fonts, licenca aberta) como substituta.
final _bodyFont = GoogleFonts.plusJakartaSansTextTheme();

class AppTheme {
  static TextTheme _buildTextTheme(Color textColor) {
    final base = _bodyFont.apply(bodyColor: textColor, displayColor: textColor);
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontSize: 32),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 20),
      titleLarge: base.titleLarge?.copyWith(fontSize: 17),
      titleMedium: base.titleMedium?.copyWith(fontSize: 15),
      titleSmall: base.titleSmall?.copyWith(fontSize: 13),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 14),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      labelMedium: base.labelMedium?.copyWith(fontSize: 12),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11),
    );
  }

  static ThemeData light() {
    final colorScheme = const ColorScheme.light().copyWith(
      primary: AwakeColors.navy,
      onPrimary: AwakeColors.offWhite,
      secondary: AwakeColors.yellow,
      onSecondary: AwakeColors.navy,
      surface: AwakeColors.offWhite,
      onSurface: AwakeColors.navy,
      surfaceContainerHighest: AwakeColors.lightBlueGrey,
      error: const Color(0xFFB3261E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AwakeColors.offWhite,
      textTheme: _buildTextTheme(AwakeColors.navy),
      appBarTheme: AppBarTheme(
        backgroundColor: AwakeColors.navy,
        foregroundColor: AwakeColors.offWhite,
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AwakeColors.offWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AwakeColors.yellow,
          foregroundColor: AwakeColors.navy,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AwakeColors.yellow,
        foregroundColor: AwakeColors.navy,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AwakeColors.navy,
        indicatorColor: AwakeColors.yellow,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AwakeColors.navy : AwakeColors.offWhite,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AwakeColors.navy : AwakeColors.offWhite,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AwakeColors.lightBlueGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AwakeColors.navy, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AwakeColors.lightBlueGrey),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark().copyWith(
      primary: AwakeColors.yellow,
      onPrimary: AwakeColors.navy,
      secondary: AwakeColors.yellow,
      onSecondary: AwakeColors.navy,
      surface: AwakeColors.darkSurface,
      onSurface: AwakeColors.offWhite,
      surfaceContainerHighest: const Color(0xFF223252),
      error: const Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AwakeColors.darkBackground,
      textTheme: _buildTextTheme(AwakeColors.offWhite),
      appBarTheme: AppBarTheme(
        backgroundColor: AwakeColors.darkSurface,
        foregroundColor: AwakeColors.offWhite,
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AwakeColors.offWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AwakeColors.yellow,
          foregroundColor: AwakeColors.navy,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AwakeColors.offWhite,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AwakeColors.yellow,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AwakeColors.yellow,
        foregroundColor: AwakeColors.navy,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AwakeColors.darkSurface,
        indicatorColor: AwakeColors.yellow,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AwakeColors.navy : AwakeColors.offWhite,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AwakeColors.navy : AwakeColors.offWhite,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AwakeColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A4A6B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AwakeColors.yellow, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: AwakeColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF3A4A6B)),
        ),
      ),
    );
  }
}
