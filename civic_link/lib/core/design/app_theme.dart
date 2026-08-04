/// Civic-Link Design System — Theme Builder
///
/// Assembles the full [ThemeData] pair (light + dark) from the token files:
/// colors, text styles, radii, shadows, motion, spacing.
///
/// The ONLY correct way to get themed colors is through `Theme.of(context)`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_decoration.dart';
import 'app_text_styles.dart';

// =============================================================================
// PUBLIC ENTRYPOINT
// =============================================================================

abstract final class AppTheme {
  static ThemeData light() =>
      _base(brightness: Brightness.light, scheme: kLightColorScheme);

  static ThemeData dark() =>
      _base(brightness: Brightness.dark, scheme: kDarkColorScheme);

  // ---------------------------------------------------------------------------
  // BASE BUILDER
  // ---------------------------------------------------------------------------
  static ThemeData _base({
    required Brightness brightness,
    required ColorScheme scheme,
  }) {
    final textTheme = buildTextTheme(
      brightness,
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,

      // ---- AppBar -------------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 64,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),

      // ---- Cards ---------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.light ? 1 : 0,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderLg,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: brightness == Brightness.dark ? 1 : 0,
          ),
        ),
      ),

      // ---- Dialogs -------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // ---- Bottom sheets -------------------------------------------------------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ---- SnackBar ------------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        insetPadding: const EdgeInsets.all(16),
      ),

      // ---- Input decoration ----------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : scheme.surfaceContainerHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      // ---- Elevated Button -----------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: brightness == Brightness.dark
              ? scheme.onPrimary
              : scheme.onPrimary,
          disabledBackgroundColor:
              scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor:
              scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderMd,
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // ---- Text button ----------------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        ),
      ),

      // ---- Outlined button ------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),

      // ---- Icon / ListTile ------------------------------------------------------
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),

      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
        tileColor: Colors.transparent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      ),

      // ---- Divider --------------------------------------------------------------
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),

      // ---- Switch / Checkbox / Radio -------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.4);
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ---- Progress indicator --------------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),

      // ---- Date / time pickers --------------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        todayForegroundColor: WidgetStateProperty.all(scheme.primary),
        todayBorder: BorderSide(color: scheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderXl),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainer,
        hourMinuteColor: scheme.surfaceContainerHighest,
        hourMinuteTextColor: scheme.onSurface,
        dayPeriodColor: scheme.surfaceContainerHighest,
        dayPeriodTextColor: scheme.onSurface,
        dialHandColor: scheme.primary,
        dialTextColor: scheme.onSurface,
        entryModeIconColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderXl),
      ),

      // ---- Tab bar ---------------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.5),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ---- Dropdown ---------------------------------------------------------------
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(scheme.surfaceContainer),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
          ),
        ),
      ),

      // ---- Page transitions -------------------------------------------------------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ---- Splash / overlay colour -------------------------------------------------
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      hoverColor: scheme.primary.withValues(alpha: 0.04),
      focusColor: scheme.primary.withValues(alpha: 0.12),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
