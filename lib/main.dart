import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:libass_binding/libass_binding.dart';

typedef LogFn = ffi.Void Function(ffi.Int level, ffi.Pointer<ffi.Char> fmt, va_list args, ffi.Pointer<ffi.Void> ctx);

void main() {
  runApp(MyApp());
}

void assLog(int level, ffi.Pointer<ffi.Char> fmt, va_list args, ffi.Pointer<ffi.Void> ctx)
{
  String result = '';
  String fmtStr = fmt.cast<Utf8>().toDartString();
  int argIndex = 0;
  int base = 0;
  int index = 0;
  while (index < fmtStr.length)
  {
    if (fmtStr[index] == '%')
    {
      if (index > base)
      { 
        result = result + fmtStr.substring(base, index);
      }
      
      base = index;
      ++index;
      while (index < fmtStr.length)
      {
        if (fmtStr[index] != 'd' &&
            fmtStr[index] != 's' &&
            fmtStr[index] != 'l' &&
            fmtStr[index] != 'p')
        {
          break;
        }
        ++index;
      }

      String format = fmtStr.substring(base, index);
      ffi.Pointer<ffi.Char> argPtr = args.elementAt(argIndex++);
      if (format == '%d')
      {
        result = result + argPtr.cast<ffi.Int>().value.toString();
      }
      else if (format == '%s')
      {
        // ffi.Pointer<ffi.WChar> argStrPtr = argPtr.cast<ffi.WChar>();
        // int strIndex = 0;
        // while (true)
        // {
        //   ffi.Pointer<ffi.WChar> v = argStrPtr.elementAt(strIndex++);
        //   int symbolCode = v.value;
        //   if (symbolCode == 0)
        //   {
        //     break;
        //   }

        //   result = result + String.fromCharCode(symbolCode);
        // }
      }
      else if (format == '%ld')
      {
        result = result + argPtr.cast<ffi.Int64>().value.toString();
      }
      else if (format == '%p')
      {
        result = result + argPtr.address.toString();
      }
      else
      {
        result = result + format;
      }

      base = index;
    }
    else
    {
      ++index;
    }
  }

  if (index > base)
  { 
    result = result + fmtStr.substring(base, index);
  }
  print(result);
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
  late ffi.DynamicLibrary dylib;
  late LibassBindings bindings;
  ffi.Pointer<ASS_Library> libraryHandle = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> rendererHandle = ffi.nullptr;
  ffi.Pointer<ASS_Library> libObject = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> renderer = ffi.nullptr;
  ffi.Pointer<ASS_Track> track = ffi.nullptr;
  ffi.Pointer<ASS_Image> image = ffi.nullptr;
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
    appState.dylib = ffi.DynamicLibrary.open(libraryPath);
    appState.bindings = LibassBindings(appState.dylib);
    appState.libObject = appState.bindings.ass_library_init();

    ffi.Pointer<ffi.NativeFunction<LogFn>> logFn = ffi.Pointer.fromFunction<LogFn>(assLog);
    appState.bindings.ass_set_message_cb(appState.libObject, logFn, ffi.nullptr);
    appState.renderer = appState.bindings.ass_renderer_init(appState.libObject);

    String fontDirPath = path.join(Directory.current.path, 'lib', 'fonts');
    ffi.Pointer<ffi.Char> fontDirFfiPath =  fontDirPath.toNativeUtf8().cast<ffi.Char>();
    appState.bindings.ass_set_fonts_dir(appState.libObject, fontDirFfiPath);

    String defaultFont = path.join(fontDirPath, 'Montserrat-Bold.ttf');
    String defaultFamily = 'Montserrat';
    appState.bindings.ass_set_fonts(appState.renderer, defaultFont.toNativeUtf8().cast<ffi.Char>(), defaultFamily.toNativeUtf8().cast<ffi.Char>(), 1, ffi.nullptr, 0);
    appState.bindings.ass_set_frame_size(appState.renderer, 600, 400);

    var assFilePath = path.join(Directory.current.path, 'lib', '[Erai-raws] Tomo-chan wa Onnanoko! - 01 [1080p][Multiple Subtitle][50D3873C].ANIBEL.ass');
    ffi.Pointer<ffi.Char> filePath = assFilePath.toNativeUtf8().cast<ffi.Char>();
    appState.track = appState.bindings.ass_read_file(appState.libObject, filePath, ffi.nullptr);

    int changeVar = 0;
    ffi.Pointer<ffi.Int> changePtr = ffi.Pointer<ffi.Int>.fromAddress(changeVar);
    appState.image = appState.bindings.ass_render_frame(appState.renderer, appState.track, 19450, changePtr);

    return Scaffold(
      body: Column(
        children: [
          Text('A random AWESOME idea:'),
          Text(appState.current)
        ],
      ),
    );
  }
}