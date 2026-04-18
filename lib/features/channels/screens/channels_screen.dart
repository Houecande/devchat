import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/channels_provider.dart';
import '../widgets/channel_tile.dart';
import 'chat_screen.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  final String? selectedChannelId;
  final String? selectedChannelName;

  const ChannelsScreen({
    super.key,
    this.selectedChannelId,
    this.selectedChannelName,
  });

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateChannelDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;
    bool isLoading = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.background,
          title: Row(
            children: [
              const Icon(Icons.add_box_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Text('Nouveau Salon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'Nom du salon', prefixIcon: Icon(Icons.tag_rounded)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: descController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_rounded)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: SwitchListTile(
                      title: const Text('Salon Privé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Seuls les membres autorisés peuvent rejoindre', style: TextStyle(fontSize: 12)),
                      value: isPrivate,
                      activeColor: AppTheme.primary,
                      onChanged: isLoading ? null : (v) => setModalState(() => isPrivate = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isLoading ? null : () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState?.validate() ?? false) {
                  setModalState(() => isLoading = true);
                  try {
                    await ref.read(createChannelProvider)(nameController.text.trim(), descController.text.trim(), isPrivate);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salon créé !'), backgroundColor: AppTheme.success));
                    }
                  } catch (e) {
                    setModalState(() => isLoading = false);
                  }
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(List<ChannelMember> requests, List<Channel> channels) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Demandes d\'accès', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: requests.isEmpty 
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune demande en attente', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final channel = channels.firstWhere((c) => c.id == req.channelId, orElse: () => Channel(id: '', name: '?', createdAt: DateTime.now()));
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(req.username ?? 'Utilisateur inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('veut rejoindre #${channel.name}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                          onPressed: () => ref.read(membershipActionsProvider).respondToRequest(req.channelId, req.userId, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: AppTheme.error),
                          onPressed: () => ref.read(membershipActionsProvider).respondToRequest(req.channelId, req.userId, false),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  void _showJoinRequestDialog(Channel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Accès restreint', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 64, color: AppTheme.primary),
            const SizedBox(height: 24),
            Text('Souhaitez-vous demander l\'accès au salon #${channel.name} ?', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(membershipActionsProvider).requestAccess(channel.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée !'), backgroundColor: AppTheme.primary));
              }
            },
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final membershipsAsync = ref.watch(userMembershipsProvider);
    final pendingRequestsAsync = ref.watch(pendingRequestsProvider);
    
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    Widget buildChannelList(List<Channel> channels, Map<String, String> memberships) {
      final filtered = channels.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      return ListView.builder(
        itemCount: filtered.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final channel = filtered[index];
          final status = memberships[channel.id];
          final isCreator = channel.createdBy == currentUserId;
          final isJoined = isCreator || status == 'joined';
          final isPending = status == 'pending';
          final isSelected = widget.selectedChannelId == channel.id;

          return ChannelTile(
            channel: channel,
            isSelected: isSelected,
            isJoined: isJoined,
            isPending: isPending,
            onTap: () {
              if (channel.isPrivate && !isJoined) {
                if (!isPending) _showJoinRequestDialog(channel);
              } else {
                if (isDesktop) context.go('/channels/${channel.id}', extra: channel.name);
                else context.push('/channels/${channel.id}', extra: channel.name);
              }
            },
          );
        },
      );
    }

    return membershipsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (memberships) => channelsAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
        data: (channels) {
          final requests = pendingRequestsAsync.value ?? [];
          
          if (isDesktop) {
            return Scaffold(
              body: Row(
                children: [
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                    ),
                    child: Column(
                      children: [
                        _buildSidebarHeader(requests, channels),
                        _buildProfileSection(),
                        _buildSearchField(),
                        Expanded(child: buildChannelList(channels, memberships)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: widget.selectedChannelId != null
                        ? ChatScreen(channelId: widget.selectedChannelId!, channelName: widget.selectedChannelName ?? 'Salon', isEmbedded: true)
                        : _buildWelcomeState(),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('DevChat'),
              actions: [
                if (requests.isNotEmpty)
                  IconButton(
                    icon: Badge(label: Text(requests.length.toString()), child: const Icon(Icons.notifications_rounded)),
                    onPressed: () => _showNotificationsDialog(requests, channels),
                  ),
                IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () => ref.read(authNotifierProvider.notifier).signOut()),
              ],
            ),
            body: Column(
              children: [
                _buildSearchField(),
                Expanded(child: buildChannelList(channels, memberships)),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCreateChannelDialog(context, ref),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          );
        }
      ),
    );
  }

  Widget _buildSidebarHeader(List<ChannelMember> requests, List<Channel> channels) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, color: AppTheme.primary, size: 32),
          const SizedBox(width: 14),
          const Text('DevChat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (requests.isNotEmpty)
            IconButton(
              icon: Badge(
                backgroundColor: AppTheme.primary,
                label: Text(requests.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                child: const Icon(Icons.notifications_rounded, color: AppTheme.primary, size: 24),
              ),
              onPressed: () => _showNotificationsDialog(requests, channels),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 24),
            onPressed: () => _showCreateChannelDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: const CircleAvatar(radius: 16, backgroundColor: AppTheme.surfaceVariant, child: Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 18)),
        title: Text(Supabase.instance.client.auth.currentUser?.email ?? 'Utilisateur', 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        trailing: IconButton(icon: const Icon(Icons.logout_rounded, size: 18), onPressed: () => ref.read(authNotifierProvider.notifier).signOut()),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher un salon...',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          fillColor: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_rounded, size: 100, color: AppTheme.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          const Text('Bienvenue sur DevChat !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Sélectionnez un salon pour commencer à échanger.', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
