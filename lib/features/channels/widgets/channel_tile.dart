import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';

class ChannelTile extends ConsumerStatefulWidget {
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
  ConsumerState<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends ConsumerState<ChannelTile> {
  bool _isDeleting = false;

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Supprimer le salon ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer #${widget.channel.name} ? Cette action supprimera tous les messages et est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDeleting = true);
              try {
                await ref.read(deleteChannelProvider)(widget.channel.id);
                if (mounted && widget.isSelected) {
                  // Si le salon supprimé était sélectionné, on redirige
                  context.go('/channels');
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isDeleting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors de la suppression : $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = widget.channel.createdBy == currentUserId;
    final primary = Theme.of(context).colorScheme.primary;
    
    Color tileColor = Colors.transparent;
    Color iconColor = AppTheme.textSecondary.withValues(alpha: 0.5);
    IconData iconData = Icons.tag_rounded;
    String statusText = widget.channel.description ?? 'Aucune description';

    if (widget.isSelected) {
      tileColor = primary.withValues(alpha: 0.1);
      iconColor = primary;
    }

    if (widget.channel.isPrivate && !isCreator && !widget.isJoined) {
      if (widget.isPending) {
        iconData = Icons.hourglass_empty_rounded;
        statusText = 'Demande envoyée...';
        iconColor = Colors.orangeAccent.withValues(alpha: 0.7);
      } else {
        iconData = Icons.lock_outline_rounded;
        statusText = 'Salon privé • Demander l\'accès';
      }
    } else if (isCreator) {
      iconColor = primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: _isDeleting ? null : widget.onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected ? primary.withValues(alpha: 0.2) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _isDeleting 
            ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
            : Icon(iconData, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.channel.name,
                style: TextStyle(
                  color: widget.isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.8),
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.channel.isPrivate)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.shield_rounded, size: 10, color: isCreator ? AppTheme.success : AppTheme.textSecondary.withValues(alpha: 0.4)),
              ),
          ],
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(
              color: widget.isSelected ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 11,
              fontStyle: (widget.channel.isPrivate && !widget.isJoined) ? FontStyle.italic : null),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isCreator && !_isDeleting
          ? IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error.withValues(alpha: 0.5)),
              onPressed: () => _showDeleteConfirm(context),
            )
          : (widget.channel.isPrivate && !widget.isJoined && !widget.isPending)
            ? Icon(Icons.add_circle_outline_rounded, size: 18, color: primary.withValues(alpha: 0.5))
            : null,
      ),
    );
  }
}
