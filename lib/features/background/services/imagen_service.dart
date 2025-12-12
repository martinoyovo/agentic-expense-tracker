import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class ImagenService extends ChangeNotifier {
  String? _currentBackgroundUrl;
  String? _currentDescription;
  String? _geminiGeneratedPrompt;
  Uint8List? _generatedImageData;
  bool _isGenerating = false;

  String? get currentBackgroundUrl => _currentBackgroundUrl;
  String? get currentDescription => _currentDescription;
  String? get geminiGeneratedPrompt => _geminiGeneratedPrompt;
  Uint8List? get generatedImageData => _generatedImageData;
  bool get isGenerating => _isGenerating;

  /// Generate background using Gemini to create enhanced prompts
  /// In production, this would call Imagen API with the Gemini-generated prompt
  Future<void> generateBackground(String userPrompt) async {
    _isGenerating = true;
    notifyListeners();

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash-exp',
      );

      // Use Gemini to generate a highly detailed, creative image prompt
      final promptGenerationRequest = '''
You are an expert at creating detailed image generation prompts. 
Given a simple user request for a background image, create a highly detailed, 
aesthetic prompt suitable for image generation.

User request: "$userPrompt"

Create a detailed prompt that:
1. Describes the visual style, colors, mood, and atmosphere
2. Specifies it's for a mobile app background (needs to be subtle, not distracting)
3. Includes artistic direction (lighting, composition, color palette)
4. Is suitable for an expense tracker app (professional but inviting)

Respond with ONLY the enhanced prompt, nothing else.
''';

      debugPrint('🎨 Using Gemini to generate enhanced image prompt...');
      final response =
          await model.generateContent([Content.text(promptGenerationRequest)]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Gemini did not generate a prompt');
      }

      final enhancedPrompt = response.text!.trim();
      _geminiGeneratedPrompt = enhancedPrompt;
      _currentDescription = userPrompt;

      debugPrint('✨ Gemini generated prompt: $enhancedPrompt');

      // Use ImageGen model (gemini-2.5-flash-image-preview) to generate image
      // This is the same approach used in Flutter demos - no authentication needed!
      debugPrint('🎨 Calling ImageGen model to generate image...');
      final imageData = await _generateImageWithImageGen(enhancedPrompt);

      if (imageData != null) {
        _generatedImageData = imageData;
        // Store image as base64 data URL for display
        final base64Image = base64Encode(imageData);
        _currentBackgroundUrl = 'data:image/png;base64,$base64Image';
        debugPrint(
            '✅ Image generated successfully (${imageData.length} bytes)');
      } else {
        // Fallback to gradient if image generation fails
        _currentBackgroundUrl = null;
        _generatedImageData = null;
        debugPrint('⚠️ Image generation failed, using gradient fallback');
      }

      debugPrint('✅ Background generation complete');
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating background: $e');
      debugPrint('Stack trace: $stackTrace');
      // Use a gradient fallback
      _currentBackgroundUrl = null;
      _currentDescription = userPrompt;
      _geminiGeneratedPrompt = null;
      _generatedImageData = null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Generate image using ImageGen model (gemini-2.5-flash-image-preview)
  /// This uses the same approach as Flutter demos - no authentication needed!
  /// Reference: https://github.com/flutter/demos/tree/main/firebase_ai_logic_showcase
  Future<Uint8List?> _generateImageWithImageGen(String prompt) async {
    try {
      // Use ImageGen model with image response modality
      // This is the same model used in Flutter demos
      final imageModel = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-image-preview',
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
        ),
      );

      debugPrint('📤 Generating image with ImageGen model...');
      final response =
          await imageModel.generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 60), // Image generation can take longer
        onTimeout: () {
          throw Exception('ImageGen API request timeout');
        },
      );

      // Extract image bytes from response
      // ImageGen returns images in inlineDataParts
      if (response.inlineDataParts.isNotEmpty) {
        final imageBytes = response.inlineDataParts.first.bytes;
        debugPrint(
            '✅ Successfully generated image (${imageBytes.length} bytes)');
        return imageBytes;
      } else {
        debugPrint('⚠️ ImageGen response missing image data');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating image with ImageGen: $e');
      debugPrint('Stack trace: $stackTrace');

      // Return null to trigger gradient fallback
      return null;
    }
  }

  void clearBackground() {
    _currentBackgroundUrl = null;
    _currentDescription = null;
    _geminiGeneratedPrompt = null;
    _generatedImageData = null;
    notifyListeners();
  }
}
