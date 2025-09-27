import 'dart:collection';
import 'dart:io';

import 'package:app_dirs/app_dirs.dart';
import 'package:flud/main.dart';
import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:win32_registry/win32_registry.dart';

class ApplicationInfo {
  final String name;
  final List<String> executeCmd;
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
              apps[name] = ApplicationInfo(
                name,
                stripExecuteCmd(exec.split(' ')),
                iconPath,
                file.path,
              );
              names.add(name);
            }
          }
        }
      case TargetPlatform.macOS:
        // TODO: Handle this case.
        throw UnimplementedError();
      case TargetPlatform.windows:
        // Method 1: Get from start menu shortcuts
        // Works for most things but notably not microsoft store apps and some
        // built in windows apps. However this is the only easy way to get icons
        var paths = <String>[
          'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs',
          '${Directories().baseDirs.data}\\Microsoft\\Windows\\Start Menu\\Programs',
        ];
        for (var programsPath in paths) {
          var programsDirectory = Directory(programsPath);
          await for (var file in programsDirectory.list(
            recursive: true,
            followLinks: true,
          )) {
            if (file is! Directory &&
                (file.path.endsWith('lnk') || file.path.endsWith('.exe'))) {
              var name = file.path.substring(
                file.path.lastIndexOf('\\') + 1,
                file.path.lastIndexOf('.'),
              );
              if (!names.contains(name)) {
                apps[name] = ApplicationInfo(
                  name,
                  // Start just... doesn't work... so I'm using explorer.
                  <String>['explorer', file.path],
                  file.path,
                  file.path,
                );
                names.add(name);
              }
            }
          }
        }
        // Method 2: Get from registry list of applications
        // This only checks PackagedApps which includes all microsoft store apps
        // Some windows built ins might be missed.
        // Also, I have no idea how to get icons.
        final key = Registry.openPath(
          RegistryHive.currentUser,
          path: 'Software\\RegisteredApplications',
        );
        for (var value in key.values) {
          if (value is StringValue) {
            final nextPath = value.value;
            const windowsAppPathStart =
                'Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\AppModel\\Repository\\Packages\\';
            if (nextPath.startsWith(windowsAppPathStart)) {
              try {
                final nextKey = Registry.openPath(
                  RegistryHive.currentUser,
                  path: nextPath,
                );
                final fullAppID = nextPath.substring(
                  windowsAppPathStart.length,
                  nextPath.indexOf('\\', windowsAppPathStart.length),
                );
                final packageID =
                    fullAppID.substring(0, fullAppID.indexOf('_') + 1) +
                    fullAppID.substring(fullAppID.lastIndexOf('_') + 1);
                final name = nextKey.getStringValue('ApplicationName')!;
                if (!names.contains(name)) {
                  apps[name] = ApplicationInfo(
                    name,
                    ['explorer', 'shell:AppsFolder\\$packageID!App'],
                    null,
                    'From the Microsoft Store or Windows',
                  );
                  names.add(name);
                }
                nextKey.close();
              } catch (_, _) {}
            }
          }
        }
        key.close();
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
