import 'package:flutter/material.dart';

class AppTheme {
  static const Color negro = Color(0xFF0D0D0D);
  static const Color grisMuyOscuro = Color(0xFF141414);
  static const Color grisOscuro = Color(0xFF1E1E1E);
  static const Color grisMedio = Color(0xFF2A2A2A);
  static const Color grisClaro = Color(0xFF3A3A3A);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color blancoSuave = Color(0xFFE0E0E0);
  static const Color blancoMuySuave = Color(0xFFB0B0B0);

  static const Color rojoCritico = Color(0xFFD32F2F);
  static const Color rojoOscuro = Color(0xFFB71C1C);
  static const Color ambarAdvertencia = Color(0xFFFFB300);
  static const Color ambarOscuro = Color(0xFFF57C00);
  static const Color verdeOk = Color(0xFF43A047);
  static const Color azulInfo = Color(0xFF2196F3);

  static const Color fondo = negro;
  static const Color superficie = grisOscuro;
  static const Color superficieElevada = grisMedio;
  static const Color borde = grisClaro;
  static const Color textoPrincipal = blanco;
  static const Color textoSecundario = blancoSuave;
  static const Color textoTerciario = blancoMuySuave;
  static const Color textoSobreRojo = blanco;
  static const Color textoSobreAmbar = negro;

  static const double radio = 8.0;
  static const double radioBoton = 12.0;

  static const TextStyle base = TextStyle(
    fontFamily: 'Roboto',
    color: textoPrincipal,
    height: 1.4,
  );

  static const TextStyle baseSecundario = TextStyle(
    fontFamily: 'Roboto',
    color: textoSecundario,
    height: 1.4,
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    color: textoSecundario,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: textoSecundario,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textoPrincipal,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textoSecundario,
    fontFamily: 'Roboto',
    height: 1.4,
  );

  static const TextStyle numerosGrandes = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFamily: 'monospace',
    color: textoPrincipal,
  );

  static const TextStyle monospace = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textoTerciario,
  );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondo,
        colorScheme: const ColorScheme.dark(
          primary: rojoCritico,
          primaryContainer: rojoOscuro,
          secondary: ambarAdvertencia,
          secondaryContainer: ambarOscuro,
          surface: superficie,
          surfaceContainerHighest: superficieElevada,
          outline: borde,
          onPrimary: textoSobreRojo,
          onSecondary: textoSobreAmbar,
          onSurface: textoPrincipal,
          onSurfaceVariant: textoSecundario,
          error: rojoCritico,
          onError: textoSobreRojo,
        ),
        textTheme: const TextTheme(
          displayLarge: displayLarge,
          displayMedium: displayMedium,
          displaySmall: displaySmall,
          headlineLarge: headlineLarge,
          headlineMedium: headlineMedium,
          headlineSmall: headlineSmall,
          titleLarge: titleLarge,
          titleMedium: titleMedium,
          titleSmall: titleSmall,
          bodyLarge: bodyLarge,
          bodyMedium: bodyMedium,
          bodySmall: bodySmall,
          labelLarge: labelLarge,
          labelMedium: labelMedium,
          labelSmall: labelSmall,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: grisMuyOscuro,
          foregroundColor: textoPrincipal,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: headlineMedium,
        ),
        cardTheme: CardThemeData(
          color: superficie,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
            side: const BorderSide(color: borde, width: 0.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: rojoCritico,
            foregroundColor: textoSobreRojo,
            disabledBackgroundColor: grisClaro,
            disabledForegroundColor: textoTerciario,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioBoton),
            ),
            textStyle: labelLarge,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: rojoCritico,
            foregroundColor: textoSobreRojo,
            disabledBackgroundColor: grisClaro,
            disabledForegroundColor: textoTerciario,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioBoton),
            ),
            textStyle: labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textoPrincipal,
            disabledForegroundColor: textoTerciario,
            side: const BorderSide(color: borde, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radioBoton),
            ),
            textStyle: labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: rojoCritico,
            disabledForegroundColor: textoTerciario,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(88, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radio),
            ),
            textStyle: labelMedium,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: textoPrincipal,
            disabledForegroundColor: textoTerciario,
            backgroundColor: Colors.transparent,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: superficieElevada,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radio),
            borderSide: const BorderSide(color: borde, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radio),
            borderSide: const BorderSide(color: borde, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radio),
            borderSide: const BorderSide(color: rojoCritico, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radio),
            borderSide: const BorderSide(color: rojoCritico, width: 1),
          ),
          labelStyle: bodyMedium,
          hintStyle: bodySmall,
        ),
        dividerTheme: const DividerThemeData(
          color: borde,
          thickness: 0.5,
          space: 16,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          titleTextStyle: bodyLarge,
          subtitleTextStyle: bodyMedium,
          iconColor: textoTerciario,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: grisMuyOscuro,
          selectedItemColor: rojoCritico,
          unselectedItemColor: textoTerciario,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: superficieElevada,
          contentTextStyle: bodyMedium,
          actionTextColor: ambarAdvertencia,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: superficie,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio * 2),
          ),
          titleTextStyle: headlineMedium,
          contentTextStyle: bodyMedium,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: rojoCritico,
          linearTrackColor: grisClaro,
          circularTrackColor: grisClaro,
        ),
      );

  static const EdgeInsets paddingXS = EdgeInsets.all(4);
  static const EdgeInsets paddingS = EdgeInsets.all(8);
  static const EdgeInsets paddingM = EdgeInsets.all(16);
  static const EdgeInsets paddingL = EdgeInsets.all(24);
  static const EdgeInsets paddingXL = EdgeInsets.all(32);

  static const EdgeInsets paddingHorizontalS = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets paddingHorizontalM = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets paddingHorizontalL = EdgeInsets.symmetric(horizontal: 24);

  static const EdgeInsets paddingVerticalS = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets paddingVerticalM = EdgeInsets.symmetric(vertical: 16);
  static const EdgeInsets paddingVerticalL = EdgeInsets.symmetric(vertical: 24);

  static const double espacioXS = 4;
  static const double espacioS = 8;
  static const double espacioM = 16;
  static const double espacioL = 24;
  static const double espacioXL = 32;
  static const double espacioXXL = 48;

  static const double iconoXS = 16;
  static const double iconoS = 20;
  static const double iconoM = 24;
  static const double iconoL = 32;
  static const double iconoXL = 48;
  static const double iconoXXL = 96;
}
