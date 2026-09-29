import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoro_forge/src/app.dart';
void main(){
  testWidgets('Small viewport empty GPS has no overflow',(tester)async{
    tester.view.physicalSize=const Size(360,780);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:forgeTheme,home:const Scaffold(body:Padding(padding:EdgeInsets.all(20),child:RouteMap(points:[],tiles:false)))));
    expect(find.text('In attesa del percorso'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('Seven weekday cells',(tester)async{
    await tester.pumpWidget(MaterialApp(theme:forgeTheme,home:const Scaffold(body:WeekStrip(days:[1,3,5]))));
    expect(find.byIcon(Icons.fitness_center),findsNWidgets(3));expect(find.byIcon(Icons.remove),findsNWidgets(4));
  });
  testWidgets('Measurement dialog rejects empty input',(tester)async{
    await tester.pumpWidget(MaterialApp(theme:forgeTheme,home:const Scaffold(body:MeasurementDialog())));
    await tester.tap(find.text('Salva'));await tester.pump();
    expect(find.text('Inserisci peso 30–400 kg e/o girovita 30–250 cm.'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
