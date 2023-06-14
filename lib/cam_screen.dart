import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//import 'package:flutter_camera_demo/screens/preview_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const double imageIconSize = 55;
const double mediumIconSize = 24;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  CameraController? controller;

  File? _imageFile;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isRearCameraSelected = true;

  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  double _currentScale = 1.0;
  double _baseScale = 1.0;
  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      debugPrint('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(widget.cameras[0]);
      allFileList.clear();
      //refreshAlreadyCapturedImages();
    } else {
      debugPrint('Camera Permission: DENIED');
    }
  }

  // refreshAlreadyCapturedImages() async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   List<FileSystemEntity> fileList = await directory.list().toList();
  //   allFileList.clear();
  //   List<Map<int, dynamic>> fileNames = [];
  //
  //   for (FileSystemEntity file in fileList) {
  //     if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
  //       allFileList.add(File(file.path));
  //       String name = file.path.split('/').last.split('.').first;
  //       fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
  //     }
  //   }
  //
  //   if (fileNames.isNotEmpty) {
  //     final recentFile = fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
  //     String recentFileName = recentFile[1];
  //     _imageFile = File('${directory.path}/$recentFileName');
  //     setState(() {});
  //   }
  // }

  Future<XFile?> takePicture() async {
    // final CameraController? cameraController = controller;

    if (controller!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      // XFile file = await controller!.takePicture();
      // return file;
      return await controller!.takePicture();
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return null;
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 0.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription, ResolutionPreset.high,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.yuv420 : ImageFormatGroup.jpeg, // ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted)
        setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController.getMinExposureOffset().then((value) => _minAvailableExposureOffset = value),
        cameraController.getMaxExposureOffset().then((value) => _maxAvailableExposureOffset = value),
        cameraController.getMaxZoomLevel().then((value) => _maxAvailableZoom = value),
        cameraController.getMinZoomLevel().then((value) => _minAvailableZoom = value),
      ]);

      controller?.setZoomLevel(_minAvailableZoom);

      print('_minAvailableExposureOffset>> $_minAvailableExposureOffset');
      print('_maxAvailableExposureOffset>> $_maxAvailableExposureOffset');
      print('_minAvailableZoom>> $_minAvailableZoom');
      print('_maxAvailableZoom>> $_maxAvailableZoom');

      _currentFlashMode = controller?.value.flashMode;
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  double _getImageZoom(MediaQueryData data) {
    final double logicalWidth = data.size.width;
    // final double logicalHeight = controller!.value.aspectRatio * logicalWidth;
    final double logicalHeight = data.size.aspectRatio * logicalWidth;

    final EdgeInsets padding = data.padding;
    final double maxLogicalHeight =
        data.size.height - padding.top - padding.bottom;

    return maxLogicalHeight / logicalHeight;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }
    _currentScale = (_baseScale * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    await controller!.setZoomLevel(_currentScale);

    //  or use below for zoom level
    //var maxZoomLevel = await camController.getMaxZoomLevel();
    // just calling it dragIntensity for now, you can call it whatever you like.
    //var dragIntensity = details.scale;
    //if (dragIntensity < 1) {
    // 1 is the minimum zoom level required by the camController's method, hence setting 1 if the user zooms out (less than one is given to details when you zoom-out/pinch-in).
    //  camController.setZoomLevel(1);
    //} else if (dragIntensity > 1 && dragIntensity < maxZoomLevel) {
    // self-explanatory, that if the maxZoomLevel exceeds, you will get an error (greater than one is given to details when you zoom-in/pinch-out).
    // camController.setZoomLevel(dragIntensity);
    //} else {
    // if it does exceed, you can provide the maxZoomLevel instead of dragIntensity (this block is executed whenever you zoom-in/pinch-out more than the max zoom level).
    //  camController.setZoomLevel(maxZoomLevel);
    // }
  }


  @override
  void initState() {
    // Hide the status bar in Android
    //SystemChrome.setEnabledSystemUIOverlays([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    getPermissionStatus();
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> navigateBack() async {
    List<String> filesFinalList = allFileList.map((e) => e.path).toList();
    Navigator.pop(context, filesFinalList);
    return Future.value(true);
  }

  // @override
  // Widget build(BuildContext context) {
  //   final size = MediaQuery
  //       .of(context)
  //       .size;
  //   final deviceRatio = size.width / size.height;
  //
  //   FutureBuilder<void>(
  //     future: _initializeControllerFuture,
  //     builder: (context, snapshot) {
  //       if (snapshot.connectionState == ConnectionState.done) {
  //         // If the Future is complete, display the preview.
  //         return Stack(
  //           children: <Widget>[
  //             Center(
  //               child: Transform.scale(
  //                 scale: _controller.value.aspectRatio / deviceRatio,
  //                 child: new AspectRatio(
  //                   aspectRatio: _controller.value.aspectRatio,
  //                   child: new CameraPreview(_controller),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         );
  //       } else {
  //         return Container(
  //             child:
  //             CircularProgressIndicator()); // Otherwise, display a loading indicator.
  //       }
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // final size = MediaQuery.of(context).size;
    // final deviceRatio = size.width / size.height;
    print('controller!.value.aspectRatio>> ${controller!.value.aspectRatio}');
    //print('deviceRatio>> $deviceRatio');
    //final size = MediaQuery.of(context).size.width;
    return SafeArea(
      child: WillPopScope(
        onWillPop: () => navigateBack(),
        child: Scaffold(
          appBar: null,
          backgroundColor: Colors.black,
          body: _isCameraPermissionGranted
              ? _isCameraInitialized
          // ? RotatedBox(
          //   quarterTurns:
          //   MediaQuery.of(context).orientation == Orientation.landscape
          //       ? 3
          //       : 0,
          //   child: Transform.scale(
          //     scale: 1.0,
          //     child: AspectRatio(
          //       aspectRatio: 3.0 / 4.0,
          //       child: OverflowBox(
          //         alignment: Alignment.center,
          //         child: FittedBox(
          //           fit: BoxFit.fitWidth,
          //           child: SizedBox(
          //             width: size,
          //             //height: double.infinity,
          //             //height: size / controller!.value.aspectRatio,
          //             child: Stack(
          //               children: <Widget>[
          //                 CameraPreview(controller!),
          //               ],
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // )
              ? Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Transform.scale(
                  //scale: controller!.value.aspectRatio / deviceRatio,
                  scale: 1.0,
                  //scale: _getImageZoom(MediaQuery.of(context)),
                  child: AspectRatio(
                    aspectRatio: 1/controller!.value.aspectRatio, // 4:3
                    // aspectRatio: 3.0 / 4.0, // 0.75
                    child: Listener(
                      onPointerDown: (_) => _pointers++,
                      onPointerUp: (_) => _pointers--,
                      child: CameraPreview(
                        controller!,
                        child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: _handleScaleStart,
                            onScaleUpdate: _handleScaleUpdate,
                            onTapDown: (details) => onViewFinderTap(details, constraints),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  // height: mediumIconSize + 5,
                  width: double.infinity,
                  color: Colors.black45,
                  //padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Visibility(
                        visible: Platform.isIOS,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_outlined, color: Colors.white, size: mediumIconSize),
                          onPressed: () => navigateBack(),
                          //padding: EdgeInsets.zero,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.flash_off, color: _currentFlashMode == FlashMode.off ? Colors.amber : Colors.white, size: mediumIconSize),
                        onPressed:() async {
                          setState(() {
                            _currentFlashMode = FlashMode.off;
                          });
                          await controller!.setFlashMode(FlashMode.off);
                        },
                      ),
                      IconButton(
                        icon:  Icon(Icons.flash_auto, color: _currentFlashMode == FlashMode.auto ? Colors.amber : Colors.white, size: mediumIconSize),
                        onPressed: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.auto;
                          });
                          await controller!.setFlashMode(FlashMode.auto);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.flash_on, color: _currentFlashMode == FlashMode.always ? Colors.amber : Colors.white, size: mediumIconSize),
                        onPressed: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.always;
                          });
                          await controller!.setFlashMode(FlashMode.always);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.highlight, color: _currentFlashMode == FlashMode.torch ? Colors.amber : Colors.white, size: mediumIconSize),
                        onPressed: () async {
                          debugPrint('_currentFlashMode>> $_currentFlashMode');
                          FlashMode? mode;
                          if (_currentFlashMode == FlashMode.torch) {
                            // torch is on
                            mode = FlashMode.off;
                          }else {
                            mode = FlashMode.torch;
                          }

                          if (mode != null) {
                            setState(() {
                              _currentFlashMode = mode;
                            });
                            await controller!.setFlashMode(mode);
                          }

                        },
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.black45,
                  //padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: _imageFile != null ? () {
                          // Navigator.of(context).push(
                          //   MaterialPageRoute(
                          //     builder: (context) =>
                          //         PreviewScreen(
                          //           imageFile: _imageFile!,
                          //           fileList: allFileList,
                          //         ),
                          //   ),
                          // );
                        }
                            : null,
                        child: Container(
                          width: imageIconSize -4,
                          height: imageIconSize -4,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.white, width: 2),
                            image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                          ),
                          child: Container(),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          XFile? rawImage = await takePicture();
                          File imageFile = File(rawImage!.path);

                          String currentUnix = DateTime.now().millisecondsSinceEpoch.toString();

                          final directory = await getApplicationDocumentsDirectory();

                          String fileFormat = imageFile.path.split('.').last;
                          debugPrint('fileFormat>> $fileFormat');

                          File file = await imageFile.copy('${directory.path}/$currentUnix.$fileFormat',);
                          debugPrint('file>> ${file.path}');

                          _imageFile = file;
                          allFileList.add(file);

                          setState(() {});

                          // refreshAlreadyCapturedImages();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: const [
                            Icon(
                              Icons.circle,
                              color: Colors.white38,
                              size: imageIconSize + 32,
                            ),
                            Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: imageIconSize+12,
                            ),
                            // Container(),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _animationController.reset();
                          _animationController.forward();
                          setState(() {
                            _isCameraInitialized = false;
                          });
                          onNewCameraSelected(widget.cameras[_isRearCameraSelected ? 1 : 0]);
                          setState(() {
                            _isRearCameraSelected = !_isRearCameraSelected;
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.black38,
                                size: imageIconSize + 10),
                            //Icon(_isRearCameraSelected ? Icons.camera_front : Icons.camera_rear, color: Colors.white, size: 30),
                            RotationTransition(
                                turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
                                child: const Icon( Icons.cameraswitch_rounded, color: Colors.white, size: imageIconSize - 20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
              : const Center(
              child: Text('Loading...',
                  style: TextStyle(color: Colors.white)))
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                const Text('Permission Denied',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    getPermissionStatus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Give Permission',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
