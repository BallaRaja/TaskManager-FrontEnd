import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ai_planner_controller.dart';

class WeekPlannerPage extends StatefulWidget {
  const WeekPlannerPage({super.key});

  @override
  State<WeekPlannerPage> createState() => _WeekPlannerPageState();
}

class _WeekPlannerPageState extends State<WeekPlannerPage>
    with SingleTickerProviderStateMixin {
  final AIPlannerController _planner = AIPlannerController();
  final TextEditingController _promptCtrl = TextEditingController();

  /// Start of the selected week (always a Monday).
  late DateTime _weekStart;
  bool _loading = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = DateTime(now.year, now.month, now.day);
    debugPrint('📍 [WeekPlannerPage] initState: _weekStart=$_weekStart');

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _planner.addListener(_onPlannerUpdate);
    _init();
  }

  Future<void> _init() async {
    debugPrint('📍 [WeekPlannerPage] _init() loading tasks & lists...');
    await _planner.loadTasksAndLists();
    debugPrint('📍 [WeekPlannerPage] _init() done, mounted=$mounted');
    if (mounted) setState(() => _loading = false);
  }

  void _onPlannerUpdate() {
    debugPrint(
      '📍 [WeekPlannerPage] _onPlannerUpdate: isGenerating=${_planner.isGenerating}, tasks=${_planner.generatedTasks.length}, error=${_planner.errorMessage}',
    );
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

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  Future<void> _pickWeekStart() async {
    final now = DateTime.now();
    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 60));
    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 365));

    // Ensure initialDate is clamped within range
    DateTime initial = _weekStart;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Pick the first day of your 7-day plan',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: Colors.deepPurple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      if (normalized != _weekStart) {
        setState(() {
          _weekStart = normalized;
          _planner.clearPlan();
        });
      }
    }
  }

  void _generate() {
    final prompt = _promptCtrl.text.trim();
    debugPrint(
      '📍 [WeekPlannerPage] _generate() prompt="$prompt", weekStart=$_weekStart',
    );
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tell the AI what to plan for your week!'),
        ),
      );
      return;
    }
    _planner.generateWeekPlan(_weekStart, prompt);
  }

  void _confirmUpload() async {
    debugPrint('📍 [WeekPlannerPage] _confirmUpload() called');
    final ok = await _planner.confirmAndUpload();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Week plan added to your list!'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
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
    final startLabel = DateFormat('d MMM').format(_weekStart);
    final endLabel = DateFormat('d MMM yyyy').format(_weekEnd);
    final existingTasks = _planner.tasksForWeek(_weekStart);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Week Planner'),
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
                // ── Week picker ──
                _WeekCard(
                  startLabel: startLabel,
                  endLabel: endLabel,
                  onTap: _pickWeekStart,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // ── Day-by-day existing tasks ──
                _buildExistingWeekView(
                  existingTasks,
                  isDark,
                  startLabel,
                  endLabel,
                ),
                const SizedBox(height: 24),

                // ── Prompt ──
                const _SectionLabel(
                  'What should AI plan for your week?',
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Help me prepare for final exams while staying healthy…',
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
                          : 'Generate Week Plan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

                // ── Generated week plan ──
                if (_planner.generatedTasks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _SectionLabel(
                                'Your Week Plan',
                                icon: Icons.date_range_rounded,
                              ),
                            ),
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
                        _buildGeneratedWeekView(isDark),
                        const SizedBox(height: 20),

                        // ── Confirm button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _planner.isUploading
                                ? null
                                : _confirmUpload,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
     EXISTING TASKS — DAY-BY-DAY VIEW
     ════════════════════════════════════════════════════════════════ */

  Widget _buildExistingWeekView(
    List<Map<String, dynamic>> tasks,
    bool isDark,
    String start,
    String end,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'Existing tasks ($start – $end)',
          icon: Icons.event_note_rounded,
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          _EmptyHint('No tasks this week yet.', isDark: isDark)
        else
          ...List.generate(7, (i) {
            final day = _weekStart.add(Duration(days: i));
            final dayLabel = DateFormat('EEE, d MMM').format(day);
            final dayTasks = tasks.where((t) {
              final d = DateTime.tryParse(t['dueDate'] ?? '')?.toLocal();
              if (d == null) return false;
              return d.year == day.year &&
                  d.month == day.month &&
                  d.day == day.day;
            }).toList();

            if (dayTasks.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple[300],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...dayTasks.map((t) => _MiniTaskTile(t, isDark)),
                ],
              ),
            );
          }),
      ],
    );
  }

  /* ════════════════════════════════════════════════════════════════
     GENERATED TASKS — GROUPED BY DAY
     ════════════════════════════════════════════════════════════════ */

  Widget _buildGeneratedWeekView(bool isDark) {
    // Group by day
    final Map<String, List<MapEntry<int, PlannedTask>>> grouped = {};
    for (int i = 0; i < _planner.generatedTasks.length; i++) {
      final task = _planner.generatedTasks[i];
      final key = DateFormat('EEE, d MMM').format(task.dueDate);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(MapEntry(i, task));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((dayEntry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dayEntry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Tasks for this day
              ...dayEntry.value.map(
                (entry) => _PlannedWeekTaskCard(
                  task: entry.value,
                  index: entry.key,
                  isDark: isDark,
                  onEdit: () => _showEditSheet(entry.key, entry.value),
                  onDelete: () => _planner.removeTask(entry.key),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /* ════════════════════════════════════════════════════════════════
     EDIT BOTTOM SHEET
     ════════════════════════════════════════════════════════════════ */

  void _showEditSheet(int index, PlannedTask task) {
    final titleCtrl = TextEditingController(text: task.title);
    final notesCtrl = TextEditingController(text: task.notes);
    String selectedPriority = task.priority;
    TimeOfDay selectedTime = TimeOfDay(
      hour: task.dueDate.hour,
      minute: task.dueDate.minute,
    );
    DateTime selectedDate = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.deepPurple,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit Task',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date + Priority
                  Row(
                    children: [
                      // Date chip
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: _weekStart,
                              lastDate: _weekEnd,
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            child: Text(
                              DateFormat('EEE, d').format(selectedDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Priority
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPriority,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          items: ['low', 'medium', 'high']
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p[0].toUpperCase() + p.substring(1),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(() => selectedPriority = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Time
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
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: Colors.deepPurple[300],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedTime.format(ctx),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final updated = PlannedTask(
                          title: titleCtrl.text.trim().isEmpty
                              ? task.title
                              : titleCtrl.text.trim(),
                          dueDate: DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          ),
                          priority: selectedPriority,
                          notes: notesCtrl.text.trim(),
                        );
                        _planner.updateTask(index, updated);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

class _WeekCard extends StatelessWidget {
  final String startLabel;
  final String endLabel;
  final VoidCallback onTap;
  final bool isDark;

  const _WeekCard({
    required this.startLabel,
    required this.endLabel,
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
                ? [Colors.deepPurple.shade900, Colors.indigo.shade900]
                : [Colors.deepPurple.shade50, Colors.indigo.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              color: isDark ? Colors.deepPurple[200] : Colors.deepPurple,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '$startLabel  →  $endLabel',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.deepPurple[900],
                ),
              ),
            ),
            Icon(
              Icons.edit_calendar_rounded,
              color: isDark ? Colors.white60 : Colors.deepPurple[300],
              size: 20,
            ),
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
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
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
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

class _MiniTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDark;

  const _MiniTaskTile(this.task, this.isDark);

  @override
  Widget build(BuildContext context) {
    final title = task['title'] ?? 'Untitled';
    final priority = task['priority'] ?? 'medium';
    final isCompleted = task['status'] == 'completed';

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
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : prColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: isCompleted ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedWeekTaskCard extends StatelessWidget {
  final PlannedTask task;
  final int index;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlannedWeekTaskCard({
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Time
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.notes.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          task.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(prIcon, color: prColor, size: 18),
                const SizedBox(width: 2),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.grey[400],
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
}
