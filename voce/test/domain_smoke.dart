// Pure Dart; runs without the Flutter engine or network dependencies.
import '../lib/domain.dart';

void require(bool value, String label) {
  if (!value) throw StateError(label);
  print('PASS $label');
}

void main() {
  final now = DateTime.utc(2026, 9, 30, 12);
  final relevant = {
    'text': 'sanità software infermieri ${'contesto ' * 30}',
    'published_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
    'comments_count': 5,
  };
  final old = {
    'text': 'sport e calcio',
    'published_at': now.subtract(const Duration(days: 10)).toIso8601String(),
    'comments_count': 400,
  };
  require(
    rankPost(relevant, ['sanità', 'software', 'infermieri'], now: now).score >
        rankPost(old, ['sanità', 'software'], now: now).score,
    'contenuto pertinente e recente prioritario',
  );
  require(
    rankPost({'text': ''}, [], now: now).score == 0,
    'nessun bonus per dati sconosciuti',
  );
  require(
    rankPost(
          {
            'text': 'sanità',
            'published_at': now.add(const Duration(days: 1)).toIso8601String(),
          },
          ['sanità'],
          now: now,
        ).score ==
        18,
    'nessun bonus per date future',
  );
  require(
    rankPost(relevant, ['sanità', 'sanità'], now: now).score ==
        rankPost(relevant, ['sanità'], now: now).score,
    'parole duplicate non gonfiano il punteggio',
  );
  require(
    linkedInUrl('https://linkedin.com.evil.example/feed') == null,
    'blocca host ingannevoli',
  );
  require(
    linkedInUrl('https://evil@linkedin.com/feed') == null,
    'blocca credenziali nel link',
  );
  require(
    linkedInUrl('https://www.linkedin.com/feed/') != null,
    'accetta link LinkedIn HTTPS',
  );
  require(
    editorialChecks('Il risultato migliora del 90%.').isNotEmpty,
    'richiede verifica delle percentuali',
  );
  require(
    editorialChecks(
      'Vorrei capire come avete misurato i passaggi ripetuti.',
    ).isEmpty,
    'nessuna segnalazione arbitraria su testo ordinario',
  );
}
