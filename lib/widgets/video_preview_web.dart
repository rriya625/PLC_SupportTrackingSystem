// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoPreview extends StatefulWidget {
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
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  String? url;
  html.VideoElement? video;
  bool failed = false;
  @override
  void dispose() {
    video?.pause();
    video?.removeAttribute('src');
    video?.load();
    if (url != null) html.Url.revokeObjectUrl(url!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed)
      return const Text(
        'This browser cannot preview this video format. Use Download to play it on your device.',
      );
    return SizedBox(
      height: widget.height,
      child: HtmlElementView.fromTagName(
        tagName: 'video',
        onElementCreated: (element) {
          final ext = widget.fileName.split('.').last.toLowerCase();
          final mime = ext == 'mov'
              ? 'video/quicktime'
              : ext == 'webm'
              ? 'video/webm'
              : ext == 'ogv'
              ? 'video/ogg'
              : 'video/mp4';
          url = html.Url.createObjectUrlFromBlob(
            html.Blob([widget.bytes], mime),
          );
          video = element as html.VideoElement;
          video!
            ..controls = true
            ..preload = 'metadata'
            ..setAttribute('playsinline', '')
            ..style.width = '100%'
            ..style.height = '100%'
            ..src = url!;
          video!.onError.listen((_) {
            if (mounted) setState(() => failed = true);
          });
        },
      ),
    );
  }
}
