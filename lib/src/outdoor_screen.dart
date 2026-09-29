part of 'app.dart';
class OutdoorScreen extends StatelessWidget {
  const OutdoorScreen({super.key});
  Future<void> _act(BuildContext c,Future<void> Function() action)async{try{await action();}catch(e){if(c.mounted)message(c,'Operazione non riuscita: $e');}}
  @override Widget build(BuildContext context){final s=AppScope.of(context),gps=s.gps;return AnimatedBuilder(animation:gps,builder:(c,_){final r=gps.run;return ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
    Text(r==null?'La strada\nè il tuo campo.':r.label,style:Theme.of(context).textTheme.headlineLarge),const SizedBox(height:12),Text(gps.quality,style:TextStyle(color:gps.error==null?muted:Colors.orangeAccent)),
    const SizedBox(height:18),RouteMap(points:gps.engine?.points??const [],tiles:s.profile.mapTiles),const SizedBox(height:18),FCard(child:Column(children:[Row(children:[Expanded(child:Stat(decimal(gps.meters/1000,2),'chilometri')),Expanded(child:Stat(clock(gps.elapsed),'tempo attivo'))]),const Divider(height:32),Row(children:[Expanded(child:Stat(gps.currentPace,'ritmo recente · min/km')),Expanded(child:Stat(pace(gps.meters,gps.elapsed),'ritmo medio · min/km'))])])),const SizedBox(height:18),
    if(r==null) ...[
      FilledButton.icon(onPressed:gps.busy?null:()=>_act(context,()=>gps.start('walk')),icon:const Icon(Icons.directions_walk),label:Text(gps.busy?'Avvio…':'Inizia camminata')),const SizedBox(height:10),OutlinedButton.icon(onPressed:gps.busy?null:()=>_act(context,()=>gps.start('run')),icon:const Icon(Icons.directions_run),label:const Text('Inizia corsa')),const SizedBox(height:12),const Text('La posizione viene richiesta solo quando inizi. Il cronometro parte al primo segnale GPS utilizzabile.',style:TextStyle(color:muted,fontSize:12))
    ]else ...[
      if(r.status=='acquiring')const Padding(padding:EdgeInsets.only(bottom:12),child:Text('Ricerca del segnale: attendi all’aperto. Il tempo di attesa non viene conteggiato.',style:TextStyle(color:lime))),
      if(gps.paused)const Padding(padding:EdgeInsets.only(bottom:12),child:Text('In pausa · posizione non registrata.',style:TextStyle(color:lime))),
      FilledButton.icon(onPressed:gps.busy?null:()=>_act(context,gps.tracking?()=>gps.pause():()=>gps.resume()),icon:Icon(gps.tracking?Icons.pause:Icons.play_arrow),label:Text(gps.tracking?'Pausa':'Riprendi')),const SizedBox(height:10),
      OutlinedButton.icon(onPressed:gps.busy?null:()async{if(await confirm(context,'Terminare l’attività?','Salva ${decimal(gps.meters/1000,2)} km e ${clock(gps.elapsed)} registrati.',action:'Termina e salva') && context.mounted)await _act(context,()=>gps.finish());},icon:const Icon(Icons.stop_circle_outlined),label:const Text('Termina e salva')),
      TextButton(onPressed:gps.busy?null:()async{if(await confirm(context,'Eliminare questa attività?','La traccia e il tempo registrati verranno cancellati.',action:'Elimina',destructive:true) && context.mounted)await _act(context,()=>gps.finish(discard:true));},child:const Text('Scarta attività'))
    ],
    if(gps.error!=null)Wrap(children:[TextButton(onPressed:()=>Geolocator.openLocationSettings(),child:const Text('Impostazioni GPS')),TextButton(onPressed:()=>Geolocator.openAppSettings(),child:const Text('Permessi dell’app'))]),
    const SectionTitle('Ultime attività'),if(s.runs.where((v)=>v.status=='finished').isEmpty)const Text('Le attività salvate compariranno qui.',style:TextStyle(color:muted)),for(final old in s.runs.where((v)=>v.status=='finished').take(8))RunTile(run:old)
  ]);});}
}
class RouteMap extends StatefulWidget {
  final List<TrackPoint> points;final bool tiles;const RouteMap({super.key,required this.points,required this.tiles});@override State<RouteMap> createState()=>_RouteMapState();
}
class _RouteMapState extends State<RouteMap>{
  final controller=MapController();bool ready=false;@override void dispose(){controller.dispose();super.dispose();}
  void _fit(){if(!ready || widget.points.isEmpty)return;final pts=widget.points.map((p)=>LatLng(p.lat,p.lon)).toList();if(pts.length==1 || pts.every((p)=>p==pts.first))controller.move(pts.first,16);else controller.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(pts),padding:const EdgeInsets.all(35),maxZoom:18));}
  @override Widget build(BuildContext context){
    if(widget.points.isEmpty)return const SizedBox(height:230,child:EmptyPanel(icon:Icons.gps_not_fixed,title:'In attesa del percorso',body:'La mappa apparirà con il primo punto GPS.'));
    final groups=<int,List<LatLng>>{};for(final p in widget.points){groups.putIfAbsent(p.segment,()=>[]).add(LatLng(p.lat,p.lon));}final start=widget.points.first,end=widget.points.last;
    return ClipRRect(borderRadius:BorderRadius.circular(22),child:SizedBox(height:300,child:Stack(children:[
      FlutterMap(mapController:controller,options:MapOptions(initialCenter:LatLng(end.lat,end.lon),initialZoom:16,backgroundColor:const Color(0xFF233129),onMapReady:(){ready=true;_fit();}),children:[
        if(widget.tiles)TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'it.zoroforge.zoro_forge'),
        PolylineLayer(polylines:groups.values.where((g)=>g.length>1).map((g)=>Polyline(points:g,strokeWidth:5,color:const Color(0xFF388400))).toList()),
        MarkerLayer(markers:[Marker(point:LatLng(start.lat,start.lon),width:25,height:25,child:const Icon(Icons.flag,color:Colors.blue,size:25)),Marker(point:LatLng(end.lat,end.lon),width:24,height:24,child:Container(decoration:BoxDecoration(shape:BoxShape.circle,color:lime,border:Border.all(color:ink,width:3))))])
      ]),
      Positioned(top:10,right:10,child:IconButton.filled(tooltip:'Inquadra percorso',onPressed:_fit,icon:const Icon(Icons.center_focus_strong))),
      if(widget.tiles)Positioned(left:0,bottom:0,child:Material(color:Colors.black87,child:InkWell(onTap:()=>openExternal(context,'https://www.openstreetmap.org/copyright'),child:const Padding(padding:EdgeInsets.all(7),child:Text('© OpenStreetMap contributors',style:TextStyle(fontSize:10,color:Colors.white)))))),
      if(!widget.tiles)const Positioned(left:10,bottom:12,child:Text('Traccia · sfondo cartografico disattivato',style:TextStyle(fontSize:11)))
    ])));
  }
}
class RunTile extends StatelessWidget {
  final RunRecord run;const RunTile({super.key,required this.run});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:FCard(padding:EdgeInsets.zero,child:ListTile(leading:Icon(run.mode=='run'?Icons.directions_run:Icons.directions_walk,color:lime),title:Text('${run.label} · ${decimal(run.meters/1000,2)} km'),subtitle:Text('${localDate(run.started)} · ${clock(run.elapsed)} · ${pace(run.meters,run.elapsed)} min/km'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>RunDetailScreen(run:run))))));
}
class RunDetailScreen extends StatefulWidget {
  final RunRecord run;const RunDetailScreen({super.key,required this.run});@override State<RunDetailScreen> createState()=>_RunDetailScreenState();
}
class _RunDetailScreenState extends State<RunDetailScreen>{
  Future<List<TrackPoint>>? pending;@override void didChangeDependencies(){super.didChangeDependencies();pending??=AppScope.of(context).repository.points(widget.run.id);}
  @override Widget build(BuildContext context){final s=AppScope.of(context),r=widget.run;return Scaffold(appBar:AppBar(title:Text(r.label)),body:SafeArea(child:FutureBuilder<List<TrackPoint>>(future:pending,builder:(c,snapshot){
    if(snapshot.hasError)return Center(child:Text('Traccia non leggibile: ${snapshot.error}'));if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());final pts=snapshot.data!,splits=kilometerSplits(pts);
    return ListView(padding:const EdgeInsets.fromLTRB(20,8,20,32),children:[Text(localDate(r.started),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:18),RouteMap(points:pts,tiles:s.profile.mapTiles),const SizedBox(height:18),FCard(child:Wrap(spacing:24,runSpacing:18,children:[Stat('${decimal(r.meters/1000,2)} km','distanza'),Stat(clock(r.elapsed),'tempo attivo'),Stat(pace(r.meters,r.elapsed),'min/km medio')])),
      const SectionTitle('Parziali chilometrici'),if(splits.isEmpty)const Text('Nessun chilometro completo registrato.',style:TextStyle(color:muted)),for(final split in splits)ListTile(title:Text('Chilometro ${split.kilometer}'),trailing:Text('${clock(split.seconds)} min/km')),const SizedBox(height:20),
      FilledButton.icon(onPressed:pts.isEmpty?null:()async{if(!await confirm(context,'Esportare la traccia GPX?','Il file contiene posizioni precise e orari. Condividilo soltanto con chi vuoi.',action:'Esporta') || !context.mounted)return;try{final copy=RunRecord.fromJson(r.toJson());copy.points=pts;await shareTextFile(context,'zoro-${dayKey(r.started)}-${r.id}.gpx',toGpx(copy),'application/gpx+xml');}catch(e){if(context.mounted)message(context,'Esportazione non riuscita: $e');}},icon:const Icon(Icons.share_outlined),label:const Text('Esporta GPX')),
      const SizedBox(height:14),TextButton(onPressed:()async{if(!await confirm(context,'Eliminare l’attività?','Questa operazione cancella anche la traccia GPS.',action:'Elimina',destructive:true))return;try{await s.repository.deleteRun(r.id);await s.reloadRuns();if(context.mounted)Navigator.pop(context);}catch(e){if(context.mounted)message(context,'Eliminazione non riuscita: $e');}},child:const Text('Elimina attività'))
    ]);
  })));
  }
}
