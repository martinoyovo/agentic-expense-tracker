import 'dart:async';
import 'package:flutter/material.dart';
import '../services/live_chat_service.dart';
import '../services/audio_service.dart';
import '../../../core/constants/app_constants.dart';

/// Widget for voice chat with Gemini Live API
class VoiceChatWidget extends StatefulWidget {
  final LiveChatService liveChatService;
  final AudioService audioService;
  final VoidCallback? onClose;

  const VoiceChatWidget({
    super.key,
    required this.liveChatService,
    required this.audioService,
    this.onClose,
  });

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _audioSubscription;
  StreamSubscription? _responseSubscription;

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Pulse animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for AI speaking
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Initialize and connect
    _initialize();
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // Initialize audio service
      await widget.audioService.initialize();

      if (!mounted) return;

      // Connect to Gemini Live API
      await widget.liveChatService.connect(
        systemInstruction: '''
You are a helpful expense tracking assistant. Help users manage their expenses through voice conversation.
Be concise and conversational. When users mention expenses, help them track and categorize them.
Keep responses brief since this is voice interaction.
''',
      );

      if (!mounted) return;

      // Listen for audio responses from AI
      _responseSubscription = widget.liveChatService.audioResponseStream.listen(
        (audioData) {
          debugPrint(
              '🎧 Voice widget received audio: ${audioData.length} bytes');
          if (mounted) {
            widget.audioService.playAudio(audioData);
          } else {
            debugPrint('⚠️ Widget not mounted, skipping playback');
          }
        },
        onError: (error) {
          debugPrint('❌ Audio response stream error: $error');
        },
      );

      // Note: Audio stream will be started when recording begins
      // This is done in _toggleRecording() to ensure proper timing

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      String errorMsg = e.toString();

      // Provide user-friendly error messages
      if (errorMsg.contains('not found') ||
          errorMsg.contains('not supported')) {
        errorMsg = 'Voice chat is not available in your region.\n\n'
            'The Gemini Live API requires a specific Firebase project configuration.';
      } else if (errorMsg.contains('WebSocket') ||
          errorMsg.contains('Connection')) {
        errorMsg = 'Unable to connect to voice service.\n\n'
            'Please check your internet connection and try again.';
      } else {
        errorMsg = 'Failed to start voice chat.\n\n$errorMsg';
      }

      setState(() {
        _isConnecting = false;
        _errorMessage = errorMsg;
      });
    }
  }

  void _toggleRecording() async {
    if (!mounted) return;

    if (widget.audioService.isRecording) {
      await widget.audioService.stopRecording();
      await widget.liveChatService.endAudioInput();
      _pulseController.stop();
      // Cancel audio subscription when stopping
      await _audioSubscription?.cancel();
      _audioSubscription = null;
    } else {
      // Stop any playing audio first
      await widget.audioService.stopPlaying();

      if (!mounted) return;

      // Start audio stream before recording
      widget.liveChatService.startAudioStream(widget.audioService.audioStream);

      // Start recording
      await widget.audioService.startRecording();

      if (!mounted) return;
      _pulseController.repeat(reverse: true);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Stop animations first
    _pulseController.stop();
    _waveController.stop();

    // Cancel all subscriptions
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _responseSubscription?.cancel();
    _responseSubscription = null;

    // Stop recording if active
    if (widget.audioService.isRecording) {
      widget.audioService.stopRecording();
    }

    // Stop playing audio if active
    if (widget.audioService.isPlaying) {
      widget.audioService.stopPlaying();
    }

    // Dispose controllers
    _pulseController.dispose();
    _waveController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = widget.audioService.isRecording;
    final isPlaying = widget.audioService.isPlaying;
    final isSpeaking = widget.liveChatService.isSpeaking;
    final isProcessing = widget.liveChatService.isProcessing;
    final isConnected = widget.liveChatService.isConnected;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Main content (header is now in parent FloatingChatWidget)
            Expanded(
              child: _buildContent(
                  theme, isConnected, isRecording, isSpeaking, isProcessing),
            ),

            // Controls
            _buildControls(theme, isConnected, isRecording, isPlaying),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    bool isConnected,
    bool isRecording,
    bool isSpeaking,
    bool isProcessing,
  ) {
    if (_isConnecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'Connecting to Gemini...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingM),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated orb
            _buildAnimatedOrb(theme, isRecording, isSpeaking, isProcessing),

            const SizedBox(height: AppConstants.spacingL),

            // Status text
            _buildStatusText(theme, isRecording, isSpeaking, isProcessing),

            const SizedBox(height: AppConstants.spacingM),

            // Transcripts
            _buildTranscripts(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedOrb(
    ThemeData theme,
    bool isRecording,
    bool isSpeaking,
    bool isProcessing,
  ) {
    Color orbColor;
    if (isRecording) {
      orbColor = theme.colorScheme.error;
    } else if (isSpeaking) {
      orbColor = theme.colorScheme.primary;
    } else if (isProcessing) {
      orbColor = theme.colorScheme.tertiary;
    } else {
      orbColor = theme.colorScheme.outline;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isRecording ? _pulseAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  orbColor.withOpacity(0.8),
                  orbColor.withOpacity(0.4),
                  orbColor.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: orbColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orbColor,
                ),
                child: Icon(
                  isRecording
                      ? Icons.mic
                      : isSpeaking
                          ? Icons.volume_up
                          : isProcessing
                              ? Icons.hourglass_empty
                              : Icons.mic_none,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(
    ThemeData theme,
    bool isRecording,
    bool isSpeaking,
    bool isProcessing,
  ) {
    String statusText;
    if (isRecording) {
      statusText = 'Listening...';
    } else if (isSpeaking) {
      statusText = 'AI is speaking...';
    } else if (isProcessing) {
      statusText = 'Processing...';
    } else {
      statusText = 'Tap the button to speak';
    }

    return Text(
      statusText,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTranscripts(ThemeData theme) {
    final userTranscript = widget.liveChatService.currentTranscript;
    final aiTranscript = widget.liveChatService.aiTranscript;

    if (userTranscript == null && aiTranscript == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      constraints: const BoxConstraints(maxHeight: 150),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userTranscript != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userTranscript,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (aiTranscript != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiTranscript,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    ThemeData theme,
    bool isConnected,
    bool isRecording,
    bool isPlaying,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main recording button
        GestureDetector(
          onTap: isConnected ? _toggleRecording : null,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: (isRecording
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop : Icons.mic,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacingS),

        // Hint text
        Text(
          isRecording ? 'Tap to stop' : 'Tap to speak',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),

        const SizedBox(height: AppConstants.spacingS),

        // Voice selector
        _buildVoiceSelector(theme),
      ],
    );
  }

  Widget _buildVoiceSelector(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Voice: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        DropdownButton<AiVoice>(
          value: widget.liveChatService.selectedVoice,
          underline: const SizedBox.shrink(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          items: AiVoice.values.map((voice) {
            return DropdownMenuItem(
              value: voice,
              child: Text(voice.name),
            );
          }).toList(),
          onChanged: widget.liveChatService.isConnected
              ? null // Can't change voice while connected
              : (voice) {
                  if (voice != null && mounted) {
                    widget.liveChatService.setVoice(voice);
                    setState(() {});
                  }
                },
        ),
      ],
    );
  }
}
