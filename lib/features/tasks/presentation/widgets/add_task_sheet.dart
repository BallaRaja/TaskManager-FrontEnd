// lib/features/tasks/presentation/widgets/add_task_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';
import 'package:client/features/calendar/presentation/calendar_controller.dart';

void showAddTaskSheet(BuildContext context) {
  final tasksController = Provider.of<TasksController>(context, listen: false);
  final calendarController = Provider.of<CalendarController>(context, listen: false);

  if (tasksController.taskLists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No task list found. Please create one first."),
      ),
    );
    return;
  }

  // Use the currently selected task list
  final String currentTaskListId =
      tasksController.taskLists[tasksController.selectedListIndex]["_id"] as String;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AddTaskSheet(
          tasksController: tasksController,
          calendarController: calendarController,
          taskListId: currentTaskListId,
        ),
  );
}

class AddTaskSheet extends StatefulWidget {
  final TasksController tasksController;
  final CalendarController calendarController;
  final String taskListId; // The ID of the list to add the task to

  const AddTaskSheet({
    super.key,
    required this.tasksController,
    required this.calendarController,
    required this.taskListId,
  });

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isImportant = false;
  String _repeatFrequency = 'none'; // 'none', 'daily', 'weekly', 'monthly'
  List<String> _repeatDays = []; // For weekly repeat (e.g., ['mon', 'tue'])

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _titleFocus.requestFocus(),
    );
  }

  DateTime? get _fullDueDateTime {
    if (_selectedDate == null) return null;
    final time = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );
  }

  String _formatSelectedDate() {
    if (_selectedDate == null) return 'No date';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${_selectedDate!.day} ${months[_selectedDate!.month - 1]} ${_selectedDate!.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'No time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatRepeat() {
    if (_repeatFrequency == 'none') return 'Does not repeat';
    if (_repeatFrequency == 'daily') return 'Daily';
    if (_repeatFrequency == 'monthly') return 'Monthly';
    if (_repeatFrequency == 'weekly') {
      if (_repeatDays.isEmpty) return 'Weekly';
      final days = _repeatDays
          .map((d) => d.substring(0, 3).toUpperCase())
          .join(', ');
      return 'Weekly on $days';
    }
    return 'Does not repeat';
  }

  void _openDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: Colors.purple),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    if (!mounted) return;
    _showDateOptionsSheet();
  }

  void _showDateOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      Text(
                        _formatSelectedDate(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Set time
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Set time'),
                  trailing: Text(
                    _formatTime(_selectedTime),
                    style: TextStyle(
                      color: _selectedTime != null
                          ? Colors.purple
                          : Colors.grey[600],
                      fontWeight: _selectedTime != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(
                            context,
                          ).colorScheme.copyWith(primary: Colors.purple),
                        ),
                        child: child!,
                      ),
                    );
                    if (time != null) {
                      setState(() => _selectedTime = time);
                      setModalState(() => _selectedTime = time);
                    }
                  },
                ),
                // Repeat
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Repeat'),
                  trailing: Text(
                    _formatRepeat(),
                    style: TextStyle(
                      color: _repeatFrequency != 'none'
                          ? Colors.purple
                          : Colors.grey[600],
                      fontWeight: _repeatFrequency != 'none'
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRepeatSheet();
                  },
                ),
                const Spacer(),
                // Done button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRepeatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDateOptionsSheet();
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Text(
                      'Repeat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _showDateOptionsSheet();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Colors.purple),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Repeat frequency options
                RadioListTile<String>(
                  title: const Text('Does not repeat'),
                  value: 'none',
                  groupValue: _repeatFrequency,
                  activeColor: Colors.purple,
                  onChanged: (val) {
                    setState(() => _repeatFrequency = val!);
                    setModalState(() => _repeatFrequency = val!);
                    _repeatDays.clear();
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Daily'),
                  value: 'daily',
                  groupValue: _repeatFrequency,
                  activeColor: Colors.purple,
                  onChanged: (val) {
                    setState(() => _repeatFrequency = val!);
                    setModalState(() => _repeatFrequency = val!);
                    _repeatDays.clear();
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Weekly'),
                  value: 'weekly',
                  groupValue: _repeatFrequency,
                  activeColor: Colors.purple,
                  onChanged: (val) {
                    setState(() {
                      _repeatFrequency = val!;
                      if (_repeatDays.isEmpty && _selectedDate != null) {
                        final weekday = _selectedDate!.weekday;
                        final days = [
                          'mon',
                          'tue',
                          'wed',
                          'thu',
                          'fri',
                          'sat',
                          'sun',
                        ];
                        _repeatDays = [days[weekday - 1]];
                      } else if (_repeatDays.isEmpty) {
                        _repeatDays = ['mon'];
                      }
                    });
                    setModalState(() {});
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Monthly'),
                  value: 'monthly',
                  groupValue: _repeatFrequency,
                  activeColor: Colors.purple,
                  onChanged: (val) {
                    setState(() => _repeatFrequency = val!);
                    setModalState(() => _repeatFrequency = val!);
                    _repeatDays.clear();
                  },
                ),
                // Weekly days selector
                if (_repeatFrequency == 'weekly') ...[
                  const SizedBox(height: 30),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 16),
                    child: Text(
                      'Repeat on',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ].asMap().entries.map((e) {
                            final dayLower = e.value.toLowerCase().substring(
                              0,
                              3,
                            );
                            final selected = _repeatDays.contains(dayLower);
                            return GestureDetector(
                              onTap: () {
                                if (selected && _repeatDays.length == 1)
                                  return; // prevent deselecting last day
                                setState(() {
                                  selected
                                      ? _repeatDays.remove(dayLower)
                                      : _repeatDays.add(dayLower);
                                });
                                setModalState(() {});
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? Colors.purple
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.purple
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    e.value[0],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Title required")));
      return;
    }

    if (_fullDueDateTime != null &&
        _fullDueDateTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Due time cannot be in the past")),
      );
      return;
    }

    Map<String, dynamic>? repeat;
    if (_repeatFrequency != 'none') {
      repeat = {
        "frequency": _repeatFrequency,
        "interval": 1,
        if (_repeatFrequency == 'weekly' && _repeatDays.isNotEmpty)
          "daysOfWeek": _repeatDays,
      };
    }

    final body = {
      "title": title,
      "taskListId": widget.taskListId, // Now uses the currently selected list
      if (_notesController.text.trim().isNotEmpty)
        "notes": _notesController.text.trim(),
      if (_fullDueDateTime != null)
        // Send as UTC so backend stores a timezone-unambiguous value
        "dueDate": _fullDueDateTime!.toUtc().toIso8601String(),
      "priority": _isImportant ? "high" : "medium",
      if (repeat != null) "repeat": repeat,
    };

    print("📤 Saving task: $body");

    try {
      final createdTask = await widget.tasksController.createTask(body);
      if (mounted) {
        if (createdTask != null) {
          widget.calendarController.upsertTaskLocal(createdTask);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Task created!")));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Failed to create task")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: "New Task",
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: "Add details",
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            Icons.calendar_today,
                            "Add date",
                            _openDatePicker,
                            _selectedDate != null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _actionButton(
                            _isImportant ? Icons.star : Icons.star_border,
                            "Important",
                            () => setState(() => _isImportant = !_isImportant),
                            _isImportant,
                            color: _isImportant ? Colors.amber : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (_selectedDate != null ||
                        _repeatFrequency != 'none' ||
                        _isImportant)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[900]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Summary",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedDate != null)
                              _summaryRow(
                                Icons.calendar_today,
                                "${_formatSelectedDate()} • ${_formatTime(_selectedTime)}",
                                () => setState(() {
                                  _selectedDate = null;
                                  _selectedTime = null;
                                  _repeatFrequency = 'none';
                                  _repeatDays.clear();
                                }),
                              ),
                            if (_repeatFrequency != 'none')
                              _summaryRow(
                                Icons.repeat,
                                _formatRepeat(),
                                () => setState(() {
                                  _repeatFrequency = 'none';
                                  _repeatDays.clear();
                                }),
                              ),
                            if (_isImportant)
                              _summaryRow(
                                Icons.star,
                                "Important",
                                () => setState(() => _isImportant = false),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              // Save button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 25,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    bool active, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active
              ? Colors.purple.withOpacity(0.1)
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.purple : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color ?? (active ? Colors.purple : Colors.grey[600]),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.purple : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }
}
