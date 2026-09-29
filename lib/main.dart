import 'package:flutter/material.dart';
import 'src/app.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await AppStore.open();
    runApp(ZoroApp(store: store));
  } catch (error) {
    runApp(MaterialApp(theme: forgeTheme, home: Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.storage_rounded, size: 56), const SizedBox(height: 24),
        const Text('Archivio non disponibile', style: TextStyle(fontSize: 24)), const SizedBox(height: 12),
        const Text('I dati non sono stati cancellati. Chiudi e riapri l’app. Se il problema resta, conserva questa schermata.'),
        const SizedBox(height: 12), SelectableText('$error'),
      ]),
    )))));
  }
}
