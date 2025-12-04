import 'package:flutter/material.dart';

class SurfaceManager extends ChangeNotifier {
  Widget? _backgroundWidget;
  Widget? _chartWidget;
  Widget? _totalWidget;
  final List<Widget> _categoryWidgets = [];
  Widget? _dialogWidget;

  Widget? get backgroundWidget => _backgroundWidget;
  Widget? get chartWidget => _chartWidget;
  Widget? get totalWidget => _totalWidget;
  List<Widget> get categoryWidgets => List.unmodifiable(_categoryWidgets);
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

  void addCategory(Widget widget) {
    _categoryWidgets.add(widget);
    notifyListeners();
  }

  void clearCategories() {
    _categoryWidgets.clear();
    notifyListeners();
  }

  void setCategories(List<Widget> widgets) {
    _categoryWidgets.clear();
    _categoryWidgets.addAll(widgets);
    notifyListeners();
  }

  void setDialog(Widget? widget) {
    _dialogWidget = widget;
    notifyListeners();
  }

  void clearDialog() {
    _dialogWidget = null;
    notifyListeners();
  }

  void clearAll() {
    _backgroundWidget = null;
    _chartWidget = null;
    _totalWidget = null;
    _categoryWidgets.clear();
    _dialogWidget = null;
    notifyListeners();
  }
}
