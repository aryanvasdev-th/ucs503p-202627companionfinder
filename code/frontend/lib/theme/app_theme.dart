import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens shared across light and dark, mirrored from the design canvas.
class AppColors {
  AppColors._();

  // Brand accent
  static const Color brandLight = Color(0xFFBC3B39);
  static const Color brandInkLight = Color(0xFF8F2C2A);
  static const Color brandTintLight = Color(0xFFFBEDEC);

  static const Color brandDark = Color(0xFFE2604A);
  static const Color brandInkDark = Color(0xFFF0846F);
  static const Color brandTintDark = Color(0xFF2E1D1A);

  // Secondary accent (indigo), used for "View Details" / attendee-count badges
  static const Color indigoLight = Color(0xFF5B57E8);
  static const Color indigoTintLight = Color(0xFFE9E8FC);
  static const Color indigoDark = Color(0xFF8C89F5);
  static const Color indigoTintDark = Color(0xFF26244A);

  // Status
  static const Color greenLight = Color(0xFF3C8A5B);
  static const Color greenTintLight = Color(0xFFE4F3EA);
  static const Color greenDark = Color(0xFF6FBE8F);
  static const Color greenTintDark = Color(0xFF1D3327);

  // Surfaces
  static const Color bgLight = Color(0xFFF7F4F2);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color fieldLight = Color(0xFFF1ECE9);
  static const Color dividerLight = Color(0xFFEDE8E5);
  static const Color textLight = Color(0xFF1B1917);
  static const Color text2Light = Color(0xFF6E6864);
  static const Color text3Light = Color(0xFFA39C97);

  static const Color bgDark = Color(0xFF131211);
  static const Color surfaceDark = Color(0xFF1E1C1B);
  static const Color fieldDark = Color(0xFF262321);
  static const Color dividerDark = Color(0xFF2B2827);
  static const Color textDark = Color(0xFFF4F1EF);
  static const Color text2Dark = Color(0xFFA8A19D);
  static const Color text3Dark = Color(0xFF79726E);
}

/// Non-Material tokens (the ones ColorScheme has no slot for) exposed via
/// `Theme.of(context).extension<AppExtras>()`.
class AppExtras extends ThemeExtension<AppExtras> {
  final Color brandInk;
  final Color brandTint;
  final Color indigo;
  final Color indigoTint;
  final Color green;
  final Color greenTint;
  final Color field;
  final Color text2;
  final Color text3;

  const AppExtras({
    required this.brandInk,
    required this.brandTint,
    required this.indigo,
    required this.indigoTint,
    required this.green,
    required this.greenTint,
    required this.field,
    required this.text2,
    required this.text3,
  });

  static const light = AppExtras(
    brandInk: AppColors.brandInkLight,
    brandTint: AppColors.brandTintLight,
    indigo: AppColors.indigoLight,
    indigoTint: AppColors.indigoTintLight,
    green: AppColors.greenLight,
    greenTint: AppColors.greenTintLight,
    field: AppColors.fieldLight,
    text2: AppColors.text2Light,
    text3: AppColors.text3Light,
  );

  static const dark = AppExtras(
    brandInk: AppColors.brandInkDark,
    brandTint: AppColors.brandTintDark,
    indigo: AppColors.indigoDark,
    indigoTint: AppColors.indigoTintDark,
    green: AppColors.greenDark,
    greenTint: AppColors.greenTintDark,
    field: AppColors.fieldDark,
    text2: AppColors.text2Dark,
    text3: AppColors.text3Dark,
  );

  @override
  AppExtras copyWith({
    Color? brandInk,
    Color? brandTint,
    Color? indigo,
    Color? indigoTint,
    Color? green,
    Color? greenTint,
    Color? field,
    Color? text2,
    Color? text3,
  }) {
    return AppExtras(
      brandInk: brandInk ?? this.brandInk,
      brandTint: brandTint ?? this.brandTint,
      indigo: indigo ?? this.indigo,
      indigoTint: indigoTint ?? this.indigoTint,
      green: green ?? this.green,
      greenTint: greenTint ?? this.greenTint,
      field: field ?? this.field,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
    );
  }

  @override
  AppExtras lerp(ThemeExtension<AppExtras>? other, double t) {
    if (other is! AppExtras) return this;
    return AppExtras(
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      indigo: Color.lerp(indigo, other.indigo, t)!,
      indigoTint: Color.lerp(indigoTint, other.indigoTint, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenTint: Color.lerp(greenTint, other.greenTint, t)!,
      field: Color.lerp(field, other.field, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppExtras get extras => Theme.of(this).extension<AppExtras>()!;
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color text, Color text2) {
    final headingFont = GoogleFonts.fredokaTextTheme();
    final bodyFont = GoogleFonts.plusJakartaSansTextTheme();
    return bodyFont
        .copyWith(
          displayLarge: headingFont.displayLarge,
          displayMedium: headingFont.displayMedium,
          displaySmall: headingFont.displaySmall,
          headlineLarge: headingFont.headlineLarge,
          headlineMedium: headingFont.headlineMedium,
          headlineSmall: headingFont.headlineSmall,
          titleLarge: headingFont.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleMedium: headingFont.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleSmall: headingFont.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: text, displayColor: text)
        .copyWith(
          bodySmall: bodyFont.bodySmall?.copyWith(color: text2),
          labelSmall: bodyFont.labelSmall?.copyWith(color: text2),
        );
  }

  static ThemeData get light {
    const cs = ColorScheme.light(
      primary: AppColors.brandLight,
      onPrimary: Colors.white,
      secondary: AppColors.indigoLight,
      onSecondary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      error: AppColors.brandLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: _textTheme(AppColors.textLight, AppColors.text2Light),
      extensions: const [AppExtras.light],
      dividerColor: AppColors.dividerLight,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.text3Light),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandLight,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const cs = ColorScheme.dark(
      primary: AppColors.brandDark,
      onPrimary: Colors.white,
      secondary: AppColors.indigoDark,
      onSecondary: Color(0xFF161522),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      error: AppColors.brandDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: _textTheme(AppColors.textDark, AppColors.text2Dark),
      extensions: const [AppExtras.dark],
      dividerColor: AppColors.dividerDark,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.text3Dark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandDark,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
