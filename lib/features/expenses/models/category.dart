import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final Color color;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final colorString = json['color'] as String;
    String hexColor = colorString.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    final color = Color(int.parse(hexColor, radix: 16));

    return ExpenseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: color,
    );
  }

  ExpenseCategory copyWith({
    String? id,
    String? name,
    Color? color,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
