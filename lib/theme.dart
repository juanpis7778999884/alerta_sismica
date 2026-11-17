import 'package:flutter/material.dart';

/// Identidad visual de Alerta Sísmica.
///
/// El rojo se reserva para emergencias y acciones críticas. El resto de la
/// interfaz usa superficies claras con contraste alto para facilitar la lectura
/// durante una situación de estrés.
class AppTheme {
  AppTheme._();

  static const Color rojoCritico = Color(0xFFC62828);
  static const Color rojoOscuro = Color(0xFF8E0000);
  static const Color rojoSuave = Color(0xFFFDECEA);
  static const Color ambarAdvertencia = Color(0xFFF9A825);
  static const Color ambarOscuro = Color(0xFFE65100);
  static const Color verdeOk = Color(0xFF2E7D32);
  static const Color azulInfo = Color(0xFF1565C0);
  static const Color grisNeutro = Color(0xFF5F6368);

  static const Color fondoLuz = Color(0xFFF6F7F9);
  static const Color superficieLuz = Color(0xFFFFFFFF);
  static const Color superficieElevadaLuz = Color(0xFFEEF1F4);
  static const Color bordeLuz = Color(0xFFD7DCE2);
  static const Color textoLuz = Color(0xFF1A1C1E);
  static const Color textoSecundarioLuz = Color(0xFF5F6368);

  static const Color fondoOscuro = Color(0xFF121416);
  static const Color superficieOscura = Color(0xFF1A1D20);
  static const Color superficieElevadaOscura = Color(0xFF23272B);
  static const Color bordeOscuro = Color(0xFF3B4147);
  static const Color textoOscuro = Color(0xFFE7EAEE);
  static const Color textoSecundarioOscuro = Color(0xFFAEB6BF);

  static const double radio = 12.0;
  static const double radioBoton = 14.0;
  static const double radioGrande = 20.0;

  static const double espacioXS = 4;
  static const double espacioS = 8;
  static const double espacioM = 16;
  static const double espacioL = 24;
  static const double espacioXL = 32;
  static const double espacioXXL = 48;

  static const EdgeInsets paddingXS = EdgeInsets.all(espacioXS);
  static const EdgeInsets paddingS = EdgeInsets.all(espacioS);
  static const EdgeInsets paddingM = EdgeInsets.all(espacioM);
  static const EdgeInsets paddingL = EdgeInsets.all(espacioL);
  static const EdgeInsets paddingXL = EdgeInsets.all(espacioXL);

  static const double iconoXS = 16;
  static const double iconoS = 20;
  static const double iconoM = 24;
  static const double iconoL = 32;
  static const double iconoXL = 48;
  static const double iconoXXL = 72;

  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle numerosGrandes = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle monospace = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const Color colorMagnitudMenor = Color(0xFF2E7D32);
  static const Color colorMagnitudLeve = Color(0xFF7CB342);
  static const Color colorMagnitudModerado = Color(0xFFF9A825);
  static const Color colorMagnitudFuerte = Color(0xFFEF6C00);
  static const Color colorMagnitudMayor = Color(0xFFC62828);

  static Color colorParaMagnitud(double magnitud) {
    if (magnitud >= 7) return colorMagnitudMayor;
    if (magnitud >= 6) return colorMagnitudFuerte;
    if (magnitud >= 5) return colorMagnitudModerado;
    if (magnitud >= 4) return colorMagnitudLeve;
    return colorMagnitudMenor;
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Alias conservado para integraciones que esperaban el tema claro.
  static ThemeData get theme => light;

  static ThemeData _build(Brightness brightness) {
    final esOscuro = brightness == Brightness.dark;
    final fondo = esOscuro ? fondoOscuro : fondoLuz;
    final superficie = esOscuro ? superficieOscura : superficieLuz;
    final superficieElevada = esOscuro
        ? superficieElevadaOscura
        : superficieElevadaLuz;
    final borde = esOscuro ? bordeOscuro : bordeLuz;
    final texto = esOscuro ? textoOscuro : textoLuz;
    final textoSecundario = esOscuro
        ? textoSecundarioOscuro
        : textoSecundarioLuz;
    final primary = esOscuro ? const Color(0xFFFF6B6B) : rojoCritico;
    final onPrimary = esOscuro ? const Color(0xFF3A0000) : Colors.white;
    final primaryContainer = esOscuro ? const Color(0xFF5F0E0E) : rojoSuave;
    final onPrimaryContainer = esOscuro
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF5F0E0E);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: esOscuro ? const Color(0xFF90A4AE) : const Color(0xFF455A64),
      onSecondary: esOscuro ? const Color(0xFF0F171B) : Colors.white,
      secondaryContainer: esOscuro
          ? const Color(0xFF2C363C)
          : const Color(0xFFE3E9ED),
      onSecondaryContainer: esOscuro
          ? const Color(0xFFD3E2EA)
          : const Color(0xFF17262C),
      tertiary: esOscuro ? const Color(0xFFFFCC80) : ambarOscuro,
      onTertiary: esOscuro ? const Color(0xFF3D2600) : Colors.white,
      tertiaryContainer: esOscuro
          ? const Color(0xFF5B3A00)
          : const Color(0xFFFFF3E0),
      onTertiaryContainer: esOscuro
          ? const Color(0xFFFFE0B2)
          : const Color(0xFF3D2600),
      error: esOscuro ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: esOscuro ? const Color(0xFF690005) : Colors.white,
      errorContainer: esOscuro
          ? const Color(0xFF93000A)
          : const Color(0xFFF9DEDC),
      onErrorContainer: esOscuro
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF410E0B),
      surface: superficie,
      onSurface: texto,
      surfaceContainerHighest: superficieElevada,
      onSurfaceVariant: textoSecundario,
      outline: borde,
      outlineVariant: borde.withValues(alpha: esOscuro ? 0.55 : 0.7),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: esOscuro ? textoOscuro : const Color(0xFF2E3135),
      onInverseSurface: esOscuro ? const Color(0xFF1A1C1E) : Colors.white,
      inversePrimary: esOscuro ? rojoCritico : const Color(0xFFFFB4AB),
    );

    final textTheme = TextTheme(
      displayLarge: displayLarge.copyWith(color: texto),
      displayMedium: displayMedium.copyWith(color: texto),
      displaySmall: displaySmall.copyWith(color: texto),
      headlineLarge: headlineLarge.copyWith(color: texto),
      headlineMedium: headlineMedium.copyWith(color: texto),
      headlineSmall: headlineSmall.copyWith(color: texto),
      titleLarge: titleLarge.copyWith(color: texto),
      titleMedium: titleMedium.copyWith(color: texto),
      titleSmall: titleSmall.copyWith(color: textoSecundario),
      bodyLarge: bodyLarge.copyWith(color: texto),
      bodyMedium: bodyMedium.copyWith(color: textoSecundario),
      bodySmall: bodySmall.copyWith(color: textoSecundario),
      labelLarge: labelLarge.copyWith(color: texto),
      labelMedium: labelMedium.copyWith(color: texto),
      labelSmall: labelSmall.copyWith(color: textoSecundario),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: fondo,
      colorScheme: scheme,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: superficie,
        foregroundColor: texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: headlineMedium.copyWith(color: texto),
      ),
      cardTheme: CardThemeData(
        color: superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
          side: BorderSide(color: borde, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: superficieElevada,
          disabledForegroundColor: textoSecundario,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioBoton),
          ),
          textStyle: labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: superficieElevada,
          disabledForegroundColor: textoSecundario,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioBoton),
          ),
          textStyle: labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texto,
          disabledForegroundColor: textoSecundario,
          side: BorderSide(color: borde, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioBoton),
          ),
          textStyle: labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: textoSecundario,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
          textStyle: labelMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: texto,
          disabledForegroundColor: textoSecundario,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esOscuro ? superficieElevadaOscura : const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: borde, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: borde, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
        labelStyle: bodyMedium.copyWith(color: textoSecundario),
        hintStyle: bodySmall.copyWith(color: textoSecundario),
        errorStyle: bodySmall.copyWith(color: scheme.error),
      ),
      dividerTheme: DividerThemeData(color: borde, thickness: 0.8, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        titleTextStyle: bodyLarge.copyWith(color: texto),
        subtitleTextStyle: bodyMedium.copyWith(color: textoSecundario),
        iconColor: textoSecundario,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryContainer,
        elevation: 2,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => labelSmall.copyWith(
            color: states.contains(WidgetState.selected)
                ? primary
                : textoSecundario,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : textoSecundario,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: esOscuro
            ? const Color(0xFFE7EAEE)
            : const Color(0xFF2E3135),
        contentTextStyle: bodyMedium.copyWith(
          color: esOscuro ? const Color(0xFF1A1C1E) : Colors.white,
        ),
        actionTextColor: esOscuro ? rojoCritico : const Color(0xFFFFB4AB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioGrande),
        ),
        titleTextStyle: headlineMedium.copyWith(color: texto),
        contentTextStyle: bodyMedium.copyWith(color: textoSecundario),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radioGrande),
          ),
        ),
        showDragHandle: true,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: superficieElevada,
        circularTrackColor: superficieElevada,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.35)
              : null,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: superficieElevada,
        overlayColor: primary.withValues(alpha: 0.12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: superficieElevada,
        selectedColor: primaryContainer,
        side: BorderSide(color: borde),
        labelStyle: labelMedium.copyWith(color: texto),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioBoton),
        ),
      ),
    );
  }
}
