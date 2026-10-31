import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoPreview extends StatelessWidget {
  const VideoPreview({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.height,
  });
  final Uint8List bytes;
  final String fileName;
  final double height;
  @override
  Widget build(BuildContext context) => const Text(
    'Video preview is available in the web portal. Download to play this file.',
  );
}
