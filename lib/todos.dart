import 'package:flud/todo_model.dart';
import 'package:flutter/material.dart';

class TodoList extends InheritedNotifier<TodoListModel> {
  const TodoList({
    super.key,
    required super.child,
    required TodoListModel super.notifier,
  });

  static TodoListModel? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TodoList>()?.notifier!;
  }

  static TodoListModel of(BuildContext context) {
    final TodoListModel? result = maybeOf(context);
    assert(result != null, 'No TodoList found in context');
    return result!;
  }
}

class TodoBar extends StatelessWidget {
  const TodoBar({super.key});

  @override
  Widget build(BuildContext context) {
    var list = TodoList.of(context);
    var dropdownOptions = list
        .getCategories()
        .map((s) => DropdownMenuEntry<String>(value: s, label: s))
        .toList(growable: false);
    var colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.secondaryContainer.withAlpha(0),
            colors.secondaryContainer,
          ],
          stops: [0.25, 1.0],
          begin: AlignmentGeometry.centerLeft,
          end: AlignmentGeometry.centerRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(5.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 10.0,
        children: [
          Text(
            'To-do: ${list.currentTodo() ?? 'Nothing!'}',
            textScaler: TextScaler.linear(1.25),
          ),
          FloatingActionButton.small(
            onPressed: () => list.removeFirst(),
            child: Icon(Icons.check),
          ),
          FloatingActionButton.small(
            onPressed: () => list.skip(),
            child: Icon(Icons.skip_next),
          ),
          DropdownMenu<String>(
            dropdownMenuEntries: dropdownOptions,
            onSelected: (val) {
              if (val != null) {
                list.switchActiveCategory(val);
              }
            },
            initialSelection: list.activeTodoName,
          ),
        ],
      ),
    );
  }
}

class EditTodoDialog extends StatefulWidget {
  final Map<String, List<String>> todos;

  const EditTodoDialog(this.todos, {super.key});

  @override
  createState() => EditTodoDialogState();
}

class EditTodoDialogState extends State<EditTodoDialog> {
  TextEditingController newTodoController = TextEditingController();
  TextEditingController newCategoryController = TextEditingController();
  List<String> activeTodos = [];
  String? activeTodoName;

  @override
  void initState() {
    super.initState();
    var name = widget.todos.keys.firstOrNull;
    if (name != null) {
      activeTodos = widget.todos[name] ?? [];
      activeTodoName = name;
    }
  }

  @override
  Widget build(BuildContext context) {
    var dropdownWidgets = widget.todos.keys
        .map((key) => DropdownMenuEntry<String>(value: key, label: key))
        .toList(growable: false);

    return Dialog(
      child: Padding(
        padding: EdgeInsetsGeometry.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 16.0,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back),
                ),
                const Text(
                  'Add/edit to-dos',
                  textScaler: TextScaler.linear(1.5),
                ),
              ],
            ),
            const Divider(),
            Row(
              spacing: 16.0,
              children: [
                DropdownMenu(
                  initialSelection: dropdownWidgets.firstOrNull?.value,
                  dropdownMenuEntries: dropdownWidgets,
                  onSelected: (val) => setState(() {
                    activeTodoName = val;
                    activeTodos = widget.todos[val]!; // Should be infallible
                  }),
                  width:
                      256.0, // is there a way to make this not fixed? whatever
                ),
                Expanded(
                  child: TextField(
                    controller: newCategoryController,
                    onSubmitted: (_) => addCategory(),
                  ),
                ),
                FilledButton(
                  onPressed: () => addCategory(),
                  child: const Text('Add new to-do category'),
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    widget.todos.remove(activeTodoName);
                    activeTodoName = null;
                    activeTodos = [];
                  }),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.red),
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  child: Text('Delete this category'),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newTodoController,
                    onSubmitted: (_) => addTodo(),
                  ),
                ),
                FilledButton(
                  onPressed: () => addTodo(),
                  child: const Text('Add new to-do'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.all(5.0),
                itemBuilder: (context, idx) {
                  return Padding(
                    key: Key('$idx'),
                    padding: EdgeInsetsGeometry.all(5.0),
                    child: Row(
                      spacing: 16.0,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FloatingActionButton.small(
                          onPressed: () {
                            setState(() {
                              activeTodos.removeAt(idx);
                            });
                          },
                          child: Icon(Icons.delete),
                        ),
                        Text(activeTodos[idx]),
                      ],
                    ),
                  );
                },
                itemCount: activeTodos.length,
                onReorder: (int oldIndex, int newIndex) {
                  var old = activeTodos.removeAt(oldIndex);
                  if (newIndex < widget.todos.length) {
                    activeTodos.insert(newIndex, old);
                  } else {
                    activeTodos.add(old);
                  }
                },
              ),
            ),
            const Divider(),
            Align(
              alignment: AlignmentGeometry.center,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, widget.todos),
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void addTodo() {
    setState(() {
      activeTodos.add(newTodoController.text);
    });
    newTodoController.clear();
  }

  void addCategory() {
    setState(() {
      if (newCategoryController.text.isNotEmpty &&
          newCategoryController.text != 'currentlyActiveTodo') {
        widget.todos[newCategoryController.text] = [];
      }
    });
    newCategoryController.clear();
  }
}
