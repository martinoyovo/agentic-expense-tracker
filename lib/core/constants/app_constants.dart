import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Expense Tracker';

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXl = 32.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;

  // Category colors (defaults)
  static const Map<String, Color> defaultCategoryColors = {
    'Food & Drink': Color(0xFF4CAF50),
    'Travel': Color(0xFF2196F3),
    'Work': Color(0xFFFF9800),
    'Entertainment': Color(0xFF9C27B0),
    'Shopping': Color(0xFFE91E63),
    'Health': Color(0xFF00BCD4),
    'Other': Color(0xFF607D8B),
  };

  // Named colors for parsing
  static const Map<String, Color> namedColors = {
    'red': Colors.red,
    'pink': Colors.pink,
    'purple': Colors.purple,
    'deep purple': Colors.deepPurple,
    'indigo': Colors.indigo,
    'blue': Colors.blue,
    'light blue': Colors.lightBlue,
    'cyan': Colors.cyan,
    'teal': Colors.teal,
    'green': Colors.green,
    'light green': Colors.lightGreen,
    'lime': Colors.lime,
    'yellow': Colors.yellow,
    'amber': Colors.amber,
    'orange': Colors.orange,
    'deep orange': Colors.deepOrange,
    'brown': Colors.brown,
    'grey': Colors.grey,
    'blue grey': Colors.blueGrey,
  };

  // Parse color from string (hex or named)
  static Color parseColor(String colorString) {
    final lowerColor = colorString.toLowerCase().trim();

    // Check named colors
    if (namedColors.containsKey(lowerColor)) {
      return namedColors[lowerColor]!;
    }

    // Parse hex color
    try {
      String hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.grey; // Fallback
    }
  }

  // GenUI Surface IDs
  static const String surfaceBackground = 'background';
  static const String surfaceChart = 'chart';
  static const String surfaceTotal = 'total';
  static const String surfaceCategories = 'categories';
  static const String surfaceDialog = 'dialog';

  // Chart types
  static const String chartTypePie = 'pie';
  static const String chartTypeBar = 'bar';
  static const String chartTypeLine = 'line';
}
