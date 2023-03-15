import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

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

class SubtitleRenderer extends StatefulWidget {
  const SubtitleRenderer(String id);

  @override
  State<SubtitleRenderer> createState() => _SubtitleRendererState();
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, const Offset(0, 0), Paint());
  }

  @override
  bool shouldRepaint(ImagePainter oldDelegate) {
    return false;
  }
}

class _SubtitleRendererState extends State<SubtitleRenderer> {
  int _timeStamp = 0;

  late ffi.DynamicLibrary dylib;
  late LibassBindings bindings;
  ffi.Pointer<ASS_Library> libraryHandle = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> rendererHandle = ffi.nullptr;
  ffi.Pointer<ASS_Library> libObject = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> renderer = ffi.nullptr;
  ffi.Pointer<ASS_Track> track = ffi.nullptr;
  late ui.Image resultImage;
  bool hasImage = false;

  _SubtitleRendererState(){
    var libname = 'ass.dll';
    if (kDebugMode)
    {
      libname = 'assd.dll';
    }

    var libraryPath = path.join(Directory.current.path, 'lib', 'win32', libname);
    dylib = ffi.DynamicLibrary.open(libraryPath);
    bindings = LibassBindings(dylib);
    libObject = bindings.ass_library_init();

    ffi.Pointer<ffi.NativeFunction<LogFn>> logFn = ffi.Pointer.fromFunction<LogFn>(assLog);
    bindings.ass_set_message_cb(libObject, logFn, ffi.nullptr);
    renderer = bindings.ass_renderer_init(libObject);

    String fontDirPath = path.join(Directory.current.path, 'lib', 'fonts');
    ffi.Pointer<ffi.Char> fontDirFfiPath =  fontDirPath.toNativeUtf8().cast<ffi.Char>();
    bindings.ass_set_fonts_dir(libObject, fontDirFfiPath);

    String defaultFont = path.join(fontDirPath, 'Montserrat-Bold.ttf');
    String defaultFamily = 'Montserrat';
    bindings.ass_set_fonts(renderer, defaultFont.toNativeUtf8().cast<ffi.Char>(), defaultFamily.toNativeUtf8().cast<ffi.Char>(), 1, ffi.nullptr, 0);
    bindings.ass_set_frame_size(renderer, 600, 400);

    var assFilePath = path.join(Directory.current.path, 'lib', '[Erai-raws] Tomo-chan wa Onnanoko! - 01 [1080p][Multiple Subtitle][50D3873C].ANIBEL.ass');
    ffi.Pointer<ffi.Char> filePath = assFilePath.toNativeUtf8().cast<ffi.Char>();
    track = bindings.ass_read_file(libObject, filePath, ffi.nullptr);

    //timer = Timer(Duration(milliseconds: 16), _setTimeStamp);
    _timeStamp = 19450 - 16;
    _setTimeStamp();
  }

  _setTimeStamp() async {
    _timeStamp += 16;
    print('Timestamp $_timeStamp');
    int changeVar = 0;
    ffi.Pointer<ffi.Int> changePtr = ffi.Pointer<ffi.Int>.fromAddress(changeVar);
    ffi.Pointer<ASS_Image> frameImage = bindings.ass_render_frame(renderer, track, _timeStamp, changePtr);

    int width = frameImage.ref.w;
    int height = frameImage.ref.h;

    Uint8List memory = Uint8List(4 * width * height);
    memory.fillRange(0, memory.length, 255);

    while (frameImage != ffi.nullptr) {
      ass_image imageRef = frameImage.ref;
      int color = imageRef.color;
      var r = (color >> 24) & 0xFF;
      var g = (color >> 16) & 0xFF;
      var b = (color >> 8) & 0xFF;
      var a = 255 - color & 0xFF;

      for (int y = 0; y < height; ++y)
      {
        for (int x = 0; x < width; ++x)
        {
          int offset = y * imageRef.stride + x;
          double alpha = imageRef.bitmap.elementAt(offset).value / 255.0;
          if (alpha == 0)
          {
            continue;
          }

          int listOffset = 4 * (y * width + x);
          memory[listOffset] = (r * alpha).toInt();
          memory[listOffset + 1] = (g * alpha).toInt();
          memory[listOffset + 2] = (b * alpha).toInt();
          memory[listOffset + 3] = (a * alpha).toInt();
        }
      }

      frameImage = imageRef.next;
    }

    ui.decodeImageFromPixels(memory, width, height, ui.PixelFormat.rgba8888, (result)
    {
      _setImage(result);
    });
  }

  _setImage(ui.Image img){
    setState(() {
      resultImage = img;
      hasImage = true;
    });
  }

  @override
  Widget build(BuildContext ctx) {
    if (hasImage == false) {
      return Center(child: Text("Wait a moment", textDirection: TextDirection.ltr));
    }

    return Center(child: CustomPaint(painter: ImagePainter(resultImage)));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: SubtitleRenderer('renderer'));
  }
}