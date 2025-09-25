import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';

class ApplicationInfo {
  final String name;
  final String executeCmd;
  final String? iconPath;
  final String filePath;

  const ApplicationInfo(
    this.name,
    this.executeCmd,
    this.iconPath,
    this.filePath,
  );
}

class ApplicationListData {
  HashMap<String, ApplicationInfo> apps = HashMap();
  Fuzzy<String>? fuzzy;

  void populate() async {
    var names = <String>[];
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
        final home = Platform.environment['HOME'];
        var possiblePaths = Platform.environment['XDG_DATA_DIRS']!.split(":");
        possiblePaths.add('$home/.local/share');
        var dirs = <Directory>[];
        for (var path in possiblePaths) {
          path += '/applications';
          var dir = Directory(path);
          if (dir.existsSync()) dirs.add(dir);
        }
        for (var dir in dirs) {
          await for (var file in dir.list(recursive: false)) {
            if (file.path.endsWith('.desktop') && file is File) {
              var s = file.readAsStringSync();
              var name = findXdgDesktopAttribute(s, 'Name=')!;
              if (names.contains(name)) {
                continue;
              }
              var exec = findXdgDesktopAttribute(s, 'Exec=')!;
              var iconPath = findXdgDesktopAttribute(s, 'Icon=');
              apps[name] = ApplicationInfo(name, exec, iconPath, file.path);
              names.add(name);
            }
          }
        }
      case TargetPlatform.macOS:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.windows:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    fuzzy = Fuzzy(names);
  }

  List<ApplicationInfo> search(String query) {
    if (fuzzy == null) {
      return [];
    } else {
      var result = fuzzy!.search(query);
      return result.map((r) => apps[r.item]!).take(10).toList(growable: false);
    }
  }
}

String? findXdgDesktopAttribute(String s, String key) {
  var startIndex = s.indexOf(key) + key.length;
  if (startIndex != -1) {
    var endIndex = s.indexOf('\n', startIndex);
    return s.substring(startIndex, endIndex == -1 ? s.length - 1 : endIndex);
  } else {
    return null;
  }
}

Future<List<FileInfo>> findFiles(String path) async {
  var lastSlash = path.lastIndexOf(RegExp("/|\\\\")) + 1;
  var rootDir = Directory(path.substring(0, lastSlash));
  var leftover = path.substring(lastSlash);
  var list = <FileInfo>[];
  try {
    await for (var f in rootDir.list(followLinks: false)) {
      var fileLeftover = f.path.substring(
        f.path.lastIndexOf(RegExp("/|\\\\")) + 1,
      );
      if (fileLeftover.startsWith(leftover)) {
        FileType type;
        if (f is Link) {
          type = FileType.link;
        } else if (f is Directory) {
          type = FileType.directory;
        } else {
          type = FileType.file;
        }
        list.add(FileInfo(fileLeftover, f.path, type));
      }
    }
  } catch (_, _) {
    // probably tried listing an invalid path.
    return [];
  }

  return list;
}

enum FileType { file, directory, link }

class FileInfo {
  final String path;
  final String name;
  final FileType type;

  const FileInfo(this.name, this.path, this.type);
}
