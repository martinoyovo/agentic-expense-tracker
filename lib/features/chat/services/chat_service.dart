import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart' as genui;

// #region agent log
void _debugLogChat(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  debugPrint('🔍 [$hypothesisId] $location: $message | $data');
}
// #endregion

/// Represents a single chat message
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Service to manage chat messages and communicate with GenUI
class ChatService extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  genui.GenUiConversation? _conversation;
  StreamSubscription? _textResponseSubscription;
  StreamSubscription? _errorSubscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;

  /// Initialize with GenUI conversation
  void initialize(genui.GenUiConversation conversation) {
    _conversation = conversation;

    // Listen to text responses
    _textResponseSubscription =
        conversation.contentGenerator.textResponseStream.listen((text) {
      // #region agent log
      _debugLogChat(
          'chat_service:textResponseStream',
          'AI text response received',
          {
            'textLength': text.length,
            'textPreview':
                text.length > 100 ? '${text.substring(0, 100)}...' : text,
            'messagesCount': _messages.length,
          },
          'C');
      // #endregion
      _handleAIResponse(text);
    });

    // Listen to errors
    _errorSubscription =
        conversation.contentGenerator.errorStream.listen((error) {
      _handleError(error);
    });

    // Listen to processing state
    conversation.contentGenerator.isProcessing
        .addListener(_onProcessingChanged);

    // Add welcome message
    addAIMessage(
      'Hi! I\'m your expense tracking assistant. I can help you:\n'
      '• Add expenses (e.g., "Coffee \$5")\n'
      '• Create categories\n'
      '• Show charts (pie, bar, line)\n'
      '• Display totals\n'
      '• Change backgrounds\n\n'
      'What would you like to do?',
    );
  }

  void _onProcessingChanged() {
    final isProcessing =
        _conversation?.contentGenerator.isProcessing.value ?? false;
    if (_isTyping != isProcessing) {
      _isTyping = isProcessing;
      notifyListeners();
    }
  }

  void _handleAIResponse(String text) {
    if (text.isNotEmpty) {
      // Remove loading message if exists
      _messages.removeWhere((m) => m.isLoading && !m.isUser);
      addAIMessage(text);
    }
  }

  void _handleError(genui.ContentGeneratorError error) {
    // Remove loading message
    _messages.removeWhere((m) => m.isLoading && !m.isUser);

    final errorStr = error.error.toString();
    String userMessage;

    if (errorStr.contains('Operation not permitted') ||
        errorStr.contains('Connection failed') ||
        errorStr.contains('SocketException')) {
      userMessage = 'Unable to connect. Please check your network connection.';
    } else {
      userMessage = 'Sorry, something went wrong. Please try again.';
    }

    addAIMessage(userMessage);
    _isTyping = false;
    notifyListeners();
  }

  /// Send a user message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _conversation == null) return;

    // #region agent log
    _debugLogChat(
        'chat_service:sendMessage',
        'User sending message',
        {
          'text': text,
          'messagesCountBefore': _messages.length,
        },
        'C');
    // #endregion

    // Add user message
    addUserMessage(text);

    // Add loading indicator
    final loadingMessage = ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(loadingMessage);
    _isTyping = true;
    notifyListeners();

    // Send to GenUI
    try {
      _conversation!.sendRequest(
        genui.UserMessage.text(text),
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      _messages.removeWhere((m) => m.isLoading);
      addAIMessage(
          'Sorry, I couldn\'t process your request. Please try again.');
      _isTyping = false;
      notifyListeners();
    }
  }

  void addUserMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();
  }

  void addAIMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    _isTyping = false;
    notifyListeners();
  }

  void setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _textResponseSubscription?.cancel();
    _errorSubscription?.cancel();
    _conversation?.contentGenerator.isProcessing
        .removeListener(_onProcessingChanged);
    super.dispose();
  }
}
