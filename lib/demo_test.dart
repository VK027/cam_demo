import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
//import 'package:shared_preferences/shared_preferences.dart';

late String initCamera;
late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
 // SharedPreferences pre = await SharedPreferences.getInstance();
  //await prefs.setString("cameraSelected","front");
  //initCamera = await pre.getString("cameraSelected");
  //print('initCamera ${initCamera}');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: CameraHomeScreen(cameras, initCamera),
    );
  }
}
// @override
// void initState() {
//   super.initState();
//   getDeviceMemory().then((value) {
//     initCameraLens();
//     startLive();
//   });
// }

class CameraHomeScreen extends StatefulWidget {
  List<CameraDescription> cameras;
  String initCamera;

  CameraHomeScreen(this.cameras, this.initCamera);

  @override
  State<StatefulWidget> createState() {
    return _CameraHomeScreenState();
  }
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  late String imagePath;
  bool _toggleCamera = false;
  String _currentCamera = 'back';
  late CameraController controller;

  @override
  void initState() {
    print( 'widget.initCamera ${widget.initCamera}' );
    if (widget.initCamera == 'back') {
      onCameraSelected(widget.cameras[0]);
    } else {
      onCameraSelected(widget.cameras[1]);
    }

    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No Camera Found',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      );
    }

    if (!controller.value.isInitialized) {
      return Container();
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Container(
        child: Stack(
          children: <Widget>[
            CameraPreview(controller),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 120.0,
                padding: EdgeInsets.all(20.0),
                color: Color.fromRGBO(00, 00, 00, 0.7),
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.center,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.all(Radius.circular(50.0)),
                          onTap: () {
                            _captureImage();
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/images/ic_shutter_1.png',
                              width: 72.0,
                              height: 72.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.all(Radius.circular(50.0)),
                          onTap: () {
                            if (!_toggleCamera) {
                              SharedPreferencesHelper prefs =
                              SharedPreferencesHelper();
                              //prefs.setCameraSelected('front');
                              print("front");
                              onCameraSelected(widget.cameras[1]);
                              setState(() {
                                _toggleCamera = true;
                              });
                            } else {
                              SharedPreferencesHelper prefs =
                              SharedPreferencesHelper();
                              //prefs.setCameraSelected('back');
                              print("back");
                              onCameraSelected(widget.cameras[0]);
                              setState(() {
                                _toggleCamera = false;
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/images/ic_switch_camera_3.png',
                              color: Colors.grey[200],
                              width: 42.0,
                              height: 42.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) await controller.dispose();
    controller = CameraController(cameraDescription, ResolutionPreset.medium);

    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showMessage('Camera Error: ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      showException(e);
    }

    if (mounted) setState(() {});
  }

  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  void _captureImage() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
        });
        if (filePath != null && filePath.isNotEmpty) {
          showMessage('Picture saved to $filePath');
          setCameraResult();
        }
      }
    });
  }

  void setCameraResult() {
    Navigator.pop(context, imagePath);
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showMessage('Error: select a camera first.');
      return '';
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/FlutterDevs/Camera/Images';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return '';
    }

    try {
      //await controller.takePicture(filePath);
      await controller.takePicture();
    } on CameraException catch (e) {
      showException(e);
      return '';
    }
    return filePath;
  }

  void showException(CameraException e) {
    logError(e.code, e.description!);
    showMessage('Error: ${e.code}\n${e.description}');
  }

  void showMessage(String message) {
    print(message);
  }

  void logError(String code, String message) =>
      print('Error: $code\nMessage: $message');
}

class SharedPreferencesHelper {
  ///
  /// Instantiation of the SharedPreferences library
  ///
  final String _nameKey = "cameraSelected";

  /// ------------------------------------------------------------
  /// Method that returns the user decision on sorting order
  /// ------------------------------------------------------------
  // Future<String> getCameraSelected() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   return prefs.getString(_nameKey) ?? 'name';
  // }

  /// ----------------------------------------------------------
  /// Method that saves the user decision on sorting order
  /// ----------------------------------------------------------
  // Future<bool> setCameraSelected(String value) async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   return prefs.setString(_nameKey, value);
  // }
}




// String initCamera;
// List<CameraDescription> cameras;
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   SharedPreferences pre = await SharedPreferences.getInstance();
//   //await prefs.setString("cameraSelected","front");
//   initCamera = await pre.getString("cameraSelected");
//   print('initCamera ${initCamera}');
//   runApp(MyApp());
// }
// ...
// class CameraHomeScreen extends StatefulWidget {
//   List<CameraDescription> cameras;
//   String initCamera;
//
//   CameraHomeScreen(this.cameras, this.initCamera);
//   ...
//   void initState() {
//     print( 'widget.initCamera ${widget.initCamera}' );
//     if (widget.initCamera == 'back') {
//       onCameraSelected(widget.cameras[0]);
//     } else {
//       onCameraSelected(widget.cameras[1]);
//     }
//
//     super.initState();
//   }