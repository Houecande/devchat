import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';
import 'code_block_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 12),
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMe) _buildTime(),
                    if (isMe) const SizedBox(width: 8),
                    Text(
                      isMe ? 'Moi' : (message.username ?? 'Anonyme'),
                      style: TextStyle(
                        color: isMe ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (!isMe) const SizedBox(width: 8),
                    if (!isMe) _buildTime(),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 16),
                    ),
                  ),
                  child: message.type == 'code'
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: CodeBlockWidget(
                            code: message.content,
                            language: message.language ?? 'plaintext',
                          ),
                        )
                      : Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 12),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isMe ? AppTheme.primary : Colors.transparent, width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.surfaceVariant,
        backgroundImage: message.avatarUrl != null
            ? NetworkImage(message.avatarUrl!)
            : null,
        child: message.avatarUrl == null
            ? Text(
                (isMe ? 'M' : (message.username ?? '?'))[0].toUpperCase(),
                style: TextStyle(color: isMe ? AppTheme.primary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }

  Widget _buildTime() {
    return Text(
      timeago.format(message.createdAt, locale: 'fr'),
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.7),
        fontSize: 10,
      ),
    );
  }
}
