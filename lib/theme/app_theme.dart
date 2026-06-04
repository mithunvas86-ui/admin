import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: Colors.blue.shade600,
      secondary: Colors.blue.shade400,
      surface: Colors.white,
      background: Colors.grey.shade50,
    ),
    textTheme: GoogleFonts.chivoTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.black),
      titleTextStyle: GoogleFonts.chivo(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    ),
  );
}

class AppColors {
  static const primary = Color(0xFF1E88E5);
  static const secondary = Color(0xFF42A5F5);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF388E3C);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const yellow = Color(0xFFFBC02D);
  static const onSurfaceVariant = Color(0xFF616161);
  static const surfaceContainerHigh = Color(0xFFEEEEEE);
}
