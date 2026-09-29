part of 'app.dart';
class Repository {
  final Database db;
  Repository(this.db);
  static Future<Repository> open() async {
    final db = await openDatabase(path.join(await getDatabasesPath(), 'zoro_forge_v2.sqlite'), version: 1,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE documents(kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(kind,id))');
        await db.execute('CREATE TABLE run_points(run_id TEXT NOT NULL, seq INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(run_id,seq))');
      });
    return Repository(db);
  }
  Future<Json?> one(String kind, String id) async {
    final rows = await db.query('documents', where: 'kind=? AND id=?', whereArgs: [kind, id], limit: 1);
    return rows.isEmpty ? null : asMap(jsonDecode(rows.first['payload'] as String));
  }
  Future<List<Json>> all(String kind) async {
    final rows = await db.query('documents', where: 'kind=?', whereArgs: [kind]);
    return rows.map((r) => asMap(jsonDecode(r['payload'] as String))).toList();
  }
  Future<void> put(String kind, String id, Json value) => db.insert('documents', {'kind': kind, 'id': id, 'payload': jsonEncode(value)}, conflictAlgorithm: ConflictAlgorithm.replace).then((_) {});
  Future<void> remove(String kind, String id) async { await db.delete('documents', where: 'kind=? AND id=?', whereArgs: [kind, id]); }
  Future<void> finishWorkout(Workout w) async {
    await db.transaction((txn) async {
      await txn.insert('documents', {'kind':'workout','id':w.id,'payload':jsonEncode(w.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('documents', where:'kind=? AND id=?', whereArgs:['draft','workout']);
    });
  }
  Future<void> checkpointRun(RunRecord run, int from) async {
    final summary = jsonEncode(run.toJson(includePoints: false));
    final entries = run.points.skip(from).map((p) => jsonEncode(p.toJson())).toList();
    await db.transaction((txn) async {
      await txn.insert('documents', {'kind':'run', 'id': run.id, 'payload': summary}, conflictAlgorithm: ConflictAlgorithm.replace);
      final batch = txn.batch();
      for (var i = 0; i < entries.length; i++) { batch.insert('run_points', {'run_id':run.id,'seq':from+i,'payload':entries[i]}, conflictAlgorithm: ConflictAlgorithm.replace); }
      await batch.commit(noResult: true);
    });
  }
  Future<List<TrackPoint>> points(String id) async => (await db.query('run_points', where:'run_id=?', whereArgs:[id], orderBy:'seq ASC')).map((r) => TrackPoint.fromJson(asMap(jsonDecode(r['payload'] as String)))).toList();
  Future<void> deleteRun(String id) async {
    await db.transaction((txn) async { await txn.delete('documents',where:'kind=? AND id=?',whereArgs:['run',id]); await txn.delete('run_points',where:'run_id=?',whereArgs:[id]); });
  }
  Future<Json> backup() async {
    final documents = await db.query('documents'); final points = await db.query('run_points'); final portable = <Json>[];
    for (final r in documents) {
      final data = asMap(jsonDecode(r['payload'] as String));
      if (r['kind'] == 'timer' || (r['kind'] == 'media' && data['type'] == 'file')) continue;
      portable.add({'kind':r['kind'],'id':r['id'],'data':data});
    }
    return {'format':'zoro-forge-flutter','version':2,'created':DateTime.now().toUtc().toIso8601String(), 'documents':portable,'points':points.map((r) => {'run_id':r['run_id'],'seq':r['seq'],'data':jsonDecode(r['payload'] as String)}).toList()};
  }
  static void validateBackup(Json j, Catalog catalog) {
    if (j['format'] != 'zoro-forge-flutter' || j['version'] != 2) throw const FormatException('Questo non è un backup Flutter v2.');
    final docs = j['documents']; final pts = j['points'];
    if (docs is! List || pts is! List || docs.length > 20000 || pts.length > 500000) throw const FormatException('Archivio troppo grande o non valido.');
    final keys = <String>{}, runIds = <String>{}; var unfinishedRuns=0;
    for (final raw in docs) {
      final r=asMap(raw); final kind=r['kind'], id=r['id']; final d=asMap(r['data']);
      if (!['profile','workout','draft','measurement','run','media'].contains(kind) || id is! String || id.length > 200) throw const FormatException('Record non valido.');
      if (!keys.add('$kind/$id')) throw const FormatException('Record duplicato.');
      if (kind == 'workout' || kind == 'draft') {
        final w=Workout.fromJson(d);
        if (!catalog.programs.containsKey(w.program) || w.exercises.isEmpty || w.exercises.length>100) throw const FormatException('Seduta non valida.');
        for(final e in w.exercises) {
          if (!catalog.exercises.containsKey(e.exerciseId) || e.sets.length>50 || e.rest<0 || e.rest>3600) throw const FormatException('Esercizio non valido.');
          for(final s in e.sets) { if(s.done && s.validate(catalog.exercises[e.exerciseId]!)!=null) throw const FormatException('Serie completata non valida.'); }
        }
      }
      if (kind == 'profile' && id != 'main') throw const FormatException('ID profilo non valido.');
      if (kind == 'draft' && id != 'workout') throw const FormatException('ID bozza non valido.');
      if (['workout','measurement','run'].contains(kind) && d['id'] != id) throw const FormatException('ID record incoerente.');
      if (kind == 'profile') {
        final p=Profile.fromJson(d);
        if ((p.height!=0 && (p.height<100 || p.height>230)) || (p.initialWeight!=0 && (p.initialWeight<30 || p.initialWeight>400)) || (p.targetWeight!=0 && (p.targetWeight<30 || p.targetWeight>400))) throw const FormatException('Profilo non valido.');
      }
      if (kind == 'measurement') {
        final m=Measurement.fromJson(d);
        if(m.weight != null && (m.weight!<30 || m.weight!>400)) throw const FormatException('Peso non valido.');
        if(m.waist != null && (m.waist!<30 || m.waist!>250)) throw const FormatException('Girovita non valido.');
      }
      if (kind == 'run') {
        final run=RunRecord.fromJson(d); runIds.add(id);
        if(run.status!='finished' && ++unfinishedRuns>1)throw const FormatException('Il backup contiene più attività GPS non concluse.');
        if (!['run','walk'].contains(run.mode) || !run.meters.isFinite || run.meters<0 || run.elapsed<0) throw const FormatException('Attività non valida.');
      }
      if (kind == 'media' && (!catalog.exercises.containsKey(id) || !['youtube','mp4','external'].contains(d['type']) || !_safeHttps('${d['url']}'))) throw const FormatException('Riferimento video non valido.');
    }
    final pointKeys=<String>{};final sequences=<String,List<int>>{};
    for(final raw in pts) {
      final p=asMap(raw);
      if(!runIds.contains(p['run_id']) || p['seq'] is! int || (p['seq'] as int)<0 || !pointKeys.add('${p['run_id']}/${p['seq']}')) throw const FormatException('Traccia non valida.');
      sequences.putIfAbsent(p['run_id'] as String,()=>[]).add(p['seq'] as int);
      final v=TrackPoint.fromJson(asMap(p['data']));
      if(!v.lat.isFinite || !v.lon.isFinite || v.lat.abs()>90 || v.lon.abs()>180 || !v.accuracy.isFinite || v.accuracy<0 || v.elapsed<0 || v.segment<0) throw const FormatException('Coordinate non valide.');
    }
    for(final sequence in sequences.values){ sequence.sort(); for(var i=0;i<sequence.length;i++){ if(sequence[i]!=i)throw const FormatException('Sequenza di coordinate incompleta.'); } }
  }
  Future<void> restore(Json backup) async {
    await db.transaction((txn) async {
      await txn.delete('documents'); await txn.delete('run_points'); final batch=txn.batch();
      for(final raw in backup['documents'] as List) {
        final r=asMap(raw); final data=asMap(r['data']);
        if(r['kind']=='run' && data['status']!='finished') data['status']='interrupted';
        batch.insert('documents', {'kind':r['kind'],'id':r['id'],'payload':jsonEncode(data)});
      }
      for(final raw in backup['points'] as List) { final p=asMap(raw); batch.insert('run_points',{'run_id':p['run_id'],'seq':p['seq'],'payload':jsonEncode(p['data'])}); }
      await batch.commit(noResult:true);
    });
  }
}
