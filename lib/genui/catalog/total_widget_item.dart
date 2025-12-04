import 'package:genui/genui.dart';
import '../../features/summary/widgets/total_widget.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final totalWidgetItem = CatalogItem(
  name: 'TotalWidget',
  dataSchema: S.object(
    properties: {
      'amount': S.number(description: 'The total amount to display'),
      'label': S.string(
          description:
              'Descriptive label (e.g., "this week", "November", "all time")'),
    },
    required: ['amount', 'label'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    return TotalWidget(
      amount: (data['amount'] as num).toDouble(),
      label: data['label'] as String,
    );
  },
);
