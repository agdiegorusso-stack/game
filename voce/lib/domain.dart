import 'dart:math' as math;

typedef Json = Map<String, dynamic>;

const profileSeed =
    '''Diego Russo. Infermiere presso ASL Roma 2 e sviluppatore di applicazioni. Fondatore di NUTRIMI. Scrivo di sanità digitale partendo dai problemi assistenziali, di sviluppo software e di uso responsabile dell'AI. Non parlo a nome del datore di lavoro. Non attribuirmi titoli, risultati clinici, numeri o episodi personali non forniti.''';
const voiceSeed =
    '''Italiano naturale, diretto, lucido e competente. Una tesi precisa e dettagli concreti; niente adulazione, enfasi da guru, metafore automatiche o antitesi ripetute. Commenti di norma 40–100 parole, senza hashtag e senza promozione forzata di NUTRIMI. Le domande finali devono servire al confronto. Non inventare pazienti, turni, dialoghi, statistiche o citazioni. Contestare le idee senza attribuire intenzioni. Le mie correzioni hanno priorità su queste indicazioni.''';

class Opportunity {
  final int score;
  final List<String> reasons;
  const Opportunity(this.score, this.reasons);
}

/// Editorial heuristic, not a LinkedIn algorithm or a reach prediction.
Opportunity rankPost(Json post, List<String> interests, {DateTime? now}) {
  final body = (post['text'] ?? '').toString().toLowerCase();
  final matches = interests
      .map((t) => t.trim().toLowerCase())
      .toSet()
      .where(
        (t) =>
            t.isNotEmpty &&
            (t.length <= 2
                ? RegExp(
                    '(^|[^a-zà-ÿ0-9])${RegExp.escape(t)}([^a-zà-ÿ0-9]|\u0024)',
                  ).hasMatch(body)
                : body.contains(t)),
      )
      .toSet();
  final relevance = math.min(55, matches.length * 18);
  final parsed = DateTime.tryParse((post['published_at'] ?? '').toString());
  final age = parsed == null
      ? null
      : (now ?? DateTime.now()).difference(parsed).inMinutes / 60;
  final fresh = age == null || age < 0
      ? 0
      : age <= 6
      ? 20
      : age <= 24
      ? 14
      : age <= 72
      ? 6
      : 0;
  final count = post['comments_count'] is num
      ? (post['comments_count'] as num).toInt()
      : null;
  final room = count == null || count < 0
      ? 0
      : count < 10
      ? 15
      : count < 50
      ? 10
      : count < 200
      ? 5
      : 0;
  final detail = body.length >= 180 ? 10 : 0;
  final reasons = <String>[
    matches.isEmpty
        ? 'Nessuna parola chiave dei tuoi temi rilevata'
        : 'Temi: ${matches.join(', ')}',
    parsed == null
        ? 'Data non disponibile: nessun bonus'
        : age! < 0
        ? 'Data futura: da verificare'
        : 'Recenza: +$fresh',
    count == null
        ? 'Commenti non noti: nessun bonus'
        : 'Spazio nella discussione: +$room',
    'Contesto disponibile: +$detail',
  ];
  return Opportunity(
    (relevance + fresh + room + detail).toInt().clamp(0, 100),
    reasons,
  );
}

String? linkedInUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty)
    return null;
  if (uri.host != 'linkedin.com' && !uri.host.endsWith('.linkedin.com'))
    return null;
  return uri.toString();
}

List<String> editorialChecks(String text) {
  final flags = <String>[];
  final lower = text.toLowerCase();
  for (final phrase in [
    'condivido pienamente',
    'nel mondo in continua evoluzione',
    'e voi cosa ne pensate',
    'rivoluzionerà tutto',
    'cambierà tutto',
  ]) {
    if (lower.contains(phrase))
      flags.add('Valuta una formulazione più concreta: «$phrase»');
  }
  if (RegExp(r'\d+\s*%').hasMatch(text))
    flags.add('Controlla fonte, periodo e denominatore delle percentuali.');
  if (text.length > 3000)
    flags.add('Testo oltre 3.000 caratteri: accorcia il post.');
  if (RegExp(
    r'\b(paziente|ieri in reparto|durante il turno)\b',
    caseSensitive: false,
  ).hasMatch(text))
    flags.add(
      'Verifica che ogni episodio personale sia reale e condivisibile.',
    );
  return flags;
}
