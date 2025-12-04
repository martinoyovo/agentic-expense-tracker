import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

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
  
  final _audioResponseController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _aiTranscriptController = StreamController<String>.broadcast();
  
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

  /// Connect to Gemini Live API
  Future<void> connect({String? systemInstruction}) async {
    if (_isConnected) return;
    
    try {
      debugPrint('Connecting to Gemini Live API...');
      
      // Try available Live API models
      // Note: Model availability depends on your Firebase project and region
      _liveModel = FirebaseAI.googleAI().liveGenerativeModel(
        model: 'gemini-2.0-flash-exp', // Updated model name
        liveGenerationConfig: LiveGenerationConfig(
          responseModalities: [ResponseModalities.audio, ResponseModalities.text],
          speechConfig: SpeechConfig(voiceName: _selectedVoice.name),
        ),
        systemInstruction: systemInstruction != null 
            ? Content.text(systemInstruction) 
            : null,
      );
      
      _session = await _liveModel!.connect();
      _isConnected = true;
      notifyListeners();
      
      debugPrint('Connected to Gemini Live API successfully');
      
      // Start listening for responses
      _startListeningForResponses();
      
    } catch (e) {
      debugPrint('Error connecting to Gemini Live: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Start listening for responses from the server
  void _startListeningForResponses() {
    if (_session == null) return;
    
    _session!.receive().listen(
      (response) {
        _handleServerResponse(response);
      },
      onError: (error) {
        debugPrint('Live session error: $error');
        _isProcessing = false;
        _isSpeaking = false;
        // Mark as disconnected on error to prevent reconnect loop
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        debugPrint('Live session completed');
        _isProcessing = false;
        _isSpeaking = false;
        notifyListeners();
        
        // Only restart listening if still connected and no error occurred
        // Don't auto-reconnect to avoid infinite loops
      },
    );
  }

  /// Handle server responses
  void _handleServerResponse(LiveServerResponse response) {
    final serverMessage = response.message;
    
    // Check for setup complete (not directly accessible, check by type name)
    if (serverMessage.runtimeType.toString() == 'LiveServerSetupComplete') {
      debugPrint('Live session setup complete');
      return;
    }
    
    if (serverMessage is LiveServerContent) {
      // Handle model turn content (audio/text)
      if (serverMessage.modelTurn != null) {
        _isSpeaking = true;
        notifyListeners();
        
        for (final part in serverMessage.modelTurn!.parts) {
          if (part is InlineDataPart) {
            // Audio data from AI
            _audioResponseController.add(part.bytes);
          } else if (part is TextPart) {
            // Text response from AI
            _aiTranscript = (_aiTranscript ?? '') + part.text;
            _aiTranscriptController.add(part.text);
            notifyListeners();
          }
        }
      }
      
      // Handle transcriptions
      if (serverMessage.inputTranscription != null) {
        _currentTranscript = serverMessage.inputTranscription!.text;
        if (_currentTranscript != null) {
          _transcriptController.add(_currentTranscript!);
        }
        notifyListeners();
      }
      
      if (serverMessage.outputTranscription != null) {
        _aiTranscript = serverMessage.outputTranscription!.text;
        if (_aiTranscript != null) {
          _aiTranscriptController.add(_aiTranscript!);
        }
        notifyListeners();
      }
      
      // Check if turn is complete
      if (serverMessage.turnComplete == true) {
        _isProcessing = false;
        _isSpeaking = false;
        notifyListeners();
      }
      
      // Check if interrupted
      if (serverMessage.interrupted == true) {
        _isProcessing = false;
        _isSpeaking = false;
        notifyListeners();
      }
    }
    
    if (serverMessage is LiveServerToolCall) {
      debugPrint('Tool call received: ${serverMessage.functionCalls}');
      // Handle tool calls if needed
    }
  }

  /// Send audio data to the AI
  Future<void> sendAudio(Uint8List audioData) async {
    if (_session == null || !_isConnected) {
      debugPrint('Cannot send audio: not connected');
      return;
    }
    
    try {
      _isProcessing = true;
      notifyListeners();
      
      // Send audio as PCM format (16-bit, 16kHz, mono)
      await _session!.sendAudioRealtime(
        InlineDataPart('audio/pcm;rate=16000', audioData),
      );
    } catch (e) {
      debugPrint('Error sending audio: $e');
      _isProcessing = false;
      notifyListeners();
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
      // Send turn complete signal
      await _session!.send(turnComplete: true);
    } catch (e) {
      debugPrint('Error ending audio input: $e');
    }
  }

  /// Disconnect from Gemini Live API
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    try {
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
    _audioResponseController.close();
    _transcriptController.close();
    _aiTranscriptController.close();
    super.dispose();
  }
}

