part of 'app.dart';
Future<void> openExercise(BuildContext context,String id) => Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>ExerciseScreen(exerciseId:id)));
Json? mediaFor(AppStore store,Exercise ex) => store.media[ex.id] ?? (ex.videos.isEmpty?null:ex.videos.first);
class DemoTile extends StatelessWidget {
  final Exercise exercise; final VoidCallback onTap;const DemoTile({super.key,required this.exercise,required this.onTap});
  @override Widget build(BuildContext context){
    final s=AppScope.of(context), media=mediaFor(s,exercise);final id=media==null?null:youtubeId('${media['url']}');
    return ClipRRect(borderRadius:BorderRadius.circular(20),child:Material(color:panel,child:InkWell(onTap:onTap,child:AspectRatio(aspectRatio:16/9,child:Stack(fit:StackFit.expand,children:[
      if(id!=null)Image.network('https://i.ytimg.com/vi/$id/hqdefault.jpg',fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.ondemand_video_outlined,size:48,color:muted)))else const Center(child:Icon(Icons.ondemand_video_outlined,size:48,color:muted)),
      const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Color(0xDD000000)]))),
      if(media!=null)const Center(child:CircleAvatar(radius:29,backgroundColor:lime,child:Icon(Icons.play_arrow_rounded,size:36,color:ink))),
      Positioned(left:16,bottom:14,right:16,child:Text(media==null?'Tecnica e video personale':media['type']=='file'?'Il tuo video · offline':'Guarda la dimostrazione',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)))
    ])))));
  }
}
class LibraryScreen extends StatefulWidget {const LibraryScreen({super.key});@override State<LibraryScreen> createState()=>_LibraryScreenState();}
class _LibraryScreenState extends State<LibraryScreen>{
  String query='';
  @override Widget build(BuildContext context){final s=AppScope.of(context);final all=s.catalog.exercises.values.where((e)=>'${e.name} ${e.group} ${e.equipment}'.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding:const EdgeInsets.all(20),children:[Text('Il movimento,\nprima del carico.',style:Theme.of(context).textTheme.headlineLarge),const SizedBox(height:18),TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Cerca esercizio o gruppo muscolare'),onChanged:(v)=>setState(()=>query=v)),const SizedBox(height:18),
      for(final e in all)Padding(padding:const EdgeInsets.only(bottom:10),child:FCard(padding:EdgeInsets.zero,child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:10),leading:const Icon(Icons.play_circle_outline,color:lime,size:32),title:Text(e.name),subtitle:Text('${e.group} · ${e.equipment}'),trailing:const Icon(Icons.chevron_right),onTap:()=>openExercise(context,e.id)))),if(all.isEmpty)const Text('Nessun esercizio trovato.')]);
  }
}
class ExerciseScreen extends StatefulWidget {final String exerciseId;const ExerciseScreen({super.key,required this.exerciseId});@override State<ExerciseScreen> createState()=>_ExerciseScreenState();}
class _ExerciseScreenState extends State<ExerciseScreen>{
  bool copying=false;
  Future<void> _choose(AppStore s,Exercise ex) async {
    final choice=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:const Icon(Icons.video_file_outlined),title:const Text('Video dal telefono'),subtitle:const Text('Copia privata nell’app · massimo 200 MB'),onTap:()=>Navigator.pop(c,'file')),
      ListTile(leading:const Icon(Icons.link),title:const Text('Collegamento YouTube o MP4'),onTap:()=>Navigator.pop(c,'url')),
      if(s.media.containsKey(ex.id))ListTile(leading:const Icon(Icons.restore),title:const Text('Ripristina dimostrazione originale'),onTap:()=>Navigator.pop(c,'reset')),const SizedBox(height:12)])));
    if(choice==null || !mounted)return;
    try {
      if(choice=='reset'){await s.saveMedia(ex.id,null);return;}
      if(choice=='url'){
        final text=await inputDialog(context,'Collegamento al video',keyboard:TextInputType.url);if(text==null || text.trim().isEmpty)return;final url=text.trim(),yt=youtubeId(text.trim());
        if(!_safeHttps(url))throw const FormatException('Usa un collegamento HTTPS valido.');
        if(yt==null && !Uri.parse(url).path.toLowerCase().endsWith('.mp4'))throw const FormatException('Inserisci un video YouTube oppure un collegamento diretto .mp4.');
        await s.saveMedia(ex.id,{'type':yt!=null?'youtube':'mp4','url':url,'title':'Video scelto da te','publisher':'Fonte personale'});
      }else{
        final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['mp4','m4v','mov'],allowMultiple:false,withData:false);if(result==null)return;final selected=result.files.single;
        if(selected.path==null || selected.size>200*1024*1024)throw const FormatException('Scegli un video accessibile di massimo 200 MB.');
        if(!mounted)return;setState(()=>copying=true);final directory=Directory(path.join((await getApplicationDocumentsDirectory()).path,'exercise_media'));await directory.create(recursive:true);
        final destination=path.join(directory.path,'${ex.id}-${uid()}${path.extension(selected.name)}');await File(selected.path!).copy(destination);
        try {await s.saveMedia(ex.id,{'type':'file','file':destination,'title':selected.name,'publisher':'Video personale'});}catch(_){await File(destination).delete();rethrow;}
      }
    }catch(e){if(mounted)message(context,'Video non modificato: $e');}finally{if(mounted)setState(()=>copying=false);}
  }
  @override Widget build(BuildContext context){
    final s=AppScope.of(context),ex=s.catalog.exercises[widget.exerciseId]!;final media=mediaFor(s,ex);
    return Scaffold(appBar:AppBar(title:const Text('Movimento e tecnica')),body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,32),children:[
      Text(ex.name,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:6),Text('${ex.group} · ${ex.equipment}',style:const TextStyle(color:muted)),const SizedBox(height:20),
      if(media!=null)ExerciseMediaPlayer(key:ValueKey(jsonEncode(media)),media:media)else const FCard(child:Text('Per questo esercizio non è ancora selezionato un filmato. Puoi aggiungere il video del tuo istruttore.')),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:copying?null:()=>_choose(s,ex),icon:const Icon(Icons.video_settings),label:Text(copying?'Copia del video…':'Scegli un altro video')),
      const SectionTitle('Come eseguirlo'),FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[for(var i=0;i<ex.steps.length;i++)Padding(padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${i+1}.',style:const TextStyle(color:lime,fontWeight:FontWeight.w800)),const SizedBox(width:12),Expanded(child:Text(ex.steps[i]))])),Text(ex.tempo,style:const TextStyle(color:muted))])),
      const SizedBox(height:16),ExpansionTile(title:const Text('Errori da evitare'),children:[for(final error in ex.errors)ListTile(leading:const Icon(Icons.close,size:18),title:Text(error))]),
      if(ex.alternatives.isNotEmpty)ExpansionTile(title:const Text('Alternative'),children:[for(final id in ex.alternatives)ListTile(title:Text(s.catalog.exercises[id]!.name),trailing:const Icon(Icons.chevron_right),onTap:()=>openExercise(context,id))])
    ])));
  }
}
class ExerciseMediaPlayer extends StatefulWidget {final Json media;const ExerciseMediaPlayer({super.key,required this.media});@override State<ExerciseMediaPlayer> createState()=>_ExerciseMediaPlayerState();}
class _ExerciseMediaPlayerState extends State<ExerciseMediaPlayer> with WidgetsBindingObserver{
  YoutubePlayerController? youtube;VideoPlayerController? video;String? failure;bool loading=true,ytStarted=false;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_init();}
  Future<void> _init() async{
    final m=widget.media;
    try{
      if(m['type']=='youtube'){loading=false;return;}
      if(m['type']=='file'){final file=File('${m['file']}');if(!await file.exists())throw const FileSystemException('Video non trovato. Selezionalo di nuovo.');video=VideoPlayerController.file(file);}
      else if(m['type']=='mp4'){if(!_safeHttps('${m['url']}'))throw const FormatException('Indirizzo video non valido.');video=VideoPlayerController.networkUrl(Uri.parse('${m['url']}'));}
      else{loading=false;return;}
      await video!.initialize().timeout(const Duration(seconds:30));await video!.setLooping(true);
    }catch(e){failure='Impossibile caricare questo video. $e';}finally{if(mounted)setState(()=>loading=false);}
  }
  void _startYoutube(){
    final id=youtubeId('${widget.media['url']}');if(id==null){setState(()=>failure='Collegamento video non valido.');return;}
    youtube=YoutubePlayerController.fromVideoId(videoId:id,autoPlay:false,params:const YoutubePlayerParams(showControls:true,showFullscreenButton:true,privacyEnhancedMode:true,interfaceLanguage:'it',captionLanguage:'it'));setState(()=>ytStarted=true);
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed){video?.pause();youtube?.pause();}}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);video?.dispose();youtube?.close();super.dispose();}
  @override Widget build(BuildContext context){final m=widget.media,url='${m['url']??''}';return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(loading)const AspectRatio(aspectRatio:16/9,child:Center(child:CircularProgressIndicator()))
    else if(failure!=null)FCard(child:Text(failure!))
    else if(m['type']=='youtube')ytStarted?ClipRRect(borderRadius:BorderRadius.circular(18),child:YoutubePlayer(controller:youtube!,aspectRatio:16/9)):
      AspectRatio(aspectRatio:16/9,child:Material(color:panel,borderRadius:BorderRadius.circular(18),clipBehavior:Clip.antiAlias,child:InkWell(onTap:_startYoutube,child:Stack(fit:StackFit.expand,children:[Image.network('https://i.ytimg.com/vi/${youtubeId(url)}/hqdefault.jpg',fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink()),const Center(child:CircleAvatar(radius:30,backgroundColor:lime,child:Icon(Icons.play_arrow,size:38,color:ink))),const Positioned(bottom:8,left:12,right:12,child:Text('Riproduci video',style:TextStyle(fontWeight:FontWeight.bold,backgroundColor:Colors.black54)))]))))
    else if(video!=null && video!.value.isInitialized)NativeVideoControls(controller:video!)
    else FCard(child:FilledButton.icon(onPressed:()=>openExternal(context,url),icon:const Icon(Icons.open_in_new),label:const Text('Apri il filmato della fonte'))),
    const SizedBox(height:10),Text('${m['title']??'Dimostrazione'}',style:const TextStyle(fontWeight:FontWeight.w600)),Text('${m['publisher']??''}${m['type']=='file'?' · offline':' · online'}',style:const TextStyle(color:muted,fontSize:12)),
    if(url.isNotEmpty)Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()=>openExternal(context,url),icon:const Icon(Icons.open_in_new,size:16),label:const Text('Apri nella fonte')))
  ]);}
}
class NativeVideoControls extends StatelessWidget {
  final VideoPlayerController controller;final bool fullscreen;const NativeVideoControls({super.key,required this.controller,this.fullscreen=false});
  @override Widget build(BuildContext context)=>ValueListenableBuilder<VideoPlayerValue>(valueListenable:controller,builder:(c,v,_){return Column(mainAxisSize:MainAxisSize.min,children:[
    ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.62),child:AspectRatio(aspectRatio:v.aspectRatio>0?v.aspectRatio:16/9,child:VideoPlayer(controller))),VideoProgressIndicator(controller,allowScrubbing:true,padding:const EdgeInsets.symmetric(vertical:12)),
    Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:6,children:[IconButton.filled(tooltip:v.isPlaying?'Pausa':'Riproduci',onPressed:()=>v.isPlaying?controller.pause():controller.play(),icon:Icon(v.isPlaying?Icons.pause:Icons.play_arrow)),Text('${clock(v.position.inSeconds)} / ${clock(v.duration.inSeconds)}'),
      PopupMenuButton<double>(initialValue:v.playbackSpeed,tooltip:'Velocità',onSelected:controller.setPlaybackSpeed,itemBuilder:(_)=>[.25,.5,.75,1.0,1.25].map((speed)=>PopupMenuItem(value:speed,child:Text('${decimal(speed,2)}×'))).toList(),child:Padding(padding:const EdgeInsets.all(12),child:Text('${decimal(v.playbackSpeed,2)}×'))),IconButton(tooltip:'Ripeti',onPressed:()=>controller.setLooping(!v.isLooping),icon:Icon(Icons.repeat,color:v.isLooping?lime:muted)),
      if(!fullscreen)IconButton(tooltip:'Schermo intero',icon:const Icon(Icons.fullscreen),onPressed:()async{await controller.pause();if(!context.mounted)return;await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:const Text('Dimostrazione')),body:SafeArea(child:Center(child:NativeVideoControls(controller:controller,fullscreen:true))))));})
    ]),if(v.hasError)Text(v.errorDescription??'Errore di riproduzione',style:const TextStyle(color:Colors.orangeAccent))
  ]);});
}
