// lib/features/tasks/presentation/widgets/add_task_sheet.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';
import 'package:client/features/calendar/presentation/calendar_controller.dart';
import 'package:client/core/services/notification_service.dart';

void showAddTaskSheet(BuildContext context) {
  final tasksController = Provider.of<TasksController>(context, listen: false);
  final calendarController = Provider.of<CalendarController>(
    context,
    listen: false,
  );

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
      tasksController.taskLists[tasksController.selectedListIndex]["_id"]
          as String;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTaskSheet(
      tasksController: tasksController,
      calendarController: calendarController,
      taskListId: currentTaskListId,
      pageContext: context, // ← pass the page context for success dialog
    ),
  );
}

class AddTaskSheet extends StatefulWidget {
  final TasksController tasksController;
  final CalendarController calendarController;
  final String taskListId;
  final BuildContext pageContext; // Parent page context for success dialog

  const AddTaskSheet({
    super.key,
    required this.tasksController,
    required this.calendarController,
    required this.taskListId,
    required this.pageContext,
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
      if (!mounted) return;

      if (createdTask != null) {
        final bool isOffline = createdTask['_offline'] == true;

        widget.calendarController.upsertTaskLocal(createdTask);

        // Schedule 2-min reminder if task has a due date/time (online only)
        if (!isOffline && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await NotificationService().scheduleTaskReminder(createdTask);
        }

        // Close sheet first, then show success popup using the page context
        if (mounted) Navigator.pop(context);

        if (isOffline) {
          _showOfflineQueuedDialog(widget.pageContext, createdTask);
        } else {
          _showTaskCreatedDialog(widget.pageContext, createdTask);
        }
      } else {
        // ❌ FAILURE — keep sheet open, show error dialog
        _showErrorDialog(context, "Failed to create task. Please try again.");
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context, "Something went wrong: $e");
      }
    }
  }

  void _showTaskCreatedDialog(
    BuildContext ctx,
    Map<String, dynamic> createdTask,
  ) {
    final String title = createdTask['title'] ?? 'Task';
    final String? dueIso = createdTask['dueDate'];
    String dueLabel = 'No due date';
    if (dueIso != null) {
      final dt = DateTime.parse(dueIso).toLocal();
      final h = dt.hour == 0
          ? 12
          : dt.hour > 12
          ? dt.hour - 12
          : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      final p = dt.hour < 12 ? 'AM' : 'PM';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dueLabel = '${dt.day} ${months[dt.month - 1]} ${dt.year}  •  $h:$m:$s $p';
    }

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.purple,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Task Created!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.task_alt,
                        size: 16,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dueLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (dueIso != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 14,
                    color: Colors.purple[300],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reminder set for 2 min before',
                    style: TextStyle(fontSize: 12, color: Colors.purple[400]),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Great!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineQueuedDialog(
    BuildContext ctx,
    Map<String, dynamic> task,
  ) {
    final String title = task['title'] ?? 'Task';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Saved Offline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re offline. "$title" has been saved locally and will sync automatically when you\'re back online.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Will sync when connected',
                      style:
                          TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext ctx, String message) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK', style: TextStyle(color: Colors.purple)),
          ),
        ],
      ),
    );
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
