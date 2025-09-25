import 'dart:io';
import 'dart:math';
import 'package:flud/shortcut_dialogs.dart';
import 'package:flud/main.dart';
import 'package:flud/searcher.dart';
import 'package:flud/shortcuts_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

enum SearchState { searchForApps, searchForFiles, noSearch }

class CentralPanel extends StatelessWidget {
  const CentralPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CentralPanelData>(
      builder: (_, data, _) {
        Widget center;
        switch (data.searchState) {
          case SearchState.searchForApps:
            center = AppSearchResultsPanel(data.foundApps);
          case SearchState.searchForFiles:
            center = FileSearchResultsPanel(data.foundFiles);
          case SearchState.noSearch:
            center = ShortcutsMenu();
        }

        return Actions(
          actions: {
            WidgetListSelected: CallbackAction<WidgetListSelected>(
              onInvoke: (intent) {
                switch (data.searchState) {
                  case SearchState.searchForApps:
                    invokeExecuteCmd(data.foundApps[intent.index].executeCmd);
                    sendCloseApp(context);
                  case SearchState.searchForFiles:
                    requestOpenFile(data.foundFiles[intent.index].path);
                    sendCloseApp(context);
                  case SearchState.noSearch:
                }
                return null;
              },
            ),
          },
          child: center,
        );
      },
    );
  }
}

class CentralPanelData extends ChangeNotifier {
  final ApplicationListData apps = ApplicationListData()..populate();
  SearchState searchState = SearchState.noSearch;
  List<ApplicationInfo> foundApps = [];
  List<FileInfo> foundFiles = [];
  final ShortcutNode startNode = loadShortcuts();
  final List<double> pathAngles = [];
  late ShortcutNode currentActiveNode = startNode;

  void updateSearchResults(String text) async {
    if (isStartOfFilePath(text)) {
      searchState = SearchState.searchForFiles;
      var path = text;
      if (text.startsWith('~')) {
        path = path.replaceFirst('~', Platform.environment['HOME']!);
      }
      foundFiles = await findFiles(path);
    } else {
      searchState = SearchState.searchForApps;
      foundApps = apps.search(text);
    }
    notifyListeners();
  }

  void setSearchState(SearchState state) {
    searchState = state;
    notifyListeners();
  }

  void enterPressed(BuildContext context, String text) {
    var success = false;
    switch (searchState) {
      case SearchState.searchForApps:
        if (foundApps.firstOrNull != null) {
          invokeExecuteCmd(foundApps.first.executeCmd);
          success = true;
        }
      // Stolen from [here](https://stackoverflow.com/questions/1795111/is-there-a-cross-platform-way-to-open-a-file-browser-in-python)
      case SearchState.searchForFiles:
        var path =
            (text.endsWith('/') || text.endsWith('\\') ? text : null) ??
            (foundFiles.firstOrNull != null ? foundFiles.first.path : null);
        if (path != null) {
          requestOpenFile(path);
          success = true;
        }
      case SearchState.noSearch:
      // unreachable
    }
    // Close the app if we successfully launched something
    if (success) {
      sendCloseApp(context);
    }
  }

  void triggerShortcuts() {
    searchState = SearchState.noSearch;
    startNode.isActive = true;
    notifyListeners();
  }

  ShortcutInputResult handleInput(String character) {
    var result = currentActiveNode.handleInput(character);
    if (result == ShortcutInputResult.openedFolder) {
      var index =
          currentActiveNode.children.indexOf(currentActiveNode.activeChild!) +
          1;
      var angle =
          (90 * pi / 180) * index / (currentActiveNode.children.length + 1);
      currentActiveNode = currentActiveNode.activeChild!;
      pathAngles.add(angle);
      notifyListeners();
    }
    return result;
  }

  void addNewShortcut(String characterPath, ShortcutNode shortcutNode) {
    var currentNode = startNode;
    characterLoop:
    for (var char in characterPath.characters.take(characterPath.length - 1)) {
      for (var node in currentNode.children) {
        if (node.characterBind == char) {
          if (node.exec != null) {
            throw const FormatException(
              'Character path conflicted with an existing shortcut. Trying removing that shortcut first, or using a different character.',
            );
          }
          currentNode = node;
          continue characterLoop;
        }
      }

      // No existing folder found; make a new one
      var newNode = ShortcutNode(
        char,
        level: currentNode.level + 1,
        icon: Icon(Icons.folder, size: shortcutIconSize),
        children: [],
      );
      currentNode.children.add(newNode);
      currentNode = newNode;
    }

    // Check there is no conflicting shortcut bind, then add new node
    for (var node in currentNode.children) {
      if (node.characterBind == shortcutNode.characterBind) {
        throw const FormatException(
          'Character path conflicted with an existing shortcut. Trying removing that shortcut first, or using a different character.',
        );
      }
    }
    currentNode.children.add(shortcutNode);
  }
}

void requestOpenFile(String path) {
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
      // Should work on most linux systems.
      Process.run("xdg-open", [path]);
    case TargetPlatform.macOS:
      Process.run("open", [path]);
    case TargetPlatform.windows:
      Process.run("start", [path]);
  }
}

void invokeExecuteCmd(String executeCmd) {
  var cmd = stripExecuteCmd(executeCmd.split(' '));
  runCommandWrapped(cmd.first, cmd.skip(1).toList(growable: false));
}

void sendCloseApp(BuildContext context) {
  var closeAction = Actions.maybeFind<CloseAppIntent>(context);
  if (closeAction != null) {
    Actions.of(context).invokeAction(closeAction, const CloseAppIntent());
  }
}

@immutable
class SelectableWidgetList extends StatelessWidget {
  final Widget Function(BuildContext, int) builder;
  final int count;

  const SelectableWidgetList(this.builder, this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: count,
      itemBuilder: (context, idx) {
        return TextButton(
          onPressed: () {
            var action = Actions.maybeFind<WidgetListSelected>(context);
            if (action != null) {
              Actions.of(context).invokeAction(action, WidgetListSelected(idx));
            }
          },
          style: ButtonStyle(
            shape: WidgetStateProperty<OutlinedBorder>.fromMap({
              WidgetState.any: const LinearBorder(),
            }),
          ),
          child: builder(context, idx),
        );
      },
      separatorBuilder: (_, _) {
        return Divider();
      },
    );
  }
}

class WidgetListSelected extends Intent {
  final int index;
  const WidgetListSelected(this.index);
}

class AppSearchResultsPanel extends StatelessWidget {
  final List<ApplicationInfo> apps;
  const AppSearchResultsPanel(this.apps, {super.key});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Align(
        alignment: AlignmentGeometry.topLeft,
        child: Text("No apps found."),
      );
    }
    return SelectableWidgetList((_, index) {
      var app = apps[index];
      return Row(
        children: [
          getAppIcon(app.iconPath, 64.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(app.name), Text(app.filePath)],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.small(
                onPressed: () async {
                  var data = Provider.of<CentralPanelData>(
                    context,
                    listen: false,
                  );
                  var result = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      return AddAppShortcutDialog(app);
                    },
                  );
                  if (result != null && result.isNotEmpty) {
                    var fullIconPath = getAppIconPath(app.iconPath);
                    var node = ShortcutNode(
                      result.characters.last,
                      iconPath: fullIconPath,
                      icon: getAppIconFromPath(fullIconPath, 64.0),
                      exec: stripExecuteCmd(app.executeCmd.split(' ')),
                      level: result.length,
                    );
                    try {
                      data.addNewShortcut(result, node);
                    } catch (e, _) {
                      if (context.mounted) {
                        sendErrorSnackBar(e, context);
                      }
                    }
                    saveShortcuts(data.startNode.children);
                  }
                },
                child: Icon(Icons.star_border),
              ),
            ),
          ),
        ],
      );
    }, apps.length);
  }
}

class FileSearchResultsPanel extends StatelessWidget {
  final List<FileInfo> files;
  const FileSearchResultsPanel(this.files, {super.key});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Align(
        alignment: AlignmentGeometry.topLeft,
        child: Text("No files found."),
      );
    }
    return SelectableWidgetList((_, index) {
      var file = files[index];
      IconData icon;
      switch (file.type) {
        case FileType.file:
          icon = Icons.open_in_new;
        case FileType.directory:
          icon = Icons.folder;
        case FileType.link:
          icon = Icons.link;
      }
      return Row(
        children: [
          Icon(icon, size: 64.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(file.name), Text(file.path)],
          ),
        ],
      );
    }, files.length);
  }
}

String? getAppIconPath(String? iconPath) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // TODO: Handle this case.
      return null;
    case TargetPlatform.fuchsia:
      // TODO: Handle this case.
      return null;
    case TargetPlatform.iOS:
      // TODO: Handle this case.
      return null;
    case TargetPlatform.linux:
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
            // TODO: support SVG and make search more exhaustive
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
        }
      }
      if (foundFile && imageFile != null) {
        return imageFile.path;
      } else {
        return null;
      }
    case TargetPlatform.macOS:
      // TODO: Handle this case.
      return null;
    case TargetPlatform.windows:
      // TODO: Handle this case.
      return null;
  }
}

Widget getAppIcon(String? iconPath, double size) {
  return getAppIconFromPath(getAppIconPath(iconPath), size);
}

Widget getAppIconFromPath(String? fullPath, double size) {
  if (fullPath != null) {
    if (fullPath.endsWith('svg')) {
      return SvgPicture.file(File(fullPath), width: size, height: size);
    } else {
      return Image.file(File(fullPath), width: size, height: size);
    }
  } else {
    return Icon(Icons.open_in_new, size: size);
  }
}
