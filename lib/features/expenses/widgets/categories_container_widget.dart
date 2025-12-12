import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'category_column_widget.dart';

/// A container widget that displays multiple CategoryColumn widgets side by side
class CategoriesContainerWidget extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const CategoriesContainerWidget({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('No categories yet. Add an expense to get started!'),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categories.map((categoryData) {
            return CategoryColumnWidget(
              id: categoryData['id'] as String,
              name: categoryData['name'] as String,
              color: AppConstants.parseColor(categoryData['color'] as String),
              expenses: (categoryData['expenses'] as List)
                  .cast<Map<String, dynamic>>(),
            );
          }).toList(),
        ),
      ),
    );
  }
}
