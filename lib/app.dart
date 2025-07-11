import 'package:flutter/material.dart';
import 'routes.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Define a shared color palette
    // const primaryColor = Color(0xFF2A2A3D);
    // const secondaryColor = Colors.orange;
    // const surfaceLight = Colors.white;
    // const backgroundLight = Color(0xFFF5F5F5);
    // const surfaceDark = Color(0xFF121212);
    // const backgroundDark = Colors.black;

    final lightColorScheme = ColorScheme.light(
      primary: Color(0xFF6F7CEF),
      onPrimary: Color(0xFFFFFFFF), // white text on primary
      secondary: Color(0xFFF1D07C),
      onSecondary: Color(0xFF282860), // dark text on yellow
      tertiary: Color(0xFF00D48D), // success / confirm
      error: Color(0xFFEC7440),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF), // background
      onSurface: Color(0xFF282860), // dark text on white
      surfaceContainerHighest: Color(0xFFF5F5F5), // light grey bg variant
      onSurfaceVariant: Color(0xFF6F7CEF), // brand tone on bg
      outline: Color(0xFFB0B9F1), // lighter brand tint for input border
      outlineVariant: Color(0xFF00AAAA), // subtle border
      secondaryContainer: Color(0xFFFFF3C4), // light yellow background
      onSecondaryContainer: Color(0xFF282860),
    );

    final darkColorScheme = ColorScheme.dark(
      primary: Color(0xFF6F7CEF),
      onPrimary: Color(0xFF282860),
      secondary: Color(0xFFF1D07C),
      onSecondary: Color(0xFF282860),
      tertiary: Color(0xFF00D48D),
      error: Color(0xFFEC7440),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFF282860), // dark background
      onSurface: Color(0xFFFFFFFF), // white text
      surfaceContainerHighest:
          Color(0xFF333366), // slightly lighter dark variant
      onSurfaceVariant: Color(0xFFB0B9F1),
      outline: Color(0xFF4C5099),
      outlineVariant: Color(0xFF00AAAA),
      secondaryContainer: Color(0xFF4A4A78), // muted yellow bg
      onSecondaryContainer: Color(0xFFF1D07C),
    );

    return MaterialApp(
      title: 'Scheduler App',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 0,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: lightColorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
          elevation: 0,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: darkColorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
