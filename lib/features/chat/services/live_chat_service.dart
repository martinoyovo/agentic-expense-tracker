import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;
import 'package:genui/genui.dart' as genui;
import '../../../app.dart'
    show globalExpenseService, globalSurfaceManager, globalGenUiConversation;

/// Available voice options for the AI
enum AiVoice {
  aoede('Aoede', 'Warm and clear'),
  charon('Charon', 'Deep and resonant'),
  fenrir('Fenrir', 'Strong and bold'),
  kore('Kore', 'Soft and gentle'),
  puck('Puck', 'Playful and energetic');

  final String name;
  final String description;
  const AiVoice(this.name, this.description);
}

/// Service to manage real-time voice chat with Gemini Live API
class LiveChatService extends ChangeNotifier {
  LiveGenerativeModel? _liveModel;
  LiveSession? _session;

  bool _isConnected = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String? _currentTranscript;
  String? _aiTranscript;
  AiVoice _selectedVoice = AiVoice.aoede;

  // Stop controller for continuous message processing (matching Google's demo)
  StreamController<bool> _stopController = StreamController<bool>();

  final _audioResponseController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _aiTranscriptController = StreamController<String>.broadcast();

  // Tools for function calling
  List<dynamic>? _tools; // Store DynamicAiTool instances
  List<Tool>? _firebaseTools; // Store converted Firebase AI tools

  // Getters
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  String? get currentTranscript => _currentTranscript;
  String? get aiTranscript => _aiTranscript;
  AiVoice get selectedVoice => _selectedVoice;

  /// Stream of audio data from AI responses
  Stream<Uint8List> get audioResponseStream => _audioResponseController.stream;

  /// Stream of user speech transcriptions
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Stream of AI response transcriptions
  Stream<String> get aiTranscriptStream => _aiTranscriptController.stream;

  /// Set the AI voice
  void setVoice(AiVoice voice) {
    _selectedVoice = voice;
    notifyListeners();
  }

  /// Set tools for function calling (called from app.dart)
  void setTools(List<dynamic> tools, List<Tool> firebaseTools) {
    _tools = tools;
    _firebaseTools = firebaseTools;
  }

  /// Connect to Gemini Live API
  Future<void> connect({String? systemInstruction, List<Tool>? tools}) async {
    if (_isConnected) return;

    try {
      debugPrint('🔌 Connecting to Gemini Live API...');
      debugPrint(
          '📋 Config: model=gemini-2.0-flash-live-preview-04-09, voice=${_selectedVoice.name}');

      // Use Vertex AI with Gemini 2.0 Flash Live (matching Google's demo)
      // Make sure Vertex AI API is enabled in Google Cloud Console
      _liveModel = FirebaseAI.vertexAI().liveGenerativeModel(
        model:
            'gemini-2.0-flash-live-preview-04-09', // Full Live API model name
        liveGenerationConfig: LiveGenerationConfig(
          responseModalities: [
            ResponseModalities.audio, // Only audio (matching Google's demo)
          ],
          speechConfig: SpeechConfig(voiceName: _selectedVoice.name),
        ),
        systemInstruction:
            systemInstruction != null ? Content.text(systemInstruction) : null,
        tools: tools ?? _firebaseTools, // Use passed tools or stored tools
      );

      debugPrint('🔗 Establishing connection...');
      _session = await _liveModel!.connect();
      _isConnected = true;
      notifyListeners();

      debugPrint('✅ Connected to Gemini Live API successfully');

      // Start continuous message processing (matching Google's demo)
      debugPrint('👂 Starting continuous message processing...');
      _processMessagesContinuously(stopSignal: _stopController);
    } catch (e) {
      debugPrint('❌ Error connecting to Gemini Live: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Continuous message processing (matching Google's demo pattern)
  Future<void> _processMessagesContinuously({
    required StreamController<bool> stopSignal,
  }) async {
    bool shouldContinue = true;

    stopSignal.stream.listen((stop) {
      if (stop) {
        shouldContinue = false;
      }
    });

    while (shouldContinue) {
      try {
        await for (final response in _session!.receive()) {
          await _handleLiveServerResponse(response);
        }
      } catch (e) {
        debugPrint('❌ Error in message processing: $e');
        _isProcessing = false;
        _isSpeaking = false;
        _isConnected = false;
        notifyListeners();
        break;
      }
    }
  }

  /// Handle live server responses (matching Google's demo pattern)
  Future<void> _handleLiveServerResponse(LiveServerResponse response) async {
    final serverMessage = response.message;

    // Check for setup complete (not directly accessible, check by type name)
    if (serverMessage.runtimeType.toString() == 'LiveServerSetupComplete') {
      debugPrint('✅ Live session setup complete');
      return;
    }

    if (serverMessage is LiveServerContent) {
      debugPrint('📨 Received LiveServerContent');

      // Handle model turn content (audio/text)
      if (serverMessage.modelTurn != null) {
        debugPrint(
            '🎤 Model turn detected with ${serverMessage.modelTurn!.parts.length} parts');
        _isSpeaking = true;
        notifyListeners();

        for (final part in serverMessage.modelTurn!.parts) {
          if (part is InlineDataPart) {
            // Audio data from AI
            debugPrint('🔊 Received audio data: ${part.bytes.length} bytes');
            _audioResponseController.add(part.bytes);
          } else if (part is TextPart) {
            // Text response from AI
            debugPrint('📝 Received text: ${part.text}');
            _aiTranscript = (_aiTranscript ?? '') + part.text;
            _aiTranscriptController.add(part.text);
            notifyListeners();
          }
        }
      } else {
        debugPrint('⚠️ Model turn is null');
      }

      // Handle transcriptions
      if (serverMessage.inputTranscription != null) {
        debugPrint(
            '🎙️ Input transcription: ${serverMessage.inputTranscription!.text}');
        _currentTranscript = serverMessage.inputTranscription!.text;
        if (_currentTranscript != null) {
          _transcriptController.add(_currentTranscript!);
        }
        notifyListeners();
      }

      if (serverMessage.outputTranscription != null) {
        debugPrint(
            '🗣️ Output transcription: ${serverMessage.outputTranscription!.text}');
        _aiTranscript = serverMessage.outputTranscription!.text;
        if (_aiTranscript != null) {
          _aiTranscriptController.add(_aiTranscript!);
        }
        notifyListeners();
      }

      // Check if turn is complete
      if (serverMessage.turnComplete == true) {
        debugPrint('✅ Turn complete');
        _isProcessing = false;
        _isSpeaking = false;
        notifyListeners();
      }

      // Check if interrupted
      if (serverMessage.interrupted == true) {
        debugPrint('⚠️ Turn interrupted');
        _isProcessing = false;
        _isSpeaking = false;
        notifyListeners();
      }
    } else {
      debugPrint('⚠️ Server message type: ${serverMessage.runtimeType}');
    }

    if (serverMessage is LiveServerToolCall) {
      debugPrint('🔧 Tool call received: ${serverMessage.functionCalls}');
      await _handleLiveServerToolCall(serverMessage);
    }
  }

  /// Handle tool calls from the Live API
  Future<void> _handleLiveServerToolCall(LiveServerToolCall response) async {
    final functionCalls = response.functionCalls;
    if (functionCalls == null || functionCalls.isEmpty) return;

    debugPrint('🔧 Processing ${functionCalls.length} function call(s)');

    // Execute each function call using the stored tools
    for (final functionCall in functionCalls) {
      try {
        // Access function call properties dynamically
        final functionName = (functionCall as dynamic).name as String;
        final args =
            ((functionCall as dynamic).args as Map<String, dynamic>?) ??
                <String, dynamic>{};

        debugPrint('🔧 Executing: $functionName with args: $args');

        // Execute the tool function
        await _executeToolFunction(functionName, args);

        debugPrint('✅ Tool $functionName executed successfully');
      } catch (e, stackTrace) {
        debugPrint('❌ Error executing tool: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Note: The Live API will handle tool responses automatically
    // We just need to execute the tools and trigger UI updates
  }

  /// Execute a tool function by name using stored tools
  Future<Map<String, dynamic>> _executeToolFunction(
      String name, Map<String, dynamic> arguments) async {
    // First try to use the stored tools' invokeFunction
    if (_tools != null) {
      for (final tool in _tools!) {
        try {
          final toolName = (tool as dynamic).name as String;
          if (toolName == name) {
            final invokeFunction = (tool as dynamic).invokeFunction;
            if (invokeFunction != null) {
              debugPrint('🔧 Using tool invokeFunction for $name');
              final result =
                  await invokeFunction(arguments) as Map<String, dynamic>;
              // Trigger UI update after tool execution
              _triggerUIUpdate();
              return result;
            }
          }
        } catch (e) {
          debugPrint('❌ Error accessing tool invokeFunction: $e');
        }
      }
    }

    // Fallback to manual execution
    return await _executeToolFunctionManual(name, arguments);
  }

  /// Manual tool execution (fallback)
  Future<Map<String, dynamic>> _executeToolFunctionManual(
      String name, Map<String, dynamic> arguments) async {
    // Import the tool execution logic from app.dart
    // Since we can't directly import, we'll use the global service references
    final expenseService = globalExpenseService;

    if (expenseService == null) {
      return {'error': 'ExpenseService not available'};
    }

    switch (name) {
      case 'addExpense':
        final title = arguments['title']?.toString() ?? '';
        // Handle amount conversion - could be String, int, or double
        final amountValue = arguments['amount'];
        final amount = amountValue is num
            ? amountValue.toDouble()
            : (amountValue is String
                ? double.tryParse(amountValue) ?? 0.0
                : 0.0);
        // Handle categoryId conversion - could be String or int
        final categoryIdValue = arguments['categoryId'];
        final categoryId = categoryIdValue is String
            ? categoryIdValue
            : categoryIdValue?.toString() ?? '';

        final expense = expenseService.addExpense(title, amount, categoryId);
        final categories = expenseService.categories;
        final expenses = expenseService.expenses;

        final allCategoriesData = categories
            .map((cat) => {
                  'id': cat.id,
                  'name': cat.name,
                  'color': _colorToHex(cat.color),
                  'expenses': expenses
                      .where((e) => e.categoryId == cat.id)
                      .map((e) => {
                            'id': e.id,
                            'title': e.title,
                            'amount': e.amount,
                            'date': e.date.toIso8601String(),
                          })
                      .toList(),
                })
            .toList();

        // Update UI surfaces
        _updateCategoriesSurface(allCategoriesData);

        return {
          'success': true,
          'expenseId': expense.id,
          'allCategories': allCategoriesData,
          'total': expenseService.totalExpenses,
        };

      case 'addCategory':
        final categoryName = arguments['name']?.toString() ?? '';
        final color = arguments['color']?.toString() ?? '';

        final category = expenseService.addCategory(categoryName, color);

        // Refresh UI
        _refreshExpensesUI();

        return {
          'success': true,
          'categoryId': category.id,
          'categoryName': category.name,
        };

      case 'getAllExpenses':
        final categories = expenseService.categories;
        final expenses = expenseService.expenses;

        final result = <String, dynamic>{
          'categories': categories
              .map((cat) => {
                    'id': cat.id,
                    'name': cat.name,
                    'color': _colorToHex(cat.color),
                    'expenses': expenses
                        .where((e) => e.categoryId == cat.id)
                        .map((e) => {
                              'id': e.id,
                              'title': e.title,
                              'amount': e.amount,
                              'date': e.date.toIso8601String(),
                            })
                        .toList(),
                  })
              .toList(),
          'total': expenseService.totalExpenses,
        };

        return result;

      case 'findCategoryByName':
        final name = arguments['name'] as String;
        final category = expenseService.findCategoryByName(name);

        if (category == null) {
          return {'found': false};
        }

        return {
          'found': true,
          'categoryId': category.id,
          'categoryName': category.name,
          'color': _colorToHex(category.color),
        };

      case 'updateCategoryColor':
        final categoryIdValue = arguments['categoryId'];
        final categoryId = categoryIdValue is String
            ? categoryIdValue
            : categoryIdValue?.toString() ?? '';
        final color = arguments['color']?.toString() ?? '';

        expenseService.updateCategoryColor(categoryId, color);

        // Refresh UI
        _refreshExpensesUI();

        return {
          'success': true,
          'categoryId': categoryId,
          'newColor': color,
        };

      default:
        return {'error': 'Unknown tool: $name'};
    }
  }

  /// Helper to convert Color to hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  /// Trigger UI update after tool execution
  void _triggerUIUpdate() {
    // Trigger GenUI to refresh by sending a silent message
    final conversation = globalGenUiConversation;
    if (conversation != null) {
      try {
        // Send a message to GenUI to refresh - it will call getAllExpenses and update surfaces
        conversation.sendRequest(
          genui.UserMessage.text('Refresh expenses display'),
        );
        debugPrint('✅ Triggered GenUI refresh');
      } catch (e) {
        debugPrint('❌ Error triggering GenUI refresh: $e');
      }
    }
  }

  /// Update categories surface with new data by triggering GenUI refresh
  void _updateCategoriesSurface(List<Map<String, dynamic>> categoriesData) {
    _triggerUIUpdate();
  }

  /// Refresh expenses UI
  void _refreshExpensesUI() {
    final expenseService = globalExpenseService;
    if (expenseService == null) return;

    final categories = expenseService.categories;
    final expenses = expenseService.expenses;

    final categoriesData = categories
        .map((cat) => {
              'id': cat.id,
              'name': cat.name,
              'color': _colorToHex(cat.color),
              'expenses': expenses
                  .where((e) => e.categoryId == cat.id)
                  .map((e) => {
                        'id': e.id,
                        'title': e.title,
                        'amount': e.amount,
                        'date': e.date.toIso8601String(),
                      })
                  .toList(),
            })
        .toList();

    _updateCategoriesSurface(categoriesData);
  }

  /// Start streaming audio to the AI
  /// This uses sendMediaStream which is the recommended approach from Flutter demos
  Future<void> startAudioStream(Stream<Uint8List> audioStream) async {
    if (_session == null || !_isConnected) {
      debugPrint('Cannot start audio stream: not connected');
      return;
    }

    try {
      _isProcessing = true;
      notifyListeners();

      // Track audio chunks for debugging
      int chunkCount = 0;
      int totalBytes = 0;

      // Convert audio stream to InlineDataPart stream
      // Using 'audio/pcm' without rate (matching Google's demo)
      final mediaStream = audioStream.map((audioData) {
        chunkCount++;
        totalBytes += audioData.length;
        if (chunkCount % 50 == 0) {
          // Log every 50th chunk to avoid spam
          debugPrint(
              '📤 Sent $chunkCount audio chunks ($totalBytes bytes total)');
        }
        return InlineDataPart('audio/pcm', audioData);
      });

      // Use sendMediaStream (recommended approach from Flutter demos)
      // This will process the stream asynchronously
      _session!.sendMediaStream(mediaStream).catchError((error) {
        debugPrint('❌ Error in audio stream: $error');
        _isProcessing = false;
        notifyListeners();
      });

      debugPrint('▶️ Started audio stream to Gemini Live API');
    } catch (e) {
      debugPrint('❌ Error starting audio stream: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Send a single audio chunk
  /// Note: This is kept for compatibility but startAudioStream is preferred
  Future<void> sendAudio(Uint8List audioData) async {
    if (_session == null || !_isConnected) {
      debugPrint('Cannot send audio: not connected');
      return;
    }

    try {
      // Use sendAudioRealtime for individual chunks
      // Using 'audio/pcm' without rate (matching Google's demo)
      await _session!.sendAudioRealtime(
        InlineDataPart('audio/pcm', audioData),
      );
    } catch (e) {
      debugPrint('Error sending audio: $e');
    }
  }

  /// Send text message (for text-to-speech response)
  Future<void> sendText(String text) async {
    if (_session == null || !_isConnected) {
      debugPrint('Cannot send text: not connected');
      return;
    }

    try {
      _isProcessing = true;
      _aiTranscript = null; // Clear previous AI transcript
      notifyListeners();

      await _session!.send(
        input: Content.text(text),
        turnComplete: true,
      );
    } catch (e) {
      debugPrint('Error sending text: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Signal end of audio input (user stopped speaking)
  Future<void> endAudioInput() async {
    if (_session == null || !_isConnected) return;

    try {
      debugPrint('⏹️ Sending turn complete signal to Gemini');
      // Send turn complete signal without any input content
      // This signals to the AI that the user has finished speaking
      await _session!.send(
        turnComplete: true,
      );
      debugPrint('✅ Turn complete signal sent');
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error ending audio input: $e');
      // Don't throw - this is just signaling end of input
    }
  }

  /// Disconnect from Gemini Live API
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      // Stop continuous message processing
      _stopController.add(true);
      await _stopController.close();
      // Reset new StreamController for next connection
      _stopController = StreamController<bool>();

      await _session?.close();
      _session = null;
      _liveModel = null;
      _isConnected = false;
      _isProcessing = false;
      _isSpeaking = false;
      _currentTranscript = null;
      _aiTranscript = null;
      notifyListeners();

      debugPrint('Disconnected from Gemini Live API');
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Clear transcripts
  void clearTranscripts() {
    _currentTranscript = null;
    _aiTranscript = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _stopController.close();
    _audioResponseController.close();
    _transcriptController.close();
    _aiTranscriptController.close();
    super.dispose();
  }
}
