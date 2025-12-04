import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/live_chat_service.dart';
import '../services/audio_service.dart';
import '../../../core/constants/app_constants.dart';
import 'voice_chat_widget.dart';

/// Chat mode enum
enum ChatMode { text, voice }

/// Custom chat view widget with text and voice modes
class ChatView extends StatefulWidget {
  final ChatService chatService;
  
  /// Lazy getter for voice services - only called when user enables voice mode
  final LiveChatService Function()? liveChatServiceGetter;
  final AudioService Function()? audioServiceGetter;

  const ChatView({
    super.key,
    required this.chatService,
    this.liveChatServiceGetter,
    this.audioServiceGetter,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  ChatMode _currentMode = ChatMode.text;
  
  // Cached voice services - only created when user switches to voice mode
  LiveChatService? _liveChatService;
  AudioService? _audioService;

  /// Check if voice mode is available (without triggering initialization)
  bool get _supportsVoice => 
      widget.liveChatServiceGetter != null && widget.audioServiceGetter != null;

  @override
  void initState() {
    super.initState();
    widget.chatService.addListener(_onMessagesChanged);
  }

  void _onMessagesChanged() {
    setState(() {});
    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.chatService.removeListener(_onMessagesChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    widget.chatService.sendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  void _toggleMode() {
    if (_currentMode == ChatMode.text && _supportsVoice) {
      // Switching to voice mode - initialize services now
      _liveChatService ??= widget.liveChatServiceGetter!();
      _audioService ??= widget.audioServiceGetter!();
    }
    
    setState(() {
      _currentMode = _currentMode == ChatMode.text 
          ? ChatMode.voice 
          : ChatMode.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMode == ChatMode.voice && _liveChatService != null && _audioService != null) {
      return VoiceChatWidget(
        liveChatService: _liveChatService!,
        audioService: _audioService!,
        onClose: _toggleMode,
      );
    }
    
    return _buildTextChat();
  }

  Widget _buildTextChat() {
    final theme = Theme.of(context);
    final messages = widget.chatService.messages;
    final isTyping = widget.chatService.isTyping;

    return Column(
      children: [
        // Messages list
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        'Start a conversation',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (_supportsVoice) ...[
                        const SizedBox(height: AppConstants.spacingM),
                        TextButton.icon(
                          onPressed: _toggleMode,
                          icon: const Icon(Icons.mic),
                          label: const Text('Try Voice Chat'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(message: message);
                  },
                ),
        ),
        
        // Typing indicator
        if (isTyping)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TypingDot(delay: 0),
                      SizedBox(width: 4),
                      _TypingDot(delay: 150),
                      SizedBox(width: 4),
                      _TypingDot(delay: 300),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        // Input field
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Voice mode button
                if (_supportsVoice)
                  IconButton(
                    onPressed: _toggleMode,
                    icon: const Icon(Icons.mic),
                    tooltip: 'Switch to voice chat',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                if (_supportsVoice)
                  const SizedBox(width: AppConstants.spacingS),
                
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !isTyping,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                IconButton.filled(
                  onPressed: isTyping ? null : _sendMessage,
                  icon: Icon(
                    isTyping ? Icons.hourglass_empty : Icons.send,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Individual message bubble
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    if (message.isLoading) {
      return const SizedBox.shrink(); // Hide loading messages, we show typing indicator instead
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppConstants.spacingS),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated typing dot
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5 + _animation.value * 0.5),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
