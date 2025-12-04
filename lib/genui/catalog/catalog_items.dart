import 'package:genui/genui.dart';
import 'category_column_item.dart';
import 'expense_card_item.dart';
import 'chart_widget_item.dart';
import 'total_widget_item.dart';
import 'confirmation_dialog_item.dart';
import 'background_image_item.dart';

/// Creates the GenUI catalog with all available widgets
Catalog createCatalog() {
  return Catalog([
    categoryColumnItem,
    expenseCardItem,
    chartWidgetItem,
    totalWidgetItem,
    confirmationDialogItem,
    backgroundImageItem,
  ]);
}
