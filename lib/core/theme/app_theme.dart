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

  // Tons do tema "mais escuro" (preto de verdade, bom pra tela AMOLED
  // economizar bateria) -- mesma estrutura do tema escuro normal, so
  // troca o navy por preto.
  static const amoledSurface = Color(0xFF0A0A0A);
  static const amoledBackground = Color(0xFF000000);
}

/// Paleta da Shallom (usada nas telas de quem NAO e Awake -- Homens,
/// Mulheres). O azul e a cor de destaque; o "chrome" (barra de baixo,
/// cabecalho) continua navy pra manter a identidade unificada da
/// igreja, so troca o acento e o icone.
class ShallomColors {
  static const azul = Color(0xFF9BB0C7);
  static const creme = Color(0xFFF7F2DD);
  static const dourado = Color(0xFFCBA135);
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
  // Guarda os temas ja prontos na memoria depois da primeira vez de
  // cada um -- um cache por combinacao (claro/escuro x Awake/Shallom),
  // assim nunca precisa recalcular fontes e cores do zero de novo.
  static ThemeData? _lightAwake;
  static ThemeData? _lightShallom;
  static ThemeData? _darkAwake;
  static ThemeData? _darkShallom;
  static ThemeData? _amoledAwake;
  static ThemeData? _amoledShallom;

  /// `ehAwake` decide a cor de destaque do app inteiro (botoes, FAB,
  /// barra de navegacao): amarelo Awake ou azul Shallom. Nas telas de
  /// login/cadastro, antes de sabermos o ministerio da pessoa, usa o
  /// padrao (Awake).
  static ThemeData light({bool ehAwake = true}) {
    if (ehAwake) return _lightAwake ??= _buildLight(true);
    return _lightShallom ??= _buildLight(false);
  }

  static ThemeData dark({bool ehAwake = true}) {
    if (ehAwake) return _darkAwake ??= _buildDark(true);
    return _darkShallom ??= _buildDark(false);
  }

  /// Variante "mais escura" -- mesmo tema escuro, so com fundo preto de
  /// verdade (bom pra economizar bateria em tela AMOLED).
  static ThemeData amoled({bool ehAwake = true}) {
    if (ehAwake) return _amoledAwake ??= _buildDark(true, amoled: true);
    return _amoledShallom ??= _buildDark(false, amoled: true);
  }

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

  static ThemeData _buildLight(bool ehAwake) {
    final corDestaque = ehAwake ? AwakeColors.yellow : ShallomColors.azul;

    final colorScheme = const ColorScheme.light().copyWith(
      primary: AwakeColors.navy,
      onPrimary: AwakeColors.offWhite,
      secondary: corDestaque,
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
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AwakeColors.offWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: corDestaque,
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: corDestaque,
        foregroundColor: AwakeColors.navy,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? corDestaque : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? corDestaque.withOpacity(0.5)
              : null;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AwakeColors.navy,
        indicatorColor: corDestaque,
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
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AwakeColors.lightBlueGrey.withOpacity(0.5)),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// `amoled` troca o navy pelo preto de verdade (tema "mais escuro") --
  /// mesma estrutura do tema escuro normal, so os tons de fundo mudam.
  static ThemeData _buildDark(bool ehAwake, {bool amoled = false}) {
    final corDestaque = ehAwake ? AwakeColors.yellow : ShallomColors.azul;
    final corSurface = amoled ? AwakeColors.amoledSurface : AwakeColors.darkSurface;
    final corBackground = amoled ? AwakeColors.amoledBackground : AwakeColors.darkBackground;
    final corBorda = amoled ? const Color(0xFF262626) : const Color(0xFF3A4A6B);
    final corBordaCard = amoled ? const Color(0xFF1F1F1F) : const Color(0xFF2A3B5C);
    final corSurfaceContainer = amoled ? const Color(0xFF1A1A1A) : const Color(0xFF223252);

    final colorScheme = ColorScheme.dark(
      primary: AwakeColors.yellow,
      onPrimary: AwakeColors.navy,
      secondary: corDestaque,
      onSecondary: AwakeColors.navy,
      surface: corSurface,
      onSurface: AwakeColors.offWhite,
      surfaceContainerHighest: corSurfaceContainer,
      error: const Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: corBackground,
      textTheme: _buildTextTheme(AwakeColors.offWhite),
      appBarTheme: AppBarTheme(
        backgroundColor: corSurface,
        foregroundColor: AwakeColors.offWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AwakeColors.offWhite,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: corDestaque,
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
          foregroundColor: corDestaque,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: corDestaque,
        foregroundColor: AwakeColors.navy,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? corDestaque : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? corDestaque.withOpacity(0.5)
              : null;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: corSurface,
        indicatorColor: corDestaque,
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
        fillColor: corSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: corBorda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: corDestaque, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: corSurface,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: corBordaCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: corSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        color: corSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
