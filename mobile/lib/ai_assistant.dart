import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'customer_api.dart';

class MobileAiApi {
  MobileAiApi({
    required this.token,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://talegaon-fresh-ai-backend.onrender.com',
        )).replaceFirst(RegExp(r'/+$'), '');

  final String token;
  final http.Client _client;
  final String _baseUrl;

  Future<String> chat(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const CustomerApiException('Please enter a question.');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/customers/me/ai/chat'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': trimmed}),
    );

    if (response.statusCode == 401) {
      throw const CustomerApiException('Session expired. Please sign in again.', statusCode: 401);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'AI assistant is temporarily unavailable. Please try again.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {}
      throw CustomerApiException(message, statusCode: response.statusCode);
    }

    try {
      final body = jsonDecode(response.body);
      if (body is! Map || body['reply'] is! String) {
        throw const FormatException();
      }
      final reply = (body['reply'] as String).trim();
      if (reply.isEmpty) {
        throw const FormatException();
      }
      return reply;
    } catch (_) {
      throw const CustomerApiException('The assistant returned an invalid response. Please try again.');
    }
  }
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key, required this.token});

  final String token;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_AiMessage>[
    const _AiMessage(
      text: 'Hi! 👋 I’m your FRESHORA assistant. I can help with orders, tracking, products, checkout, and cancellations.',
      fromUser: false,
    ),
  ];
  late final MobileAiApi api;
  bool sending = false;

  static const _quickPrompts = <String>[
    'What is my latest order number?',
    'Track my latest order',
    'Show my order details',
    'How do I place an order?',
    'How do I cancel an order?',
  ];

  @override
  void initState() {
    super.initState();
    api = MobileAiApi(token: widget.token);
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    controller.clear();
    setState(() {
      messages.add(_AiMessage(text: text, fromUser: true));
      sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await api.chat(text);
      if (!mounted) return;
      setState(() => messages.add(_AiMessage(text: reply, fromUser: false)));
    } on CustomerApiException catch (e) {
      if (!mounted) return;
      setState(() => messages.add(_AiMessage(text: e.message, fromUser: false, isError: true)));
    } catch (_) {
      if (!mounted) return;
      setState(() => messages.add(const _AiMessage(
        text: 'I could not reach the assistant. Please try again.',
        fromUser: false,
        isError: true,
      )));
    } finally {
      if (mounted) {
        setState(() => sending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendQuickPrompt(String value) async {
    controller.text = value;
    await send();
  }

  void _newConversation() {
    if (sending) return;
    setState(() {
      messages
        ..clear()
        ..add(const _AiMessage(
          text: 'Hi! 👋 I’m ready to help. Ask for your latest order number, tracking, order details, products, or checkout help.',
          fromUser: false,
        ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(Icons.auto_awesome_rounded, size: 20),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FRESHORA AI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Order & support assistant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New conversation',
            onPressed: sending ? null : _newConversation,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (messages.length == 1 && !sending)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primaryContainer, colors.surfaceContainerHighest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What can I help with?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                      'Use a quick action below or type naturally. For tracking, I will ask for an Order ID when one is required.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPrompts.map((prompt) => _QuickPrompt(
                        label: prompt,
                        onTap: () => _sendQuickPrompt(prompt),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                itemCount: messages.length + (sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (sending && index == messages.length) return const _TypingBubble();
                  return _MessageBubble(message: messages[index]);
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, -2), color: Color(0x14000000))],
              ),
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.viewPaddingOf(context).bottom),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        hintText: 'Ask FRESHORA…',
                        prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                    onPressed: sending ? null : send,
                    icon: const Icon(Icons.arrow_upward_rounded),
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

class _AiMessage {
  const _AiMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
  });

  final String text;
  final bool fromUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AiMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alignment = message.fromUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: message.isError
              ? colors.errorContainer
              : message.fromUser
                  ? colors.primary
                  : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.fromUser ? 20 : 5),
            bottomRight: Radius.circular(message.fromUser ? 5 : 20),
          ),
          border: Border.all(
            color: message.isError
                ? colors.error.withValues(alpha: .25)
                : message.fromUser
                    ? colors.primary
                    : colors.outlineVariant,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isError
                ? colors.onErrorContainer
                : message.fromUser
                    ? colors.onPrimary
                    : colors.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: const SizedBox(
          width: 24,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _QuickPrompt extends StatelessWidget {
  const _QuickPrompt({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      onPressed: onTap,
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}
