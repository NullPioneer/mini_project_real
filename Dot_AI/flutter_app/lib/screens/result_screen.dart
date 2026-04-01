// =============================================================
//  Result Screen
//  Shows extracted Braille text, audio playback, and chat link
// =============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/dot_loader.dart';
import 'chat_screen.dart';

class ResultScreen extends StatefulWidget {
  final String extractedText;   // Text from Braille processing
  final File imageFile;         // Original image file

  const ResultScreen({
    super.key,
    required this.extractedText,
    required this.imageFile,
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
    final result = await ApiService.textToSpeech(text: widget.extractedText);

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
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatScreen(
          extractedText: widget.extractedText,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Success badge
              _buildSuccessBadge(),

              const SizedBox(height: 24),

              // Extracted text card
              _buildTextCard(),

              const SizedBox(height: 24),

              // Audio playback card
              _buildAudioCard(),

              const SizedBox(height: 16),

              // Audio error
              if (_audioError != null) _buildErrorCard(_audioError!),

              const SizedBox(height: 24),

              // Ask Questions button
              GradientButton(
                label: 'Ask Questions',
                icon: Icons.chat_bubble_rounded,
                onPressed: _goToChat,
              ),

              const SizedBox(height: 16),

              // Back button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Process Another Image'),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Extraction Result'),
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, color: AppTheme.textSecondary),
          onPressed: () {
            // TODO: Implement share functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.successColor, size: 16),
          const SizedBox(width: 8),
          Text(
            '${widget.extractedText.split(' ').length} words extracted',
            style: const TextStyle(
              color: AppTheme.successColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
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
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.text_snippet_rounded,
                  color: AppTheme.primaryLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Extracted Braille Text',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // Character count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.extractedText.length} chars',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Scrollable text area
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                widget.extractedText,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.7,
                  letterSpacing: 0.2,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Waveform icon / play indicator
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _isPlaying
                  ? AppTheme.accentColor.withOpacity(0.2)
                  : AppTheme.surfaceDark,
              shape: BoxShape.circle,
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
                        ? AppTheme.accentColor
                        : AppTheme.textSecondary,
                    size: 28,
                  ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Listen to Text',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isPlaying
                      ? 'Playing audio...'
                      : _isLoadingAudio
                          ? 'Generating audio...'
                          : 'Tap to hear the Braille text read aloud',
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
                gradient: _isPlaying ? null : AppTheme.primaryGradient,
                color: _isPlaying ? AppTheme.surfaceLight : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isPlaying ? 'Stop' : 'Play',
                style: TextStyle(
                  color: _isPlaying ? AppTheme.textSecondary : Colors.white,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.errorColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                  color: AppTheme.errorColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}