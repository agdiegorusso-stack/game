part of 'app.dart';
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});@override State<WorkoutScreen> createState()=>_WorkoutScreenState();
}
class _WorkoutScreenState extends State<WorkoutScreen> with WidgetsBindingObserver {
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(WakelockPlus.enable().catchError((Object _){}));}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);unawaited(WakelockPlus.disable().catchError((Object _){}));super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){unawaited(WakelockPlus.toggle(enable:state==AppLifecycleState.resumed).catchError((Object _){}));}
  Future<void> _finish(AppStore s) async {
    final w=s.draft;if(w==null)return;
    final ok=await confirm(context,w.doneCount==0?'Chiudere la seduta?':w.complete?'Salvare l’allenamento?':'Salvare la seduta parziale?',w.doneCount==0?'Non sono presenti serie completate. La bozza verrà eliminata.':'${w.doneCount} serie registrate su ${w.totalCount}. Verranno salvate soltanto le serie effettivamente spuntate.',action:w.doneCount==0?'Elimina bozza':'Salva');
    if(!ok || !mounted)return;try {await s.finishWorkout();if(mounted)Navigator.pop(context);}catch(e){if(mounted)message(context,'La bozza è ancora aperta: salvataggio non riuscito. $e');}
  }
  Future<void> _substitute(AppStore s,ExerciseLog log) async {
    final ex=s.catalog.exercises[log.exerciseId]!;
    if(log.doneCount>0){message(context,'Per sostituire questo esercizio annulla prima le sue serie registrate.');return;}
    final chosen=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('Sostituisci esercizio')),for(final id in ex.alternatives)ListTile(title:Text(s.catalog.exercises[id]!.name),subtitle:Text(s.catalog.exercises[id]!.equipment),onTap:()=>Navigator.pop(c,id))])));
    if(chosen==null || !mounted)return;final next=s.catalog.exercises[chosen]!;log.exerciseId=chosen;log.skipped=false;log.technique=false;log.rest=next.rest;log.sets=List.generate(log.sets.length,(_)=>SetLog());s.changed();
  }
  @override Widget build(BuildContext context){
    final s=AppScope.of(context),w=s.draft;
    if(w==null || w.exercises.isEmpty)return Scaffold(appBar:AppBar(title:const Text('Allenamento')),body:const Center(child:Text('Nessuna seduta aperta.')));
    final i=w.selected.clamp(0,w.exercises.length-1).toInt();final log=w.exercises[i],ex=s.catalog.exercises[log.exerciseId]!;final previous=s.previous(ex.id);final suggestion=canProgress(ex,previous,log.sets.length);
    return Scaffold(appBar:AppBar(title:Text('Seduta ${w.program}'),actions:[TextButton(onPressed:s.busy?null:()=>_finish(s),child:Text(s.busy?'Salvataggio…':'Termina'))]),bottomNavigationBar:RestBar(timer:s.rest),
      body:SafeArea(bottom:true,child:ListView(padding:const EdgeInsets.fromLTRB(20,0,20,24),children:[
        if(s.storageError!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(s.storageError!,style:const TextStyle(color:Colors.orangeAccent))),
        Row(children:[Expanded(child:Text('${w.doneCount}/${w.totalCount} serie',style:const TextStyle(color:muted))),Text('${i+1}/${w.exercises.length} esercizi',style:const TextStyle(color:muted))]),
        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(10),child:LinearProgressIndicator(value:w.totalCount==0?0:w.doneCount/w.totalCount,minHeight:6)),
        const SizedBox(height:16),SizedBox(height:46,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:w.exercises.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,index){final e=w.exercises[index];return ChoiceChip(label:Text('${index+1}${e.complete?' ✓':e.skipped?' –':''}'),selected:index==i,onSelected:s.busy?null:(_){FocusScope.of(context).unfocus();w.selected=index;s.changed();});})),
        const SizedBox(height:18),Text(ex.name,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:6),Text('${log.sets.length} × ${ex.target} · recupero ${log.rest} s',style:const TextStyle(color:muted)),const SizedBox(height:18),DemoTile(exercise:ex,onTap:()=>openExercise(context,ex.id)),const SizedBox(height:14),FCard(child:Text(ex.cue,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w500))),
        if(suggestion)Padding(padding:const EdgeInsets.only(top:12),child:FCard(color:const Color(0xFF223923),child:const Text('Nelle ultime due sedute hai raggiunto il limite alto con margine e tecnica confermata. Valuta il più piccolo aumento disponibile; nessun carico viene modificato da solo.'))),
        if(previous.isNotEmpty)Padding(padding:const EdgeInsets.only(top:14),child:Text('Ultima volta: ${previous.first.sets.where((v)=>v.done).map((v)=>'${ex.hasLoad?'${decimal(v.kg??0)} kg × ':''}${v.value} ${ex.unit}').join(' · ')}',style:const TextStyle(color:muted))),
        if(ex.perSide)const Padding(padding:EdgeInsets.only(top:12),child:Text('Quantità per lato. Spunta la serie dopo aver completato entrambi i lati.',style:TextStyle(color:lime))),const SizedBox(height:18),
        if(log.skipped)FCard(child:Column(children:[const Text('Esercizio saltato: non verrà conteggiato come completo.'),TextButton(onPressed:(){log.skipped=false;s.changed();},child:const Text('Ripristina esercizio'))]))
        else for(var si=0;si<log.sets.length;si++)Padding(padding:const EdgeInsets.only(bottom:10),child:SetEditor(key:ValueKey('${log.id}-${log.sets[si].id}'),exercise:ex,log:log,set:log.sets[si],index:si,store:s)),
        Wrap(spacing:8,runSpacing:8,children:[
          if(!log.skipped)OutlinedButton.icon(onPressed:s.busy||log.sets.length>=30?null:(){log.sets.add(SetLog());s.changed();},icon:const Icon(Icons.add,size:18),label:const Text('Serie')),
          OutlinedButton.icon(onPressed:() async {final input=await inputDialog(context,'Recupero in secondi',initial:'${log.rest}',keyboard:TextInputType.number);final value=int.tryParse(input??'');if(value!=null && value>=0 && value<=1800){log.rest=value;s.changed();}},icon:const Icon(Icons.timer_outlined,size:18),label:const Text('Recupero')),
          if(ex.alternatives.isNotEmpty)OutlinedButton.icon(onPressed:s.busy?null:()=>_substitute(s,log),icon:const Icon(Icons.swap_horiz,size:18),label:const Text('Sostituisci')),
          if(!log.skipped)TextButton(onPressed:s.busy?null:() async {if(await confirm(context,'Saltare questo esercizio?','Le serie già registrate restano nello storico, ma questo esercizio non risulterà completo.',action:'Salta')){log.skipped=true;s.changed();}},child:const Text('Salta'))
        ]),
        if(ex.timed)Padding(padding:const EdgeInsets.only(top:12),child:OutlinedButton.icon(onPressed:() async {final input=await inputDialog(context,'Durata in ${ex.unitLabel}',initial:'${ex.min}',keyboard:TextInputType.number);final value=int.tryParse(input??'');if(value!=null && value>0 && value<=18000)s.rest.start(ex.unit=='min'?value*60:value,label:ex.name);},icon:const Icon(Icons.av_timer),label:const Text('Avvia timer esercizio'))),
        const SizedBox(height:10),CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('Tecnica controllata',style:TextStyle(fontSize:15)),value:log.technique,onChanged:s.busy?null:(v){log.technique=v??false;s.changed();}),
        TextFormField(key:ValueKey('${log.id}-note'),initialValue:log.note,maxLines:2,maxLength:1000,decoration:const InputDecoration(labelText:'Note · sensazioni, regolazioni della macchina'),onChanged:(v){log.note=v;s.changed();}),
        const SizedBox(height:20),Row(children:[if(i>0)IconButton.filledTonal(onPressed:(){w.selected=i-1;s.changed();},icon:const Icon(Icons.arrow_back),tooltip:'Esercizio precedente'),if(i>0)const SizedBox(width:12),Expanded(child:FilledButton.icon(onPressed:s.busy?null:(){FocusScope.of(context).unfocus();if(i<w.exercises.length-1){w.selected=i+1;s.changed();}else{_finish(s);}},icon:Icon(i<w.exercises.length-1?Icons.arrow_forward:Icons.save_outlined),label:Text(i<w.exercises.length-1?'Prossimo esercizio':'Concludi e salva')))]),
        const SizedBox(height:14),const Text('Puoi tornare alla schermata iniziale: la seduta rimane aperta.',style:TextStyle(color:muted,fontSize:12),textAlign:TextAlign.center)
      ])));
  }
}
class SetEditor extends StatelessWidget {
  final Exercise exercise;final ExerciseLog log;final SetLog set;final int index;final AppStore store;
  const SetEditor({super.key,required this.exercise,required this.log,required this.set,required this.index,required this.store});
  void _toggle(BuildContext context){
    if(set.done){set.completed=null;store.changed();return;}final error=set.validate(exercise);if(error!=null){message(context,error);return;}
    FocusScope.of(context).unfocus();set.completed=DateTime.now();store.changed();HapticFeedback.lightImpact();if(log.rest>0)store.rest.start(log.rest);
  }
  @override Widget build(BuildContext context)=>FCard(color:set.done?const Color(0xFF20311F):panel,padding:const EdgeInsets.all(14),child:Column(children:[
    Row(children:[Text('SERIE ${index+1}',style:const TextStyle(fontWeight:FontWeight.w700,letterSpacing:1,fontSize:12)),const Spacer(),if(!set.done && log.sets.length>1)IconButton(tooltip:'Rimuovi questa serie',onPressed:store.busy?null:(){log.sets.remove(set);store.changed();},icon:const Icon(Icons.remove_circle_outline,size:20)),FilledButton.tonalIcon(onPressed:store.busy?null:()=>_toggle(context),icon:Icon(set.done?Icons.check_circle:Icons.check),label:Text(set.done?'Fatta · annulla':'Fatta'))]),
    const SizedBox(height:12),LayoutBuilder(builder:(context,constraints){final width=(constraints.maxWidth-10)/2;return Wrap(spacing:10,runSpacing:10,children:[
      if(exercise.hasLoad)SizedBox(width:width,child:TextFormField(key:ValueKey('${set.id}-kg-${set.done}'),enabled:!set.done&&!store.busy,initialValue:set.kg==null?'':decimal(set.kg!),keyboardType:const TextInputType.numberWithOptions(decimal:true),inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],decoration:InputDecoration(labelText:exercise.loadLabel,hintText:exercise.load=='optional'?'0':''),onChanged:(v){set.kg=number(v);store.changed();})),
      SizedBox(width:width,child:TextFormField(key:ValueKey('${set.id}-value-${set.done}'),enabled:!set.done&&!store.busy,initialValue:set.value?.toString()??'',keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:InputDecoration(labelText:exercise.unitLabel,hintText:exercise.min==exercise.max?'${exercise.min}':'${exercise.min}–${exercise.max}'),onChanged:(v){set.value=int.tryParse(v);store.changed();})),
      if(!exercise.timed)SizedBox(width:width,child:DropdownButtonFormField<int>(key:ValueKey('${set.id}-rir-${set.done}'),initialValue:set.rir,decoration:const InputDecoration(labelText:'Margine (RIR)'),hint:const Text('—'),items:List.generate(11,(i)=>DropdownMenuItem(value:i,child:Text('$i'))),onChanged:set.done||store.busy?null:(v){set.rir=v;store.changed();}))
    ]);})
  ]));
}
Future<String?> inputDialog(BuildContext context,String title,{String initial='',TextInputType keyboard=TextInputType.text,int maxLength=200}) => showDialog<String>(context:context,builder:(_)=>_TextInputDialog(title:title,initial:initial,keyboard:keyboard,maxLength:maxLength));
class _TextInputDialog extends StatefulWidget {
  final String title,initial;final TextInputType keyboard;final int maxLength;const _TextInputDialog({required this.title,required this.initial,required this.keyboard,required this.maxLength});
  @override State<_TextInputDialog> createState()=>_TextInputDialogState();
}
class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController controller=TextEditingController(text:widget.initial);@override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.title),content:TextField(controller:controller,autofocus:true,keyboardType:widget.keyboard,maxLength:widget.maxLength,onSubmitted:(v)=>Navigator.pop(context,v)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annulla')),TextButton(onPressed:()=>Navigator.pop(context,controller.text),child:const Text('Salva'))]);
}
