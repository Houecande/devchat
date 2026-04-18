import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _client = Supabase.instance.client;

// ─── Modèles ───────────────────────────────────────────────

class Channel {
  final String id;
  final String name;
  final String? description;
  final String? createdBy;
  final DateTime createdAt;
  final bool isPrivate;

  Channel({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    required this.createdAt,
    this.isPrivate = false,
  });

  factory Channel.fromMap(Map<String, dynamic> map) => Channel(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        createdBy: map['created_by'],
        createdAt: DateTime.parse(map['created_at']),
        isPrivate: map['is_private'] ?? false,
      );
}

class ChannelMember {
  final String channelId;
  final String userId;
  final String status; // 'pending' | 'joined'
  final String? username;

  ChannelMember({
    required this.channelId,
    required this.userId,
    required this.status,
    this.username,
  });

  factory ChannelMember.fromMap(Map<String, dynamic> map) => ChannelMember(
        channelId: map['channel_id'],
        userId: map['user_id'],
        status: map['status'],
        username: map['profiles']?['username'],
      );
}

class Message {
  final String id;
  final String channelId;
  final String userId;
  final String content;
  final String type;
  final String? language;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;

  Message({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.content,
    required this.type,
    this.language,
    required this.createdAt,
    this.username,
    this.avatarUrl,
  });

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'],
        channelId: map['channel_id'],
        userId: map['user_id'],
        content: map['content'],
        type: map['type'] ?? 'text',
        language: map['language'],
        createdAt: DateTime.parse(map['created_at']),
        username: map['profiles']?['username'],
        avatarUrl: map['profiles']?['avatar_url'],
      );
}

// ─── Providers ─────────────────────────────────────────────

final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final data = await _client
      .from('channels')
      .select()           // ← sans jointure profiles
      .order('created_at', ascending: true);

  return (data as List).map((e) => Channel.fromMap(e)).toList();
});

// Statut de membre de l'utilisateur actuel
final userMembershipsProvider = FutureProvider<Map<String, String>>((ref) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await _client.from('channel_members').select('channel_id, status').eq('user_id', userId);
  return { for (var item in data as List) item['channel_id'] : item['status'] };
});

final isMemberProvider = FutureProvider.family<bool, String>((ref, channelId) async {
  final userId = _client.auth.currentUser!.id;

  final result = await _client
      .from('channel_members')
      .select('id')       // ← juste l'id, pas de jointure
      .eq('channel_id', channelId)
      .eq('user_id', userId)
      .eq('status', 'joined')
      .maybeSingle();

  return result != null;
});

// Demandes en attente pour les salons créés par l'utilisateur
final pendingRequestsProvider = FutureProvider<List<ChannelMember>>((ref) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return [];

  // Récupérer les IDs des salons dont je suis le créateur
  final myChannels = await _client.from('channels').select('id').eq('created_by', userId);
  final channelIds = (myChannels as List).map((c) => c['id']).toList();

  if (channelIds.isEmpty) return [];

  // Récupérer les membres 'pending' de ces salons
  final data = await _client
      .from('channel_members')
      .select('*, profiles(username)')
      .filter('channel_id', 'in', channelIds)
      .eq('status', 'pending');

  return (data as List).map((e) => ChannelMember.fromMap(e)).toList();
});

// Actions
final membershipActionsProvider = Provider((ref) {
  return MembershipActions(ref);
});

class MembershipActions {
  final Ref ref;
  MembershipActions(this.ref);

  Future<void> requestAccess(String channelId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('channel_members').upsert({
      'channel_id': channelId,
      'user_id': userId,
      'status': 'pending',
    });
    ref.invalidate(userMembershipsProvider);
  }

  Future<void> respondToRequest(String channelId, String userId, bool accept) async {
    if (accept) {
      await _client.from('channel_members').update({'status': 'joined'})
          .match({'channel_id': channelId, 'user_id': userId});
    } else {
      await _client.from('channel_members').delete()
          .match({'channel_id': channelId, 'user_id': userId});
    }
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(userMembershipsProvider);
  }
}

// ─── Messages Realtime ─────────────────────────────────────

class MessagesNotifier extends StateNotifier<List<Message>> {
  MessagesNotifier() : super([]);
  RealtimeChannel? _subscription;

  Future<void> load(String channelId) async {
    final data = await _client.from('messages').select('*, profiles(username, avatar_url)')
        .eq('channel_id', channelId).order('created_at', ascending: true);
    state = (data as List).map((e) => Message.fromMap(e)).toList();

    _subscription = _client.channel('messages:$channelId').onPostgresChanges(
      event: PostgresChangeEvent.insert, schema: 'public', table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel_id', value: channelId),
      callback: (payload) async {
        final newMsg = payload.newRecord;
        final profile = await _client.from('profiles').select('username, avatar_url').eq('id', newMsg['user_id']).single();
        newMsg['profiles'] = profile;
        state = [...state, Message.fromMap(newMsg)];
      },
    ).subscribe();
  }

  Future<void> sendMessage({required String channelId, required String content, String type = 'text', String? language}) async {
    await _client.from('messages').insert({
      'channel_id': channelId, 'user_id': _client.auth.currentUser!.id,
      'content': content, 'type': type, 'language': language,
    });
  }

  @override
  void dispose() { _subscription?.unsubscribe(); super.dispose(); }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<Message>, String>((ref, channelId) {
  final n = MessagesNotifier(); n.load(channelId); return n;
});

final createChannelProvider = Provider((ref) {
  return (String name, String? description, bool isPrivate) async {
    final userId = _client.auth.currentUser!.id;
    try {
      await _client.from('channels').insert({'name': name, 'description': description, 'created_by': userId, 'is_private': isPrivate});
    } catch (e) {
      await _client.from('channels').insert({'name': name, 'description': description, 'created_by': userId});
    }
    ref.invalidate(channelsProvider);
  };
});
