import 'dart:math' as math;
import 'models.dart';
class TrackPoint {
  final double lat, lon, accuracy;
  final double? altitude;
  final DateTime time;
  final int segment, elapsed;
  const TrackPoint({required this.lat, required this.lon, required this.accuracy, required this.time, required this.segment, required this.elapsed, this.altitude});
  Json toJson() => {'lat': lat, 'lon': lon, 'accuracy': accuracy, 'altitude': altitude, 'time': time.toUtc().toIso8601String(), 'segment': segment, 'elapsed': elapsed};
  factory TrackPoint.fromJson(Json j) => TrackPoint(lat: number(j['lat'])!, lon: number(j['lon'])!, accuracy: number(j['accuracy'])!, altitude: number(j['altitude']), time: DateTime.parse(j['time']), segment: (j['segment'] as num).toInt(), elapsed: (j['elapsed'] as num).toInt());
}
double distanceMeters(double latA, double lonA, double latB, double lonB) {
  const rad = math.pi / 180;
  final dp = (latB - latA) * rad, dl = (lonB - lonA) * rad;
  final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(latA * rad) * math.cos(latB * rad) * math.sin(dl / 2) * math.sin(dl / 2);
  return 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}
class GpsEngine {
  final List<TrackPoint> points;
  double meters;
  TrackPoint? _anchor;
  DateTime? _lastValidRaw;
  int _segment;
  bool _needsBreak;
  String quality = 'In attesa del GPS';
  double? lastAccuracy;
  GpsEngine({List<TrackPoint>? points, this.meters = 0}) : points = points ?? [], _segment = points == null || points.isEmpty ? 0 : points.last.segment + 1, _needsBreak = false;
  void breakSegment() { _anchor = null; _needsBreak = true; _lastValidRaw = null; }
  TrackPoint? add({required double lat, required double lon, required double accuracy, required DateTime timestamp, required DateTime now, required int elapsed, double? speed, double? speedAccuracy, double? altitude, bool mocked = false}) {
    if (mocked) { quality = 'Posizione simulata ignorata'; return null; }
    if (!lat.isFinite || !lon.isFinite || !accuracy.isFinite || lat.abs() > 90 || lon.abs() > 180 || accuracy < 0) { quality = 'Dato GPS non valido'; return null; }
    lastAccuracy = accuracy;
    final age = now.difference(timestamp).inMilliseconds;
    if (age > 15000 || age < -5000) { quality = 'Posizione non aggiornata'; return null; }
    if (_lastValidRaw != null && !timestamp.isAfter(_lastValidRaw!)) return null;
    if (accuracy > 25) { quality = 'Segnale debole · ±${accuracy.round()} m'; return null; }
    final gap = _lastValidRaw != null && timestamp.difference(_lastValidRaw!).inSeconds > 20;
    _lastValidRaw = timestamp;
    if (gap) breakSegment();
    quality = 'GPS · ±${accuracy.round()} m';
    if (_anchor == null) {
      if (_needsBreak && points.isNotEmpty) _segment = points.last.segment + 1;
      _needsBreak = false;
      final point = TrackPoint(lat: lat, lon: lon, accuracy: accuracy, time: timestamp, segment: _segment, elapsed: elapsed, altitude: altitude);
      _anchor = point; points.add(point); _lastValidRaw = timestamp; return point;
    }
    final a = _anchor!;
    final dt = timestamp.difference(a.time).inMilliseconds / 1000;
    if (dt <= 0) return null;
    final distance = distanceMeters(a.lat, a.lon, lat, lon);
    if (distance / dt > 14 || (speed != null && speed.isFinite && speed > 14)) { quality = 'Salto GPS ignorato'; breakSegment(); return null; }
    final hasReliableSpeed = speed != null && speed.isFinite && speed >= 0 && speedAccuracy != null && speedAccuracy >= 0 && speedAccuracy <= 1.5;
    if (hasReliableSpeed && speed < 0.45) { quality = 'GPS stabile · fermo'; return null; }
    final threshold = math.max(3.0, math.min(8.0, (a.accuracy + accuracy) * 0.25));
    if (distance < threshold) return null;
    if (!hasReliableSpeed && dt > 15 && distance / dt < 0.6) { breakSegment(); return null; }
    final point = TrackPoint(lat: lat, lon: lon, accuracy: accuracy, time: timestamp, segment: _segment, elapsed: elapsed, altitude: altitude);
    meters += distance; _anchor = point; points.add(point); return point;
  }
}
class RunRecord {
  final String id, mode;
  final DateTime started;
  DateTime? ended;
  String status;
  double meters;
  int elapsed;
  List<TrackPoint> points;
  RunRecord({String? id, required this.mode, DateTime? started, this.ended, this.status = 'recording', this.meters = 0, this.elapsed = 0, List<TrackPoint>? points}) : id = id ?? uid(), started = started ?? DateTime.now(), points = points ?? [];
  String get label => mode == 'run' ? 'Corsa' : 'Camminata';
  Json toJson({bool includePoints = true}) => {'id': id, 'mode': mode, 'started': started.toIso8601String(), 'ended': ended?.toIso8601String(), 'status': status, 'meters': meters, 'elapsed': elapsed, if (includePoints) 'points': points.map((p) => p.toJson()).toList()};
  factory RunRecord.fromJson(Json j) => RunRecord(id: j['id'], mode: j['mode'], started: DateTime.parse(j['started']), ended: DateTime.tryParse('${j['ended']}'), status: j['status'], meters: number(j['meters']) ?? 0, elapsed: (j['elapsed'] as num? ?? 0).toInt(), points: (j['points'] as List? ?? []).map((p) => TrackPoint.fromJson(asMap(p))).toList());
}
class KilometerSplit {
  final int kilometer, seconds;
  const KilometerSplit(this.kilometer, this.seconds);
}
List<KilometerSplit> kilometerSplits(List<TrackPoint> points) {
  final result = <KilometerSplit>[];
  double meters = 0, previousCrossing = 0;
  int next = 1;
  for (int i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    if (a.segment != b.segment) continue;
    final d = distanceMeters(a.lat, a.lon, b.lat, b.lon);
    if (d <= 0) continue;
    while (meters + d >= next * 1000) {
      final fraction = (next * 1000 - meters) / d;
      final crossing = a.elapsed + (b.elapsed - a.elapsed) * fraction;
      result.add(KilometerSplit(next, (crossing - previousCrossing).round())); previousCrossing = crossing; next++;
    }
    meters += d;
  }
  return result;
}
String xmlEscape(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
String toGpx(RunRecord run) {
  final out = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<gpx version="1.1" creator="Zoro Forge" xmlns="http://www.topografix.com/GPX/1/1">\n<metadata><time>${run.started.toUtc().toIso8601String()}</time></metadata>\n<trk><name>${xmlEscape(run.label)} ${xmlEscape(localDate(run.started))}</name>');
  int? segment;
  for (final p in run.points) {
    if (segment != p.segment) { if (segment != null) out.write('</trkseg>'); out.write('<trkseg>'); segment = p.segment; }
    out.write('<trkpt lat="${p.lat.toStringAsFixed(7)}" lon="${p.lon.toStringAsFixed(7)}">');
    if (p.altitude != null && p.altitude!.isFinite) out.write('<ele>${p.altitude!.toStringAsFixed(1)}</ele>');
    out.write('<time>${p.time.toUtc().toIso8601String()}</time></trkpt>\n');
  }
  if (segment != null) out.write('</trkseg>');
  out.write('</trk></gpx>'); return out.toString();
}
