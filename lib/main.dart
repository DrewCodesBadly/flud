import 'dart:io';

import 'package:flud/central_panel.dart';
import 'package:flud/shortcut_dialogs.dart';
import 'package:flud/searcher.dart';
import 'package:flud/shortcuts_menu.dart';
import 'package:flud/todo_model.dart';
import 'package:flud/todos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flud',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
        // No bg color.
        scaffoldBackgroundColor: Color.fromARGB(192, 0, 0, 0),
      ),
      themeAnimationCurve: Curves.easeOut,
      themeAnimationDuration: const Duration(milliseconds: 1500),
      home: const HomePage(title: 'Flud'),
    );
  }
}

class CloseAppIntent extends Intent {
  const CloseAppIntent();
}

class LeftAccessBar extends StatelessWidget {
  const LeftAccessBar({super.key});

  @override
  Widget build(BuildContext context) {
    var colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.secondaryContainer,
            colors.secondaryContainer.withAlpha(0),
          ],
          stops: [0.0, 0.75],
          begin: AlignmentGeometry.topCenter,
          end: AlignmentGeometry.bottomCenter,
        ),
        borderRadius: BorderRadius.all(Radius.circular(5.0)),
      ),
      child: Column(
        spacing: 10.0,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          FloatingActionButton(
            onPressed: () async {
              var data = Provider.of<CentralPanelData>(context, listen: false);
              var result = await showAddShortcutDialog(context);
              if (result != null && result.characterPath.isNotEmpty) {
                var iconFile = File(result.iconPath);
                Widget? icon;
                if (iconFile.existsSync()) {
                  if (iconFile.path.endsWith('svg')) {
                    icon = SvgPicture.file(
                      iconFile,
                      width: shortcutIconSize,
                      height: shortcutIconSize,
                    );
                  } else {
                    icon = Image.file(
                      iconFile,
                      height: shortcutIconSize,
                      width: shortcutIconSize,
                    );
                  }
                }
                try {
                  data.addNewShortcut(
                    result.characterPath,
                    ShortcutNode(
                      result.characterPath.characters.last,
                      children: [],
                      exec: result.executeCmd.split(' '),
                      level: result.characterPath.length,
                      iconPath: icon != null ? result.iconPath : null,
                      icon:
                          icon ??
                          Icon(Icons.open_in_new, size: shortcutIconSize),
                    ),
                  );
                } catch (e, _) {
                  if (context.mounted) {
                    sendErrorSnackBar(e, context);
                  }
                }
                saveShortcuts(data.startNode.children);
              }
            },
            child: const Icon(Icons.add),
          ),
          FloatingActionButton(
            onPressed: () async {
              var data = Provider.of<CentralPanelData>(context, listen: false);
              var result = await showDialog<bool>(
                context: context,
                builder: (context) => EditShortcutsDialog(data.startNode),
              );
              if (result != null && result) {
                saveShortcuts(data.startNode.children);
              }
            },
            child: const Icon(Icons.edit),
          ),
          FloatingActionButton(
            onPressed: () async {
              var list = TodoList.of(context);
              var result = await showDialog<Map<String, List<String>>>(
                context: context,
                builder: (context) => EditTodoDialog(list.todosClone()),
              );
              if (result != null) {
                list.replaceTodos(result);
              }
            },
            child: const Icon(Icons.checklist),
          ),
        ],
      ),
    );
  }
}

class MainSearchBar extends StatefulWidget {
  const MainSearchBar({super.key});

  @override
  createState() => _MainSearchBarState();
}

class _MainSearchBarState extends State<MainSearchBar>
    with TickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();

  late final AnimationController _sizeController = AnimationController(
    duration: const Duration(milliseconds: 750),
    vsync: this,
  );
  late final CurvedAnimation _sizeAnimation = CurvedAnimation(
    parent: _sizeController,
    curve: Curves.easeOutQuart,
  );

  @override
  void initState() {
    super.initState();
    _sizeController.forward();
  }

  _MainSearchBarState() {
    controller.addListener(() {
      var data = Provider.of<CentralPanelData>(context, listen: false);
      if (controller.text.isEmpty) {
        data.setSearchState(SearchState.noSearch);
      } else {
        data.updateSearchResults(controller.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.tab): () {
          var data = Provider.of<CentralPanelData>(context, listen: false);
          if (data.searchState == SearchState.searchForFiles) {
            var first = data.foundFiles.firstOrNull;
            if (first != null) {
              if (first.type == FileType.directory) {
                controller.text = '${first.path}${Platform.pathSeparator}';
              } else {
                controller.text = first.path;
              }
            }
          } else {
            Actions.maybeInvoke(
              context,
              DirectionalFocusIntent(TraversalDirection.down),
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          Actions.maybeInvoke(
            context,
            DirectionalFocusIntent(TraversalDirection.down),
          );
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          Actions.maybeInvoke(
            context,
            DirectionalFocusIntent(TraversalDirection.up),
          );
        },
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizeTransition(
          axis: Axis.horizontal,
          axisAlignment: -1.0,
          sizeFactor: _sizeAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withAlpha(192),
              borderRadius: BorderRadius.all(Radius.circular(15.0)),
            ),
            // child: FocusScope(
            //   node: FocusScopeNode(
            //     onKeyEvent: (_, _) {
            //       return KeyEventResult.handled;
            //     },
            //   ),
            child: Row(
              spacing: 10.0,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.search),
                Expanded(
                  child: TextField(
                    focusNode: FocusNode(
                      onKeyEvent: (_, event) {
                        // Text field input is strange and just returning skipRemainingHandlers breaks backspace.
                        // It also breaks the actions and other stuff
                        // Unfortunately, this results in this horrendous if statement
                        if (event.character != null &&
                            event.logicalKey != LogicalKeyboardKey.tab &&
                            event.logicalKey != LogicalKeyboardKey.backspace &&
                            event.logicalKey != LogicalKeyboardKey.escape &&
                            controller.text.isNotEmpty) {
                          return KeyEventResult.skipRemainingHandlers;
                        } else {
                          return KeyEventResult.ignored;
                        }
                      },
                      descendantsAreFocusable: true,
                    ),
                    controller: controller,
                    autofocus: true,
                    onEditingComplete: () {
                      var data = Provider.of<CentralPanelData>(
                        context,
                        listen: false,
                      );
                      data.enterPressed(context, controller.text);
                    },
                    selectAllOnFocus: false,
                    decoration: const InputDecoration(hintText: "Search..."),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainViewArea extends StatelessWidget {
  const MainViewArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.add);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final todoListModel = TodoListModel();

  late final AnimationController _fadeController = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  late final CurvedAnimation _fadeAnimation = CurvedAnimation(
    parent: _fadeController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeAnimation.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CentralPanelData>(
      create: (_) => CentralPanelData(),
      child: Shortcuts(
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.escape): const CloseAppIntent(),
        },
        child: Actions(
          actions: {
            CloseAppIntent: CallbackAction<CloseAppIntent>(
              onInvoke: (_) async {
                await _fadeController.reverse();
                // SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                exit(0);
              },
            ),
          },
          child: FocusScope(
            node: FocusScopeNode(
              onKeyEvent: (node, event) {
                if (event.character != null) {
                  var centralPanel = Provider.of<CentralPanelData>(
                    node.context!,
                    listen: false,
                  );
                  if (centralPanel.startNode.isActive) {
                    switch (centralPanel.handleInput(event.character!)) {
                      case ShortcutInputResult.ignored:
                        return KeyEventResult.ignored;
                      case ShortcutInputResult.openedFolder:
                        return KeyEventResult.handled;
                      case ShortcutInputResult.ranExec:
                        sendCloseApp(node.context!);
                        return KeyEventResult.handled;
                    }
                  } else if (event.character == ' ') {
                    centralPanel.triggerShortcuts();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: TodoList(
                notifier: todoListModel,
                child: Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      spacing: 12.0,
                      children: [
                        MainSearchBar(),
                        Expanded(
                          child: Row(
                            spacing: 10.0,
                            children: [
                              LeftAccessBar(),
                              Expanded(child: CentralPanel()),
                            ],
                          ),
                        ),
                        TodoBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool isStartOfFilePath(String text) {
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
      return text.startsWith('/') || text.startsWith('~');
    case TargetPlatform.macOS:
      return text.startsWith('/') || text.startsWith('~');
    case TargetPlatform.windows:
      return text.startsWith(RegExp(".:\\\\"));
  }
}

// Adds extra args needed (just detached mode right now)
void runCommandWrapped(String name, List<String> args) {
  Process.start(name, args, mode: ProcessStartMode.detached);
}

List<String> stripExecuteCmd(List<String> cmd) {
  // LINUX:
  // I don't think this will break anything on other platforms so we can just run it anyway.
  // Either handle % fields or remove them.
  // TODO: Handle all % fields properly
  // cmd = cmd.map((s) {
  //   switch (s) {
  //     default:
  //       return s;
  //   }
  // }).toList();
  cmd.removeWhere((s) => s.startsWith('%'));
  return cmd;
}
