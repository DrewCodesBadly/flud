import 'dart:convert';
import 'dart:io';

import 'package:app_dirs/app_dirs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TodoListModel with ChangeNotifier {
  Map<String, List<String>> _todos = {};
  List<String> _activeTodos = [];
  String? _activeTodoName;
  String? get activeTodoName => _activeTodoName;
  set todos(Map<String, List<String>> val) {
    _todos = val;
    notifyListeners();
  }

  TodoListModel() {
    var todoFile = File('${getAppDirs(application: 'Flud').config}/todos.json');
    if (!todoFile.existsSync()) {
      todoFile.createSync(recursive: true);
      todoFile.writeAsStringSync('{}');
      return;
    }

    var decoded = jsonDecode(todoFile.readAsStringSync());
    if (decoded is Map) {
      for (var key in decoded.keys) {
        var val = decoded[key];
        if (key is String && val is List) {
          var newList = <String>[];
          for (var element in val) {
            if (element is String) {
              newList.add(element);
            }
          }
          _todos[key] = newList;
        } else if (key == 'currentlyActiveList' && val is String) {
          _activeTodoName = val;
        }
      }

      if (_activeTodoName != null) {
        _activeTodos = _todos[_activeTodoName] ?? [];
      }
    }
  }

  void saveTodos() {
    var todoFile = File('${getAppDirs(application: 'Flud').config}/todos.json');
    // Todo file should be guaranteed to exist, but just in case
    if (!todoFile.existsSync()) {
      todoFile.createSync(recursive: true);
      todoFile.writeAsStringSync('{}');
      return;
    }

    // Add in the current name
    var adjustedTodos = Map<String, dynamic>.from(_todos);
    if (_activeTodoName != null) {
      adjustedTodos['currentlyActiveList'] = _activeTodoName!;
    }

    todoFile.writeAsStringSync(jsonEncode(adjustedTodos));
  }

  void removeFirst() {
    if (_todos.isNotEmpty) {
      _activeTodos.removeAt(0);
      notifyListeners();
      saveTodos();
    }
  }

  void skip() {
    if (_todos.isNotEmpty) {
      _activeTodos.add(_activeTodos.removeAt(0));
      notifyListeners();
      saveTodos();
    }
  }

  String? currentTodo() {
    return _activeTodos.firstOrNull;
  }

  // Needs to be recursive to make sure discarded changes aren't saved by accident.
  Map<String, List<String>> todosClone() {
    var clone = <String, List<String>>{};
    for (var key in _todos.keys) {
      clone[key] = List<String>.from(_todos[key]!);
    }
    return clone;
  }

  void replaceTodos(Map<String, List<String>> newTodos) {
    _todos = newTodos;
    notifyListeners();
    saveTodos();
  }

  void switchActiveCategory(String newCategory) {
    var newList = _todos[newCategory];
    if (newList != null) {
      _activeTodos = newList;
      _activeTodoName = newCategory;
      notifyListeners();
      saveTodos();
    }
  }

  List<String> getCategories() {
    return _todos.keys.toList(growable: false);
  }
}
