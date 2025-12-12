import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/responsive/responsive_helper.dart';
import 'chat_view.dart';
import '../services/chat_service.dart';
import '../services/live_chat_service.dart';
import '../services/audio_service.dart';

class FloatingChatWidget extends StatefulWidget {
  final ChatService chatService;

  /// Lazy getter for voice services - only called when user enables voice mode
  final LiveChatService Function()? liveChatServiceGetter;
  final AudioService Function()? audioServiceGetter;

  final VoidCallback onClose;

  const FloatingChatWidget({
    super.key,
    required this.chatService,
    this.liveChatServiceGetter,
    this.audioServiceGetter,
    required this.onClose,
  });

  @override
  State<FloatingChatWidget> createState() => _FloatingChatWidgetState();
}

class _FloatingChatWidgetState extends State<FloatingChatWidget> {
  /// Check if voice is available without triggering initialization
  bool get _supportsVoice =>
      widget.liveChatServiceGetter != null && widget.audioServiceGetter != null;

  ChatMode _currentChatMode = ChatMode.text;

  void _onChatModeChanged(ChatMode mode) {
    setState(() {
      _currentChatMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final theme = Theme.of(context);

    if (isMobile) {
      // Mobile: Bottom sheet (prevent dismissal except via close button)
      return PopScope(
        canPop: false, // Prevent back button dismissal
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3, // Prevent dragging below this size
          maxChildSize: 0.95,
          snap: true, // Snap to min/max sizes
          snapSizes: const [0.3, 0.95], // Only allow snapping to these sizes
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.radiusL),
                  topRight: Radius.circular(AppConstants.radiusL),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: AppConstants.spacingS),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  _buildHeader(theme, isMobile: true),
                  const Divider(height: 1),
                  // Chat view
                  Expanded(
                    child: ChatView(
                      chatService: widget.chatService,
                      liveChatServiceGetter: widget.liveChatServiceGetter,
                      audioServiceGetter: widget.audioServiceGetter,
                      onModeChanged: _onChatModeChanged,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Desktop/Tablet: Floating window
    return Positioned(
      right: AppConstants.spacingL,
      bottom: AppConstants.spacingL,
      width: 420,
      height: 650,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(theme, isMobile: false),
            // Chat view
            Expanded(
              child: ChatView(
                chatService: widget.chatService,
                liveChatServiceGetter: widget.liveChatServiceGetter,
                audioServiceGetter: widget.audioServiceGetter,
                onModeChanged: _onChatModeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, {required bool isMobile}) {
    final isVoiceMode = _currentChatMode == ChatMode.voice;
    final title = isVoiceMode ? 'Voice Chat' : 'AI Assistant';
    final icon = isVoiceMode ? Icons.mic : Icons.smart_toy;

    // Get voice service status if in voice mode
    String subtitle;
    if (isVoiceMode && widget.liveChatServiceGetter != null) {
      try {
        final liveService = widget.liveChatServiceGetter!();
        subtitle = liveService.isConnected
            ? 'Connected • ${liveService.selectedVoice.name}'
            : 'Connecting...';
      } catch (e) {
        subtitle = 'Voice mode';
      }
    } else {
      subtitle = _supportsVoice ? 'Text & Voice Chat' : 'Text Chat';
    }

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusL),
            topRight: Radius.circular(AppConstants.radiusL),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
              iconSize: 20,
            ),
          ],
        ),
      );
    }
  }
}
