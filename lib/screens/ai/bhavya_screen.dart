import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';

class BhavyaScreen extends StatefulWidget {
  const BhavyaScreen({super.key});

  @override
  State<BhavyaScreen> createState() => _BhavyaScreenState();
}

class _BhavyaScreenState extends State<BhavyaScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false;
  bool _conversationMode = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      setState(() {
        _messages.add(ChatMessage(
          text: provider.currentLanguage == 'hi'
              ? '🙏 Namaste! Main Bhavya hoon, SHIV SHAKTI se powered.\nHindi, English ya Hinglish mein normal sentence mein bolo.\n\nTry karo:\n• "Ramesh ko 5000 credit kar do"\n• "Suresh ka balance batao"\n• "Ramesh ka len-den dikhao"\n• "Ramesh ko WhatsApp reminder bhejo"\n• "Ramesh ko SMS bhejo"\n• "Ramesh se 5000 UPI payment mangao"\n• "Ramesh ka invoice banao"\n• "Ramesh ka statement share karo"\n• "Mohan supplier ko steel ka reminder bhejo"\n• "Naya supplier Rahul jodo"\n• "Kitne customers hain"\n• "Aaj ka hisab batao"\n\nConversation mode: Bhavya ke jawab ke baad bina button dabaye next command sun sakti hai.'
              : '🙏 Hello! I am Bhavya, powered by SHIV SHAKTI.\nSpeak in Hindi, English or Hinglish.\n\nExamples:\n• "Add 5000 credit to Ramesh"\n• "What is Suresh balance"\n• "Help"',
          isUser: false,
        ));
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_isProcessing) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _isListening = true);

    await provider.bhavya.startListening(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'error') {
          setState(() => _isListening = false);
        }
      },
      onResult: (text) async {
        if (!mounted) return;

        if (text.trim().isEmpty) {
          setState(() => _isListening = false);
          return;
        }

        setState(() {
          _isListening = false;
          _isProcessing = true;
          _messages.add(ChatMessage(text: text, isUser: true));
        });

        try {
          final response = await provider.processVoiceCommand(text);
          if (!mounted) return;

          setState(() {
            _isProcessing = false;
            _messages.add(ChatMessage(text: response, isUser: false));
          });

          await provider.bhavya.speak(response);
          if (mounted && _conversationMode && !_isProcessing) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (mounted && _conversationMode) {
              await _startListening();
            }
          }
        } catch (_) {
          if (!mounted) return;
          const response =
              'Command process karne mein problem aayi. Dobara boliye.';
          setState(() {
            _isProcessing = false;
            _messages.add(ChatMessage(text: response, isUser: false));
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.bhavya.stopListening();
    if (mounted) setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Bhavya AI', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'powered by SHIV SHAKTI',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _conversationMode
                ? 'Conversation mode ON'
                : 'Conversation mode OFF',
            icon: Icon(
              _conversationMode ? Icons.record_voice_over : Icons.voice_over_off,
            ),
            onPressed: () {
              setState(() => _conversationMode = !_conversationMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () async {
              final provider = Provider.of<AppProvider>(context, listen: false);
              final help = provider.bhavya.getHelpText(provider.currentLanguage);
              setState(() {
                _messages.add(ChatMessage(text: help, isUser: false));
              });
              await provider.bhavya.speak(help);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFFFF6B00)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Status
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Bhavya soch rahi hai...',
                  style: TextStyle(color: Colors.grey)),
            ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('🎤 Sun rahi hoon... normal speed mein bolo',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),

          // Mic Button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: GestureDetector(
              // Tap once to start; tap again to stop.
              // Holding/releasing the button used to cancel Android speech
              // recognition before the final result arrived.
              onTap: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isListening
                      ? 1.0 + (_pulseController.value * 0.15)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [Colors.red.shade400, Colors.red.shade700]
                              : [
                                  const Color(0xFFFF6B00),
                                  const Color(0xFFFF8F00)
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
                                    ? Colors.red
                                    : const Color(0xFFFF6B00))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: _isListening ? 8 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _conversationMode
                  ? 'Conversation mode ON • Bhavya ke jawab ke baad phir sunegi'
                  : 'Mic par ek baar tap karke bolo • phir dobara tap karke band karo',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
