import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
// Avoids confusing dart:ui's Image and Flutter's Image
import 'package:flutter/material.dart'
    show StatelessWidget, Widget, RawImage, Icons, Icon, BuildContext;
import 'package:flutter_svg/svg.dart';
import 'package:win32/win32.dart';

enum AppIconType { svgImage, bitmapImage, unknownCachedImage, none }

// Size of stored images. On the high end in case of high resolution displays.
const int cachedImageSize = 128;

// StatelessWidget that fetches an icon preloaded into AppIcons.
class AppIcon extends StatelessWidget {
  final String? iconPath;
  final double size;
  late final AppIconType iconType;

  AppIcon({this.iconPath, required this.size, super.key}) {
    if (iconPath == null) {
      iconType = AppIconType.none;
      return;
    } else {
      if (iconPath!.endsWith('svg')) {
        iconType = AppIconType.svgImage;
      } else {
        iconType = AppIconType.unknownCachedImage;
      }
      AppIcons.addIconPathIfNotExists(iconPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (iconType) {
      case AppIconType.bitmapImage:
        var image = AppIcons.decodedImages[iconPath];
        return image != null
            ? RawImage(image: image, width: size, height: size)
            : Icon(Icons.open_in_new, size: size);
      case AppIconType.svgImage:
        var path = AppIcons.svgImages[iconPath];
        if (path != null) {
          var file = File(path);
          if (file.existsSync()) {
            return SvgPicture.file(file, width: size, height: size);
          }
        }
        return Icon(Icons.open_in_new, size: size);
      case AppIconType.none:
        return Icon(Icons.open_in_new, size: size);
      case AppIconType.unknownCachedImage:
        var svgPath = AppIcons.svgImages[iconPath];
        if (svgPath != null) {
          var file = File(svgPath);
          if (file.existsSync()) {
            return SvgPicture.file(file, width: size, height: size);
          }
        }
        var image = AppIcons.decodedImages[iconPath];
        return image != null
            ? RawImage(image: image, width: size, height: size)
            : Icon(Icons.open_in_new, size: size);
    }
  }
}

// Stores cached icons.
class AppIcons {
  // These live through the app's entire lifetime so they are never disposed.
  static final HashMap<String, Image> decodedImages = HashMap();
  static final HashMap<String, String> svgImages = HashMap();

  static Future<void> addIconPathIfNotExists(String iconPath) async {
    if (decodedImages.containsKey(iconPath) ||
        svgImages.containsKey(iconPath)) {
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.fuchsia:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.iOS:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.linux:
        var fullPath = linuxGetFullIconPath(iconPath);
        if (fullPath == null) {
          return;
        }
        if (fullPath.endsWith('svg')) {
          svgImages[iconPath] = fullPath;
        } else {
          // Load the image stored in that file and create an Image from it.
          // This is then stored for later use.
          var image = await loadImageFromFile(fullPath);
          if (image != null) {
            decodedImages[iconPath] = image;
          }
        }
      case TargetPlatform.macOS:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.windows:
        // Extract from shortcut
        if (iconPath.endsWith('lnk')) {
          var image = await getWindowsShortcutIcon(iconPath);
          if (image != null) {
            decodedImages[iconPath] = image;
          }
        } else {
          // Try loading image from file
          var image = await loadImageFromFile(iconPath);
          if (image != null) {
            decodedImages[iconPath] = image;
          }
        }
    }
  }
}

Future<Image?> loadImageFromFile(String fullPath) async {
  try {
    var descriptor = await ImageDescriptor.encoded(
      await ImmutableBuffer.fromFilePath(fullPath),
    );
    var codec = await descriptor.instantiateCodec(
      targetWidth: cachedImageSize,
      targetHeight: cachedImageSize,
    );
    var frame = await codec.getNextFrame();
    return frame.image;
  } catch (_, _) {
    return null;
  }
}

// TODO: Refactor all of this
// Adapted from the win32 task manager example
Future<Image?> getWindowsShortcutIcon(String path) async {
  final infoPtr = calloc.allocate<SHFILEINFO>(sizeOf<SHFILEINFO>());
  final iconInfoPtr = calloc.allocate<ICONINFO>(sizeOf<ICONINFO>());
  final bitmapInfoPtr = calloc.allocate<BITMAPINFO>(sizeOf<BITMAPINFO>());
  final hdc = CreateCompatibleDC(NULL);

  Image? image;

  // Resources that may be created and need to be freed.
  try {
    SHGetFileInfo(
      path.toNativeUtf16(),
      0, // needed? says its ignored if one isn't set anyway
      infoPtr,
      sizeOf<SHFILEINFO>(),
      0 | SHGFI_ICON | SHGFI_LARGEICON,
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

    // For whatever reason the pixels are return correctly -
    // but in the reverse of the order dart expects.
    var originalList = bits.asTypedList(
      bitmapInfoPtr.ref.bmiHeader.biSizeImage,
    );
    // var newList = <int>[];
    // for (var i = 0; i < originalList.length; i += 4) {
    //   var next = originalList[i];
    //   next |= originalList[i + 1] << 8;
    //   next |= originalList[i + 2] << 16;
    //   next |= originalList[i + 3] << 24;
    //   newList.add(next);
    // }
    var len = originalList.length;
    var newList = List<int>.from(originalList);
    for (var i = 0; i < len; i += 4) {
      newList[i] = originalList[len - i - 4];
      newList[i + 1] = originalList[len - i - 3];
      newList[i + 2] = originalList[len - i - 2];
      newList[i + 3] = originalList[len - i - 1];
    }

    var codec =
        await ImageDescriptor.raw(
          await ImmutableBuffer.fromUint8List(Uint8List.fromList(newList)),
          width: bitmapInfoPtr.ref.bmiHeader.biWidth,
          height: bitmapInfoPtr.ref.bmiHeader.biHeight,
          pixelFormat: PixelFormat.bgra8888,
        ).instantiateCodec(
          targetWidth: cachedImageSize,
          targetHeight: cachedImageSize,
        );
    var frame = await codec.getNextFrame();
    image = frame.image;
    calloc.free(bits);
  } catch (e, _) {
    image = null;
  } finally {
    DestroyIcon(infoPtr.ref.hIcon);
    DeleteDC(hdc);
    calloc.free(infoPtr);
    calloc.free(iconInfoPtr);
    calloc.free(bitmapInfoPtr);
  }
  return image;
}

String? linuxGetFullIconPath(String? iconPath) {
  final home = Platform.environment['HOME']!;
  bool foundFile = false;
  File? imageFile;
  if (iconPath != null && iconPath.isNotEmpty) {
    imageFile = File(iconPath);
    if (!imageFile.existsSync()) {
      var dataDirs = Platform.environment["XDG_DATA_DIRS"]!
          .split(':')
          .map((s) => "$s/icons")
          .toList(growable: true);
      // Supposed to search this directory first but it's inconvenient and I don't care.
      dataDirs.add('$home/.icons');
      dataDirs.add('/usr/share/pixmaps/icons');
      outer:
      for (var dir in dataDirs) {
        // Acceptable extensions to the path where the icon might be found. Not exhaustive (yet)
        // SVG and XMP not supported
        var paths = <String>[
          '$dir/hicolor/scalable/apps/$iconPath.svg',
          '$dir/hicolor/64x64/apps/$iconPath.png',
          '$dir/hicolor/32x32/apps/$iconPath.png',
          dir,
        ];
        for (var path in paths) {
          imageFile = File(path);
          if (imageFile.existsSync()) {
            foundFile = true;
            break outer;
          }
        }
      }
    } else {
      foundFile = true;
    }
  }
  if (foundFile && imageFile != null) {
    return imageFile.path;
  } else {
    return null;
  }
}
