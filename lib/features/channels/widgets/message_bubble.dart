import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';
import 'code_block_widget.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) _buildAvatar(primary),
          if (!isMe) const SizedBox(width: 12),
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMe) _buildStatusIndicator(primary),
                    if (isMe) const SizedBox(width: 8),
                    Text(
                      isMe ? 'Moi' : (message.username ?? 'Anonyme'),
                      style: TextStyle(
                        color: isMe ? primary : AppTheme.textPrimary,
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
                    color: isMe 
                      ? (message.status == MessageStatus.error ? AppTheme.error.withValues(alpha: 0.2) : primary) 
                      : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 16),
                    ),
                    border: message.status == MessageStatus.error 
                      ? Border.all(color: AppTheme.error.withValues(alpha: 0.5)) 
                      : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.type == 'code')
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: CodeBlockWidget(
                            code: message.content,
                            language: message.language ?? 'plaintext',
                          ),
                        )
                      else
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isMe && message.status == MessageStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () => ref.read(messagesProvider(message.channelId).notifier).sendMessage(
                        channelId: message.channelId,
                        content: message.content,
                        type: message.type,
                        language: message.language,
                        retryId: message.id,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.error),
                      label: const Text('Erreur de connexion. Réessayer ?', style: TextStyle(color: AppTheme.error, fontSize: 11)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 12),
          if (isMe) _buildAvatar(primary),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(Color primary) {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textSecondary));
      case MessageStatus.error:
        return const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.error);
      case MessageStatus.sent:
        return _buildTime();
    }
  }

  Widget _buildAvatar(Color primary) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.surfaceVariant,
      backgroundImage: message.avatarUrl != null ? NetworkImage(message.avatarUrl!) : null,
      child: message.avatarUrl == null
          ? Text(
              (isMe ? 'M' : (message.username ?? '?'))[0].toUpperCase(),
              style: TextStyle(color: isMe ? primary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  Widget _buildTime() {
    return Text(
      timeago.format(message.createdAt, locale: 'fr'),
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
        fontSize: 10,
      ),
    );
  }
}
