import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class ImagenService extends ChangeNotifier {
  String? _currentBackgroundUrl;
  String? _currentDescription;
  bool _isGenerating = false;

  String? get currentBackgroundUrl => _currentBackgroundUrl;
  String? get currentDescription => _currentDescription;
  bool get isGenerating => _isGenerating;

  Future<void> generateBackground(String prompt) async {
    _isGenerating = true;
    notifyListeners();

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash-exp',
      );

      // Generate image using Imagen
      final enhancedPrompt =
          'A beautiful, aesthetic background image for an expense tracker app. '
          'Style: $prompt. '
          'The image should be suitable as a full-screen background, '
          'with soft colors and not too busy so that UI elements can be placed on top.';

      final response =
          await model.generateContent([Content.text(enhancedPrompt)]);

      // Note: In a real implementation, you would extract the image URL from the response
      // For now, we'll use a placeholder pattern
      // In actual Imagen API, you'd get binary data or URL

      if (response.text != null) {
        // Placeholder: In real implementation, extract image data
        _currentBackgroundUrl = 'generated_image_url';
        _currentDescription = prompt;
      }
    } catch (e) {
      debugPrint('Error generating background: $e');
      // Use a gradient fallback
      _currentBackgroundUrl = null;
      _currentDescription = prompt;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void clearBackground() {
    _currentBackgroundUrl = null;
    _currentDescription = null;
    notifyListeners();
  }
}
