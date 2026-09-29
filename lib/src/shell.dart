part of 'app.dart';
class ZoroApp extends StatelessWidget {
  final AppStore store;const ZoroApp({super.key,required this.store});
  @override Widget build(BuildContext context)=>AppScope(store:store,child:MaterialApp(title:'Zoro Forge',debugShowCheckedModeBanner:false,theme:forgeTheme,locale:const Locale('it'),supportedLocales:const [Locale('it'),Locale('en')],localizationsDelegates:GlobalMaterialLocalizations.delegates,home:const ForgeShell()));
}
class ForgeShell extends StatefulWidget {const ForgeShell({super.key});@override State<ForgeShell> createState()=>_ForgeShellState();}
class _ForgeShellState extends State<ForgeShell> {
  int index=0;
  @override Widget build(BuildContext context) {
    final store=AppScope.of(context);
    return Scaffold(appBar:AppBar(backgroundColor:ink,title:const Text('ZORO FORGE',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:2,fontSize:20)),actions:[IconButton(tooltip:'Profilo e impostazioni',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SettingsScreen())),icon:const Icon(Icons.tune_rounded))]),
      body:SafeArea(top:false,bottom:false,child:Column(children:[
        if(store.storageError!=null)MaterialBanner(content:Text(store.storageError!),actions:[TextButton(onPressed:store.changed,child:const Text('Riprova'))]),
        Expanded(child:IndexedStack(index:index,children:[HomeScreen(onOutdoor:()=>setState(()=>index=3),onPlan:()=>setState(()=>index=1)),const PlanScreen(),const LibraryScreen(),const OutdoorScreen(),const ProgressScreen()])),RestBar(timer:store.rest)])),
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Oggi'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Scheda'),NavigationDestination(icon:Icon(Icons.play_circle_outline),selectedIcon:Icon(Icons.play_circle),label:'Esercizi'),NavigationDestination(icon:Icon(Icons.route_outlined),selectedIcon:Icon(Icons.route),label:'Outdoor'),NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights),label:'Progressi')]));
  }
}
Future<void> launchWorkout(BuildContext context,String code,{bool compact=false}) async {
  final store=AppScope.of(context);
  try { await store.startWorkout(code,compact:compact); if(!context.mounted)return; await Navigator.push(context,MaterialPageRoute(builder:(_)=>const WorkoutScreen())); }
  catch(e){if(context.mounted)message(context,'Non è stato possibile aprire la seduta: $e');}
}
class HomeScreen extends StatelessWidget {
  final VoidCallback onOutdoor,onPlan;const HomeScreen({super.key,required this.onOutdoor,required this.onPlan});
  @override Widget build(BuildContext context) {
    final s=AppScope.of(context);final code=s.nextProgram;final plan=s.catalog.programs[code]!;final weights=s.measurements.where((m)=>m.weight!=null);final weight=weights.isEmpty?s.profile.initialWeight:weights.last.weight!;
    return ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
      ClipRRect(borderRadius:BorderRadius.circular(26),child:SizedBox(height:230,child:Stack(fit:StackFit.expand,children:[
        const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF254D36),Color(0xFF101A14)],begin:Alignment.topRight,end:Alignment.bottomLeft))),
        Positioned(right:22,top:15,child:Transform.rotate(angle:-.5,child:Icon(Icons.fitness_center,size:150,color:lime.withValues(alpha:.24)))),
        const Positioned(left:20,right:20,bottom:18,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('UN ANNO. UN PERCORSO.',style:TextStyle(color:lime,fontWeight:FontWeight.w800,letterSpacing:2,fontSize:11)),SizedBox(height:6),Text('La prossima serie\ncomincia qui.',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,height:1.06))]))
      ]))),const SizedBox(height:18),
      FCard(child:Row(children:[Expanded(child:Stat(weight>0?decimal(weight):'—',weight>0?'kg ${weights.isEmpty?'iniziali':'registrati'}':'Peso · da impostare')),Expanded(child:Stat('${s.weekCount}/${s.profile.weekdays.length}','sedute complete · settimana'))])),
      if(s.draft!=null) ...[
        const SectionTitle('Hai una seduta aperta'),FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Seduta ${s.draft!.program} · ${s.draft!.doneCount}/${s.draft!.totalCount} serie',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>launchWorkout(context,s.draft!.program),icon:const Icon(Icons.play_arrow),label:const Text('Riprendi allenamento')))]))
      ] else ...[
        SectionTitle('Prossima seduta',subtitle:'Fase ${s.profile.phase+1} · ${s.catalog.phases[s.profile.phase]['name']}'),
        FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(16)),child:Text(code,style:const TextStyle(color:ink,fontSize:30,fontWeight:FontWeight.w900))),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${plan['name']}',style:Theme.of(context).textTheme.titleLarge),Text('${plan['subtitle']}',style:const TextStyle(color:muted))]))]),
          const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>launchWorkout(context,code),icon:const Icon(Icons.fitness_center),label:const Text('Inizia allenamento'))),Center(child:TextButton(onPressed:()=>launchWorkout(context,code,compact:true),child:const Text('Poco tempo? Seduta essenziale')))
        ]))
      ],
      const SectionTitle('Fuori dalla palestra'),FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.route,color:lime),SizedBox(width:10),Expanded(child:Text('Corsa e camminata GPS',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)))]),const SizedBox(height:10),const Text('Distanza, ritmo e percorso. Parti quando sei pronto.',style:TextStyle(color:muted)),const SizedBox(height:14),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:onOutdoor,icon:const Icon(Icons.my_location),label:const Text('Apri Outdoor')))])),
      const SectionTitle('La tua settimana'),WeekStrip(days:s.profile.weekdays),const SizedBox(height:8),TextButton(onPressed:onPlan,child:const Text('Vedi la scheda e cambia i giorni'))
    ]);
  }
}
class WeekStrip extends StatelessWidget {
  final List<int> days;const WeekStrip({super.key,required this.days});
  @override Widget build(BuildContext context)=>Row(children:List.generate(7,(i){
    const names=['L','M','M','G','V','S','D'];final selected=days.contains(i+1),today=DateTime.now().weekday==i+1;
    return Expanded(child:Container(margin:const EdgeInsets.symmetric(horizontal:2),padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:selected?lime:panel,borderRadius:BorderRadius.circular(12),border:Border.all(color:today?Colors.white:Colors.transparent)),child:Column(children:[Text(names[i],style:TextStyle(fontWeight:FontWeight.w700,color:selected?ink:muted)),const SizedBox(height:6),Icon(selected?Icons.fitness_center:Icons.remove,size:17,color:selected?ink:muted)])));
  }));
}
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});
  @override Widget build(BuildContext context){
    final s=AppScope.of(context);
    return ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
      const SectionTitle('La tua scheda',subtitle:'Corpo intero · 3 fasi · giorni modificabili'),FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Fase ${s.profile.phase+1} · ${s.catalog.phases[s.profile.phase]['name']}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),Text('${s.catalog.phases[s.profile.phase]['goal']}',style:const TextStyle(color:muted)),const SizedBox(height:12),WeekStrip(days:s.profile.weekdays),TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SettingsScreen())),child:const Text('Cambia fase o giorni'))])),
      for(final code in ['A','B','C','D','W']) ...[
        SectionTitle('$code · ${s.catalog.programs[code]!['name']}',subtitle:'${s.catalog.programs[code]!['subtitle']}'),FCard(padding:EdgeInsets.zero,child:Column(children:[
          for(final id in List<String>.from(s.catalog.programs[code]!['ids']))ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:6),leading:const Icon(Icons.play_circle_outline,color:lime),title:Text(s.catalog.exercises[id]!.name),subtitle:Text('${s.catalog.programs[code]!['type']=='strength' && s.profile.phase<2?2:s.catalog.exercises[id]!.sets} × ${s.catalog.exercises[id]!.target}'),onTap:()=>openExercise(context,id)),
          Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,child:FilledButton.tonal(onPressed:()=>launchWorkout(context,code),child:Text(s.draft==null?'Inizia $code':'Riprendi seduta aperta'))))
        ]))
      ]
    ]);
  }
}
