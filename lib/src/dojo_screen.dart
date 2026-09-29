part of 'app.dart';
class HeroArtwork extends StatelessWidget {
  const HeroArtwork({super.key});
  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: AspectRatio(aspectRatio: 1100 / 1376,
      child: Image.asset('assets/hero.png', key: const ValueKey('original-hero-artwork'),
        fit: BoxFit.cover, alignment: Alignment.topCenter,
        semanticLabel: 'Immagine del tuo percorso Zoro Forge',
        errorBuilder: (_, error, trace) => const ColoredBox(color: panel,
          child: Center(child: Text('Immagine non disponibile'))),
      ),
    ),
  );
}
class DojoScreen extends StatelessWidget {
  const DojoScreen({super.key});
  @override Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final completed = store.history.where((w) => ['D', 'D2'].contains(w.program) && w.complete).length;
    return ListView(key: const PageStorageKey('sword-page'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Text('Allenamento\ncon la spada', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text('Tecnica, controllo e coordinazione.', style: TextStyle(color: muted)),
        const SizedBox(height: 18),
        FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('IL TUO DOJO', style: TextStyle(color: lime, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('$completed sedute completate', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Parti dai fondamentali con una spada. Due brevi sedute a settimana, separate dagli allenamenti più faticosi delle spalle.', style: TextStyle(color: muted)),
        ])),
        const SizedBox(height: 16),
        if (store.draft != null) ...[
          FilledButton.icon(onPressed: () => launchWorkout(context, store.draft!.program),
            icon: const Icon(Icons.play_arrow), label: Text('Riprendi seduta ${store.draft!.program} aperta')),
          const SizedBox(height: 14),
        ],
        SwordSessionCard(code: 'D', title: 'Una spada · fondamentali',
          subtitle: '6 esercizi · circa 15–20 minuti',
          exercises: List<String>.from(store.catalog.programs['D']!['ids']).map((id) => store.catalog.exercises[id]!).toList(),
          onStart: () => launchWorkout(context, 'D'), onExercise: (id) => openExercise(context, id),
          startLabel: store.draft == null ? 'Inizia con una spada' : 'Riprendi seduta aperta'),
        const SizedBox(height: 20),
        SwordSessionCard(code: 'D2', title: 'Due spade · con istruttore',
          subtitle: '2 esercizi di impostazione · pratica guidata',
          exercises: List<String>.from(store.catalog.programs['D2']!['ids']).map((id) => store.catalog.exercises[id]!).toList(),
          onStart: () => launchWorkout(context, 'D2'), onExercise: (id) => openExercise(context, id),
          startLabel: store.draft == null ? 'Apri seduta guidata' : 'Riprendi seduta aperta'),
        const SizedBox(height: 16),
        const FCard(child: Text('Usa un simulatore leggero adatto all’allenamento, in uno spazio libero anche sopra la testa. Esercizi a vuoto, senza lame affilate o contatto. Fai controllare la tecnica a un maestro.')),
        const SizedBox(height: 8),
        const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Il percorso verso le tre spade'), children: [
          Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Una spada: fondamentali. Due spade: coordinazione con istruttore. Per la parte scenica, la terza resta nel fodero come accessorio: non si allena tenendo una spada tra i denti.')),
        ]),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Tutti gli esercizi')), body: const LibraryScreen()))),
          icon: const Icon(Icons.video_library_outlined), label: const Text('Apri tutta la videoteca')),
      ],
    );
  }
}
class SwordSessionCard extends StatelessWidget {
  final String code, title, subtitle, startLabel;
  final List<Exercise> exercises;
  final VoidCallback onStart;
  final ValueChanged<String> onExercise;
  const SwordSessionCard({super.key, required this.code, required this.title, required this.subtitle, required this.exercises, required this.onStart, required this.onExercise, required this.startLabel});
  @override Widget build(BuildContext context) => FCard(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted)), const SizedBox(height: 12),
      for (final e in exercises) ListTile(contentPadding: EdgeInsets.zero, minLeadingWidth: 24,
        leading: const Icon(Icons.play_circle_outline, color: lime), title: Text(e.name),
        subtitle: Text('${e.sets} × ${e.target} · ${e.rest} s recupero'), onTap: () => onExercise(e.id)),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(
        key: ValueKey('start-sword-$code'), onPressed: onStart,
        icon: const Icon(Icons.sports_martial_arts), label: Text(startLabel))),
    ]),
  );
}
