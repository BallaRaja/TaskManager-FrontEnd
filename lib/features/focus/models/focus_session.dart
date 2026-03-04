class FocusSession {
  final String id;
  final String taskId;
  final int duration; // in minutes
  final String date; // "YYYY-MM-DD"

  FocusSession({
    required this.id,
    required this.taskId,
    required this.duration,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'taskId': taskId,
    'duration': duration,
    'date': date,
  };

  factory FocusSession.fromMap(Map<String, dynamic> map) => FocusSession(
    id: map['_id'] ?? '',
    taskId: map['taskId'] ?? '',
    duration: map['duration'] ?? 25,
    date: map['date'] ?? '',
  );
}
