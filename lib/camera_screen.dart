import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget{
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return CameraScreenState();
  }
  
}
class CameraScreenState extends State<CameraScreen>{

  late CameraController cameraController;
  late Future<void> _initializeControllerFuture;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    cameraController = CameraController(widget.cameras[0], ResolutionPreset.max);
    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = cameraController.initialize();
    // cameraController.initialize().then((_) {
    //   if (!mounted) {
    //     return;
    //   }
    //   setState(() {});
    // }).catchError((Object e) {
    //   if (e is CameraException) {
    //     switch (e.code) {
    //       case 'CameraAccessDenied':
    //       // Handle access errors here.
    //         break;
    //       default:
    //       // Handle other errors here.
    //         break;
    //     }
    //   }
    // });
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    cameraController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the Future is complete, display the preview.
          return CameraPreview(cameraController);
        } else {
          // Otherwise, display a loading indicator.
          return const Center(child: CircularProgressIndicator());
        }
      },

    );
    //return CameraPreview(cameraController);
  }
  
}


/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  // This enum is from a different package, so a new value could be added at
  // any time. The example should keep working if that happens.
  // ignore: dead_code
  return Icons.camera;
}

// void _logError(String code, String? message) {
//   // ignore: avoid_print
//   print('Error: $code${message == null ? '' : '\nError Message: $message'}');
// }