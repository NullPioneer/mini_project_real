// =============================================================
//  Chat Screen - Fixed for Windows/Desktop compatibility
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../widgets/dot_loader.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'dart:io' show File;

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
  final SpeechToText _speechToText = SpeechToText();

  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
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

  Future<void> _sendMessage({String? voiceText}) async {
    final text = voiceText ?? _inputController.text.trim();
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

  Future<void> _toggleVoiceInput() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Initializing microphone...')),
      );
      try {
        _speechAvailable = await _speechToText.initialize(
          onError: (error) {
            if (mounted) setState(() => _isListening = false);
          },
        );
      } catch (_) {
        _speechAvailable = false;
      }
      if (!_speechAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Speech recognition completely disabled / not supported on your OS.')),
        );
        return;
      }
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognized = result.recognizedWords;
            setState(() => _isListening = false);
            if (recognized.isNotEmpty) _sendMessage(voiceText: recognized);
          } else {
            setState(() {
              _inputController.text = result.recognizedWords;
              _inputController.selection = TextSelection.fromPosition(
                TextPosition(offset: _inputController.text.length),
              );
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
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
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child:
                  Text('⠿', style: TextStyle(fontSize: 18, color: Colors.white)),
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
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.textSecondary, size: 22),
          onPressed: _clearChat,
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
      color: AppTheme.primaryColor.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.text_snippet_rounded,
              color: AppTheme.primaryLight, size: 16),
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
            top: BorderSide(color: AppTheme.surfaceLight.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isListening
                      ? AppTheme.errorColor.withOpacity(0.5)
                      : AppTheme.surfaceLight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening...'
                            : 'Ask about the Braille text...',
                        hintStyle: TextStyle(
                          color: _isListening
                              ? AppTheme.errorColor
                              : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleVoiceInput,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppTheme.errorColor.withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? AppTheme.errorColor
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isGenerating ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isGenerating ? null : AppTheme.primaryGradient,
                color: _isGenerating ? AppTheme.surfaceLight : null,
                shape: BoxShape.circle,
                boxShadow: _isGenerating
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _isGenerating
                    ? const Padding(
                        padding: EdgeInsets.all(14), child: DotLoader())
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
