import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../../features/expenses/widgets/category_column_widget.dart';
import '../../core/constants/app_constants.dart';

final categoryColumnItem = CatalogItem(
  name: 'CategoryColumn',
  dataSchema: S.object(
    properties: {
      'id': S.string(description: 'Unique identifier for the category'),
      'name': S.string(description: 'The name of the category (e.g., "Food & Drink", "Travel")'),
      'color': S.string(description: 'Hex color code (e.g., "#FF5733") or named color (e.g., "purple")'),
      'expenses': S.list(
        description: 'Array of expense objects in this category',
        items: S.object(
          properties: {
            'id': S.string(description: 'Unique expense ID'),
            'title': S.string(description: 'Expense title/description'),
            'amount': S.number(description: 'Amount in dollars'),
            'date': S.string(description: 'ISO 8601 date string (ALWAYS include this)'),
          },
          required: ['id', 'title', 'amount', 'date'],
        ),
      ),
    },
    required: ['id', 'name', 'color', 'expenses'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    final colorString = data['color'] as String;
    final color = AppConstants.parseColor(colorString);

    return CategoryColumnWidget(
      id: data['id'] as String,
      name: data['name'] as String,
      color: color,
      expenses: (data['expenses'] as List).cast<Map<String, dynamic>>(),
    );
  },
);
