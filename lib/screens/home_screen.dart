import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/responsive/responsive_helper.dart';
import '../features/chat/services/chat_service.dart';
import '../features/chat/services/live_chat_service.dart';
import '../features/chat/services/audio_service.dart';
import '../features/chat/widgets/floating_chat_widget.dart';
import '../genui/surfaces/surface_manager.dart';

class HomeScreen extends StatefulWidget {
  final SurfaceManager surfaceManager;
  final ChatService chatService;

  /// Lazy getter for LiveChatService - only instantiated when accessed
  final LiveChatService Function()? liveChatServiceGetter;

  /// Lazy getter for AudioService - only instantiated when accessed
  final AudioService Function()? audioServiceGetter;

  const HomeScreen({
    super.key,
    required this.surfaceManager,
    required this.chatService,
    this.liveChatServiceGetter,
    this.audioServiceGetter,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isChatOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ResponsiveHelper.isMobile(context)
          ? AppBar(
              title: const Text('AI Expense Tracker'),
              centerTitle: true,
              elevation: 0,
            )
          : null,
      body: Stack(
        children: [
          // Background layer - fills entire screen
          Positioned.fill(
            child: ListenableBuilder(
              listenable: widget.surfaceManager,
              builder: (context, _) {
                return widget.surfaceManager.backgroundWidget ??
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.secondaryContainer,
                          ],
                        ),
                      ),
                    );
              },
            ),
          ),

          // Content layer
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.surfaceManager,
              builder: (context, _) {
                return _buildResponsiveLayout();
              },
            ),
          ),

          // Chat overlay
          if (_isChatOpen)
            ListenableBuilder(
              listenable: widget.surfaceManager,
              builder: (context, _) {
                if (ResponsiveHelper.isMobile(context)) {
                  // Mobile: Modal barrier + bottom sheet (no tap-to-dismiss)
                  return GestureDetector(
                    // Prevent tap-to-dismiss - only close button can close
                    onTap: () {
                      // Do nothing - prevent dismissal on tap outside
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: FloatingChatWidget(
                        chatService: widget.chatService,
                        liveChatServiceGetter: widget.liveChatServiceGetter,
                        audioServiceGetter: widget.audioServiceGetter,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
                    ),
                  );
                } else {
                  // Desktop/Tablet: Floating window
                  return FloatingChatWidget(
                    chatService: widget.chatService,
                    liveChatServiceGetter: widget.liveChatServiceGetter,
                    audioServiceGetter: widget.audioServiceGetter,
                    onClose: () => setState(() => _isChatOpen = false),
                  );
                }
              },
            ),

          // Dialog overlay (MUST be after chat to appear on top on ALL devices)
          ListenableBuilder(
            listenable: widget.surfaceManager,
            builder: (context, _) {
              if (widget.surfaceManager.dialogWidget != null) {
                return Positioned.fill(
                  child: Material(
                    color: Colors.black.withOpacity(0.5),
                    child: SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 400,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.8,
                            ),
                            child: widget.surfaceManager.dialogWidget,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),

      // FAB for mobile
      floatingActionButton: ResponsiveHelper.isMobile(context) && !_isChatOpen
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _isChatOpen = true),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
            )
          : null,
    );
  }

  Widget _buildResponsiveLayout() {
    final screenSize = ResponsiveHelper.getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.desktop:
        return _buildDesktopLayout();
      case ScreenSize.tablet:
        return _buildTabletLayout();
      case ScreenSize.mobile:
        return _buildMobileLayout();
    }
  }

  Widget _buildDesktopLayout() {
    final hasChartOrTotal = widget.surfaceManager.chartWidget != null ||
        widget.surfaceManager.totalWidget != null;
    final hasCategories = widget.surfaceManager.categoryWidgets.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Chart and Total side by side (only if they exist)
          if (hasChartOrTotal) ...[
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  // Chart
                  if (widget.surfaceManager.chartWidget != null)
                    Expanded(
                      flex: 2,
                      child: widget.surfaceManager.chartWidget!,
                    ),
                  if (widget.surfaceManager.chartWidget != null &&
                      widget.surfaceManager.totalWidget != null)
                    const SizedBox(width: AppConstants.spacingL),
                  // Total
                  if (widget.surfaceManager.totalWidget != null)
                    Expanded(
                      flex: 1,
                      child: widget.surfaceManager.totalWidget!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
          ],

          // Categories container - starts at top if no chart/total, otherwise below them
          Expanded(
            child: hasCategories
                ? Align(
                    alignment: Alignment.topLeft,
                    child: widget.surfaceManager.categoryWidgets.first,
                  )
                : _buildEmptyState(),
          ),

          // Chat button if not open
          if (!_isChatOpen)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: FloatingActionButton.extended(
                  onPressed: () => setState(() => _isChatOpen = true),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat with AI'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    final hasChartOrTotal = widget.surfaceManager.chartWidget != null ||
        widget.surfaceManager.totalWidget != null;
    final hasCategories = widget.surfaceManager.categoryWidgets.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Chart and Total side by side (only if they exist)
          if (hasChartOrTotal) ...[
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  if (widget.surfaceManager.chartWidget != null)
                    Expanded(
                      child: widget.surfaceManager.chartWidget!,
                    ),
                  if (widget.surfaceManager.chartWidget != null &&
                      widget.surfaceManager.totalWidget != null)
                    const SizedBox(width: AppConstants.spacingM),
                  if (widget.surfaceManager.totalWidget != null)
                    Expanded(
                      child: widget.surfaceManager.totalWidget!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],

          // Categories container - starts at top if no chart/total, otherwise below them
          Expanded(
            child: hasCategories
                ? Align(
                    alignment: Alignment.topLeft,
                    child: widget.surfaceManager.categoryWidgets.first,
                  )
                : _buildEmptyState(),
          ),

          // Chat button if not open
          if (!_isChatOpen)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                child: FloatingActionButton(
                  onPressed: () => setState(() => _isChatOpen = true),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final hasChartOrTotal = widget.surfaceManager.chartWidget != null ||
        widget.surfaceManager.totalWidget != null;
    final hasCategories = widget.surfaceManager.categoryWidgets.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked vertically (only if they exist)
        if (hasChartOrTotal) ...[
          if (widget.surfaceManager.chartWidget != null)
            SizedBox(
              height: 250,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: widget.surfaceManager.chartWidget,
              ),
            ),
          if (widget.surfaceManager.totalWidget != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
              child: SizedBox(
                width: double.infinity,
                child: widget.surfaceManager.totalWidget,
              ),
            ),
          if (hasChartOrTotal) const SizedBox(height: AppConstants.spacingS),
        ],

        // Categories container - starts at top if no chart/total, otherwise below them
        Expanded(
          child: hasCategories
              ? Padding(
                  padding: EdgeInsets.only(
                    top: hasChartOrTotal
                        ? AppConstants.spacingS
                        : AppConstants.spacingM,
                    left: AppConstants.spacingM,
                    right: AppConstants.spacingM,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: widget.surfaceManager.categoryWidgets.first,
                  ),
                )
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Add expenses, create charts, and more!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingL),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isChatOpen = true),
            icon: const Icon(Icons.chat),
            label: const Text('Open Chat'),
          ),
        ],
      ),
    );
  }
}
