import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../../features/background/widgets/background_image_widget.dart';

final backgroundImageItem = CatalogItem(
  name: 'BackgroundImage',
  dataSchema: S.object(
    properties: {
      'imageUrl': S.string(description: 'URL of the background image (can be null to show gradient)'),
      'description': S.string(description: 'Description of the background theme/style'),
    },
    required: ['description'], // imageUrl is optional
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    // Handle both string and null imageUrl
    final imageUrlValue = data['imageUrl'];
    final imageUrl = imageUrlValue is String ? imageUrlValue : null;
    return BackgroundImageWidget(
      imageUrl: imageUrl,
      description: data['description'] as String?,
    );
  },
);
