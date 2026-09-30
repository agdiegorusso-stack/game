import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain.dart';
import 'platform_services.dart';
import 'store.dart';

const ink = Color(0xFF122E2A);
const teal = Color(0xFF087F70);
const paper = Color(0xFFF5F6F2);
const muted = Color(0xFF64756F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoceApp());
}

class VoceApp extends StatelessWidget {
  const VoceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Voce',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        surface: paper,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -.8,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
        bodyMedium: TextStyle(height: 1.5, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9E2DC)),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFD7EEE6),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final store = AppStore();
  int tab = 0;
  bool shareOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Device.channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedAvailable') await checkShare();
    });
    store.init().then((_) => checkShare());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Device.channel.setMethodCallHandler(null);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    store.active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      store.refresh();
      checkShare();
    }
  }

  Future<void> checkShare() async {
    if (shareOpen) return;
    try {
      final text = await Device.sharedText();
      if (text != null && text.isNotEmpty && mounted) {
        shareOpen = true;
        await showImport(context, store, false, shared: text);
        shareOpen = false;
      }
    } catch (_) {
      shareOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'voce',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tag(
              store.api.configured ? 'SERVER CONFIGURATO' : 'MODALITÀ LOCALE',
              color: store.api.configured ? teal : muted,
            ),
          ),
        ],
      ),
      body: !store.ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  if (store.loading || store.generating)
                    const LinearProgressIndicator(minHeight: 2),
                  if (store.error.isNotEmpty)
                    MaterialBanner(
                      content: Text(
                        store.error,
                        style: const TextStyle(fontSize: 12),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            store.clearError();
                          },
                          child: const Text('Chiudi'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: switch (tab) {
                          0 => InboxPage(store: store),
                          1 => StudioPage(store: store),
                          2 => RadarPage(store: store),
                          _ => ProfilePage(store: store),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Risposte',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            label: 'Radar',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Profilo',
          ),
        ],
      ),
    ),
  );
}

void notice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

Future<void> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) notice(context, e.toString());
  }
}

Future<void> openLinkedIn(BuildContext context, String text) async {
  if (linkedInUrl(text) == null) {
    notice(context, 'Aggiungi un link LinkedIn valido per aprire il post.');
    return;
  }
  await attempt(context, () => Device.open(text));
}

class Tag extends StatelessWidget {
  final String label;
  final Color color;
  const Tag(this.label, {super.key, this.color = teal});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: .6,
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  const Panel({super.key, required this.child, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE1E7E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const Heading(this.eyebrow, this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: teal,
          ),
        ),
        const SizedBox(height: 9),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: muted, height: 1.5)),
      ],
    ),
  );
}

class Empty extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Widget action;
  const Empty({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.action,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        const SizedBox(height: 16),
        Icon(icon, size: 45, color: teal),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        action,
        const SizedBox(height: 12),
      ],
    ),
  );
}

class InboxPage extends StatefulWidget {
  final AppStore store;
  const InboxPage({super.key, required this.store});
  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final items = s.comments.where((x) => (x['done'] == true) == done).toList();
    final pending = s.comments.where((x) => x['done'] != true).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Heading(
          'CONVERSAZIONI',
          'Le risposte,\ncon la tua voce.',
          'Leggi il contesto. Scegli le parole. Continua il confronto.',
        ),
        Panel(
          color: ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: s.loading || !s.api.configured
                        ? null
                        : () => s.refresh(sync: true),
                    icon: const Icon(Icons.sync_rounded),
                    color: Colors.white,
                    disabledColor: Colors.white38,
                    tooltip: 'Sincronizza commenti',
                  ),
                ],
              ),
              const Text(
                'commenti da gestire',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                s.status['comment_access'] == true
                    ? (s.status['mode'] == 'browser' ? 'Commenti raccolti dal browser. Le risposte pronte compaiono qui; stato e copertura in Profilo.' : 'Monitoraggio server abilitato per i post registrati. Verifica gli errori in Profilo.')
                    : 'Collega il raccoglitore in Profilo per trovare qui i commenti e le risposte preparate automaticamente.',
                style: const TextStyle(color: Color(0xFFBED4CB), fontSize: 12),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Da gestire')),
                  ButtonSegment(value: true, label: Text('Gestiti')),
                ],
                selected: {done},
                onSelectionChanged: (v) => setState(() => done = v.first),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => showImport(context, s, true),
              icon: const Icon(Icons.add),
              tooltip: 'Importa commento',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          Empty(
            title: done
                ? 'Nessun commento gestito'
                : 'La tua coda parte da qui',
            description:
                'I commenti raccolti dal browser compariranno qui. Verifica il collegamento in Profilo; puoi anche aggiungere un contenuto a mano.',
            icon: Icons.forum_outlined,
            action: FilledButton.icon(
              onPressed: () => showImport(context, s, true),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi commento'),
            ),
          ),
        for (final item in items) CommentCard(item: item, store: s),
        const Text(
          '“Gestito” è uno stato personale: copiare un testo non equivale a pubblicarlo.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

class CommentCard extends StatelessWidget {
  final Json item;
  final AppStore store;
  const CommentCard({super.key, required this.item, required this.store});
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tag(
              item['source'] == 'linkedin_browser'
                  ? 'DAL BROWSER'
                  : item['source'] == 'linkedin_api'
                  ? 'LINKEDIN API'
                  : item['source'] == 'example'
                  ? 'ESEMPIO • NON REALE'
                  : 'IMPORTATO',
            ),
            if (item['draft'] != null) const Tag('BOZZA PRONTA'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          item['author'] ?? 'Commento importato',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SelectableText(
          item['text'] ?? '',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        if ((item['parent_post'] ?? '').toString().isNotEmpty)
          ExpansionTile(
            key: PageStorageKey('comment-context-${item['id']}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: const Text(
              'Contesto del post',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(item['parent_post']),
              ),
              if ((item['parent_comment'] ?? '').toString().isNotEmpty)
                Text('Replica precedente: ${item['parent_comment']}'),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: store.generating
                  ? null
                  : () => attempt(context, () async {
                      if (item['draft'] is Map) {
                        final d = <String, dynamic>{
                          ...Json.from(item['draft']),
                          'kind': 'reply',
                          'url': item['url'],
                          'id': 'api-${item['id']}',
                          'source': item['source'],
                          'state': 'bozza',
                          'expires_at': (item['fetched_at'] as num) + 172800,
                        };
                        final existing = store.drafts
                            .where((x) => x['id'] == d['id'])
                            .firstOrNull;
                        if (existing == null) {
                          store.drafts.insert(0, d);
                          await store.save();
                        }
                        if (context.mounted)
                          await showDraft(context, store, existing ?? d);
                      } else {
                        final draft = await store.generate(
                          'reply',
                          item['text'],
                          parent: item['parent_post'] ?? '',
                          instruction:
                              'Replica precedente: ${item['parent_comment'] ?? ''}',
                          origin: item,
                        );
                        if (context.mounted)
                          await showDraft(context, store, draft);
                      }
                    }),
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: Text(
                item['draft'] != null ? 'Apri risposta' : 'Prepara risposta',
              ),
            ),
            OutlinedButton(
              onPressed: () => openLinkedIn(context, item['url'] ?? ''),
              child: const Text('Apri post'),
            ),
            TextButton(
              onPressed: () => attempt(
                context,
                () => store.mark(item, item['done'] != true),
              ),
              child: Text(
                item['done'] == true ? 'Da gestire' : 'Segna gestito',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class StudioPage extends StatefulWidget {
  final AppStore store;
  const StudioPage({super.key, required this.store});
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final topic = TextEditingController();
  final sources = TextEditingController();
  final instruction = TextEditingController();
  @override
  void dispose() {
    topic.dispose();
    sources.dispose();
    instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Heading(
          'STUDIO EDITORIALE',
          'Un punto di vista.\nIl tuo.',
          'Dalle tue idee a un post che aggiunge qualcosa alla conversazione.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('SANITÀ · TECNOLOGIA · LAVORO'),
              const SizedBox(height: 18),
              TextField(
                controller: topic,
                minLines: 3,
                maxLines: 7,
                maxLength: 12000,
                decoration: const InputDecoration(
                  labelText: 'Di cosa vuoi parlare?',
                  hintText: 'La tesi, il problema concreto, la tua opinione…',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'Software in reparto':
                        'Come valuterei un software per un reparto prima di adottarlo: osservare un’attività, contare i passaggi ripetuti e raccogliere le difficoltà degli utilizzatori. Presentala come proposta, senza inventare sperimentazioni.',
                    'Costruire NUTRIMI':
                        'Sono infermiere e ho sviluppato NUTRIMI. Voglio discutere il valore di coinvolgere gli utenti nelle scelte di sviluppo, senza inventare risultati o feedback.',
                    'AI e responsabilità':
                        'Per un progetto di AI sanitaria, quali errori scegliamo di misurare e come decidiamo quando serve una verifica umana? Scrivi come riflessione di progettazione, non come consiglio clinico.',
                  }.entries)
                    ActionChip(
                      label: Text(entry.key),
                      onPressed: () => topic.text = entry.value,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: sources,
                minLines: 2,
                maxLines: 5,
                maxLength: 12000,
                decoration: const InputDecoration(
                  labelText: 'Fatti e fonti disponibili',
                  hintText:
                      'Incolla gli estratti pertinenti e i relativi link. Il solo link non viene letto.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instruction,
                maxLength: 3000,
                decoration: const InputDecoration(
                  labelText: 'Indicazione per questa bozza',
                  hintText: 'Es. più diretto, senza domanda finale',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: s.generating
                      ? null
                      : () => attempt(context, () async {
                          if (topic.text.trim().isEmpty)
                            throw ApiException(
                              'Scrivi prima il tema del post.',
                            );
                          final d = await s.generate(
                            'post',
                            topic.text.trim(),
                            sources: sources.text.trim(),
                            instruction: instruction.text.trim(),
                          );
                          if (context.mounted) await showDraft(context, s, d);
                        }),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    s.generating
                        ? 'Sto preparando il testo…'
                        : 'Scrivi la bozza',
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Il tuo quaderno',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (s.drafts.isEmpty)
          const Panel(
            child: Text(
              'Le bozze e le tue modifiche restano qui. La generazione richiede il servizio AI configurato in Profilo.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final d in s.drafts)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tag(
                      d['kind'] == 'post'
                          ? 'POST'
                          : d['kind'] == 'reply'
                          ? 'RISPOSTA'
                          : 'COMMENTO',
                    ),
                    const Spacer(),
                    Tag(
                      (d['state'] ?? 'bozza').toString().toUpperCase(),
                      color: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  d['text'] ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => showDraft(context, s, d),
                      child: const Text('Apri e modifica'),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        final ok = await confirm(
                          context,
                          'Eliminare questa bozza?',
                        );
                        if (ok) {
                          s.drafts.remove(d);
                          if (context.mounted) await attempt(context, s.save);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Elimina bozza',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RadarPage extends StatefulWidget {
  final AppStore store;
  const RadarPage({super.key, required this.store});
  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  String query = '';
  bool relevantOnly = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final entries =
        s.posts
            .map((p) => (p, rankPost(p, s.interests)))
            .where(
              (r) =>
                  (!relevantOnly || r.$2.score >= 45) &&
                  '${r.$1['text']} ${r.$1['author']}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList()
          ..sort((a, b) => b.$2.score.compareTo(a.$2.score));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Heading(
          'RADAR',
          'Scegli dove\ncontribuire.',
          'I post selezionati per te, con il commento già pronto.',
        ),
        Panel(
          color: const Color(0xFFE8EFE6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: teal, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.status['feed_access'] == true
                      ? 'Post raccolti dal tuo feed e ordinati per i tuoi temi. La selezione copre i contenuti caricati dal browser; il punteggio non garantisce visibilità.'
                      : 'Il raccoglitore deve essere acceso e collegato a LinkedIn. Configura il tuo server in Profilo per ricevere i post del feed.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showImport(context, s, false),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi post'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () =>
                  openLinkedIn(context, 'https://www.linkedin.com/feed/'),
              child: const Text('Apri feed'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cerca nei post',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Solo priorità ≥ 45',
            style: TextStyle(fontSize: 14),
          ),
          subtitle: const Text(
            'Punteggio editoriale, non stima di reach',
            style: TextStyle(fontSize: 12),
          ),
          value: relevantOnly,
          onChanged: (v) => setState(() => relevantOnly = v),
        ),
        if (entries.isEmpty)
          Empty(
            title: 'Trova la prossima conversazione',
            description:
                'Il feed raccolto dal browser arriverà qui con una selezione per i tuoi argomenti. Controlla lo stato in Profilo.',
            icon: Icons.radar_rounded,
            action: OutlinedButton(
              onPressed: () => showImport(context, s, false),
              child: const Text('Importa un contenuto'),
            ),
          ),
        for (final record in entries)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tag(
                            record.$1['source'] == 'example'
                                ? 'ESEMPIO • NON REALE'
                                : record.$1['source'] == 'linkedin_browser'
                                ? 'DAL TUO FEED'
                                : 'IMPORTATO',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            record.$1['author'] ?? 'Autore non indicato',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F0E9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${record.$2.score}',
                            style: const TextStyle(
                              color: teal,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(fontSize: 10, color: teal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SelectableText(
                  record.$1['text'],
                  style: const TextStyle(height: 1.5),
                ),
                ExpansionTile(
                  key: PageStorageKey('radar-reasons-${record.$1['id']}'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Perché questo punteggio?',
                    style: TextStyle(fontSize: 13),
                  ),
                  children: [
                    for (final reason in record.$2.reasons)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            reason,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Parole chiave fino a 55 punti, recenza 20, numero di commenti 15, testo disponibile 10. I dati mancanti non ricevono bonus. Il punteggio non valuta la verità del post.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: s.generating
                          ? null
                          : () => attempt(context, () async {
                              final d = record.$1['draft'] is Map
                                  ? <String, dynamic>{
                                      ...Json.from(record.$1['draft']),
                                      'id': 'browser-draft-${record.$1['id']}',
                                      'kind': 'comment',
                                      'url': record.$1['url'],
                                      'source': record.$1['source'],
                                      'state': 'bozza',
                                      'expires_at': (record.$1['fetched_at'] as num) + 172800,
                                    }
                                  : await s.generate(
                                      'comment', record.$1['text'], origin: record.$1,
                                    );
                              if (context.mounted)
                                await showDraft(context, s, d);
                            }),
                      icon: const Icon(Icons.auto_awesome, size: 17),
                      label: Text(record.$1['draft'] is Map ? 'Leggi commento pronto' : 'Proponi commento'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          openLinkedIn(context, record.$1['url'] ?? ''),
                      child: const Text('Apri post'),
                    ),
                    TextButton(
                      onPressed: () => attempt(context, () async {
                        s.posts.remove(record.$1);
                        await s.save();
                      }),
                      child: const Text('Rimuovi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showImport(
  BuildContext context,
  AppStore store,
  bool isComment, {
  String shared = '',
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        ImportSheet(store: store, isComment: isComment, shared: shared),
  );
}

class ImportSheet extends StatefulWidget {
  final AppStore store;
  final bool isComment;
  final String shared;
  const ImportSheet({
    super.key,
    required this.store,
    required this.isComment,
    this.shared = '',
  });
  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  final body = TextEditingController();
  final parent = TextEditingController();
  final author = TextEditingController();
  final url = TextEditingController();
  final count = TextEditingController();
  final age = TextEditingController();
  late bool comment;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    comment = widget.isComment;
    final match = RegExp(r'https://[^\s]+').firstMatch(widget.shared);
    if (match != null && linkedInUrl(match.group(0)!) != null)
      url.text = match.group(0)!;
    body.text = widget.shared
        .replaceAll(url.text.isEmpty ? '\u0000' : url.text, '')
        .trim();
  }

  @override
  void dispose() {
    for (final c in [body, parent, author, url, count, age]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      22,
      22,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Porta qui il contesto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Post del feed')),
            ButtonSegment(value: true, label: Text('Commento')),
          ],
          selected: {comment},
          onSelectionChanged: (v) => setState(() => comment = v.first),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: author,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Autore (facoltativo)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          minLines: 4,
          maxLines: 10,
          maxLength: 18000,
          decoration: InputDecoration(
            labelText: comment
                ? 'Testo del commento'
                : 'Testo completo del post',
            hintText: 'Il solo link non contiene il contesto necessario.',
          ),
        ),
        const SizedBox(height: 12),
        if (comment) ...[
          TextField(
            controller: parent,
            minLines: 3,
            maxLines: 6,
            maxLength: 18000,
            decoration: const InputDecoration(
              labelText: 'Il tuo post originale',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Link LinkedIn (facoltativo)',
          ),
        ),
        const SizedBox(height: 12),
        if (!comment) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'N. commenti'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ore dalla pubblicazione',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'I contenuti importati vengono salvati sul dispositivo. Quando chiedi una bozza, il testo e il profilo vengono inviati al tuo server e al servizio AI configurato.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: saving
                ? null
                : () => attempt(context, () async {
                    if (body.text.trim().isEmpty ||
                        (comment && parent.text.trim().isEmpty))
                      throw ApiException(
                        'Inserisci il contenuto e, per una risposta, anche il post originale.',
                      );
                    if (url.text.trim().isNotEmpty &&
                        linkedInUrl(url.text) == null)
                      throw ApiException(
                        'Il link deve essere un indirizzo HTTPS di LinkedIn.',
                      );
                    final n = int.tryParse(count.text);
                    final h = int.tryParse(age.text);
                    if (!comment &&
                        ((count.text.isNotEmpty && (n == null || n < 0)) ||
                            (age.text.isNotEmpty &&
                                (h == null || h < 0 || h > 87600))))
                      throw ApiException(
                        'Usa numeri interi positivi per commenti e ore.',
                      );
                    setState(() => saving = true);
                    try {
                      await widget.store.importItem({
                        'author': author.text.trim().isEmpty
                            ? 'Autore non indicato'
                            : author.text.trim(),
                        'text': body.text.trim(),
                        'parent_post': parent.text.trim(),
                        'url': url.text.trim(),
                        'comments_count': n,
                        'published_at': h == null
                            ? null
                            : DateTime.now()
                                  .subtract(Duration(hours: h))
                                  .toIso8601String(),
                      }, comment);
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  }),
            child: const Text('Aggiungi'),
          ),
        ),
      ],
    ),
  );
}

Future<void> showDraft(BuildContext context, AppStore store, Json draft) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DraftPage(store: store, draft: draft),
    ),
  );
}

class DraftPage extends StatefulWidget {
  final AppStore store;
  final Json draft;
  const DraftPage({super.key, required this.store, required this.draft});
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  late final TextEditingController text;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.draft['text']);
    text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  bool get dirty => text.text != widget.draft['text'];
  Future<void> persist() async {
    widget.draft['text'] = text.text;
    await widget.store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final flags = [
      ...(widget.draft['checks'] as List? ?? []).map((x) => x.toString()),
      ...editorialChecks(text.text),
    ];
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final discard = await confirm(
            context,
            'Uscire senza salvare le modifiche?',
          );
          if (discard && context.mounted) {
            text.text = widget.draft['text'];
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Rivedi la bozza')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Tag('DA RIVEDERE'),
                if (widget.draft['engine'] != null)
                  Tag('AI · ${widget.draft['engine']}'),
              ],
            ),
            const SizedBox(height: 16),
            if ((widget.draft['rationale'] ?? '').toString().isNotEmpty)
              Panel(
                color: const Color(0xFFE8EFE6),
                child: Text(widget.draft['rationale']),
              ),
            TextField(
              controller: text,
              minLines: 10,
              maxLines: 24,
              maxLength: 3000,
              decoration: const InputDecoration(
                labelText: 'Il testo è tuo: modificalo liberamente',
              ),
            ),
            const SizedBox(height: 18),
            if (flags.isNotEmpty)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Da controllare',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final f in flags)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '• $f',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            const Text(
              'Questi controlli editoriali non verificano le fonti e non certificano che il testo sembri umano.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: saving || text.text.trim().isEmpty
                      ? null
                      : () => attempt(context, () async {
                          setState(() => saving = true);
                          try {
                            await persist();
                            await Clipboard.setData(
                              ClipboardData(text: text.text),
                            );
                            if (context.mounted)
                              notice(
                                context,
                                'Testo copiato. Puoi incollarlo su LinkedIn.',
                              );
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        }),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salva e copia'),
                ),
                OutlinedButton(
                  onPressed: () => attempt(context, () async {
                    await persist();
                    if (context.mounted) notice(context, 'Bozza salvata.');
                  }),
                  child: const Text('Salva'),
                ),
                OutlinedButton(
                  onPressed: () => openLinkedIn(
                    context,
                    (widget.draft['url'] ?? '').toString().isEmpty
                        ? 'https://www.linkedin.com/feed/'
                        : widget.draft['url'],
                  ),
                  child: const Text('Apri LinkedIn'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ho pubblicato questo testo'),
              subtitle: const Text(
                'Contrassegno manuale: non invia nulla a LinkedIn.',
              ),
              value: widget.draft['state'] == 'pubblicato',
              onChanged: (v) => attempt(context, () async {
                widget.draft['state'] = v ? 'pubblicato' : 'bozza';
                await persist();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final AppStore store;
  const ProfilePage({super.key, required this.store});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController bio, voice, examples, topics, base, token;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final s = widget.store;
    bio = TextEditingController(text: s.profile);
    voice = TextEditingController(text: s.voice);
    examples = TextEditingController(text: s.examples);
    topics = TextEditingController(text: s.interests.join(', '));
    base = TextEditingController(text: s.api.base);
    token = TextEditingController(text: s.api.token);
  }

  @override
  void dispose() {
    for (final c in [bio, voice, examples, topics, base, token]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Heading(
          'PROFILO & CONNESSIONI',
          'La tua identità,\nprima dell’algoritmo.',
          'La voce iniziale riprende il tuo dossier editoriale. Aggiornala con le tue correzioni.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: bio,
                minLines: 3,
                maxLines: 7,
                maxLength: 6000,
                decoration: const InputDecoration(
                  labelText: 'Fatti personali utilizzabili',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: voice,
                minLines: 4,
                maxLines: 9,
                maxLength: 6000,
                decoration: const InputDecoration(
                  labelText: 'Come vuoi scrivere',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: examples,
                minLines: 2,
                maxLines: 8,
                maxLength: 10000,
                decoration: const InputDecoration(
                  labelText: 'Testi tuoi approvati (facoltativi)',
                  hintText:
                      'Usa esempi che riconosci come tuoi, non vecchie bozze mai approvate.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: topics,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Parole chiave per il radar',
                  hintText: 'Separate da virgole',
                ),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Il tuo servizio AI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'L’app usa il server incluso nel progetto. La chiave del fornitore AI resta sul server; qui inserisci soltanto la chiave di accesso a Voce.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: base,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Indirizzo server HTTPS',
                  hintText: 'https://voce.tuo-dominio.it',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: token,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Chiave di accesso a Voce',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () => attempt(context, () async {
                          setState(() => saving = true);
                          try {
                            await s.configure(
                              base: base.text,
                              token: token.text,
                              bio: bio.text,
                              style: voice.text,
                              samples: examples.text,
                              topics: topics.text
                                  .split(',')
                                  .map((x) => x.trim())
                                  .toList(),
                            );
                            if (context.mounted)
                              notice(context, 'Impostazioni salvate.');
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        }),
                  child: Text(saving ? 'Salvataggio…' : 'Salva impostazioni'),
                ),
              ),
              TextButton(
                onPressed: !s.api.configured ? null : () => s.refresh(),
                child: const Text('Verifica connessione'),
              ),
              if (s.status.isNotEmpty) ...[
                const Divider(),
                statusRow('Generazione AI', s.status['ai'] == true),
                statusRow(
                  'Sessione LinkedIn',
                  s.status['linkedin_connected'] == true,
                ),
                statusRow(
                  s.status['mode'] == 'browser' ? 'Lettura commenti verificata' : 'Permesso lettura dichiarato',
                  s.status['comment_access'] == true,
                ),
                const SizedBox(height: 8),
                Text(
                  s.status['mode'] == 'browser' ? 'La sessione deve restare attiva sul computer o server. Ultima lettura e copertura sono mostrate sotto.' : 'Il permesso dichiarato viene verificato effettivamente alla prima lettura di un post.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commenti dei tuoi post',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                s.status['mode'] == 'api' ? 'La modalità API richiede permessi LinkedIn già approvati.' : 'Il browser dedicato raccoglie i tuoi post, i commenti e il feed sul computer o server. Voce riceve i risultati anche dopo che il telefono è rimasto chiuso. L’accesso iniziale e le verifiche di LinkedIn si completano nel browser.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if ((s.status['error'] ?? '').toString().isNotEmpty)
                Text(
                  s.status['error'],
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              if (s.status['mode'] == 'browser') ...[
                BrowserStatus(store: s),
              ] else if (s.status['mode'] == 'api') Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: !s.api.configured
                        ? null
                        : () => attempt(context, () async {
                            final r = await s.api.call(
                              '/v1/oauth/start',
                              data: {},
                            );
                            final u = Uri.parse(r['url']);
                            if (u.scheme != 'https' ||
                                u.host != 'www.linkedin.com' ||
                                u.path != '/oauth/v2/authorization')
                              throw ApiException('Indirizzo OAuth non valido.');
                            await Device.open(u.toString());
                          }),
                    child: const Text('Collega LinkedIn'),
                  ),
                  OutlinedButton(
                    onPressed: !s.api.configured
                        ? null
                        : () => registerDialog(context, s),
                    child: const Text('Monitora un post'),
                  ),
                  TextButton(
                    onPressed: s.status['linkedin_connected'] != true
                        ? null
                        : () => attempt(context, () async {
                            await s.api.call('/v1/disconnect', data: {});
                            await s.refresh();
                          }),
                    child: const Text('Scollega'),
                  ),
                ],
              ),
              for (final p in s.status['posts'] as List? ?? [])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p['text'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    (p['error'] ?? '').toString().isNotEmpty
                        ? p['error']
                        : p['checked'] == null
                        ? 'In attesa della prima lettura'
                        : 'Ultima lettura: ${DateTime.fromMillisecondsSinceEpoch(((p['checked'] as num) * 1000).round()).toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: s.status['mode'] == 'browser' ? null : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => attempt(context, () async {
                      await s.api.call(
                        '/v1/posts/remove',
                        data: {'urn': p['urn']},
                      );
                      await s.refresh();
                    }),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                s.status['auto_draft'] == true && s.status['ai'] == true
                    ? 'Preparazione automatica di risposte e commenti attiva sul server.'
                    : 'Bozze automatiche disattivate. Puoi attivarle sul server dopo aver configurato il servizio AI.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dati e modalità di prova',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Archivio locale cifrato con Android Keystore. Contenuti raccolti dal browser o dalle API: conservazione locale e server limitata a 48 ore. Bozze manuali e importazioni restano fino alla rimozione. Nessun tracciamento analitico.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => attempt(context, () async {
                  await s.demo();
                  if (context.mounted)
                    notice(
                      context,
                      'Aggiunti esempi chiaramente contrassegnati.',
                    );
                }),
                child: const Text('Carica due esempi dimostrativi'),
              ),
              TextButton(
                onPressed: () => attempt(context, () async {
                  if (!await confirm(
                    context,
                    'Eliminare importazioni e bozze dal dispositivo?',
                  ))
                    return;
                  s.posts.clear();
                  s.comments.clear();
                  s.drafts.clear();
                  await s.save();
                  if (context.mounted)
                    notice(
                      context,
                      'Archivio locale svuotato. I commenti monitorati sul server riappariranno al prossimo aggiornamento.',
                    );
                }),
                child: const Text('Svuota archivio locale'),
              ),
            ],
          ),
        ),
        const Text(
          'Voce 0.1.1 · Progetto indipendente, non affiliato a LinkedIn.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget statusRow(String label, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: ok ? teal : muted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          ok ? 'Pronto' : 'Da configurare',
          style: TextStyle(color: ok ? teal : muted, fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> registerDialog(BuildContext context, AppStore store) async {
  final urn = TextEditingController();
  final body = TextEditingController();
  final url = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Monitora un tuo post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Usa l’URN restituito dalle API LinkedIn. Un activity ID nel link non garantisce lo stesso ID di share o ugcPost.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urn,
              decoration: const InputDecoration(
                labelText: 'URN share oppure ugcPost',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'Link al post'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 7,
              maxLength: 18000,
              decoration: const InputDecoration(
                labelText: 'Testo del tuo post',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => attempt(ctx, () async {
            await store.api.call(
              '/v1/posts',
              data: {
                'urn': urn.text.trim(),
                'text': body.text.trim(),
                'url': url.text.trim(),
              },
            );
            await store.refresh();
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('Aggiungi'),
        ),
      ],
    ),
  );
  // The dialog's closing animation may still use its controllers.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  urn.dispose();
  body.dispose();
  url.dispose();
}


class BrowserStatus extends StatelessWidget {
  final AppStore store;
  const BrowserStatus({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final b = Json.from(store.status['browser'] as Map? ?? {});
    final names = <String, String>{
      'ready': 'Ultima raccolta riuscita', 'partial': 'Raccolta con copertura parziale',
      'collecting': 'Lettura in corso', 'paused': 'Raccolta in pausa',
      'blocked': 'LinkedIn richiede una verifica', 'login_required': 'Accedi nel browser sul computer',
      'layout_changed': 'Contenuti non riconosciuti', 'wrong_profile': 'Controlla il profilo collegato',
      'error': 'Raccolta interrotta', 'idle': 'Sessione pronta: avvia il raccoglitore',
    };
    final at = b['at'] as num?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Text(names[b['state']] ?? 'In attesa del raccoglitore', style: const TextStyle(fontWeight: FontWeight.w700)),
      if (at != null) Text('Ultimo aggiornamento: ${DateTime.fromMillisecondsSinceEpoch((at * 1000).round()).toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 12, color: muted)),
      if (b['fresh'] == false) const Text('Il raccoglitore non comunica da tempo. Verifica che il computer o server sia acceso.', style: TextStyle(color: Colors.deepOrange, fontSize: 12)),
      if (b['posts_count'] != null) Text('${b['posts_count']} post personali • ${b['feed_count']} post nel radar', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: store.loading ? null : () => store.refresh(sync: true), icon: const Icon(Icons.sync), label: const Text('Richiedi lettura')),
        TextButton(onPressed: () => attempt(context, () async {
          await store.api.call('/v1/browser/control', data: {'enabled': b['enabled'] == false});
          await store.refresh();
        }), child: Text(b['enabled'] == false ? 'Riprendi raccolta' : 'Metti in pausa')),
      ]),
    ]);
  }
}
