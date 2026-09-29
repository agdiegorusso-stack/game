part of 'app.dart';
class GpsController extends ChangeNotifier {
  final Repository repository; final Future<void> Function() onSaved; RunRecord? run; GpsEngine? engine;
  StreamSubscription<Position>? _locations; StreamSubscription<ServiceStatus>? _service; Timer? _ticker;
  final Stopwatch _watch=Stopwatch(); int _baseSeconds=0, _persistedPoints=0; Future<void> _writes=Future<void>.value();
  String? error; bool busy=false;
  bool get tracking => run!=null && ['recording','acquiring'].contains(run!.status);
  bool get paused => run!=null && ['paused','interrupted'].contains(run!.status);
  int get elapsed => _baseSeconds+_watch.elapsed.inSeconds;
  double get meters => engine?.meters ?? run?.meters ?? 0;
  String get quality => error ?? engine?.quality ?? 'GPS non attivo';
  GpsController(this.repository,{required this.onSaved}) {
    _ticker=Timer.periodic(const Duration(seconds:1),(_){ if(run!=null) { if(tracking && elapsed%5==0) unawaited(checkpoint().catchError((Object _){})); notifyListeners(); } });
  }
  Future<void> recover(List<RunRecord> runs) async {
    final pending=runs.where((r)=>r.status!='finished'); if(pending.isEmpty)return;
    run=pending.first; run!.points=await repository.points(run!.id); run!.status='interrupted'; _baseSeconds=run!.elapsed;
    engine=GpsEngine(points:run!.points,meters:run!.meters); _persistedPoints=run!.points.length;
    error='Attività interrotta: puoi riprenderla o salvare la parte registrata.'; await checkpoint(); notifyListeners();
  }
  Future<bool> _permission() async {
    if(!await Geolocator.isLocationServiceEnabled()) { error='GPS disattivato. Attiva la posizione e riprova.'; return false; }
    var permission=await Geolocator.checkPermission(); if(permission==LocationPermission.denied) permission=await Geolocator.requestPermission();
    if(permission==LocationPermission.deniedForever) { error='Permesso negato. Apri le impostazioni dell’app e consenti la posizione precisa durante l’uso.';return false; }
    if(permission==LocationPermission.denied || permission==LocationPermission.unableToDetermine) { error='Posizione non autorizzata. Nessuna registrazione avviata.';return false; }
    final accuracy=await Geolocator.getLocationAccuracy();
    if(accuracy==LocationAccuracyStatus.reduced) { error='È attiva la posizione approssimativa. Per il percorso serve la posizione precisa nelle impostazioni.';return false; }
    try { await const MethodChannel('zoro_forge/platform').invokeMethod<bool>('requestNotifications'); } on PlatformException { }
    return true;
  }
  Future<void> start(String mode) async {
    if(busy || run!=null)return; busy=true; error=null; notifyListeners();
    try { if(!await _permission())return; run=RunRecord(mode:mode,status:'acquiring'); engine=GpsEngine(); _baseSeconds=0; _watch.reset(); _persistedPoints=0; await checkpoint(); await _subscribe(); }
    catch(e) { error='Avvio GPS non riuscito: $e'; if(run!=null)run!.status='interrupted'; }
    finally { busy=false; notifyListeners(); }
  }
  Future<void> _subscribe() async {
    await _locations?.cancel(); await _service?.cancel();
    _service=Geolocator.getServiceStatusStream().listen((status){ if(status==ServiceStatus.disabled && tracking) { unawaited(pause(reason:'GPS disattivato: attività in pausa.').catchError((Object _){})); } });
    final settings=AndroidSettings(accuracy:LocationAccuracy.bestForNavigation, distanceFilter:0, intervalDuration:const Duration(seconds:2),
      foregroundNotificationConfig:const ForegroundNotificationConfig(notificationTitle:'Zoro Forge · attività GPS',notificationText:'Tracciamento attivo. Tocca per mettere in pausa o terminare.',enableWakeLock:true));
    _locations=Geolocator.getPositionStream(locationSettings:settings).listen((p){
      final current=run; final e=engine; if(current==null || e==null || !tracking)return;
      final point=e.add(lat:p.latitude,lon:p.longitude,accuracy:p.accuracy,timestamp:p.timestamp,now:DateTime.now(),elapsed:elapsed,speed:p.speed,speedAccuracy:p.speedAccuracy,altitude:p.altitude,mocked:p.isMocked);
      current.points=e.points; current.meters=e.meters;
      if(point!=null && current.status=='acquiring') { current.status='recording'; _watch.start(); }
      notifyListeners();
    },onError:(Object e){ unawaited(pause(reason:'Segnale GPS interrotto: $e').catchError((Object _){})); });
  }
  Future<void> pause({String? reason}) async {
    if(run==null)return; _watch.stop(); _baseSeconds=elapsed; _watch.reset(); run!.elapsed=_baseSeconds; run!.status='paused'; engine?.breakSegment();
    await _locations?.cancel(); _locations=null; await _service?.cancel();_service=null; if(reason!=null)error=reason;
    await checkpoint(); notifyListeners();
  }
  Future<void> resume() async {
    if(busy || run==null || tracking)return; busy=true;error=null;notifyListeners();
    try { if(!await _permission())return; engine?.breakSegment(); run!.status='acquiring'; await checkpoint(); await _subscribe(); }
    catch(e){run!.status='interrupted'; error='Ripresa non riuscita: $e';} finally {busy=false;notifyListeners();}
  }
  Future<void> checkpoint() {
    final operation=_writes.then((_) async {
      final r=run; if(r==null)return; r.elapsed=elapsed; r.meters=meters; r.points=engine?.points ?? r.points;
      final count=r.points.length; await repository.checkpointRun(r,_persistedPoints); _persistedPoints=count;
    });
    _writes=operation.catchError((Object e){error='Errore nel salvataggio GPS: $e';notifyListeners();}); return operation;
  }
  Future<void> finish({bool discard=false}) async {
    if(busy || run==null)return; busy=true; notifyListeners();
    try {
      await pause(); final r=run!;
      if(discard) { await _writes; await repository.deleteRun(r.id); }
      else { r.status='finished';r.ended=DateTime.now();await checkpoint(); }
      run=null;engine=null;_watch.reset();_baseSeconds=0;_persistedPoints=0;error=null; await onSaved();
    } finally {busy=false;notifyListeners();}
  }
  String get currentPace {
    final pts=engine?.points ?? []; if(!tracking || pts.length<2 || elapsed-pts.last.elapsed>10)return '—'; final last=pts.last;
    final recent=pts.where((p)=>p.segment==last.segment && last.elapsed-p.elapsed<=30).toList(); if(recent.length<2)return '—';
    double d=0; for(int i=1;i<recent.length;i++){d+=distanceMeters(recent[i-1].lat,recent[i-1].lon,recent[i].lat,recent[i].lon);} return pace(d,last.elapsed-recent.first.elapsed);
  }
  @override void dispose(){_locations?.cancel();_service?.cancel();_ticker?.cancel();_watch.stop();super.dispose();}
}
