import 'dart:convert';
import 'dart:math' as math;
typedef Json = Map<String, dynamic>;
Json asMap(dynamic value) => Map<String, dynamic>.from(value as Map);
double? number(dynamic value) {
  if (value == null || value == '') return null;
  final result = value is num ? value.toDouble() : double.tryParse('$value'.replaceAll(',', '.'));
  return result != null && result.isFinite ? result : null;
}
String uid() => '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 30)}';
String decimal(num n, [int digits = 1]) => n.toStringAsFixed(digits).replaceAll('.', ',');
String clock(int seconds) {
  final s = math.max(0, seconds);
  return s >= 3600 ? '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
String pace(double meters, int seconds) {
  if (meters < 30 || seconds <= 0) return '—';
  final sec = (seconds * 1000 / meters).round();
  return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}
String localDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String dayKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
class Exercise {
  final String id, name, group, equipment, load, unit, cue, tempo;
  final int sets, min, max, rest;
  final bool perSide;
  final List<String> steps, errors, alternatives;
  final List<Json> videos;
  Exercise(this.id, Json j)
      : name = j['name'] as String, group = j['group'] as String,
        equipment = j['equipment'] as String, load = j['load'] as String,
        unit = (j['unit'] ?? 'rep') as String, cue = j['cue'] as String,
        tempo = j['tempo'] as String, sets = j['sets'] as int,
        min = j['min'] as int, max = j['max'] as int, rest = j['rest'] as int,
        perSide = j['perSide'] == true,
        steps = List<String>.from(j['steps']), errors = List<String>.from(j['errors']),
        alternatives = List<String>.from(j['alt']),
        videos = (j['videos'] as List? ?? []).map(asMap).toList();
  bool get timed => unit != 'rep';
  bool get hasLoad => load != 'none';
  bool get needsLoad => load == 'machine' || load == 'each';
  String get loadLabel => load == 'each' ? 'kg per manubrio' : load == 'optional' ? 'kg aggiunti' : 'kg macchina';
  String get unitLabel => unit == 'sec' ? 'secondi' : unit == 'min' ? 'minuti' : 'ripetizioni';
  String get target => '${min == max ? '$min' : '$min–$max'} ${unit == 'rep' ? 'rip.' : unit}${perSide ? ' per lato' : ''}';
}
class Catalog {
  final Map<String, Exercise> exercises;
  final Map<String, Json> programs;
  final List<Json> phases;
  Catalog(Json j)
      : exercises = asMap(j['exercises']).map((k, v) => MapEntry(k, Exercise(k, asMap(v)))),
        programs = asMap(j['programs']).map((k, v) => MapEntry(k, asMap(v))),
        phases = (j['phases'] as List).map(asMap).toList();
  factory Catalog.decode(String text) => Catalog(asMap(jsonDecode(text)));
}
class Profile {
  double height, initialWeight, targetWeight;
  int phase;
  DateTime started;
  List<int> weekdays;
  bool mapTiles;
  Profile({this.height = 0, this.initialWeight = 0, this.targetWeight = 0,
    this.phase = 0, DateTime? started, List<int>? weekdays, this.mapTiles = true})
      : started = started ?? DateTime.now(), weekdays = weekdays ?? [1, 4];
  factory Profile.fromJson(Json j) => Profile(
    height: number(j['height']) ?? 0, initialWeight: number(j['initialWeight']) ?? 0,
    targetWeight: number(j['targetWeight']) ?? 0, phase: (j['phase'] as num? ?? 0).toInt().clamp(0, 2).toInt(),
    started: DateTime.tryParse('${j['started']}'),
    weekdays: (j['weekdays'] as List? ?? [1, 4]).map((v) => (v as num).toInt()).where((v) => v >= 1 && v <= 7).toSet().toList()..sort(),
    mapTiles: j['mapTiles'] != false,
  );
  Json toJson() => {'height': height, 'initialWeight': initialWeight, 'targetWeight': targetWeight,
    'phase': phase, 'started': started.toIso8601String(), 'weekdays': weekdays, 'mapTiles': mapTiles};
}
class SetLog {
  final String id;
  double? kg;
  int? value, rir;
  DateTime? completed;
  SetLog({String? id, this.kg, this.value, this.rir, this.completed}) : id = id ?? uid();
  bool get done => completed != null;
  String? validate(Exercise ex) {
    if (value == null || value! <= 0 || value! > (ex.timed ? 18000 : 500)) return 'Inserisci ${ex.unitLabel} effettivi validi.';
    if (ex.needsLoad && (kg == null || kg! <= 0)) return 'Inserisci il carico realmente utilizzato.';
    if (kg != null && (!kg!.isFinite || kg! < 0 || kg! > 1000)) return 'Carico non valido.';
    if (rir != null && (rir! < 0 || rir! > 10)) return 'Il margine deve essere fra 0 e 10.';
    return null;
  }
  factory SetLog.fromJson(Json j) => SetLog(id: j['id'] as String,
    kg: number(j['kg']), value: (j['value'] as num?)?.toInt(), rir: (j['rir'] as num?)?.toInt(),
    completed: DateTime.tryParse('${j['completed']}'));
  Json toJson() => {'id': id, 'kg': kg, 'value': value, 'rir': rir, 'completed': completed?.toIso8601String()};
}
class ExerciseLog {
  String exerciseId;
  final String id;
  List<SetLog> sets;
  bool skipped, technique;
  String note;
  int rest;
  ExerciseLog({required this.exerciseId, required this.sets, required this.rest,
    String? id, this.skipped = false, this.technique = false, this.note = ''}) : id = id ?? uid();
  int get doneCount => sets.where((s) => s.done).length;
  bool get complete => !skipped && sets.isNotEmpty && sets.every((s) => s.done);
  factory ExerciseLog.fromJson(Json j) => ExerciseLog(id: j['id'] as String,
    exerciseId: j['exerciseId'] as String, rest: (j['rest'] as num).toInt(),
    sets: (j['sets'] as List).map((s) => SetLog.fromJson(asMap(s))).toList(),
    skipped: j['skipped'] == true, technique: j['technique'] == true, note: '${j['note'] ?? ''}');
  Json toJson() => {'id': id, 'exerciseId': exerciseId, 'rest': rest,
    'sets': sets.map((s) => s.toJson()).toList(), 'skipped': skipped, 'technique': technique, 'note': note};
}
class Workout {
  final String id, program;
  final DateTime started;
  final int phase;
  DateTime? ended;
  List<ExerciseLog> exercises;
  String note;
  int selected;
  Workout({String? id, required this.program, required this.phase, DateTime? started,
    this.ended, required this.exercises, this.note = '', this.selected = 0})
      : id = id ?? uid(), started = started ?? DateTime.now();
  int get doneCount => exercises.fold(0, (n, e) => n + e.doneCount);
  int get totalCount => exercises.fold(0, (n, e) => n + e.sets.length);
  bool get complete => exercises.isNotEmpty && exercises.every((e) => e.complete);
  bool get strength => ['A', 'B', 'C'].contains(program);
  factory Workout.fromJson(Json j) => Workout(id: j['id'] as String, program: j['program'] as String,
    phase: (j['phase'] as num).toInt(), started: DateTime.parse(j['started'] as String),
    ended: DateTime.tryParse('${j['ended']}'), note: '${j['note'] ?? ''}',
    selected: (j['selected'] as num? ?? 0).toInt(),
    exercises: (j['exercises'] as List).map((e) => ExerciseLog.fromJson(asMap(e))).toList());
  Json toJson() => {'id': id, 'program': program, 'phase': phase,
    'started': started.toIso8601String(), 'ended': ended?.toIso8601String(), 'note': note, 'selected': selected,
    'exercises': exercises.map((e) => e.toJson()).toList()};
}
bool canProgress(Exercise ex, List<ExerciseLog> newestFirst, int requiredSets) {
  if (!ex.hasLoad || ex.timed || newestFirst.length < 2 || requiredSets < 1) return false;
  double? reference;
  for (final log in newestFirst.take(2)) {
    if (!log.complete || !log.technique || log.sets.length != requiredSets) return false;
    for (final set in log.sets) {
      if ((set.value ?? 0) < ex.max || (set.rir ?? -1) < 2 || (set.kg ?? 0) <= 0) return false;
      reference ??= set.kg!;
      if ((set.kg! - reference).abs() > 0.001) return false;
    }
  }
  return true;
}
class Measurement {
  final String id;
  final DateTime date;
  final double? weight, waist;
  Measurement({String? id, required this.date, this.weight, this.waist}) : id = id ?? uid();
  factory Measurement.fromJson(Json j) => Measurement(id: j['id'] as String,
    date: DateTime.parse(j['date'] as String), weight: number(j['weight']), waist: number(j['waist']));
  Json toJson() => {'id': id, 'date': date.toIso8601String(), 'weight': weight, 'waist': waist};
}
String? youtubeId(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || uri.scheme != 'https') return null;
  String? id;
  if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) id = uri.pathSegments.first;
  if (['youtube.com', 'www.youtube.com', 'm.youtube.com', 'www.youtube-nocookie.com'].contains(uri.host)) {
    id = uri.queryParameters['v'];
    if (id == null && uri.pathSegments.length >= 2 && ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)) id = uri.pathSegments[1];
  }
  return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}
