// lib/features/tasks/presentation/widgets/edit_task_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';
import 'package:client/features/calendar/presentation/calendar_controller.dart';

void showEditTaskSheet(BuildContext context, Map<String, dynamic> task) {
  final tasksController = Provider.of<TasksController>(context, listen: false);
  final calendarController = Provider.of<CalendarController>(context, listen: false);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditTaskSheet(
      tasksController: tasksController,
      calendarController: calendarController,
      task: task,
    ),
  );
}

class EditTaskSheet extends StatefulWidget {
  final TasksController tasksController;
  final CalendarController calendarController;
  final Map<String, dynamic> task;

  const EditTaskSheet({
    super.key,
    required this.tasksController,
    required this.calendarController,
    required this.task,
  });

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  final FocusNode _titleFocus = FocusNode();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isImportant = false;
  String _repeatFrequency = 'none';
  List<String> _repeatDays = [];

  @override
  void initState() {
    super.initState();

    // Pre-fill title + notes
    _titleController = TextEditingController(
      text: widget.task['title'] as String? ?? '',
    );
    _notesController = TextEditingController(
      text: widget.task['notes'] as String? ?? '',
    );

    // Pre-fill due date + time
    // Always convert UTC from backend → device local time before using
    final dueDateStr = widget.task['dueDate'] as String?;
    if (dueDateStr != null) {
      final parsed = DateTime.tryParse(dueDateStr)?.toLocal();
      if (parsed != null) {
        _selectedDate = DateTime(parsed.year, parsed.month, parsed.day);
        _selectedTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }

    // Pre-fill priority
    _isImportant = widget.task['priority'] == 'high';

    // Pre-fill repeat
    final repeat = widget.task['repeat'] as Map<String, dynamic>?;
    if (repeat != null) {
      _repeatFrequency = (repeat['frequency'] as String?) ?? 'none';
      final days = repeat['daysOfWeek'];
      if (days != null) {
        _repeatDays = List<String>.from(days as List);
      }
    }
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
      firstDate: DateTime(2000),
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
                        const days = [
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
                                if (selected && _repeatDays.length == 1) return;
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
                  const SizedBox(height: 40),
                ],
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
      ).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }

    Map<String, dynamic>? repeat;
    if (_repeatFrequency != 'none') {
      repeat = {
        'frequency': _repeatFrequency,
        'interval': 1,
        if (_repeatFrequency == 'weekly' && _repeatDays.isNotEmpty)
          'daysOfWeek': _repeatDays,
      };
    }

    final body = <String, dynamic>{
      'title': title,
      'notes': _notesController.text.trim(),
      'priority': _isImportant ? 'high' : 'medium',
      if (_fullDueDateTime != null)
        // Send as UTC so backend stores a timezone-unambiguous value
        'dueDate': _fullDueDateTime!.toUtc().toIso8601String()
      else
        'dueDate': null,
      'repeat': repeat,
    };

    final taskId = widget.task['_id'].toString();
    final updated = await widget.tasksController.updateTask(taskId, body);

    if (!mounted) return;
    if (updated != null) {
      widget.calendarController.upsertTaskLocal(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task updated!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update task')));
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
              // Header row with title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Edit Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
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
                        hintText: 'Task title',
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Add details',
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
                            'Date & Time',
                            _openDatePicker,
                            _selectedDate != null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _actionButton(
                            _isImportant ? Icons.star : Icons.star_border,
                            'Important',
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
                              'Summary',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedDate != null)
                              _summaryRow(
                                Icons.calendar_today,
                                '${_formatSelectedDate()} • ${_formatTime(_selectedTime)}',
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
                                'Important',
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
                      horizontal: 28,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
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
