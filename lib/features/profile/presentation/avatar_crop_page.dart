// lib/features/profile/presentation/avatar_crop_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Instagram-style avatar crop page: pan + pinch-to-zoom, circle preview.
/// Returns a cropped [File] (PNG) or null if cancelled.
class AvatarCropPage extends StatefulWidget {
  final File imageFile;

  const AvatarCropPage({super.key, required this.imageFile});

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  final TransformationController _transformCtrl = TransformationController();
  bool _isCropping = false;

  // Zoom scale tracker for the zoom slider
  double _currentScale = 1.0;
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  /// Captures what's visible inside the [RepaintBoundary] circle and
  /// returns a cropped PNG [File] saved in the system temp directory.
  Future<void> _confirmCrop() async {
    setState(() => _isCropping = true);
    try {
      // Capture the rendered pixels of the circular viewport
      final boundary =
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Failed to encode image');

      final Uint8List bytes = byteData.buffer.asUint8List();

      // Save to a unique temp file
      final tmpDir = Directory.systemTemp;
      final tmpPath =
          '${tmpDir.path}/avatar_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsBytes(bytes);

      if (mounted) Navigator.pop(context, tmpFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    // Circle viewport = 80% of screen width
    final double cropSize = screenW * 0.85;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.pop(context, null),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const Text(
                    'Crop Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _isCropping ? null : _confirmCrop,
                    child: _isCropping
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── Crop viewport ─────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The RepaintBoundary wraps the exact circle area we capture
                    RepaintBoundary(
                      key: _repaintKey,
                      child: ClipOval(
                        child: SizedBox(
                          width: cropSize,
                          height: cropSize,
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            constrained: false,
                            minScale: _minScale,
                            maxScale: _maxScale,
                            onInteractionUpdate: (details) {
                              final scale = _transformCtrl.value
                                  .getMaxScaleOnAxis();
                              setState(() => _currentScale = scale);
                            },
                            child: Image.file(
                              widget.imageFile,
                              width: cropSize,
                              height: cropSize,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Decorative circle border on top (non-capturing)
                    IgnorePointer(
                      child: SizedBox(
                        width: cropSize,
                        height: cropSize,
                        child: CustomPaint(painter: _CircleBorderPainter()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Zoom slider ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.zoom_out,
                        color: Colors.white60,
                        size: 20,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: Colors.white,
                            activeTrackColor: Colors.purple,
                            inactiveTrackColor: Colors.white24,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _currentScale,
                            min: _minScale,
                            max: _maxScale,
                            onChanged: (val) {
                              setState(() => _currentScale = val);
                              // Apply zoom via matrix
                              final Matrix4 m = Matrix4.identity()
                                ..scale(val, val);
                              _transformCtrl.value = m;
                            },
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pinch or drag the slider to zoom · Drag to reposition',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
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

/// Draws a white circle border over the crop area (visual guide only).
class _CircleBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_CircleBorderPainter oldDelegate) => false;
}
