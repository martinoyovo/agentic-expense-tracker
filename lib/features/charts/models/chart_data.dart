import 'package:flutter/material.dart';

class ChartDataPoint {
  final String label;
  final double value;
  final Color color;

  ChartDataPoint({
    required this.label,
    required this.value,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
    };
  }

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    final colorString = json['color'] as String;
    String hexColor = colorString.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    final color = Color(int.parse(hexColor, radix: 16));

    return ChartDataPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      color: color,
    );
  }
}
