// =============================================================
//  Chat Screen - Fixed for Windows/Desktop compatibility
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../widgets/dot_loader.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io' show File;
import '../services/chat_storage.dart';
import '../widgets/chat_drawer.dart';

class ChatScreen extends StatefulWidget {
  final String extractedText;

  const ChatScreen({super.key, required this.extractedText});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isListening = false;

  final List<Map<String, String>> _conversationHistory = [];

  String get _sessionId => ChatStorageService.generateId(widget.extractedText);

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final sessions = await ChatStorageService.getSessions();
    if (sessions.containsKey(_sessionId)) {
      final session = sessions[_sessionId]!;
      setState(() {
        _messages.addAll(session.messages);
        _conversationHistory.addAll(session.history);
      });
      _scrollToBottom();
    } else {
      setState(() {
        _addWelcomeMessage();
      });
      _saveSession();
    }
  }

  Future<void> _saveSession() async {
    final title = widget.extractedText.length > 20 
        ? '${widget.extractedText.substring(0, 20)}...' 
        : widget.extractedText;

    final session = ChatSession(
      id: _sessionId,
      title: title.isEmpty ? 'Braille Image' : title,
      extractedText: widget.extractedText,
      messages: _messages,
      history: _conversationHistory,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ChatStorageService.saveSession(session);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    final wordCount = widget.extractedText.split(' ').length;
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content:
          'Hello! I\'ve read the Braille text ($wordCount words). '
          'Ask me anything about it!',
      role: MessageRole.ai,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            if (val == 'done' || val == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (val) {
             if (mounted) setState(() => _isListening = false);
          },
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) => setState(() {
              _inputController.text = val.recognizedWords;
            }),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isListening = false);
        // Silently fails on Windows Desktop avoiding full crash
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not fully supported on this OS.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _inputController.clear();

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    final loadingMessage = ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      content: '',
      role: MessageRole.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(loadingMessage);
      _isGenerating = true;
    });
    _saveSession();

    _scrollToBottom();

    final result = await ApiService.queryText(
      question: text,
      context: widget.extractedText,
      history: _conversationHistory,
    );

    setState(() {
      _messages.removeWhere((m) => m.isLoading);
      _isGenerating = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      final answer = result['answer'] as String;

      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: answer,
          role: MessageRole.ai,
          timestamp: DateTime.now(),
        ));
      });

      _conversationHistory.add({'role': 'user', 'content': text});
      _conversationHistory.add({'role': 'assistant', 'content': answer});

      if (_conversationHistory.length > 20) {
        _conversationHistory.removeRange(0, 2);
      }
    } else {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content:
              'Sorry, I couldn\'t process that. Error: ${result['error']}',
          role: MessageRole.ai,
          timestamp: DateTime.now(),
        ));
      });
    }

    _saveSession();
    _scrollToBottom();
  }

  Future<void> _playAudioResponse(String text) async {
    try {
      final result = await ApiService.textToSpeech(text: text);
      if (!mounted) return;

      if (result['success'] == true) {
        final audioBase64 = result['audio_base64'] as String;
        final audioBytes = base64Decode(audioBase64);
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final audioFile = File('${tempDir.path}/chat_audio_$timestamp.mp3');
        await audioFile.writeAsBytes(audioBytes);
        await _audioPlayer.play(DeviceFileSource(audioFile.path));
      }
    } catch (_) {}
  }

  void _regenerateChat(int aiIndex) {
    if (_isGenerating || aiIndex <= 0) return;
    
    // The previous message should ideally be the user's message
    final userMessage = _messages[aiIndex - 1];
    if (!userMessage.isUser) return;
    
    final prompt = userMessage.content;
    
    setState(() {
      // Remove the AI message and the User message
      _messages.removeAt(aiIndex);
      _messages.removeAt(aiIndex - 1);
      
      // Pop the last 2 entries from history to maintain strict consistency
      if (_conversationHistory.length >= 2) {
        _conversationHistory.removeRange(_conversationHistory.length - 2, _conversationHistory.length);
      }
    });

    _saveSession();
    _inputController.text = prompt;
    _sendMessage();
  }

  void _editChat(int userIndex) {
    if (_isGenerating || userIndex < 0 || userIndex >= _messages.length) return;
    
    final userMessage = _messages[userIndex];
    if (!userMessage.isUser) return;
    
    final prompt = userMessage.content;
    
    setState(() {
      // Remove this message and all subsequent messages to "rewind" the chat context securely
      _messages.removeRange(userIndex, _messages.length);
      
      // Rebuild the history strictly from the remaining successful messages
      _conversationHistory.clear();
      for (var msg in _messages) {
        if (msg.role == MessageRole.user) {
          _conversationHistory.add({'role': 'user', 'content': msg.content});
        } else if (msg.role == MessageRole.ai && !msg.isLoading && msg.id != _messages.first.id) {
          _conversationHistory.add({'role': 'assistant', 'content': msg.content});
        }
      }
    });

    _inputController.text = prompt;
  }

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

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Clear Chat?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This will remove all messages.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _conversationHistory.clear();
                _addWelcomeMessage();
              });
              _saveSession();
            },
            child: const Text('Clear',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      endDrawer: const ChatHistoryDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildContextBanner(),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accentNeon.withValues(alpha: 0.1),
              border: Border.all(color: AppTheme.accentNeon, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child:
                  Text('⠿', style: TextStyle(fontSize: 18, color: AppTheme.accentNeon)),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Dot_AI',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
               Text('Braille Assistant',
                  style:
                      TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 22),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            tooltip: 'Chat History',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.textSecondary, size: 22),
          onPressed: _clearChat,
          tooltip: 'Clear Current Chat',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildContextBanner() {
    final preview = widget.extractedText.length > 60
        ? '${widget.extractedText.substring(0, 60)}...'
        : widget.extractedText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(bottom: BorderSide(color: AppTheme.surfaceLight, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.text_snippet_rounded,
              color: AppTheme.accentNeon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Context: "$preview"',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        if (message.isLoading) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicator(),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatBubble(
            message: message,
            onPlayAudio: () => _playAudioResponse(message.content),
            onRedo: (!message.isUser && index > 0 && message.id != _messages.first.id)
                ? () => _regenerateChat(index)
                : null,
            onEdit: (message.isUser)
                ? () => _editChat(index)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
            top: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.surfaceLight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ask about the Braille text...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 14),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Microphone Button
          GestureDetector(
            onTap: _listen,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isListening ? AppTheme.errorColor.withValues(alpha: 0.2) : AppTheme.surfaceDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening ? AppTheme.errorColor : AppTheme.surfaceLight,
                ),
              ),
              child: Center(
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening ? AppTheme.errorColor : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          GestureDetector(
            onTap: _isGenerating ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isGenerating ? null : AppTheme.neonGradient,
                color: _isGenerating ? AppTheme.surfaceLight : null,
                shape: BoxShape.circle,
                boxShadow: _isGenerating
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.accentNeon.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _isGenerating
                    ? const DotLoader()
                    : const Icon(Icons.send_rounded,
                        color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
