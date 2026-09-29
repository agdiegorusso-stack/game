part of 'app.dart';
class AppStore extends ChangeNotifier {
  final Repository repository; final Catalog catalog;
  late Profile profile;
  List<Workout> history = []; List<Measurement> measurements = []; List<RunRecord> runs = [];
  Map<String, Json> media = {}; Workout? draft; String? storageError; bool busy = false;
  Future<void> _writes = Future<void>.value(); late final RestClock rest; late final GpsController gps;
  AppStore._(this.repository, this.catalog);
  static Future<AppStore> open() async {
    final repository = await Repository.open();
    final catalog = Catalog.decode(await rootBundle.loadString('assets/catalog.json'));
    final store = AppStore._(repository, catalog);
    store.rest = RestClock(repository); store.gps = GpsController(repository, onSaved: store.reloadRuns);
    await store.reload(); await store.rest.restore(); await store.gps.recover(store.runs); return store;
  }
  Future<void> reload() async {
    final savedProfile=await repository.one('profile','main'); profile = Profile.fromJson(savedProfile ?? {});
    if(savedProfile==null)await repository.put('profile','main',profile.toJson());
    final rawDraft = await repository.one('draft','workout'); draft = rawDraft == null ? null : Workout.fromJson(rawDraft);
    if (draft != null && draft!.exercises.isNotEmpty) draft!.selected = draft!.selected.clamp(0, draft!.exercises.length - 1).toInt();
    history = (await repository.all('workout')).map(Workout.fromJson).toList()..sort((a,b) => b.started.compareTo(a.started));
    measurements = (await repository.all('measurement')).map(Measurement.fromJson).toList()..sort((a,b) => a.date.compareTo(b.date));
    media = {for(final j in await repository.all('media')) '${j['exerciseId']}':j};
    await reloadRuns(); notifyListeners();
  }
  Future<void> reloadRuns() async { runs = (await repository.all('run')).map(RunRecord.fromJson).toList()..sort((a,b) => b.started.compareTo(a.started)); notifyListeners(); }
  Future<void> enqueue(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.then((_) { if(storageError != null) { storageError=null; notifyListeners(); } }).catchError((Object error) { storageError='Salvataggio non riuscito: $error'; notifyListeners(); });
    return operation;
  }
  void changed() {
    if(busy) return;
    final d = draft == null ? null : asMap(jsonDecode(jsonEncode(draft!.toJson())));
    if (d != null) { unawaited(enqueue(() => repository.put('draft','workout',d)).catchError((Object _) {})); }
    notifyListeners();
  }
  Future<void> updateProfile(Profile value) async { await enqueue(() => repository.put('profile','main',value.toJson())); profile=value; notifyListeners(); }
  List<ExerciseLog> previous(String exerciseId) => history.expand((w) => w.exercises).where((e) => e.exerciseId==exerciseId && !e.skipped && e.doneCount>0).toList();
  String get nextProgram {
    final sequence = profile.phase == 0 ? ['A','B'] : ['A','B','C']; final done = history.where((w) => w.strength && w.complete);
    if(done.isEmpty) return 'A'; final index = sequence.indexOf(done.first.program); return sequence[(index+1)%sequence.length];
  }
  int get weekCount {
    final today=DateTime.now(); final monday=DateTime(today.year,today.month,today.day).subtract(Duration(days:today.weekday-1));
    return history.where((w) => w.strength && w.complete && !w.started.isBefore(monday)).length;
  }
  Future<void> startWorkout(String code, {bool compact = false}) async {
    if(draft!=null || busy) return; final program=catalog.programs[code]!; final ids=List<String>.from(program['ids']);
    if(compact && ids.length>4) ids.removeRange(4,ids.length); final logs=<ExerciseLog>[];
    for(final id in ids) {
      final ex=catalog.exercises[id]!; final sets=program['type']=='strength' && profile.phase<2 ? 2 : ex.sets;
      final prev=previous(id); final previousSets=prev.isEmpty ? <SetLog>[] : prev.first.sets.where((s) => s.done).toList();
      logs.add(ExerciseLog(exerciseId:id,rest:ex.rest,sets:List.generate(sets,(i) => SetLog(kg:i<previousSets.length ? previousSets[i].kg : null))));
    }
    final w=Workout(program:code,phase:profile.phase,exercises:logs,note:compact?'Seduta essenziale':'');
    await enqueue(() => repository.put('draft','workout',w.toJson())); draft=w; notifyListeners();
  }
  Future<void> finishWorkout({bool discard = false}) async {
    if(draft==null || busy) return; busy=true; notifyListeners();
    try {
      final w=Workout.fromJson(draft!.toJson());
      if(discard || w.doneCount==0) { await enqueue(() => repository.remove('draft','workout')); }
      else { w.ended=DateTime.now(); await enqueue(() => repository.finishWorkout(w)); history.insert(0,w); }
      draft=null; rest.clear();
    } finally { busy=false; notifyListeners(); }
  }
  Future<void> addMeasurement(Measurement m) async { await enqueue(() => repository.put('measurement',m.id,m.toJson())); measurements.removeWhere((v)=>v.id==m.id); measurements.add(m); measurements.sort((a,b)=>a.date.compareTo(b.date)); notifyListeners(); }
  Future<void> removeMeasurement(String id) async { await enqueue(()=>repository.remove('measurement',id)); measurements.removeWhere((m)=>m.id==id); notifyListeners(); }
  Future<void> saveMedia(String exerciseId, Json? value) async {
    if(value==null) { await enqueue(()=>repository.remove('media',exerciseId)); media.remove(exerciseId); }
    else { value['exerciseId']=exerciseId; await enqueue(()=>repository.put('media',exerciseId,value)); media[exerciseId]=value; }
    notifyListeners();
  }
  Future<void> exportBackup(BuildContext context) async {
    await _writes; await gps.checkpoint(); final backup=await repository.backup(); if(!context.mounted) return;
    await shareTextFile(context, 'zoro-forge-backup-${dayKey(DateTime.now())}.json',jsonEncode(backup), 'application/json');
  }
  @override void dispose() { gps.dispose(); rest.dispose(); super.dispose(); }
}
class RestClock extends ChangeNotifier {
  final Repository repository; DateTime? end; int pausedSeconds=0, total=0; String label='Recupero'; Timer? _ticker; bool _signalled=false;
  RestClock(this.repository) {
    _ticker=Timer.periodic(const Duration(seconds:1),(_){
      if(end!=null && remaining==0 && !_signalled) { _signalled=true; HapticFeedback.mediumImpact(); SystemSound.play(SystemSoundType.alert); }
      if(end!=null) notifyListeners();
    });
  }
  int get remaining => end==null ? pausedSeconds : math.max(0,(end!.difference(DateTime.now()).inMilliseconds/1000).ceil());
  bool get visible => total>0;
  bool get paused => end==null && pausedSeconds>0;
  Future<void> restore() async {
    final j=await repository.one('timer','rest'); if(j==null)return;
    end=DateTime.tryParse('${j['end']}'); total=(j['total'] as num? ?? 0).toInt(); pausedSeconds=(j['paused'] as num? ?? 0).toInt(); label='${j['label'] ?? 'Recupero'}'; _signalled=remaining==0;
    if(remaining==0) { total=0; end=null; }
  }
  void _save() { unawaited(repository.put('timer','rest', {'end':end?.toIso8601String(),'total':total,'paused':pausedSeconds,'label':label}).catchError((Object _) {})); }
  void start(int seconds,{String label='Recupero'}) {
    if(seconds<=0) { clear(); return; }
    total=seconds; pausedSeconds=0; end=DateTime.now().add(Duration(seconds:seconds)); this.label=label; _signalled=false; _save(); notifyListeners();
  }
  void toggle() {
    if(end!=null) { pausedSeconds=remaining; end=null; }
    else if(pausedSeconds>0) { end=DateTime.now().add(Duration(seconds:pausedSeconds)); pausedSeconds=0; }
    _save(); notifyListeners();
  }
  void add(int seconds) {
    final next=math.max(0,remaining+seconds); total=math.max(total,next); _signalled=false;
    if(paused) { pausedSeconds=next; } else { end=DateTime.now().add(Duration(seconds:next)); }
    _save(); notifyListeners();
  }
  void clear() { end=null; total=0; pausedSeconds=0; _save(); notifyListeners(); }
  @override void dispose() { _ticker?.cancel(); super.dispose(); }
}
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key,required AppStore store,required super.child}):super(notifier:store);
  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
bool _safeHttps(String input) {
  final uri=Uri.tryParse(input); if(uri==null || uri.scheme!='https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  final host=uri.host.toLowerCase(); return !['localhost','0.0.0.0','::1'].contains(host) && !host.endsWith('.local') && InternetAddress.tryParse(host)==null;
}
Future<void> openExternal(BuildContext context,String url) async {
  try { if(!_safeHttps(url) || !await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)) throw const FormatException('Collegamento non apribile.'); }
  catch(error) { if(context.mounted) message(context,'Impossibile aprire il collegamento: $error'); }
}
Future<void> shareTextFile(BuildContext context,String filename,String contents,String mime) async {
  final directory=await getTemporaryDirectory(); final file=File(path.join(directory.path,filename)); await file.writeAsString(contents,flush:true);
  if(!context.mounted)return; final box=context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:mime)],title:filename,sharePositionOrigin:box==null ? null : box.localToGlobal(Offset.zero)&box.size));
}
void message(BuildContext context,String text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text))); }
Future<bool> confirm(BuildContext context,String title,String text,{String action='Conferma',bool destructive=false}) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:Text(text),actions:[
  TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Annulla')),
  TextButton(onPressed:()=>Navigator.pop(c,true),style:destructive?TextButton.styleFrom(foregroundColor:Colors.redAccent):null,child:Text(action)),
])) ?? false;
