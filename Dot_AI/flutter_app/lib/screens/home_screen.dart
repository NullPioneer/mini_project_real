// =============================================================
//  Home Screen
//  Upload/Capture Braille image and process it
// =============================================================

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/dot_loader.dart';
import '../widgets/chat_drawer.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final List<File> _selectedFiles = []; // Currently selected files
  bool _isProcessing = false;     // True while API call is in progress
  String? _errorMessage;          // Error message to display
  
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  late AnimationController _dotsController;
  late Animation<double> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _dotsAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _dotsController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _breatheController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  
  // --- Pick files from storage (images or PDF) ---
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          final newFiles = result.paths.map((path) => File(path!)).toList();
          _selectedFiles.addAll(newFiles);
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showError('Could not access files: ${e.toString()}');
    }
  }

  // --- Pick multiple images from Photo Gallery ---
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 90,
      );
      if (images.isNotEmpty) {
        setState(() {
          final newFiles = images.map((x) => File(x.path)).toList();
          _selectedFiles.addAll(newFiles);
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showError('Could not access gallery: ${e.toString()}');
    }
  }

  // --- Capture image with camera ---
  Future<void> _captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedFiles.add(File(image.path));
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showError('Could not access camera: ${e.toString()}');
    }
  }
  void _showSourceActionSheet() {

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Image Source',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accentNeon),
              title: const Text('Gallery', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined, color: AppTheme.accentNeon),
              title: const Text('Files / Documents', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryLight),
              title: const Text('Camera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _captureFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildDrawer() removed in favor of ChatHistoryDrawer

  Future<void> _processImage() async {
    if (_selectedFiles.isEmpty) {
      _showError('Please select or capture a document first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    List<Map<String, dynamic>> finalResults = [];
    bool hasError = false;
    String lastError = '';

    // Process each file individually
    for (var file in _selectedFiles) {
      final result = await ApiService.processImages([file]);
      if (result['success'] == true) {
        final extractedText = result['text'] as String;
        finalResults.add({
          'file': file,
          'text': extractedText.isEmpty ? 'No text could be extracted.' : extractedText,
        });
      } else {
        hasError = true;
        lastError = result['error'] ?? 'Document processing failed.';
        finalResults.add({
          'file': file,
          'text': 'Error: $lastError',
        });
      }
    }

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (finalResults.isNotEmpty) {
      // Navigate to Result Screen with extracted individual texts
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            results: finalResults,
          ),
        ),
      );
    } else if (hasError) {
      _showError(lastError);
    }
  }
  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const ChatHistoryDrawer(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.backgroundDark,
                      Color(0xFF16161A),
                      AppTheme.backgroundDark,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _dotsAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ParticlePainter(angle: _dotsAnimation.value),
                  );
                },
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Header
                    _buildHeader(),

                    const SizedBox(height: 32),

                    // Image Preview Area
                    _buildImagePreview(),

                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) _buildErrorCard(),

                    // Process Button
                    _buildProcessButton(),

                    const SizedBox(height: 48),

                    // How it works section
                    _buildHowItWorks(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentNeon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentNeon, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentNeon.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '⠿',
                style: TextStyle(fontSize: 22, color: AppTheme.accentNeon, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dot_AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Formal Braille Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentNeon,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppTheme.textSecondary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Chat History',
            ),
          ],
        ),

        const SizedBox(height: 28),

        const Text(
          'Extract Braille\nwith Precision.',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.1,
            letterSpacing: -1.0,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Input the braille document via camera or gallery to parse text in real-time.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }


  Widget _buildImagePreview() {
    final bool hasFiles = _selectedFiles.isNotEmpty;
    return GestureDetector(
      onTap: _showSourceActionSheet,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFiles
                ? AppTheme.accentNeon
                : AppTheme.accentNeon.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentNeon.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: hasFiles ? 0.3 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _breatheAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentNeon.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        size: 32,
                        color: AppTheme.accentNeon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap to Add Data',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PDFs, Camera or Gallery',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFiles)
              ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    final isPdf = file.path.toLowerCase().endsWith('.pdf');
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.surfaceLight,
                        border: Border.all(color: AppTheme.accentNeon.withValues(alpha: 0.5)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (!isPdf) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      backgroundColor: Colors.black,
                                      appBar: AppBar(
                                        backgroundColor: Colors.black,
                                        iconTheme: const IconThemeData(color: Colors.white),
                                        elevation: 0,
                                      ),
                                      body: Center(
                                        child: InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 6.0,
                                          child: kIsWeb 
                                              ? Image.network(file.path) 
                                              : Image.file(file),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: isPdf
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 48, color: AppTheme.accentNeon),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            file.path.split('/').last.split('\\').last,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    )
                                  : (kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(file, fit: BoxFit.cover)),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFiles.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          if (index == 0)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentNeon.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Primary', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
              ),
          ],
        ),
        ),
      ),
    );
  }
  Widget _buildErrorCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.errorColor, width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.errorColor, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessButton() {
    if (_isProcessing) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accentNeon, width: 1),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DotLoader(),
              SizedBox(width: 12),
              Text(
                'Analyzing...',
                style: TextStyle(
                  color: AppTheme.accentNeon,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GradientButton(
      label: 'Extract Text',
      onPressed: _selectedFiles.isNotEmpty ? _processImage : null,
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      _Step(
        icon: Icons.upload_file_outlined,
        title: 'Input Data',
        description: 'Provide an image from your device.',
      ),
      _Step(
        icon: Icons.memory_outlined,
        title: 'Run OCR',
        description: 'Algorithm processes the braille dots.',
      ),
      _Step(
        icon: Icons.graphic_eq_outlined,
        title: 'Extract & Audio',
        description: 'Listen to results or query the AI.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Flow',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StepCard(step: entry.value, stepNumber: entry.key + 1),
          );
        }),
      ],
    );
  }
}

// --- Helper Widgets ---

class _Step {
  final IconData icon;
  final String title;
  final String description;

  _Step({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _StepCard extends StatelessWidget {
  final _Step step;
  final int stepNumber;

  const _StepCard({required this.step, required this.stepNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentNeon.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '0$stepNumber',
            style: const TextStyle(
              color: AppTheme.accentNeon,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 16),
          Icon(step.icon, color: AppTheme.primaryLight, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for background particles
class _ParticlePainter extends CustomPainter {
  final double angle;

  _ParticlePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw decorative Braille-like dots in background
    final positions = [
      Offset(size.width * 0.1, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.2),
      Offset(size.width * 0.05, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.65),
      Offset(size.width * 0.2, size.height * 0.9),
      Offset(size.width * 0.75, size.height * 0.88),
    ];

    for (int i = 0; i < positions.length; i++) {
      final offset = positions[i];
      final opacity = (math.sin(angle + i * 0.8) + 1) / 2 * 0.15;
      paint.color = AppTheme.accentNeon.withValues(alpha: opacity);

      // Draw a small Braille cell pattern
      for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 2; col++) {
          canvas.drawCircle(
            Offset(offset.dx + col * 10, offset.dy + row * 10),
            2.5,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.angle != angle;
}