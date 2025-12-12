import 'package:flutter/material.dart';

class SurfaceManager extends ChangeNotifier {
  Widget? _backgroundWidget;
  Widget? _chartWidget;
  Widget? _totalWidget;
  // Track categories by their surface ID to support multiple categories side-by-side
  final Map<String, Widget> _categorySurfaces = {};
  Widget? _dialogWidget;

  // Prevent rapid dialog updates (debouncing)
  DateTime? _lastDialogUpdate;
  static const _dialogDebounceMs = 500; // 500ms debounce

  Widget? get backgroundWidget => _backgroundWidget;
  Widget? get chartWidget => _chartWidget;
  Widget? get totalWidget => _totalWidget;
  List<Widget> get categoryWidgets => _categorySurfaces.values.toList();
  Widget? get dialogWidget => _dialogWidget;

  void setBackground(Widget? widget) {
    _backgroundWidget = widget;
    notifyListeners();
  }

  void setChart(Widget? widget) {
    _chartWidget = widget;
    notifyListeners();
  }

  void setTotal(Widget? widget) {
    _totalWidget = widget;
    notifyListeners();
  }

  // Add or update a category by its surface ID (supports multiple categories)
  void setCategorySurface(String surfaceId, Widget widget) {
    _categorySurfaces[surfaceId] = widget;
    notifyListeners();
  }

  // Remove a specific category by surface ID
  void removeCategorySurface(String surfaceId) {
    _categorySurfaces.remove(surfaceId);
    notifyListeners();
  }

  // Check if a category surface exists
  bool hasCategorySurface(String surfaceId) {
    return _categorySurfaces.containsKey(surfaceId);
  }

  void clearCategories() {
    _categorySurfaces.clear();
    notifyListeners();
  }

  void setDialog(Widget? widget) {
    // Debounce dialog updates to prevent LLM from showing multiple dialogs rapidly
    final now = DateTime.now();
    if (_lastDialogUpdate != null &&
        _dialogWidget != null &&
        widget != null) {
      final timeSinceLastUpdate =
          now.difference(_lastDialogUpdate!).inMilliseconds;
      if (timeSinceLastUpdate < _dialogDebounceMs) {
        // Ignore this update - too soon after the last one
        debugPrint(
            '🚫 Ignoring rapid dialog update (${timeSinceLastUpdate}ms since last update)');
        return;
      }
    }

    _lastDialogUpdate = now;
    _dialogWidget = widget;
    notifyListeners();
  }

  void clearDialog() {
    _dialogWidget = null;
    _lastDialogUpdate = null; // Reset debounce timer when dialog is cleared
    notifyListeners();
  }

  void clearAll() {
    _backgroundWidget = null;
    _chartWidget = null;
    _totalWidget = null;
    _categorySurfaces.clear();
    _dialogWidget = null;
    notifyListeners();
  }
}
