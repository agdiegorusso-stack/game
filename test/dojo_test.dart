import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoro_forge/domain/models.dart';
import 'package:zoro_forge/src/app.dart';
void main() {
  late Catalog catalog;
  setUpAll(() => catalog=Catalog.decode(File('assets/catalog.json').readAsStringSync()));
  test('Six real sword exercises, not mobility placeholders', () {
    final ids=List<String>.from(catalog.programs['D']!['ids']);expect(ids.length,6);
    for(final id in ids) {final e=catalog.exercises[id]!;expect(e.group,'Spada');expect(e.videos.first['type'],'youtube');expect(youtubeId(e.videos.first['url']),isNotNull);expect(e.hasLoad,isFalse);}
  });
  test('Two-sword programme and legacy history remain readable', () {
    expect((catalog.programs['D2']!['ids'] as List).length,2);
    for(final id in ['mobility','balance','footwork']) {expect(catalog.exercises.containsKey(id),isTrue);}
  });
  test('Sword set check is manual and reversible', () {
    final ex=catalog.exercises['sword_suburi']!;final set=SetLog(value:8);
    expect(set.validate(ex),isNull);expect(set.done,isFalse);
    set.completed=DateTime.now();expect(set.done,isTrue);set.completed=null;expect(set.done,isFalse);
  });
  test('Video chapters retain the declared start point', () {
    expect(catalog.exercises['sword_suburi']!.videos.first['startSeconds'],1465);
    expect(catalog.exercises['sword_sequence']!.videos.first['startSeconds'],700);
  });
  testWidgets('Hero is an asset image, not a dumbbell replacement', (tester) async {
    await tester.pumpWidget(MaterialApp(theme:forgeTheme,home:const Scaffold(body:HeroArtwork())));
    final image=tester.widget<Image>(find.byKey(const ValueKey('original-hero-artwork')));
    expect((image.image as AssetImage).assetName,'assets/hero.png');expect(find.byIcon(Icons.fitness_center),findsNothing);
  });
  testWidgets('Sword exercises and start button fit a small screen', (tester) async {
    tester.view.physicalSize=const Size(360,780);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final ids=List<String>.from(catalog.programs['D']!['ids']);var tapped=false;
    await tester.pumpWidget(MaterialApp(theme:forgeTheme,home:Scaffold(body:SingleChildScrollView(child:SwordSessionCard(code:'D',title:'Una spada · fondamentali',subtitle:'6 esercizi',exercises:ids.map((id)=>catalog.exercises[id]!).toList(),onStart:(){tapped=true;},onExercise:(_){},startLabel:'Inizia con una spada')))));
    expect(find.text('Impugnatura a due mani'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('start-sword-D')));
    await tester.tap(find.byKey(const ValueKey('start-sword-D')));
    expect(tapped,isTrue);expect(tester.takeException(),isNull);
  });
}
