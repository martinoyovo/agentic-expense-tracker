import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../../features/charts/widgets/chart_widget.dart';
import '../../features/charts/models/chart_data.dart';
import '../../core/constants/app_constants.dart';

final chartWidgetItem = CatalogItem(
  name: 'ChartWidget',
  dataSchema: S.object(
    properties: {
      'chartType': S.string(description: 'Type of chart to display: "pie", "bar", or "line"'),
      'data': S.list(
      description: 'Array of data points for the chart',
        items: S.object(
          properties: {
            'label': S.string(description: 'Label for the data point'),
            'value': S.number(description: 'Numeric value for the data point'),
            'color': S.string(description: 'Hex color code for this data point'),
          },
          required: ['label', 'value', 'color'],
        ),
        ),
      },
    required: ['chartType', 'data'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    final chartType = data['chartType'] as String;
    final dataList = (data['data'] as List).map((item) {
      final itemMap = item as Map<String, dynamic>;
      final colorString = itemMap['color'] as String;
      final color = AppConstants.parseColor(colorString);

      return ChartDataPoint(
        label: itemMap['label'] as String,
        value: (itemMap['value'] as num).toDouble(),
        color: color,
      );
    }).toList();

    return ChartWidget(
      chartType: chartType,
      data: dataList,
    );
  },
);
