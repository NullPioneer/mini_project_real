// =============================================================
//  Chat Bubble Widget
//  Renders user and AI messages with different styles
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onPlayAudio; // Called when speaker icon tapped
  final VoidCallback? onRedo;      // Called when redo icon tapped (AI only)
  final VoidCallback? onEdit;      // Called when edit icon tapped (User only)

  const ChatBubble({
    super.key,
    required this.message,
    this.onPlayAudio,
    this.onRedo,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar (left side only)
          if (!isUser) ...[
            _buildAIAvatar(),
            const SizedBox(width: 8),
          ],

          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: isUser ? AppTheme.neonGradient : null,
                    color: isUser ? null : AppTheme.aiBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft:
                          Radius.circular(isUser ? 12 : 4),
                      bottomRight:
                          Radius.circular(isUser ? 4 : 12),
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: AppTheme.accentNeon.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    border: isUser
                        ? null
                        : Border.all(
                            color: AppTheme.surfaceLight,
                            width: 1,
                          ),
                  ),
                  child: SelectableText(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? Colors.black
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Bottom row: time + actions
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    
                    // Copy button (For both User & AI)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copied to clipboard!'),
                            duration: Duration(seconds: 1),
                            backgroundColor: AppTheme.surfaceLight,
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    // AI Extra Actions
                    if (!isUser) ...[
                      // Redo button
                      if (onRedo != null) ...[
                        GestureDetector(
                          onTap: onRedo,
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      // Speaker button
                      if (onPlayAudio != null) ...[
                        GestureDetector(
                          onTap: onPlayAudio,
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],

                    // User Extra Actions
                    if (isUser && onEdit != null) ...[
                      GestureDetector(
                        onTap: onEdit,
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // User avatar (right side only)
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAIAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.accentNeon.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.accentNeon, width: 1.0),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('⠿',
            style: TextStyle(fontSize: 14, color: AppTheme.accentNeon)),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.accentNeon.withValues(alpha: 0.3),
        ),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded,
            size: 18, color: AppTheme.textSecondary),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
