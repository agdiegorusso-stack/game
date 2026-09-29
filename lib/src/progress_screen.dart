part of 'app.dart';
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override Widget build(BuildContext context){final s=AppScope.of(context),weights=s.measurements.where((m)=>m.weight!=null).toList();final finished=s.runs.where((r)=>r.status=='finished').toList();return ListView(padding:const EdgeInsets.fromLTRB(20,0,20,28),children:[
    Text('Quello che fai\nlascia il segno.',style:Theme.of(context).textTheme.headlineLarge),const SizedBox(height:18),FCard(child:Wrap(spacing:24,runSpacing:18,children:[Stat('${s.history.where((w)=>w.complete).length}','sedute complete'),Stat('${s.history.fold<int>(0,(sum,w)=>sum+w.doneCount)}','serie registrate'),Stat(decimal(finished.fold<double>(0,(sum,r)=>sum+r.meters)/1000,1),'km outdoor')])),
    SectionTitle('Peso e girovita',trailing:IconButton.filledTonal(tooltip:'Aggiungi misura',onPressed:()=>addMeasurementDialog(context),icon:const Icon(Icons.add))),
    if(weights.isNotEmpty)FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${decimal(weights.last.weight!)} kg',style:Theme.of(context).textTheme.headlineMedium),Text('Ultima registrazione · ${localDate(weights.last.date)}',style:const TextStyle(color:muted)),if(weights.length>1)...[const SizedBox(height:18),SizedBox(height:160,width:double.infinity,child:CustomPaint(painter:WeightPainter(weights))),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(localDate(weights.first.date),style:const TextStyle(fontSize:11,color:muted)),Text(localDate(weights.last.date),style:const TextStyle(fontSize:11,color:muted))])]]))
    else const EmptyPanel(icon:Icons.monitor_weight_outlined,title:'La prima misura parte da te',body:'Aggiungi una registrazione del peso o del girovita.'),
    if(s.measurements.isNotEmpty)ExpansionTile(title:const Text('Tutte le misure'),children:[for(final m in s.measurements.reversed)ListTile(title:Text(localDate(m.date)),subtitle:Text([if(m.weight!=null)'${decimal(m.weight!)} kg',if(m.waist!=null)'${decimal(m.waist!)} cm vita'].join(' · ')),trailing:IconButton(tooltip:'Elimina misura',icon:const Icon(Icons.delete_outline),onPressed:()async{if(await confirm(context,'Eliminare la misura?','La registrazione del ${localDate(m.date)} verrà rimossa.',action:'Elimina',destructive:true)){try{await s.removeMeasurement(m.id);}catch(e){if(context.mounted)message(context,'Misura non eliminata: $e');}}}))]),
    const SectionTitle('Allenamenti'),if(s.history.isEmpty)const Text('Le sedute salvate compariranno qui.',style:TextStyle(color:muted)),
    for(final w in s.history)Padding(padding:const EdgeInsets.only(bottom:10),child:FCard(padding:EdgeInsets.zero,child:ListTile(leading:Icon(w.complete?Icons.task_alt:Icons.pie_chart_outline,color:lime),title:Text('Seduta ${w.program} · ${w.complete?'completa':'parziale'}'),subtitle:Text('${localDate(w.started)} · ${w.doneCount}/${w.totalCount} serie'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>WorkoutDetailScreen(workout:w)))))),
    const SectionTitle('Corsa e camminata'),if(finished.isEmpty)const Text('Nessuna attività GPS salvata.',style:TextStyle(color:muted)),for(final r in finished)RunTile(run:r)
  ]);}
}
class WeightPainter extends CustomPainter {
  final List<Measurement> data;WeightPainter(this.data);
  @override void paint(Canvas canvas,Size size){
    if(data.length<2)return;final values=data.map((m)=>m.weight!).toList();final low=values.reduce((a,b)=>a<b?a:b)-1,high=values.reduce((a,b)=>a>b?a:b)+1;final first=data.first.date.millisecondsSinceEpoch.toDouble(),span=math.max(1,data.last.date.millisecondsSinceEpoch-first);final line=Path();final grid=Paint()..color=Colors.white.withValues(alpha:.08)..strokeWidth=1;
    for(var i=0;i<4;i++){final y=10+(size.height-24)*i/3;canvas.drawLine(Offset(0,y),Offset(size.width,y),grid);}
    for(var i=0;i<data.length;i++){final x=4+(size.width-8)*(data[i].date.millisecondsSinceEpoch-first);final normalizedX=4+(x-4)/span;final y=10+(size.height-24)*(1-(values[i]-low)/(high-low));if(i==0)line.moveTo(normalizedX,y);else line.lineTo(normalizedX,y);canvas.drawCircle(Offset(normalizedX,y),3,Paint()..color=lime);}
    canvas.drawPath(line,Paint()..color=lime..strokeWidth=2.5..style=PaintingStyle.stroke);
  }
  @override bool shouldRepaint(covariant WeightPainter old)=>true;
}
Future<void> addMeasurementDialog(BuildContext context)async{final result=await showDialog<Measurement>(context:context,builder:(_)=>const MeasurementDialog());if(result==null || !context.mounted)return;try{await AppScope.of(context).addMeasurement(result);}catch(e){if(context.mounted)message(context,'Misura non salvata: $e');}}
class MeasurementDialog extends StatefulWidget {const MeasurementDialog({super.key});@override State<MeasurementDialog> createState()=>_MeasurementDialogState();}
class _MeasurementDialogState extends State<MeasurementDialog>{
  final weight=TextEditingController(),waist=TextEditingController();DateTime date=DateTime.now();String? error;
  @override void dispose(){weight.dispose();waist.dispose();super.dispose();}
  void save(){final w=number(weight.text),v=number(waist.text);if((weight.text.trim().isNotEmpty&&(w==null||w<30||w>400))||(waist.text.trim().isNotEmpty&&(v==null||v<30||v>250))||(w==null&&v==null)){setState(()=>error='Inserisci peso 30–400 kg e/o girovita 30–250 cm.');return;}Navigator.pop(context,Measurement(date:date,weight:w,waist:v));}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('Nuova misura'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime.now());if(d!=null&&mounted)setState(()=>date=d);},icon:const Icon(Icons.calendar_today),label:Text(localDate(date))),const SizedBox(height:12),TextField(controller:weight,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Peso · kg')),const SizedBox(height:12),TextField(controller:waist,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Girovita · cm')),if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.orangeAccent)))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annulla')),FilledButton(onPressed:save,child:const Text('Salva'))]);
}
class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;const WorkoutDetailScreen({super.key,required this.workout});
  @override Widget build(BuildContext context){final s=AppScope.of(context),w=workout;return Scaffold(appBar:AppBar(title:Text('Seduta ${w.program}')),body:ListView(padding:const EdgeInsets.all(20),children:[
    Text(localDate(w.started),style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:8),Text('${w.doneCount}/${w.totalCount} serie · ${w.complete?'completa':'parziale'}',style:const TextStyle(color:muted)),
    for(final e in w.exercises)...[SectionTitle(s.catalog.exercises[e.exerciseId]?.name??e.exerciseId,subtitle:e.skipped?'Saltato':null),FCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      for(var i=0;i<e.sets.length;i++)if(e.sets[i].done)Padding(padding:const EdgeInsets.only(bottom:8),child:Text('Serie ${i+1}: ${s.catalog.exercises[e.exerciseId]!.hasLoad?'${decimal(e.sets[i].kg??0)} kg × ':''}${e.sets[i].value} ${s.catalog.exercises[e.exerciseId]!.unit}${e.sets[i].rir!=null?' · margine ${e.sets[i].rir}':''}')),
      if(e.doneCount==0)const Text('Nessuna serie completata.',style:TextStyle(color:muted)),if(e.note.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text(e.note))
    ]))],if(w.note.isNotEmpty)Padding(padding:const EdgeInsets.only(top:16),child:Text(w.note))
  ]));}
}
String workoutCsv(AppStore s){
  String q(Object? value){var text='${value??''}';if(value is String && RegExp(r'^[\s]*[=+@-]').hasMatch(text))text="'$text";return '"${text.replaceAll('"','""')}"';}
  final out=StringBuffer('data,seduta,esercizio,serie,kg,quantita,unita,per_lato,margine,completata,note\r\n');
  for(final w in s.history){for(final e in w.exercises){final ex=s.catalog.exercises[e.exerciseId]!;for(var i=0;i<e.sets.length;i++){final set=e.sets[i];if(!set.done)continue;out.writeln([w.started.toIso8601String(),w.program,ex.name,i+1,ex.hasLoad?set.kg:null,set.value,ex.unit,ex.perSide,set.rir,set.completed?.toIso8601String(),e.note].map(q).join(','));}}}return out.toString();
}
