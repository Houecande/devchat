import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isCode = false;
  String _selectedLanguage = 'dart';

  final _languages = ['dart', 'javascript', 'python', 'typescript',
      'kotlin', 'swift', 'java', 'cpp', 'bash', 'json'];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    _controller.clear();
    await ref.read(messagesProvider(widget.channelId).notifier).sendMessage(
          channelId: widget.channelId,
          content: content,
          type: _isCode ? 'code' : 'text',
          language: _isCode ? _selectedLanguage : null,
        );
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.channelId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Scroll automatique à l'arrivée d'un nouveau message
    ref.listen(messagesProvider(widget.channelId), (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('# ${widget.channelName}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('${messages.length} messages',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Liste des messages ──
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Aucun message. Sois le premier ! 👋',
                        style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return MessageBubble(
                        message: msg,
                        isMe: msg.userId == currentUserId,
                      );
                    },
                  ),
          ),

          // ── Barre d'envoi ──
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Toggle code + sélecteur langage
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isCode = !_isCode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isCode
                              ? AppTheme.primary
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.code, size: 14,
                                color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Code',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    if (_isCode) ...[
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12),
                        underline: const SizedBox(),
                        items: _languages
                            .map((l) => DropdownMenuItem(
                                value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedLanguage = v!),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Champ de texte + bouton envoyer
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: _isCode ? 5 : 1,
                        style: TextStyle(
                          fontFamily: _isCode ? 'monospace' : null,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: _isCode
                              ? 'Colle ton code ici...'
                              : 'Envoie un message...',
                          hintStyle:
                              const TextStyle(color: AppTheme.textSecondary),
                        ),
                        onSubmitted: (_) => _isCode ? null : _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}