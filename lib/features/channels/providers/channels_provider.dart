import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

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

enum MessageStatus { sent, sending, error }

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
  final MessageStatus status;

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
    this.status = MessageStatus.sent,
  });

  Message copyWith({MessageStatus? status}) => Message(
    id: id, channelId: channelId, userId: userId, content: content,
    type: type, language: language, createdAt: createdAt,
    username: username, avatarUrl: avatarUrl, status: status ?? this.status,
  );

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
        status: MessageStatus.sent,
      );
}

class ChannelMember {
  final String channelId;
  final String userId;
  final String status;
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

// ─── Providers ─────────────────────────────────────────────

// Liste des salons
final channelsProvider = StreamProvider<List<Channel>>((ref) async* {
  Future<List<Channel>> fetch() async {
    final data = await _client
        .from('channels')
        .select()
        .order('created_at', ascending: true);
    return (data as List).map((e) => Channel.fromMap(e)).toList();
  }

  // Émettre les données initiales
  yield await fetch();

  // Écouter les changements en temps réel
  final controller = StreamController<List<Channel>>();

  final realtimeChannel = _client
      .channel('channels_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'channels',
        callback: (_) async {
          controller.add(await fetch());
        },
      )
      .subscribe();

  ref.onDispose(() {
    realtimeChannel.unsubscribe();
    controller.close();
  });

  yield* controller.stream;
});

// Adhésions de l'utilisateur
final userMembershipsProvider = FutureProvider<Map<String, String>>((ref) async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return {};
  try {
    final data = await _client.from('channel_members').select('channel_id, status').eq('user_id', userId);
    return { for (var item in data as List) item['channel_id'] : item['status'] };
  } catch (e) { return {}; }
});

final pendingRequestsProvider = StreamProvider<List<ChannelMember>>((ref) async* {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) { yield []; return; }

  Future<List<ChannelMember>> fetchRequests() async {
    // 1. Récupérer uniquement les channels dont je suis créateur
    final myChannels = await _client
        .from('channels')
        .select('id')
        .eq('created_by', userId);

    final myChannelIds = (myChannels as List)
        .map((c) => c['id'].toString())
        .toList();

    // 2. Si je ne suis créateur d'aucun channel → aucune notif
    if (myChannelIds.isEmpty) return [];

    // 3. Récupérer les demandes pending sur MES channels uniquement
    final data = await _client
        .from('channel_members')
        .select('channel_id, user_id, status, profiles(username)')
        .eq('status', 'pending')
        .inFilter('channel_id', myChannelIds);

    return (data as List).map((e) => ChannelMember(
      channelId: e['channel_id'],
      userId: e['user_id'],
      status: e['status'],
      username: e['profiles']?['username'] ?? 'Utilisateur',
    )).toList();
  }

  yield await fetchRequests();

  // Écoute realtime uniquement sur channel_members
  final realtimeChannel = _client
      .channel('pending_requests:$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'channel_members',
        callback: (_) => ref.invalidateSelf(),
      )
      .subscribe();

  ref.onDispose(() => realtimeChannel.unsubscribe());

  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield await fetchRequests();
  }
});

final membershipActionsProvider = Provider((ref) => MembershipActions(ref));

class MembershipActions {
  final Ref ref;
  MembershipActions(this.ref);

  Future<void> requestAccess(String channelId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('channel_members').upsert({'channel_id': channelId, 'user_id': userId, 'status': 'pending'});
    ref.invalidate(userMembershipsProvider);
  }

  Future<void> respondToRequest(String channelId, String userId, bool accept) async {
    if (accept) {
      await _client.from('channel_members').update({'status': 'joined'}).match({'channel_id': channelId, 'user_id': userId});
    } else {
      await _client.from('channel_members').delete().match({'channel_id': channelId, 'user_id': userId});
    }
    ref.invalidate(userMembershipsProvider);
    ref.invalidate(pendingRequestsProvider);
  }
}

// ─── Messages ──────────────────────────────────────────────

class MessagesNotifier extends StateNotifier<List<Message>> {
  MessagesNotifier() : super([]);
  RealtimeChannel? _subscription;
  final _uuid = const Uuid();

  Future<void> load(String channelId) async {
    try {
      final data = await _client.from('messages').select('*, profiles(username, avatar_url)')
          .eq('channel_id', channelId).order('created_at', ascending: true);
      state = (data as List).map((e) => Message.fromMap(e)).toList();
    } catch (e) {}

    _subscription = _client.channel('messages:$channelId').onPostgresChanges(
      event: PostgresChangeEvent.insert, schema: 'public', table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel_id', value: channelId),
      callback: (payload) async {
        final newMsg = payload.newRecord;
        try {
          final profile = await _client.from('profiles').select('username, avatar_url').eq('id', newMsg['user_id']).single();
          newMsg['profiles'] = profile;
        } catch (_) {}
        final incoming = Message.fromMap(newMsg);
        state = [...state.where((m) => m.id != incoming.id), incoming];
      },
    ).subscribe();
  }

  Future<void> sendMessage({required String channelId, required String content, String type = 'text', String? language, String? retryId}) async {
    final userId = _client.auth.currentUser!.id;
    final tempId = retryId ?? _uuid.v4();
    final tempMsg = Message(id: tempId, channelId: channelId, userId: userId, content: content, type: type, language: language, createdAt: DateTime.now(), status: MessageStatus.sending);
    if (retryId == null) state = [...state, tempMsg];
    else state = [for (final m in state) if (m.id == tempId) tempMsg else m];
    try {
      await _client.from('messages').insert({'id': tempId, 'channel_id': channelId, 'user_id': userId, 'content': content, 'type': type, 'language': language});
    } catch (e) {
      state = [for (final m in state) if (m.id == tempId) m.copyWith(status: MessageStatus.error) else m];
    }
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
  };
});

final deleteChannelProvider = Provider((ref) {
  return (String channelId) async {
    // Supabase CASCADE s'occupe des messages et members automatiquement
    // grâce au ON DELETE CASCADE défini dans le schéma
    final response = await _client
        .from('channels')
        .delete()
        .eq('id', channelId)
        .select();

    if ((response as List).isEmpty) {
      throw Exception("Suppression impossible. Vérifiez vos droits.");
    }

    ref.invalidate(channelsProvider);
    ref.invalidate(userMembershipsProvider);
  };
});
