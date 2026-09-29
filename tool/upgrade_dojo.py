"""Add a discoverable sword programme; keep personal images outside Git."""
from pathlib import Path
import base64, json, re
ROOT=Path(__file__).resolve().parents[1]
def edit(name, old, new):
    p=ROOT/name
    s=p.read_text()
    if new in s: return
    if old not in s: raise RuntimeError(f'Expected source missing: {name}: {old[:80]}')
    p.write_text(s.replace(old,new))
p=ROOT/'pubspec.yaml'; text=p.read_text(); text=re.sub(r'version: .*', 'version: 2.0.1+20003',text)
if 'assets/hero.png' not in text:text=text.replace('    - assets/catalog.json','    - assets/catalog.json\n    - assets/hero.png')
p.write_text(text)
p=ROOT/'assets/hero.png'
if not p.exists():p.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1cAAAAASUVORK5CYII='))
p=ROOT/'lib/src/shell.dart';text=p.read_text()
start=text.index('      ClipRRect(borderRadius:BorderRadius.circular(26),child:SizedBox(height:230')
end=text.index('      FCard(child:Row(children:',start)
text=text[:start]+'''      const HeroArtwork(),const SizedBox(height:14),
      SizedBox(width:double.infinity,child:FilledButton.tonalIcon(
        onPressed:onSword,icon:const Icon(Icons.sports_martial_arts),
        label:const Text('Allenamento con la spada'))),
      const SizedBox(height:18),
'''+text[end:]
text=text.replace('onPlan:()=>setState(()=>index=1))','onPlan:()=>setState(()=>index=1),onSword:()=>setState(()=>index=2))')
text=text.replace('const LibraryScreen(),const OutdoorScreen()','const DojoScreen(),const OutdoorScreen()')
text=text.replace("NavigationDestination(icon:Icon(Icons.play_circle_outline),selectedIcon:Icon(Icons.play_circle),label:'Esercizi')", "NavigationDestination(icon:Icon(Icons.sports_martial_arts_outlined),selectedIcon:Icon(Icons.sports_martial_arts),label:'Spada')")
text=text.replace('final VoidCallback onOutdoor,onPlan;const HomeScreen({super.key,required this.onOutdoor,required this.onPlan});','final VoidCallback onOutdoor,onPlan,onSword;const HomeScreen({super.key,required this.onOutdoor,required this.onPlan,required this.onSword});')
text=text.replace("actions:[IconButton(tooltip:'Profilo e impostazioni'", "actions:[IconButton(tooltip:'Tutti gli esercizi',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Tutti gli esercizi')),body:const LibraryScreen()))),icon:const Icon(Icons.video_library_outlined)),IconButton(tooltip:'Profilo e impostazioni'")
text=text.replace("['A','B','C','D','W']", "['A','B','C','D','D2','W']")
old='  try { await store.startWorkout(code,compact:compact);'
new='''  if(code=='D2' && store.draft==null) {
    final accepted=await confirm(context,'Due spade · pratica guidata',
      'Questa seduta è da svolgere con un istruttore: due simulatori leggeri, movimenti a vuoto e nessun contatto.',action:'Inizia con istruttore');
    if(!accepted || !context.mounted)return;
  }
  try { await store.startWorkout(code,compact:compact);'''
assert old in text
p.write_text(text.replace(old,new))
edit('lib/src/app.dart',"part 'shell.dart';", "part 'shell.dart';\npart 'dojo_screen.dart';")
edit('lib/src/workout_screen.dart','if(!exercise.timed)SizedBox',"if(!exercise.timed && exercise.group!='Spada')SizedBox")
edit('lib/src/video_screen.dart','videoId:id,autoPlay:false,params:', "videoId:id,autoPlay:false,startSeconds:number(widget.media['startSeconds']),params:")
p=ROOT/'lib/src/settings_screen.dart';p.write_text(p.read_text().replace('2.0.0-beta.2','2.0.1'))
p=ROOT/'tool/bootstrap_android.py';text=p.read_text()
old='gradle.write_text(text)'
new='''text = re.sub(r'applicationId\\s*=\\s*"[^\"]+"', 'applicationId = "it.zoroforge.zoro_forge.dojo"', text)
gradle.write_text(text)'''
assert old in text
p.write_text(text.replace(old,new))
p=ROOT/'android_overlay/app/src/main/AndroidManifest.xml';text=p.read_text().replace('android:label="Zoro Forge"','android:label="Zoro Forge Dojo"').replace('android:name=".MainActivity"','android:name="it.zoroforge.zoro_forge.MainActivity"');p.write_text(text)
p=ROOT/'assets/catalog.json'; catalog=json.loads(p.read_text()); pack=json.loads((ROOT/'assets/sword_pack.json').read_text())
catalog['exercises'].update(pack['exercises']);catalog['programs'].update(pack['programs']);p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'test/domain_test.dart';text=p.read_text().replace('Catalog has 25 exercises','Catalog has 33 exercises').replace('catalog.exercises.length,25','catalog.exercises.length,33');p.write_text(text)
print('Sword programmes, native Spada tab and private hero slot prepared.')
