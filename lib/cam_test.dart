import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }
  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}

class CamTest extends StatefulWidget {
  const CamTest({Key? key}) : super(key: key);

  @override
  State<CamTest> createState() => _CamTestState();
}

class _CamTestState extends State<CamTest> {
  CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (controller!.value.aspectRatio * mediaSize.aspectRatio);
    return ClipRect(
      clipper: _MediaSizeClipper(mediaSize),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: CameraPreview(controller!),
      ),
    );
  }
}
