import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';

class ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isJoined;
  final bool isPending;

  const ChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.isSelected = false,
    this.isJoined = true,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = channel.createdBy == currentUserId;
    
    // Status visual determination
    Color tileColor = Colors.transparent;
    Color iconColor = AppTheme.textSecondary.withValues(alpha: 0.5);
    IconData iconData = Icons.tag_rounded;
    String statusText = channel.description ?? 'Aucune description';

    if (isSelected) {
      tileColor = AppTheme.primary.withValues(alpha: 0.1);
      iconColor = AppTheme.primary;
    }

    if (channel.isPrivate && !isCreator && !isJoined) {
      if (isPending) {
        iconData = Icons.hourglass_empty_rounded;
        statusText = 'Demande envoyée...';
        iconColor = Colors.orangeAccent.withValues(alpha: 0.7);
      } else {
        iconData = Icons.lock_outline_rounded;
        statusText = 'Salon privé • Demander l\'accès';
      }
    } else if (isCreator) {
      iconColor = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.8),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (channel.isPrivate)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.shield_rounded, size: 10, color: isCreator ? AppTheme.success : AppTheme.textSecondary.withValues(alpha: 0.4)),
              ),
          ],
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(
              color: isSelected ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 11,
              fontStyle: (channel.isPrivate && !isJoined) ? FontStyle.italic : null),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: (channel.isPrivate && !isJoined && !isPending)
          ? Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primary.withValues(alpha: 0.5))
          : null,
      ),
    );
  }
}
