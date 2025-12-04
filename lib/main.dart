import 'package:expense_tracker_genui/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle Flutter framework errors (like font loading failures)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log font loading errors but don't crash
    if (details.exception.toString().contains('google_fonts') ||
        details.exception.toString().contains('font') ||
        details.exception.toString().contains('Operation not permitted')) {
      debugPrint('Font loading error (non-critical): ${details.exception}');
      return; // Don't crash on font loading errors
    }
    // For other errors, use default behavior
    FlutterError.presentError(details);
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    // Log network/font errors but don't crash
    if (error.toString().contains('Operation not permitted') ||
        error.toString().contains('google_fonts') ||
        error.toString().contains('font')) {
      debugPrint('Network/font error (non-critical): $error');
      return true; // Error handled, don't crash
    }
    return false; // Let other errors propagate
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway - app can still run without Firebase
  }

  runApp(const ExpenseTrackerApp());
}
