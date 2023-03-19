import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';

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
  final ui.Image? image;
  final Offset? offset;

  ImagePainter(this.image, this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    paint.blendMode = BlendMode.srcOver;
    canvas.drawImage(image!, offset!, paint);
  }

  @override
  bool shouldRepaint(ImagePainter oldDelegate) {
    return false;
  }
}

class _SubtitleRendererState extends State<SubtitleRenderer> {
  int _timeStamp = 0;
  OverlayEntry? overlayEntry;
  ffi.Pointer<ffi.Int> changePtr = ffi.nullptr;

  late ffi.DynamicLibrary dylib;
  late LibassBindings bindings;
  ffi.Pointer<ASS_Library> libraryHandle = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> rendererHandle = ffi.nullptr;
  ffi.Pointer<ASS_Library> libObject = ffi.nullptr;
  ffi.Pointer<ASS_Renderer> renderer = ffi.nullptr;
  ffi.Pointer<ASS_Track> track = ffi.nullptr;
  late Timer timer;
  ui.Image? resultImage;
  Offset? offset;

  _SubtitleRendererState(){
    changePtr = calloc.allocate(ffi.sizeOf<ffi.Int>()).cast<ffi.Int>();
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

    var assFilePath = path.join(Directory.current.path, 'lib', '[Erai-raws] Tomo-chan wa Onnanoko! - 01 [1080p][Multiple Subtitle][50D3873C].ANIBEL.ass');
    ffi.Pointer<ffi.Char> filePath = assFilePath.toNativeUtf8().cast<ffi.Char>();
    track = bindings.ass_read_file(libObject, filePath, ffi.nullptr);

    timer = Timer.periodic(Duration(milliseconds: 16), _setTimeStamp);
    _timeStamp = 18450;
  }

  _setTimeStamp(Timer t) async {
    //_timeStamp += 16;
    _timeStamp = 19442;
    if (context == null)
      return;

    if (context.size == null)
      return;

    int canvasWidth = context.size!.width.toInt();
    int canvasHeight = context.size!.height.toInt();
    bindings.ass_set_frame_size(renderer, canvasWidth, canvasHeight);

    ffi.Pointer<ASS_Image> frameImage = bindings.ass_render_frame(renderer, track, _timeStamp, changePtr);

    int changeValue = changePtr.value;
    if (changePtr.value == 0)
      return;
    
    removeSubtitleOverlay();
    if (frameImage == ffi.nullptr)
      return;

    RenderBox? renderBox = context.findRenderObject() as RenderBox;
    offset = renderBox!.localToGlobal(Offset.zero);

    Uint8List memory = Uint8List(4 * canvasWidth * canvasHeight);
    memory.fillRange(0, memory.length, 0);

    while (frameImage != ffi.nullptr) {
      ass_image imageRef = frameImage.ref;
      int color = imageRef.color;
      var r = (color >> 24) & 0xFF;
      var g = (color >> 16) & 0xFF;
      var b = (color >> 8) & 0xFF;
      var a = 255 - color & 0xFF; 

      for (int y = 0; y < imageRef.h; ++y)
      {
        for (int x = 0; x < imageRef.w; ++x)
        {
          int offset = y * imageRef.stride + x;
          int opacity = imageRef.bitmap.elementAt(offset).value;
          if (opacity == 0)
          {
            continue;
          }

          int listOffset = 4 * ((imageRef.dst_y + y) * canvasWidth + (imageRef.dst_x + x));

          double srcOpacity = a / 255 * opacity / 255;
          double oneMinusSrc = 1.0 - srcOpacity;
  
          memory[listOffset + 0] = (memory[listOffset + 0] * oneMinusSrc + srcOpacity * r).toInt().clamp(0, 255);
          memory[listOffset + 1] = (memory[listOffset + 1] * oneMinusSrc + srcOpacity * g).toInt().clamp(0, 255);
          memory[listOffset + 2] = (memory[listOffset + 2] * oneMinusSrc + srcOpacity * b).toInt().clamp(0, 255);
          int targetAlpha = memory[listOffset + 3] + (srcOpacity * 255).toInt();
          memory[listOffset + 3] = targetAlpha.clamp(0, 255);
        }
      }

      frameImage = imageRef.next;
    }

    ui.decodeImageFromPixels(memory, canvasWidth, canvasHeight, ui.PixelFormat.rgba8888, (result)
    {
      _setImage(result);
    });
  }

  _setImage(ui.Image img){
    setState(() {
      resultImage = img;
      createSubtitleOverlay();
    });
  }

  void createSubtitleOverlay(){
    removeSubtitleOverlay();

    overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return CustomPaint(painter: ImagePainter(resultImage, offset));
      }
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void removeSubtitleOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  void dispose() {
    // Make sure to remove OverlayEntry when the widget is disposed.
    removeSubtitleOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Row(
             children: [
               Expanded(child: Image.file(File(path.join(Directory.current.path, 'images/shot.png'))))
             ]);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anibel App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Anibel App'),
        ),
        body: Center(
          child: SubtitleRenderer('SubtitleRenderer'),
          )
        ),
      );
  }
}