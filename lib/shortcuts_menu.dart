import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:app_dirs/app_dirs.dart';
import 'package:flud/central_panel.dart';
import 'package:flud/main.dart';
import 'package:flud/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const double shortcutIconSize = 48.0;
const double disabledOpacity = 0.4;
const double radiusLevelChange = 256.0;

enum ShortcutInputResult { ignored, openedFolder, ranExec }

class ShortcutsMenu extends StatefulWidget {
  const ShortcutsMenu({super.key});

  @override
  createState() => ShortcutsMenuState();
}

class ShortcutsMenuState extends State<ShortcutsMenu> {
  ShortcutsMenuState();

  @override
  Widget build(BuildContext context) {
    var data = Provider.of<CentralPanelData>(context);

    return Align(
      alignment: Alignment.topLeft,
      child: TweenAnimationBuilder<double>(
        curve: Curves.easeOut,
        duration: Duration(milliseconds: 250),
        tween: Tween(
          begin: 0.0,
          end: data.currentActiveNode.level + (data.startNode.isActive ? 1 : 0),
        ),
        builder: (_, val, _) {
          var nodes = [_buildNodeWidget(data.startNode)];
          if (data.startNode.isActive) {
            _recursiveBuildNodes(data.startNode, nodes, val);
          }
          // TODO: Improve and make this work
          // return CustomPaint(
          //   painter: ShortcutPathPainter(data.pathAngles),
          //   size: Size(500, 500),
          //   child: Stack(children: nodes),
          // );
          return Stack(children: nodes);
        },
      ),
    );
  }

  Widget _buildNodeWidget(ShortcutNode node) {
    var text = node.characterBind == ' '
        ? '[Space]'
        : '[${node.characterBind}]';
    return Column(children: [node.icon, Text(text)]);
  }

  void _recursiveBuildNodes(
    ShortcutNode node,
    List<Widget> widgets,
    double radiusCap,
  ) {
    final double angleChange = (90.0 * pi / 180) / (node.children.length + 1);
    double angle = angleChange;
    for (var child in node.children) {
      var radius = min(child.level, radiusCap) * radiusLevelChange;
      widgets.add(
        Transform(
          transform: Matrix4.translationValues(
            radius * cos(angle),
            radius * sin(angle),
            0.0,
          ),
          child: Opacity(
            opacity: child.isActive
                ? 1.0
                : clampDouble(
                    1.0 - (child.level - radiusCap),
                    0.0,
                    child.level < radiusCap ? disabledOpacity : 1.0,
                  ),
            child: _buildNodeWidget(child),
          ),
        ),
      );
      angle += angleChange;
    }
    if (node.activeChild != null) {
      _recursiveBuildNodes(node.activeChild!, widgets, radiusCap);
    }
  }
}

class ShortcutPathPainter extends CustomPainter {
  final List<double> angles;

  const ShortcutPathPainter(this.angles);

  @override
  void paint(Canvas canvas, Size size) {
    int level = 0;
    for (var angle in angles) {
      const halfIconSize = shortcutIconSize * 0.5;
      final ({double x, double y}) u = (x: cos(angle), y: sin(angle));

      canvas.drawLine(
        Offset(
          u.x * (radiusLevelChange * level + 48) + halfIconSize,
          u.y * (radiusLevelChange * level + 48) + halfIconSize,
        ),
        Offset(
          u.x * (radiusLevelChange * (level + 1) - 48) + halfIconSize,
          u.y * (radiusLevelChange * (level + 1) - 48) + halfIconSize,
        ),
        Paint()
          ..color = Colors.white.withAlpha((255 * disabledOpacity).round())
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ShortcutNode {
  final String characterBind;
  final int level;

  String? iconPath;
  List<String>? exec;
  Widget icon;
  List<ShortcutNode> children;
  ShortcutNode? activeChild;
  bool isActive = false;

  ShortcutNode(
    this.characterBind, {
    this.exec,
    this.children = const <ShortcutNode>[],
    this.icon = const Icon(Icons.open_in_new, size: shortcutIconSize),
    required this.level,
    this.iconPath,
  });

  ShortcutInputResult handleInput(String c) {
    for (var child in children) {
      if (child.characterBind == c) {
        if (child.exec != null) {
          runCommandWrapped(
            child.exec![0],
            child.exec!.skip(1).toList(growable: false),
          );
          return ShortcutInputResult.ranExec;
        } else {
          activeChild = child;
          child.isActive = true;
          return ShortcutInputResult.openedFolder;
        }
      }
    }
    return ShortcutInputResult.ignored;
  }
}

ShortcutNode loadShortcuts() {
  var configFile = File(
    '${getAppDirs(application: 'Flud').config}/shortcuts.json',
  );
  var children = <ShortcutNode>[];

  if (configFile.existsSync()) {
    try {
      var decoded = jsonDecode(configFile.readAsStringSync());
      if (decoded is! List<dynamic>) {
        throw FormatException('Bad JSON format');
      }
      children = _getNodeChildrenRecursive(decoded, 1);
    } catch (_, _) {
      // Just continue with empty children. TODO: notify user
      children.clear();
    }
  } else {
    configFile.createSync(recursive: true);
    configFile.writeAsString('[\n]');
  }

  return ShortcutNode(
    ' ',
    icon: Icon(Icons.apps, size: shortcutIconSize),
    children: children,
    level: 0,
  );
}

List<ShortcutNode> _getNodeChildrenRecursive(List<dynamic> list, int level) {
  var children = <ShortcutNode>[];
  for (var node in list) {
    var exec = node['exec'];
    var nextChildren = node['children'];

    Widget? icon;
    var iconPath = node['iconPath'];
    if (iconPath != null && iconPath is String && iconPath.isNotEmpty) {
      icon = AppIcon(iconPath: iconPath, size: shortcutIconSize);
    }

    if (node['characterBind'] == null) {
      throw FormatException('Missing character bind');
    } else if (exec != null && exec is List) {
      children.add(
        ShortcutNode(
          node['characterBind']!,
          exec: exec.map((e) => e.toString()).toList(growable: false),
          icon: icon ?? Icon(Icons.open_in_new, size: shortcutIconSize),
          iconPath: icon != null ? iconPath : null,
          level: level,
        ),
      );
    } else if (nextChildren != null && nextChildren is List<dynamic>) {
      children.add(
        ShortcutNode(
          node['characterBind']!,
          icon: icon ?? Icon(Icons.folder, size: shortcutIconSize),
          children: _getNodeChildrenRecursive(nextChildren, level + 1),
          level: level,
        ),
      );
    } else {
      throw FormatException('Found node containing no or invalid info');
    }
  }

  return children;
}

void saveShortcuts(List<ShortcutNode> shortcuts) {
  // Clean tree before saving
  cleanTree(shortcuts);

  var jsonData = [];

  for (var node in shortcuts) {
    jsonData.add(recursiveShortcutToMap(node));
  }

  var json = jsonEncode(jsonData);
  var configFile = File(
    '${getAppDirs(application: 'Flud').config}/shortcuts.json',
  );
  configFile.writeAsStringSync(json, flush: true);
}

void cleanTree(List<ShortcutNode> shortcuts) {
  for (var node in List.from(shortcuts)) {
    if (node.children.isEmpty) {
      if (node.exec == null) {
        shortcuts.remove(node);
      }
    } else {
      cleanTree(node.children);
    }
  }
}

Map<String, dynamic> recursiveShortcutToMap(ShortcutNode node) {
  Map<String, dynamic> map = {'characterBind': node.characterBind};
  map['iconPath'] = node.iconPath ?? '';
  if (node.exec != null) {
    map['exec'] = node.exec;
  } else if (node.children.isNotEmpty) {
    var children = <Map<String, dynamic>>[];
    for (var child in node.children) {
      children.add(recursiveShortcutToMap(child));
    }
    map['children'] = children;
  } else {
    throw FormatException(
      'Attempted to save node containing no or invalid info',
    );
  }

  return map;
}
