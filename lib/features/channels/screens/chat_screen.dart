import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/channels_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;
  final bool isEmbedded;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isCode = false;
  String _selectedLanguage = 'dart';
  bool _showScrollButton = false;

  final List<String> _languages = [
    'dart', 'javascript', 'python', 'typescript', 'kotlin', 'swift', 'java',
    'cpp', 'bash', 'json', 'csharp', 'go', 'ruby', 'rust', 'php', 'sql', 'yaml', 'xml'
  ]..sort();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MediaQuery.of(context).size.width > 900) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onScroll() {
    final show = _scrollController.offset > 100;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.channelId)).reversed.toList();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final primary = Theme.of(context).colorScheme.primary;

    Widget chatContent = Stack(
      children: [
        Column(
          children: [
            if (widget.isEmbedded) _buildHeader(messages.length, primary),
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
            _buildInputSection(isDesktop, primary),
          ],
        ),
        if (_showScrollButton)
          Positioned(
            right: 16,
            bottom: isDesktop ? 160 : 100,
            child: FloatingActionButton.small(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              onPressed: _scrollToBottom,
              child: const Icon(Icons.arrow_downward_rounded),
            ),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return Material(color: Theme.of(context).scaffoldBackgroundColor, child: chatContent);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.tag_rounded, color: primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.channelName,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${messages.length} messages',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: chatContent,
    );
  }

  Widget _buildInputSection(bool isDesktop, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: isDesktop ? 24 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildToggle(
                    icon: Icons.text_fields_rounded,
                    label: 'Texte',
                    isActive: !_isCode,
                    primary: primary,
                    onTap: () => setState(() => _isCode = false),
                  ),
                  const SizedBox(width: 8),
                  _buildToggle(
                    icon: Icons.code_rounded,
                    label: 'Code',
                    isActive: _isCode,
                    primary: primary,
                    onTap: () => setState(() => _isCode = true),
                  ),
                  if (_isCode) ...[
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _showLanguagePicker,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Text(_selectedLanguage,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isDesktop)
                    Text('Entrée pour envoyer • Maj+Entrée pour saut de ligne',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 11)),
                ],
              ),
              const SizedBox(height: 16),
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (!HardwareKeyboard.instance.isShiftPressed) {
                      _send();
                    }
                  },
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: _isCode ? 20 : 8,
                          minLines: 1,
                          style: TextStyle(
                            fontFamily: _isCode ? 'monospace' : null,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: _isCode
                                ? 'Colle ton code ici...'
                                : 'Message dans #${widget.channelName}',
                            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSendButton(primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    final primary = Theme.of(context).colorScheme.primary;
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _languages
              .where((l) => l.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un langage...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setModalState(() => searchQuery = v),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final lang = filtered[index];
                      return ListTile(
                        title: Text(lang, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        selected: lang == _selectedLanguage,
                        selectedTileColor: primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          setState(() => _selectedLanguage = lang);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggle({required IconData icon, required String label, required bool isActive, required Color primary, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? primary : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? primary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(Color primary) {
    return GestureDetector(
      onTap: _send,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildHeader(int count, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag_rounded, color: primary, size: 24),
          const SizedBox(width: 12),
          Text(widget.channelName,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
            child: Text('$count messages', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          const Text('Aucun message ici.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
