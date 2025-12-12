import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import '../../core/constants/app_constants.dart';
import '../../app.dart';

// #region agent log
void _debugLogDialog(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  debugPrint('🔍 [$hypothesisId] $location: $message | $data');
}
// #endregion

final confirmationDialogItem = CatalogItem(
  name: 'ConfirmationDialog',
  dataSchema: S.object(
    properties: {
      'message': S.string(description: 'The confirmation message to display'),
      'confirmLabel': S.string(
          description: 'Label for the confirm button (default: "Yes")'),
      'cancelLabel':
          S.string(description: 'Label for the cancel button (default: "No")'),
    },
    required: ['message'],
  ),
  widgetBuilder: (context) {
    final data = context.data as Map<String, dynamic>;
    final message = data['message'] as String;
    final confirmLabel = (data['confirmLabel'] as String?) ?? 'Yes';
    final cancelLabel = (data['cancelLabel'] as String?) ?? 'No';

    return Card(
      margin: const EdgeInsets.all(AppConstants.spacingL),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.help_outline,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // #region agent log
                    _debugLogDialog(
                        'confirmation_dialog:onNo',
                        'User clicked NO button',
                        {
                          'message': message,
                          'conversationExists': globalGenUiConversation != null,
                        },
                        'B');
                    // #endregion
                    // Send "No" response back to GenUI conversation
                    final conversation = globalGenUiConversation;
                    if (conversation != null) {
                      conversation.sendRequest(
                        UserUiInteractionMessage.text('No'),
                      );
                      // Clear dialog after sending (GenUI may also clear it, but this ensures it happens)
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        globalSurfaceManager?.clearDialog();
                      });
                    }
                  },
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: AppConstants.spacingS),
                ElevatedButton(
                  onPressed: () {
                    // #region agent log
                    _debugLogDialog(
                        'confirmation_dialog:onYes',
                        'User clicked YES button',
                        {
                          'message': message,
                          'conversationExists': globalGenUiConversation != null,
                        },
                        'B');
                    // #endregion
                    // Send "Yes" response back to GenUI conversation
                    final conversation = globalGenUiConversation;
                    if (conversation != null) {
                      conversation.sendRequest(
                        UserUiInteractionMessage.text('Yes'),
                      );
                      // Clear dialog after sending (GenUI may also clear it, but this ensures it happens)
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        globalSurfaceManager?.clearDialog();
                      });
                    }
                  },
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);
