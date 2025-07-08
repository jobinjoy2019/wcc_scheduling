import 'dart:async'; // Import this for runZonedGuarded
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode and debugPrint
import 'app.dart'; // Assuming your main app widget is in app.dart
import 'theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  // Wrap the entire app initialization and run within runZonedGuarded
  runZonedGuarded<Future<void>>(() async {
    // Ensure Flutter binding is initialized before any Flutter-specific calls
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();

    // Run your main application widget
    runApp(ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ));
  }, (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Caught an unhandled error in runZonedGuarded: $error');
      debugPrint('Stack trace: $stack');
    } else {
      debugPrint('Unhandled error in release mode: $error');
    }
  });
}
