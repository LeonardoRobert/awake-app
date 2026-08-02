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
}

/// Tema visual do app, baseado na identidade oficial do Awake.
///
/// NOTA SOBRE FONTE: a identidade usa "Canva Sans" para o corpo de texto e
/// uma fonte customizada ("awake shallom") só para o logotipo. Canva Sans e
/// uma fonte proprietaria da Canva e nao deve ser embutida/redistribuida no
/// app sem uma licenca especifica para isso. Por enquanto este tema usa
/// "Plus Jakarta Sans" (Google Fonts, licenca aberta) como substituta, por
/// ter uma geometria bem parecida. Troque em `_bodyFont` abaixo assim que
/// tiver os arquivos da fonte oficial licenciados para uso no app.
final _bodyFont = GoogleFonts.plusJakartaSansTextTheme();

class AppTheme {
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

    // Reduz o tamanho de cada estilo de texto manualmente (em vez de usar
    // TextTheme.apply(fontSizeFactor: ...), que trava se algum estilo da
    // fonte do Google Fonts nao tiver fontSize definido).
    final baseTheme = _bodyFont.apply(
      bodyColor: AwakeColors.navy,
      displayColor: AwakeColors.navy,
    );

    final textTheme = baseTheme.copyWith(
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: 32),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: 20),
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 17),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 15),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: 13),
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: 14),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: 12),
      labelLarge: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: 12),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: 11),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AwakeColors.offWhite,
      textTheme: textTheme,
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
}
