import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _storageKey = 'nova_ai_current_conversation_v1';

  final _service = AiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  SharedPreferences? _preferences;
  bool _busy = false;
  bool _loadingHistory = true;
  bool _restoreContext = false;
  bool _codingMode = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _loadSavedConversation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConversation() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences?.getString(_storageKey);
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved) as List<dynamic>;
        final restored = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => ChatMessage(
                  role: item['role'] as String? ?? 'assistant',
                  content: item['content'] as String? ?? '',
                ))
            .where((message) => message.content.isNotEmpty)
            .toList();
        if (mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(restored);
            _restoreContext = restored.isNotEmpty;
          });
        }
      }
    } catch (_) {
      // A damaged local history should not prevent the assistant from opening.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _saveConversation() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences!.setString(
        _storageKey,
        jsonEncode(_messages.map((message) => message.toJson()).toList()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ المحادثة على الجهاز.')),
      );
    }
  }

  String _makePrompt(String currentMessage, List<ChatMessage> previous) {
    final instructions = _codingMode
        ? 'أنت NOVA AI، مساعد برمجة خبير. اشرح الحل بالعربية عندما يكتب المستخدم بالعربية. '
            'اكتب أكواداً كاملة وصحيحة قدر الإمكان، واشرح أين توضع وكيف تُشغّل. '
            'لا تدّعِ أنك نفذت أو اختبرت كوداً لم تنفذه فعلياً.\n\n'
        : '';

    if (!_restoreContext || previous.isEmpty) {
      return '$instructions$currentMessage';
    }

    final recent = previous.length > 6
        ? previous.sublist(previous.length - 6)
        : previous;
    final transcript = recent.map((message) {
      final speaker = message.isUser ? 'المستخدم' : 'NOVA';
      final excerpt = message.content.length > 420
          ? message.content.substring(0, 420)
          : message.content;
      return '$speaker: $excerpt';
    }).join('\n');

    return '$instructions'
        'هذا ملخص آخر رسائل المحادثة السابقة، استخدمه لفهم السياق ولا تعاود الإجابة عنها من البداية:\n'
        '$transcript\n\n'
        'الطلب الحالي للمستخدم: $currentMessage';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy || _loadingHistory) return;

    final previous = List<ChatMessage>.from(_messages);
    final prompt = _makePrompt(text, previous);

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _busy = true;
      _downloadProgress = null;
      _controller.clear();
    });
    await _saveConversation();
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(
        prompt,
        onDownloadProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _restoreContext = false;
      });
      await _saveConversation();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content:
              'تعذر تشغيل النموذج المحلي. في أول استخدام، اتصل بالإنترنت لتنزيل النموذج (حوالي 1.1 GB)، وتأكد من توفر مساحة كافية في الهاتف. بعد اكتمال التنزيل ستعمل المحادثات دون إنترنت.\n\nالتفاصيل: $error',
        ));
      });
      await _saveConversation();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloadProgress = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _newChat() async {
    if (_busy) return;
    _service.resetChat();
    setState(() {
      _messages.clear();
      _restoreContext = false;
    });
    await _preferences?.remove(_storageKey);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
                ),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOVA AI',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  _codingMode ? 'مساعد برمجة • محلي' : 'LOCAL MODEL • OFFLINE',
                  style: const TextStyle(fontSize: 9, letterSpacing: 1.0),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'وضع المساعد',
            initialValue: _codingMode,
            onSelected: (value) => setState(() => _codingMode = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: false,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.chat_bubble_outline),
                  title: Text('المساعد العام'),
                ),
              ),
              PopupMenuItem(
                value: true,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.code),
                  title: Text('مساعد البرمجة'),
                ),
              ),
            ],
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: _busy || _loadingHistory ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _welcome()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                        itemCount: _messages.length + (_busy ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _TypingBubble(progress: _downloadProgress);
                          }
                          return _MessageBubble(message: _messages[index]);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_loadingHistory,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _codingMode
                            ? 'اكتب سؤالاً برمجياً إلى NOVA...'
                            : 'اكتب رسالتك إلى NOVA...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: FilledButton(
                      onPressed: _busy || _loadingHistory ? null : _send,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 82,
              width: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    blurRadius: 35,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 38),
            ),
            const SizedBox(height: 24),
            const Text('مرحباً بك في NOVA AI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'مساعدك المحلي الخاص. محادثاتك تُحفظ على هذا الجهاز، ويمكنك اختيار وضع مساعد البرمجة من القائمة بالأعلى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF191D30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF22D3EE)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'حفظ المحادثات يتم محلياً على هاتفك، ولا نرسلها إلى خادم. تنزيل النموذج يحتاج إلى الإنترنت في أول مرة فقط.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF5140A5) : const Color(0xFF191D30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: user
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: SelectableText(
          message.content,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final downloading = progress != null;
    final label = downloading
        ? 'تنزيل النموذج ${((progress! * 100).round())}%'
        : 'NOVA يفكر...';

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Chip(
          avatar: downloading
              ? const Icon(Icons.download_rounded, size: 17)
              : const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          label: Text(label),
        ),
      ),
    );
  }
}
