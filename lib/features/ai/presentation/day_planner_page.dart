import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai_planner_controller.dart';

class DayPlannerPage extends StatefulWidget {
  const DayPlannerPage({super.key});

  @override
  State<DayPlannerPage> createState() => _DayPlannerPageState();
}

class _DayPlannerPageState extends State<DayPlannerPage>
    with SingleTickerProviderStateMixin {
  final AIPlannerController _planner = AIPlannerController();
  final TextEditingController _promptCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _planner.addListener(_onPlannerUpdate);
    _init();
  }

  Future<void> _init() async {
    await _planner.loadTasksAndLists();
    if (mounted) setState(() => _loading = false);
  }

  void _onPlannerUpdate() {
    if (mounted) setState(() {});
    if (_planner.generatedTasks.isNotEmpty) _fadeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _planner.removeListener(_onPlannerUpdate);
    _planner.dispose();
    _promptCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: Colors.deepPurple,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _planner.clearPlan();
      });
    }
  }

  void _generate() {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tell the AI what to plan for you!')),
      );
      return;
    }
    _planner.generateDayPlan(_selectedDate, prompt);
  }

  void _confirmUpload() async {
    final ok = await _planner.confirmAndUpload();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('All tasks added to your list!'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true); // true = refresh parent
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Some tasks failed to upload. Try again.'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /* ════════════════════════════════════════════════════════════════
     BUILD
     ════════════════════════════════════════════════════════════════ */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(_selectedDate);
    final existingTasks = _planner.tasksForDate(_selectedDate);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Day Planner'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Date picker ──
                _DateCard(
                  label: dateLabel,
                  onTap: _pickDate,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // ── Existing tasks ──
                _SectionLabel(
                  'Existing tasks on $dateLabel',
                  icon: Icons.event_note_rounded,
                ),
                const SizedBox(height: 8),
                if (existingTasks.isEmpty)
                  _EmptyHint('No tasks on this day yet.', isDark: isDark)
                else
                  ...existingTasks.map((t) => _ExistingTaskTile(t, isDark)),
                const SizedBox(height: 24),

                // ── Prompt ──
                _SectionLabel(
                  'What should AI plan for you?',
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Plan a productive study day for my math exam…',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Generate button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _planner.isGenerating ? null : _generate,
                    icon: _planner.isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 20),
                    label: Text(
                      _planner.isGenerating
                          ? 'Generating…'
                          : 'Generate Day Plan',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

                // ── Error ──
                if (_planner.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _planner.errorMessage!,
                    style: TextStyle(color: Colors.red[400], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],

                // ── Generated tasks ──
                if (_planner.generatedTasks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _SectionLabel(
                              'Your Day Plan',
                              icon: Icons.wb_sunny_rounded,
                            ),
                            const Spacer(),
                            Text(
                              '${_planner.generatedTasks.length} tasks',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._planner.generatedTasks
                            .asMap()
                            .entries
                            .map(
                              (entry) => _PlannedTaskCard(
                                task: entry.value,
                                index: entry.key,
                                isDark: isDark,
                                onEdit: () =>
                                    _showEditSheet(entry.key, entry.value),
                                onDelete: () {
                                  _planner.removeTask(entry.key);
                                },
                              ),
                            ),
                        const SizedBox(height: 20),

                        // ── Confirm button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed:
                                _planner.isUploading ? null : _confirmUpload,
                            icon: _planner.isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 22),
                            label: Text(
                              _planner.isUploading
                                  ? 'Uploading…'
                                  : 'Confirm & Add All Tasks',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  /* ════════════════════════════════════════════════════════════════
     EDIT BOTTOM SHEET
     ════════════════════════════════════════════════════════════════ */

  void _showEditSheet(int index, PlannedTask task) {
    final titleCtrl = TextEditingController(text: task.title);
    final notesCtrl = TextEditingController(text: task.notes);
    String selectedPriority = task.priority;
    TimeOfDay selectedTime =
        TimeOfDay(hour: task.dueDate.hour, minute: task.dueDate.minute);

    Color _priorityColor(String p) {
      switch (p) {
        case 'high':
          return Colors.red[400]!;
        case 'low':
          return Colors.green[400]!;
        default:
          return Colors.orange[400]!;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.deepPurple, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Task',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[500]),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Title
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Task title',
                      prefixIcon: const Icon(Icons.title_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Colors.deepPurple, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.notes_rounded, size: 20),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Colors.deepPurple, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Priority chips
                  const Text('Priority',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: ['low', 'medium', 'high'].map((p) {
                      final isSelected = selectedPriority == p;
                      final color = _priorityColor(p);
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: p != 'high' ? 10 : 0),
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() => selectedPriority = p);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withOpacity(0.15)
                                    : isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : isDark
                                          ? Colors.white12
                                          : Colors.grey[300]!,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    p == 'high'
                                        ? Icons
                                            .keyboard_double_arrow_up_rounded
                                        : p == 'low'
                                            ? Icons
                                                .keyboard_arrow_down_rounded
                                            : Icons.remove_rounded,
                                    color: isSelected
                                        ? color
                                        : Colors.grey[500],
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p[0].toUpperCase() + p.substring(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? color
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Time picker
                  const Text('Time',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              color: Colors.deepPurple[300], size: 22),
                          const SizedBox(width: 12),
                          Text(
                            selectedTime.format(ctx),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey[400], size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final updated = PlannedTask(
                          title: titleCtrl.text.trim().isEmpty
                              ? task.title
                              : titleCtrl.text.trim(),
                          dueDate: DateTime(
                            task.dueDate.year,
                            task.dueDate.month,
                            task.dueDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          ),
                          priority: selectedPriority,
                          notes: notesCtrl.text.trim(),
                        );
                        _planner.updateTask(index, updated);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ══════════════════════════════════════════════════════════════════
   REUSABLE WIDGETS
   ══════════════════════════════════════════════════════════════════ */

class _DateCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _DateCard({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.deepPurple.shade900, Colors.deepPurple.shade800]
                : [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: isDark ? Colors.deepPurple[200] : Colors.deepPurple,
                size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.deepPurple[900],
                ),
              ),
            ),
            Icon(Icons.edit_calendar_rounded,
                color: isDark ? Colors.white60 : Colors.deepPurple[300],
                size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _SectionLabel(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.deepPurple),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  final bool isDark;

  const _EmptyHint(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(text,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

class _ExistingTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDark;

  const _ExistingTaskTile(this.task, this.isDark);

  @override
  Widget build(BuildContext context) {
    final title = task['title'] ?? 'Untitled';
    final status = task['status'] ?? 'pending';
    final priority = task['priority'] ?? 'medium';
    final isCompleted = status == 'completed';

    Color prColor;
    switch (priority) {
      case 'high':
        prColor = Colors.red[400]!;
        break;
      case 'low':
        prColor = Colors.green[400]!;
        break;
      default:
        prColor = Colors.orange[400]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : prColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: isCompleted ? Colors.grey : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: prColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              priority,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: prColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedTaskCard extends StatelessWidget {
  final PlannedTask task;
  final int index;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlannedTaskCard({
    required this.task,
    required this.index,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(task.dueDate);

    Color prColor;
    IconData prIcon;
    switch (task.priority) {
      case 'high':
        prColor = Colors.red[400]!;
        prIcon = Icons.keyboard_double_arrow_up_rounded;
        break;
      case 'low':
        prColor = Colors.green[400]!;
        prIcon = Icons.keyboard_arrow_down_rounded;
        break;
      default:
        prColor = Colors.orange[400]!;
        prIcon = Icons.remove_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Time chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
                // Priority badge
                Icon(prIcon, color: prColor, size: 20),
                const SizedBox(width: 4),
                // Delete
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.grey[400]),
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
