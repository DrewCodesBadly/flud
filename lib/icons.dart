import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';

// TODO: Refactor all of this
// Adapted from the win32 task manager example
Future<Widget> getWindowsShortcutIcon(String? path, double size) async {
  Widget? foundIcon;
  final infoPtr = calloc.allocate<SHFILEINFO>(sizeOf<SHFILEINFO>());
  final iconInfoPtr = calloc.allocate<ICONINFO>(sizeOf<ICONINFO>());
  final bitmapInfoPtr = calloc.allocate<BITMAPINFO>(sizeOf<BITMAPINFO>());
  final hdc = CreateCompatibleDC(NULL);

  // Resources that may be created and need to be freed.
  try {
    if (path == null) {
      throw Error();
    }

    SHGetFileInfo(
      path.toNativeUtf16(),
      0, // needed? says its ignored if one isn't set anyway
      infoPtr,
      sizeOf<SHFILEINFO>(),
      0 | SHGFI_ICON,
    );
    if (infoPtr.ref.hIcon == NULL) {
      throw Error();
    }

    // Get icon data from hIcon
    if (GetIconInfo(infoPtr.ref.hIcon, iconInfoPtr) == 0) {
      throw Error();
    }

    bitmapInfoPtr.ref.bmiHeader
      ..biSize = sizeOf<BITMAPINFOHEADER>()
      ..biBitCount = 0;

    // Fetches image dimensions
    if (GetDIBits(
          hdc,
          iconInfoPtr.ref.hbmColor,
          0,
          0,
          nullptr,
          bitmapInfoPtr,
          DIB_RGB_COLORS,
        ) ==
        0) {
      throw Error();
    }

    if (bitmapInfoPtr.ref.bmiHeader.biSizeImage == 0) {
      throw Error();
    }

    final bits = calloc.allocate<Uint8>(
      bitmapInfoPtr.ref.bmiHeader.biSizeImage,
    );

    // Retrieves actual image bytes
    if (GetDIBits(
          hdc,
          iconInfoPtr.ref.hbmColor,
          0,
          bitmapInfoPtr.ref.bmiHeader.biHeight,
          bits,
          bitmapInfoPtr,
          DIB_RGB_COLORS,
        ) ==
        0) {
      calloc.free(bits);
      throw Error();
    }

    // foundIcon = Image.memory(
    //   Uint8List.fromList(
    //     bits.asTypedList(bitmapInfoPtr.ref.bmiHeader.biSizeImage),
    //   ),
    //   width: size,
    //   height: size,
    // );
    var codec = await ImageDescriptor.raw(
      await ImmutableBuffer.fromUint8List(
        bits.asTypedList(bitmapInfoPtr.ref.bmiHeader.biSizeImage),
      ),
      width: bitmapInfoPtr.ref.bmiHeader.biWidth,
      height: bitmapInfoPtr.ref.bmiHeader.biHeight,
      pixelFormat: PixelFormat.rgba8888,
    ).instantiateCodec(targetWidth: size.round(), targetHeight: size.round());
    var image = null;
    foundIcon = RawImage(image: image, width: size, height: size);
    calloc.free(bits);
  } catch (_, _) {
    foundIcon = null;
  } finally {
    DestroyIcon(infoPtr.ref.hIcon);
    DeleteDC(hdc);
    calloc.free(infoPtr);
    calloc.free(iconInfoPtr);
    calloc.free(bitmapInfoPtr);
  }
  return foundIcon ?? Icon(Icons.open_in_new, size: size);
}
