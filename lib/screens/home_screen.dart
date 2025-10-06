import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../models/todo.dart';
import 'task_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelection([Todo? first]) {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      if (first?.id != null) _selectedIds.add(first!.id!);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(Todo t) {
    final id = t.id;
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _addTaskSheet(BuildContext context) async {
    final formInit = TaskFormData();
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => TaskForm(
        initial: formInit,
        onSubmit: (data) async {
          await context.read<TodoProvider>().addTodo(
                data.title,
                notes: data.notes,
                dueAt: data.dueDate?.millisecondsSinceEpoch,
                priority: data.priority,
                tags: data.tags,
              );
        },
      ),
    );
  }

  Future<void> _editTaskSheet(BuildContext context, Todo todo) async {
    final formInit = TaskFormData()
      ..title = todo.title
      ..notes = todo.notes
      ..dueDate = todo.dueAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(todo.dueAtMillis!)
          : null
      ..priority = todo.priority
      ..tags = todo.tags;
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => TaskForm(
        initial: formInit,
        onSubmit: (data) async {
          await context.read<TodoProvider>().editTodo(
                todo,
                title: data.title,
                notes: data.notes,
                dueAt: data.dueDate?.millisecondsSinceEpoch,
                priority: data.priority,
                tags: data.tags,
              );
        },
      ),
    );
  }

  void _showUndoSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ลบงานแล้ว'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => context.read<TodoProvider>().undoDelete(),
        ),
      ),
    );
  }

  String _priorityText(int p) =>
      switch (p) { 2 => 'สูง', 1 => 'กลาง', _ => 'ต่ำ' };
  Color _priorityColor(int p) => switch (p) {
        2 => Colors.redAccent,
        1 => Colors.amber,
        _ => Colors.green
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TodoProvider>();
    final fmt = DateFormat('dd MMM');
    final gradient = const LinearGradient(
      colors: [Color(0xFF6FE7DD), Color(0xFF3490DE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          title: _selectionMode
              ? Text('เลือกแล้ว ${_selectedIds.length} รายการ')
              : const Text('🌿 งานของฉัน'),
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF56C596), Color(0xFF3490DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close), onPressed: _exitSelection)
              : null,
          actions: [
            if (_selectionMode)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () async {
                        final items = List<Todo>.from(p.items);
                        for (final t in items) {
                          if (t.id != null && _selectedIds.contains(t.id)) {
                            await p.deleteTodo(t);
                          }
                        }
                        if (mounted) {
                          _exitSelection();
                          _showUndoSnack(context);
                        }
                      },
              )
            else
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: () => _addTaskSheet(context),
              ),
          ],
        ),
        floatingActionButton: !_selectionMode
            ? FloatingActionButton(
                backgroundColor: Colors.teal,
                elevation: 6,
                onPressed: () => _addTaskSheet(context),
                child: const Icon(Icons.add, size: 32),
              )
            : null,
        body: Container(
          padding: const EdgeInsets.all(12),
          child: p.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : p.items.isEmpty
                  ? const Center(
                      child: Text('ยังไม่มีงานในรายการ',
                          style: TextStyle(color: Colors.white, fontSize: 18)))
                  : ListView.builder(
                      itemCount: p.items.length,
                      itemBuilder: (context, i) {
                        final t = p.items[i];
                        final dueStr = t.dueAtMillis != null
                            ? fmt.format(DateTime.fromMillisecondsSinceEpoch(
                                t.dueAtMillis!))
                            : null;
                        final overdue = t.dueAtMillis != null &&
                            !t.isDone &&
                            DateTime.now().millisecondsSinceEpoch >
                                t.dueAtMillis!;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              activeColor: Colors.teal,
                              value: t.isDone,
                              onChanged: (_) => p.toggleDone(t),
                            ),
                            title: Text(
                              t.title,
                              style: TextStyle(
                                color: t.isDone ? Colors.grey : Colors.black87,
                                decoration: t.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (t.notes?.isNotEmpty == true)
                                  Text(t.notes!,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (dueStr != null)
                                      Chip(
                                        label: Text(
                                          overdue
                                              ? '$dueStr (เลยกำหนด)'
                                              : dueStr,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        backgroundColor: overdue
                                            ? Colors.redAccent
                                            : Colors.teal,
                                      ),
                                    const SizedBox(width: 6),
                                    Chip(
                                      label: Text(
                                        'Priority ${_priorityText(t.priority)}',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      backgroundColor:
                                          _priorityColor(t.priority),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.teal),
                              onPressed: () => _editTaskSheet(context, t),
                            ),
                            onLongPress: () => _enterSelection(t),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
