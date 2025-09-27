import 'package:flud/central_panel.dart';
import 'package:flud/icons.dart';
import 'package:flud/searcher.dart';
import 'package:flud/shortcuts_menu.dart';
import 'package:flutter/material.dart';

enum AddShortcutResult { success, invalidPath }

class NodeDialogData {
  final String characterPath;
  final String iconPath;
  final String executeCmd;

  const NodeDialogData({
    required this.characterPath,
    required this.executeCmd,
    required this.iconPath,
  });
}

Future<NodeDialogData?> showAddShortcutDialog(BuildContext context) {
  return showDialog<NodeDialogData>(
    context: context,
    builder: (BuildContext context) {
      return AddShortcutDialog();
    },
  );
}

class AddShortcutDialog extends StatefulWidget {
  const AddShortcutDialog({super.key});

  @override
  createState() => AddShortcutDialogState();
}

class AddShortcutDialogState extends State<AddShortcutDialog> {
  final TextEditingController charsController = TextEditingController();
  final TextEditingController iconController = TextEditingController();
  final TextEditingController cmdController = TextEditingController();

  AddShortcutDialogState();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsetsGeometry.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              spacing: 16.0,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                ),
                const Text(
                  'Add a new custom shortcut',
                  textScaler: TextScaler.linear(1.5),
                ),
              ],
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Triggering character sequence:'),
            ),
            TextField(
              controller: charsController,
              decoration: InputDecoration(
                hintText: 'Type a string of characters here - case sensitive!',
              ),
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Icon path, or leave blank:'),
            ),
            TextField(
              controller: iconController,
              decoration: InputDecoration(
                hintText: 'Type an absolute file path here, or leave blank...',
              ),
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Command to execute on activation:'),
            ),
            TextField(
              controller: cmdController,
              decoration: InputDecoration(hintText: 'Type a shell command...'),
            ),
            const Divider(),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  NodeDialogData(
                    characterPath: charsController.text,
                    iconPath: iconController.text,
                    executeCmd: cmdController.text,
                  ),
                );
              },
              child: const Text('Add shortcut'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddAppShortcutDialog extends StatefulWidget {
  final ApplicationInfo app;
  const AddAppShortcutDialog(this.app, {super.key});

  @override
  // How else am I supposed to pass data to the state??
  // ignore: no_logic_in_create_state
  createState() => AddAppShortcutDialogState(app);
}

class AddAppShortcutDialogState extends State<AddAppShortcutDialog> {
  final TextEditingController controller = TextEditingController();
  final ApplicationInfo app;
  AddAppShortcutDialogState(this.app);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsetsGeometry.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              spacing: 16.0,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                ),
                const Text(
                  'Add an app shortcut',
                  textScaler: TextScaler.linear(1.5),
                ),
              ],
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Triggering character sequence:'),
            ),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type a string of characters here - case sensitive!',
              ),
            ),
            const Divider(),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: const Text('Add shortcut'),
            ),
          ],
        ),
      ),
    );
  }
}

void sendErrorSnackBar(Object e, BuildContext context) {
  final snackBar = SnackBar(content: Text(e.toString()));
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

class EditShortcutsDialog extends StatefulWidget {
  final ShortcutNode startNode;
  final List<ShortcutNode> fullNodeList = [];

  EditShortcutsDialog(this.startNode, {super.key}) {
    fullNodeList.addAll(recursiveGetAllNodes(startNode));
  }
  @override
  createState() => EditShortcutsDialogState();
}

class EditShortcutsDialogState extends State<EditShortcutsDialog> {
  final TextEditingController iconPathController = TextEditingController();
  final TextEditingController cmdController = TextEditingController();

  ShortcutNode? currentlyEditing;
  bool shortcutsAreDirty = false;

  @override
  Widget build(BuildContext context) {
    if (currentlyEditing == null) {
      return Actions(
        actions: {
          WidgetListSelected: CallbackAction<WidgetListSelected>(
            onInvoke: (intent) {
              setState(() {
                currentlyEditing = widget.fullNodeList[intent.index];
                iconPathController.text = currentlyEditing!.iconPath ?? '';
                cmdController.text = currentlyEditing!.exec!.join(' ');
              });
              return null;
            },
          ),
        },
        child: Dialog(
          child: Padding(
            padding: EdgeInsetsGeometry.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  spacing: 16.0,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back),
                    ),
                    const Text(
                      'Select an existing shortcut to edit',
                      textScaler: TextScaler.linear(1.5),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SelectableWidgetList((context, idx) {
                    var node = widget.fullNodeList[idx];
                    return Row(
                      spacing: 16.0,
                      children: [
                        node.icon,
                        Expanded(
                          child: Text(
                            getShortcutDisplayString(node),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }, widget.fullNodeList.length),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, shortcutsAreDirty);
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Dialog(
        child: Padding(
          padding: EdgeInsetsGeometry.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 16.0,
                children: [
                  IconButton(
                    onPressed: () => setState(() => currentlyEditing = null),
                    icon: Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      getShortcutDisplayString(currentlyEditing!),
                      textScaler: TextScaler.linear(1.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(),
              const Text('Icon path, or leave blank:'),
              TextField(
                controller: iconPathController,
                decoration: InputDecoration(
                  hintText:
                      'Type an absolute file path here, or leave blank...',
                ),
              ),
              const Divider(),
              const Text('Command to execute on activation:'),
              TextField(
                controller: cmdController,
                decoration: InputDecoration(
                  hintText: 'Type a shell command...',
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton(
                    onPressed: () {
                      currentlyEditing!.iconPath = iconPathController.text;
                      currentlyEditing!.icon = AppIcon(
                        iconPath: iconPathController.text,
                        size: shortcutIconSize,
                      );
                      currentlyEditing!.exec = cmdController.text.split(' ');
                      shortcutsAreDirty = true;
                      setState(() {
                        currentlyEditing = null;
                      });
                    },
                    child: Text('Update shortcut'),
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.fullNodeList.remove(currentlyEditing);
                      findAndRemoveShortcutNode(
                        widget.startNode,
                        currentlyEditing!,
                      );
                      shortcutsAreDirty = true;
                      setState(() {
                        currentlyEditing = null;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.red),
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                    ),
                    child: Text('Delete shortcut'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Cursed code but it works
void findAndRemoveShortcutNode(
  ShortcutNode startNode,
  ShortcutNode shortcutNode,
) {
  var list = findContainingList(startNode, shortcutNode);
  if (list != null) {
    list.remove(shortcutNode);
  }
}

List<ShortcutNode>? findContainingList(
  ShortcutNode parentNode,
  ShortcutNode targetNode,
) {
  for (var child in parentNode.children) {
    if (child == targetNode) {
      return parentNode.children;
    } else if (child.children.isNotEmpty) {
      var list = findContainingList(child, targetNode);
      if (list != null) {
        return list;
      }
    }
  }
  return null;
}

List<ShortcutNode> recursiveGetAllNodes(ShortcutNode node) {
  var out = <ShortcutNode>[];
  for (var child in node.children) {
    if (child.children.isNotEmpty) {
      out.addAll(recursiveGetAllNodes(child));
    } else {
      out.add(child);
    }
  }
  return out;
}

String getShortcutDisplayString(ShortcutNode node) {
  return '${node.characterBind}: "${node.exec!.fold('', (a, b) {
    if (a.isEmpty) {
      return b;
    } else {
      return '$a $b';
    }
  })}"';
}
