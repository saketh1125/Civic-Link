import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_link/main.dart';

ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: kPrimaryBlack,
    colorScheme: ColorScheme.dark(
      primary: kAccentGreen,
      onPrimary: kPrimaryBlack,
      secondary: kAccentGreen,
      onSecondary: kPrimaryBlack,
      surface: kPrimaryBlack,
      onSurface: Colors.white,
      error: Colors.redAccent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: kInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: kHintGrey, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentGreen,
        foregroundColor: kPrimaryBlack,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: Colors.white,
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
      labelSmall: TextStyle(color: kHintGrey, fontSize: 15),
    ),
    dividerColor: Colors.white38,
  );
}

/// Pump a widget wrapped in ProviderScope and the app theme.
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget) {
    return pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: widget,
        ),
      ),
    );
  }
}
