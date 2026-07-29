// =============================================================
//  Result Screen
//  Shows extracted Braille text, audio playback, and chat link
// =============================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/dot_loader.dart';
import 'chat_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> results;

  const ResultScreen({
    super.key,
    required this.results,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoadingAudio = false;  // True while fetching audio from backend
  bool _isPlaying = false;       // True while audio is playing
  String? _audioError;           // Audio-related error message
  int _currentIndex = 0;         // Current result index

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Entry animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();

    // Listen to audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // --- Fetch audio from backend and play it ---
  Future<void> _playAudio() async {
    // If already playing, stop
    if (_isPlaying) {
      await _audioPlayer.stop();
      return;
    }

    setState(() {
      _isLoadingAudio = true;
      _audioError = null;
    });

    // Call TTS API
    final currentText = widget.results[_currentIndex]['text'] as String;
    final result = await ApiService.textToSpeech(text: currentText);

    setState(() => _isLoadingAudio = false);

    if (!mounted) return;

    if (result['success'] == true) {
      try {
        // Decode base64 audio
        final audioBase64 = result['audio_base64'] as String;
        final audioBytes = base64Decode(audioBase64);

        // Save to temporary file and play
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final audioFile = File('${tempDir.path}/braille_audio_$timestamp.mp3');
        await audioFile.writeAsBytes(audioBytes);

        await _audioPlayer.play(DeviceFileSource(audioFile.path));
      } catch (e) {
        setState(() => _audioError = 'Audio playback failed: ${e.toString()}');
      }
    } else {
      setState(() => _audioError = result['error'] ?? 'Failed to generate audio');
    }
  }

  // --- Navigate to Chat Screen ---
  void _goToChat() {
    final currentText = widget.results[_currentIndex]['text'] as String;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          extractedText: currentText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const Scaffold(backgroundColor: AppTheme.backgroundDark);

    final currentText = widget.results[_currentIndex]['text'] as String;
    final currentFile = widget.results[_currentIndex]['file'] as File;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: _buildAppBar(),
      body: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pagination controls
              if (widget.results.length > 1) _buildPagination(),
              if (widget.results.length > 1) const SizedBox(height: 20),

              // Image display to clarify WHICH image is processing
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    border: Border.all(color: AppTheme.accentNeon.withValues(alpha: 0.3)),
                  ),
                  child: currentFile.path.toLowerCase().endsWith('.pdf')
                    ? const Icon(Icons.picture_as_pdf, color: AppTheme.accentNeon, size: 48)
                    : (kIsWeb 
                        ? Image.network(currentFile.path, fit: BoxFit.cover)
                        : Image.file(currentFile, fit: BoxFit.cover)),
                ),
              ),

              const SizedBox(height: 20),

              // Success badge
              _buildSuccessBadge(currentText),

              const SizedBox(height: 24),

              // Extracted text card
              _buildTextCard(currentText),

              const SizedBox(height: 24),

              // Audio playback card
              _buildAudioCard(),

              const SizedBox(height: 16),

              // Audio error
              if (_audioError != null) _buildErrorCard(_audioError!),

              const SizedBox(height: 24),

              // Ask Questions button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _goToChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Ask AI Custom Questions'),
                ),
              ),

              const SizedBox(height: 16),

              // Back button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Process Another Image'),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(widget.results.length > 1 ? 'Extraction Results' : 'Extraction Result'),
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _currentIndex > 0
              ? () {
                  if (_isPlaying) _audioPlayer.stop();
                  setState(() => _currentIndex--);
                }
              : null,
          icon: Icon(Icons.arrow_back_ios_rounded, color: _currentIndex > 0 ? AppTheme.accentNeon : AppTheme.surfaceLight),
        ),
        Text(
          'Document ${_currentIndex + 1} of ${widget.results.length}',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        IconButton(
          onPressed: _currentIndex < widget.results.length - 1
              ? () {
                  if (_isPlaying) _audioPlayer.stop();
                  setState(() => _currentIndex++);
                }
              : null,
          icon: Icon(Icons.arrow_forward_ios_rounded, color: _currentIndex < widget.results.length - 1 ? AppTheme.accentNeon : AppTheme.surfaceLight),
        ),
      ],
    );
  }

  Widget _buildSuccessBadge(String currentText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.accentNeon,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentNeon.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.accentNeon, size: 16),
          const SizedBox(width: 8),
          Text(
            '${currentText.split(' ').length} words extracted',
            style: const TextStyle(
              color: AppTheme.accentNeon,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(String currentText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentNeon.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentNeon.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentNeon, width: 1),
                ),
                child: const Icon(
                  Icons.text_snippet_outlined,
                  color: AppTheme.accentNeon,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Extracted Text',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // Character count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentNeon.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.accentNeon.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${currentText.length} chars',
                  style: const TextStyle(
                    color: AppTheme.accentNeon,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 20),
                tooltip: 'Copy text',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: currentText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Text copied to clipboard', style: TextStyle(color: Colors.white)),
                      backgroundColor: AppTheme.surfaceLight,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 16),

          // Scrollable text area
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                currentText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.7,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.surfaceLight,
        ),
      ),
      child: Row(
        children: [
          // Waveform icon / play indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isPlaying
                  ? AppTheme.accentNeon.withValues(alpha: 0.1)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: _isPlaying ? Border.all(color: AppTheme.accentNeon, width: 1.0) : null,
            ),
            child: _isLoadingAudio
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: DotLoader(),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _isPlaying
                        ? AppTheme.accentNeon
                        : AppTheme.primaryColor,
                    size: 24,
                  ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Playback',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? 'Playing audio...'
                      : _isLoadingAudio
                          ? 'Generating audio...'
                          : 'Listen to the extracted text',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Play/Stop button
          GestureDetector(
            onTap: _isLoadingAudio ? null : _playAudio,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isPlaying ? AppTheme.surfaceLight : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isPlaying ? 'Stop' : 'Play',
                style: TextStyle(
                  color: _isPlaying ? AppTheme.textSecondary : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.errorColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}