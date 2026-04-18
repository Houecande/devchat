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

  Channel({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    required this.createdAt,
  });

  factory Channel.fromMap(Map<String, dynamic> map) => Channel(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        createdBy: map['created_by'],
        createdAt: DateTime.parse(map['created_at']),
      );
}

class Message {
  final String id;
  final String channelId;
  final String userId;
  final String content;
  final String type; // 'text' | 'code'
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

// ─── Channels Provider ─────────────────────────────────────

final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final data = await _client
      .from('channels')
      .select()
      .order('created_at', ascending: true);

  return (data as List).map((e) => Channel.fromMap(e)).toList();
});

// ─── Messages Realtime Provider ────────────────────────────

class MessagesNotifier extends StateNotifier<List<Message>> {
  MessagesNotifier() : super([]);

  RealtimeChannel? _subscription;

  Future<void> load(String channelId) async {
    // Charger les messages existants
    final data = await _client
        .from('messages')
        .select('*, profiles(username, avatar_url)')
        .eq('channel_id', channelId)
        .order('created_at', ascending: true);

    state = (data as List).map((e) => Message.fromMap(e)).toList();

    // Écouter les nouveaux messages en temps réel
    _subscription = _client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) async {
            // Récupérer le profil du nouveau message
            final newMsg = payload.newRecord;
            final profile = await _client
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', newMsg['user_id'])
                .single();

            newMsg['profiles'] = profile;
            state = [...state, Message.fromMap(newMsg)];
          },
        )
        .subscribe();
  }

  Future<void> sendMessage({
    required String channelId,
    required String content,
    String type = 'text',
    String? language,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('messages').insert({
      'channel_id': channelId,
      'user_id': userId,
      'content': content,
      'type': type,
      'language': language,
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  (ref, channelId) {
    final notifier = MessagesNotifier();
    notifier.load(channelId);
    return notifier;
  },
);

// ─── Create Channel Provider ───────────────────────────────

final createChannelProvider = Provider((ref) {
  return (String name, String? description) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('channels').insert({
      'name': name,
      'description': description,
      'created_by': userId,
    });
    ref.invalidate(channelsProvider);
  };
});