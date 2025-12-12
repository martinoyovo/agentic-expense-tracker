import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../../features/expenses/widgets/expense_card_widget.dart';

final expenseCardItem = CatalogItem(
  name: 'ExpenseCard',
  dataSchema: S.object(
    properties: {
      'id': S.string(description: 'Unique identifier for the expense'),
      'title': S.string(description: 'The name/description of the expense'),
      'amount': S.number(description: 'The expense amount in dollars'),
      'date': S.string(description: 'ISO 8601 date string when the expense occurred (ALWAYS include)'),
    },
    required: ['id', 'title', 'amount', 'date'],
    ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    return ExpenseCardWidget(
      id: data['id'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      date: data['date'] != null ? DateTime.parse(data['date'] as String) : null,
    );
  },
);
