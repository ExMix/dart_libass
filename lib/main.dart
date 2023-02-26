import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libass_binding/libass_binding.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = Directory.current.path;
  late DynamicLibrary dylib;
  late LibassBindings bindings;
  Pointer<ASS_Library> libraryHandle = nullptr;
  Pointer<ASS_Renderer> rendererHandle = nullptr;
  Pointer<ASS_Library> libObject = nullptr;
  Pointer<ASS_Renderer> renderer = nullptr;
  Pointer<ASS_Track> track = nullptr;
  Pointer<ASS_Image> image = nullptr;
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var libname = 'ass.dll';
    if (kDebugMode)
    {
      libname = 'assd.dll';
    }

    var libraryPath = path.join(Directory.current.path, 'lib', 'win32', libname);

    var appState = context.watch<MyAppState>();
    appState.dylib = DynamicLibrary.open(libraryPath);
    appState.bindings = LibassBindings(appState.dylib);
    appState.libObject = appState.bindings.ass_library_init();
    appState.renderer = appState.bindings.ass_renderer_init(appState.libObject);

    var assFilePath = path.join(Directory.current.path, 'lib', '[Erai-raws] Tomo-chan wa Onnanoko! - 01 [1080p][Multiple Subtitle][50D3873C].ANIBEL.ass');
    Pointer<Char> filePath = assFilePath.toNativeUtf8().cast<Char>();
    appState.track = appState.bindings.ass_read_file(appState.libObject, filePath, nullptr);

    int changeVar = 0;
    Pointer<Int> changePtr = Pointer<Int>.fromAddress(changeVar);
    appState.image = appState.bindings.ass_render_frame(appState.renderer, appState.track, 1000, changePtr);

    return Scaffold(
      body: Column(
        children: [
          Text('A random AWESOME idea:'),
          Text(appState.current),

          ElevatedButton(
            onPressed: () {
              appState.notifyListeners();
            },
            child: Text('Next'),
          ),

        ],
      ),
    );
  }
}