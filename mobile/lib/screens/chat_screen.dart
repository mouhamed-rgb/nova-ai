import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = AiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _busy = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(_messages);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'تعذر الاتصال بالسيرفر. تحقق من عنوان السيرفر واتصال الإنترنت.\n\nالتفاصيل: $error',
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
      }
    }
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

  Future<void> _showServerSettings() async {
    final current = await _service.getServerUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A2B),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات السيرفر',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('أدخل رابط HTTPS للسيرفر المنشور. أثناء التطوير استخدم عنوان الخادم المحلي المناسب.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://your-server.example.com',
                labelText: 'Server URL',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await _service.setServerUrl(controller.text);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('حفظ العنوان'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOVA AI', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('OPEN MODEL • ONLINE',
                    style: TextStyle(fontSize: 9, letterSpacing: 1.4)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إعدادات السيرفر',
            onPressed: _showServerSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: () => setState(_messages.clear),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _welcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingBubble();
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
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك إلى NOVA...',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _send,
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
              'مساعدك الذكي المدعوم بنموذج مفتوح المصدر على سيرفر خاص.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _showServerSettings,
              icon: const Icon(Icons.settings_ethernet),
              label: const Text('إعداد عنوان السيرفر'),
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
      alignment: user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF5140A5) : const Color(0xFF191D30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: user ? Colors.transparent : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: SelectableText(
          message.content,
          textDirection: TextDirection.auto,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Chip(
          avatar: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('NOVA يفكر...'),
        ),
      ),
    );
  }
}
