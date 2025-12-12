import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/category.dart';

class ExpenseService extends ChangeNotifier {
  final List<ExpenseCategory> _categories = [];
  final List<Expense> _expenses = [];

  // Track recent expense additions to prevent duplicates
  final Map<String, DateTime> _recentExpenseKeys = {};
  static const _deduplicationWindow = Duration(
      seconds: 30); // Increased to prevent duplicates from rapid AI calls

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<Expense> get expenses => List.unmodifiable(_expenses);

  // Get expenses for a specific category
  List<Expense> getExpensesForCategory(String categoryId) {
    return _expenses.where((e) => e.categoryId == categoryId).toList();
  }

  // Add a new category (with deduplication - won't add if name exists)
  ExpenseCategory addCategory(String name, String colorHex) {
    // Check if category with same name already exists
    final existing = findCategoryByName(name);
    if (existing != null) {
      debugPrint(
          '🔍 [DEDUPE] Category "$name" already exists, returning existing');
      return existing;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final color = _parseColor(colorHex);
    final category = ExpenseCategory(id: id, name: name, color: color);
    _categories.add(category);
    notifyListeners();
    return category;
  }

  // Update category color
  void updateCategoryColor(String categoryId, String colorHex) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      final color = _parseColor(colorHex);
      _categories[index] = _categories[index].copyWith(color: color);
      notifyListeners();
    }
  }

  // Find category by name (case insensitive)
  ExpenseCategory? findCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Add a new expense (with deduplication - returns existing if duplicate)
  Expense addExpense(String title, double amount, String categoryId) {
    // Normalize the title for better deduplication
    final normalizedTitle = title.trim().toLowerCase();

    // Create a key for deduplication based on title, amount, and category
    final dedupeKey =
        '${normalizedTitle}_${amount.toStringAsFixed(2)}_$categoryId';
    final now = DateTime.now();

    // Check if this exact expense was added recently
    if (_recentExpenseKeys.containsKey(dedupeKey)) {
      final lastAdded = _recentExpenseKeys[dedupeKey]!;
      if (now.difference(lastAdded) < _deduplicationWindow) {
        debugPrint(
            '🔍 [DEDUPE] Skipping duplicate expense: "$title" \$$amount (category: $categoryId)');
        // Find and return the existing expense
        final existing = _expenses
            .where(
              (e) =>
                  e.title.trim().toLowerCase() == normalizedTitle &&
                  e.amount.toStringAsFixed(2) == amount.toStringAsFixed(2) &&
                  e.categoryId == categoryId,
            )
            .lastOrNull;

        if (existing != null) {
          debugPrint('✅ Returning existing expense: ${existing.id}');
          return existing;
        }
      }
    }

    // Also check if an expense with the same characteristics already exists in the list
    // (not just recent additions, but any existing expense)
    final duplicateExists = _expenses.any(
      (e) =>
          e.title.trim().toLowerCase() == normalizedTitle &&
          e.amount.toStringAsFixed(2) == amount.toStringAsFixed(2) &&
          e.categoryId == categoryId &&
          // Only consider it a duplicate if added within the deduplication window
          now.difference(e.date).abs() < _deduplicationWindow,
    );

    if (duplicateExists) {
      debugPrint(
          '🔍 [DEDUPE] Found existing duplicate expense in list: "$title" \$$amount');
      final existing = _expenses
          .where(
            (e) =>
                e.title.trim().toLowerCase() == normalizedTitle &&
                e.amount.toStringAsFixed(2) == amount.toStringAsFixed(2) &&
                e.categoryId == categoryId &&
                now.difference(e.date).abs() < _deduplicationWindow,
          )
          .last;
      return existing;
    }

    // Clean up old keys
    _recentExpenseKeys.removeWhere(
      (key, time) => now.difference(time) > _deduplicationWindow,
    );

    // Record this expense addition
    _recentExpenseKeys[dedupeKey] = now;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final expense = Expense(
      id: id,
      title: title.trim(), // Trim whitespace
      amount: amount,
      categoryId: categoryId,
      date: DateTime.now(),
    );
    _expenses.add(expense);
    debugPrint(
        '✅ Added new expense: "$title" \$$amount (ID: $id, Category: $categoryId)');
    notifyListeners();
    return expense;
  }

  // Remove expense
  void removeExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  // Get total expenses
  double get totalExpenses {
    return _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get total for a specific category
  double getTotalForCategory(String categoryId) {
    return _expenses
        .where((e) => e.categoryId == categoryId)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Helper to parse color
  Color _parseColor(String colorString) {
    final lowerColor = colorString.toLowerCase().trim();

    // Named colors
    final namedColors = {
      'red': const Color(0xFFF44336),
      'pink': const Color(0xFFE91E63),
      'purple': const Color(0xFF9C27B0),
      'deep purple': const Color(0xFF673AB7),
      'indigo': const Color(0xFF3F51B5),
      'blue': const Color(0xFF2196F3),
      'light blue': const Color(0xFF03A9F4),
      'cyan': const Color(0xFF00BCD4),
      'teal': const Color(0xFF009688),
      'green': const Color(0xFF4CAF50),
      'light green': const Color(0xFF8BC34A),
      'lime': const Color(0xFFCDDC39),
      'yellow': const Color(0xFFFFEB3B),
      'amber': const Color(0xFFFFC107),
      'orange': const Color(0xFFFF9800),
      'deep orange': const Color(0xFFFF5722),
      'brown': const Color(0xFF795548),
      'grey': const Color(0xFF9E9E9E),
      'blue grey': const Color(0xFF607D8B),
    };

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
      return const Color(0xFF9E9E9E); // Fallback to grey
    }
  }
}
