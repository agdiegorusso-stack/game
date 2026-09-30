import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'domain.dart';
import 'platform_services.dart';

class AppStore extends ChangeNotifier {
  final Api api = Api();
  String profile = profileSeed;
  String voice = voiceSeed;
  String examples = '';
  List<String> interests = [
    'sanità',
    'infermier',
    'healthtech',
    'intelligenza artificiale',
    'ai ',
    'nutrizione',
    'software',
  ];
  List<Json> comments = [];
  List<Json> posts = [];
  List<Json> drafts = [];
  Json status = {};
  String error = '';
  bool loading = false;
  bool generating = false;
  bool ready = false;
  bool active = true;
  bool storageReadable = true;
  bool _closed = false;
  Timer? timer;
  Future<void> _saveQueue = Future.value();

  Future<void> init() async {
    try {
      final raw = await Device.read('workspace');
      if (raw != null && raw.isNotEmpty) {
        final d = jsonDecode(raw) as Json;
        profile = d['profile'] ?? profileSeed;
        voice = d['voice'] ?? voiceSeed;
        examples = d['examples'] ?? '';
        interests = List<String>.from(d['interests'] ?? interests);
        comments = (d['comments'] as List? ?? [])
            .map((x) => Json.from(x))
            .toList();
        posts = (d['posts'] as List? ?? []).map((x) => Json.from(x)).toList();
        drafts = (d['drafts'] as List? ?? []).map((x) => Json.from(x)).toList();
        api.base = d['base'] ?? '';
      }
      api.token = await Device.read('server_token') ?? '';
      purge();
    } catch (_) {
      storageReadable = false;
      error =
          'Non è stato possibile leggere i dati salvati. Riprova prima di aggiungere contenuti.';
    }
    if (_closed) return;
    ready = true;
    notifyListeners();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!active) return;
      purge();
      notifyListeners();
      if (api.configured) refresh();
    });
    if (api.configured) await refresh();
  }

  void purge() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    comments.removeWhere(
      (c) =>
          c['source'] == 'linkedin_api' &&
          now - (c['fetched_at'] as num? ?? 0) >= 172800,
    );
    drafts.removeWhere(
      (d) => d['expires_at'] is num && (d['expires_at'] as num) <= now,
    );
  }

  Future<void> save() {
    if (!storageReadable)
      return Future.error(
        ApiException(
          'Archivio non leggibile: riavvia l’app. I dati esistenti non sono stati sovrascritti.',
        ),
      );
    final snapshot = jsonEncode({
      'profile': profile,
      'voice': voice,
      'examples': examples,
      'interests': interests,
      'comments': comments,
      'posts': posts,
      'drafts': drafts,
      'base': api.base,
    });
    final token = api.token;
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      try {
        await Device.write('workspace', snapshot);
        await Device.write('server_token', token);
      } catch (_) {
        error =
            'Salvataggio non riuscito: tieni aperta l’app e copia le bozze importanti.';
        notifyListeners();
        rethrow;
      }
    });
    notifyListeners();
    return _saveQueue;
  }

  Future<void> refresh({bool sync = false}) async {
    if (_closed || loading || !api.configured || !storageReadable) return;
    loading = true;
    error = '';
    notifyListeners();
    try {
      if (sync) {
        final r = await api.call('/v1/sync', data: {});
        if ((r['errors'] as List? ?? []).isNotEmpty)
          error = (r['errors'] as List).join('\n');
      }
      status = await api.call('/v1/status');
      final inbox = await api.call('/v1/inbox');
      final items = (inbox['items'] as List).map((x) => Json.from(x)).toList();
      comments = [
        ...comments.where((x) => x['source'] != 'linkedin_api'),
        ...items,
      ];
      purge();
      await save();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> configure({
    required String base,
    required String token,
    required String bio,
    required String style,
    required String samples,
    required List<String> topics,
  }) async {
    if (base.isNotEmpty && !Api.validBase(base))
      throw ApiException(
        'Usa HTTPS, senza parametri o credenziali nell’indirizzo.',
      );
    if (bio.trim().isEmpty || style.trim().isEmpty)
      throw ApiException('Compila profilo e voce editoriale.');
    final changedServer = api.base != base || api.token != token;
    api.base = base.trim();
    api.token = token.trim();
    profile = bio;
    voice = style;
    examples = samples;
    interests = topics.where((x) => x.trim().isNotEmpty).toList();
    if (changedServer) {
      status = {};
      comments.removeWhere((x) => x['source'] == 'linkedin_api');
    }
    await save();
    if (api.configured) {
      await api.call(
        '/v1/profile',
        data: {'profile': profile, 'voice': voice, 'examples': examples},
      );
      await refresh();
    }
  }

  Future<Json> generate(
    String kind,
    String text, {
    String parent = '',
    String sources = '',
    String instruction = '',
    Json? origin,
  }) async {
    if (generating) throw ApiException('Una generazione è già in corso.');
    generating = true;
    notifyListeners();
    try {
      final output = await api.call(
        '/v1/generate',
        data: {
          'kind': kind,
          'text': text,
          'parent_post': parent,
          'sources': sources,
          'instruction': instruction,
          'profile': profile,
          'voice': voice,
          'examples': examples,
          'history': drafts
              .take(5)
              .map((d) => {'kind': d['kind'], 'text': d['text']})
              .toList(),
        },
      );
      final draft = <String, dynamic>{
        ...output,
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'kind': kind,
        'created_at': DateTime.now().toIso8601String(),
        'url': origin?['url'] ?? '',
        'state': 'bozza',
        'origin_id': origin?['id'],
        'source': origin?['source'] ?? 'manual',
      };
      if (origin?['source'] == 'linkedin_api')
        draft['expires_at'] = (origin!['fetched_at'] as num) + 172800;
      drafts.insert(0, draft);
      await save();
      return draft;
    } finally {
      generating = false;
      notifyListeners();
    }
  }

  Future<void> importItem(Json item, bool isComment) async {
    final target = isComment ? comments : posts;
    if (target.any(
      (x) =>
          x['text'] == item['text'] &&
          x['url'] == item['url'] &&
          x['author'] == item['author'],
    ))
      throw ApiException('Questo contenuto è già presente.');
    item['id'] = DateTime.now().microsecondsSinceEpoch.toString();
    item['source'] = 'manual';
    item['done'] = false;
    target.insert(0, item);
    await save();
  }

  Future<void> mark(Json item, bool done) async {
    if (item['source'] == 'linkedin_api')
      await api.call(
        '/v1/inbox/update',
        data: {'id': item['id'], 'done': done},
      );
    item['done'] = done;
    await save();
  }

  Future<void> demo() async {
    if (posts.any((p) => p['source'] == 'example')) return;
    posts.add({
      'id': 'demo-post',
      'source': 'example',
      'author': 'Esempio dimostrativo',
      'text':
          'Stiamo progettando un software per la documentazione infermieristica. Vorremmo capire quali passaggi ripetuti rendono più lento il lavoro e come coinvolgere chi lo userà prima di completare lo sviluppo. Quali prove pratiche fareste durante un turno simulato?',
      'url': '',
      'comments_count': 12,
      'published_at': DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    });
    comments.add({
      'id': 'demo-comment',
      'source': 'example',
      'author': 'Interlocutore di esempio',
      'text':
          'Come coinvolgeresti gli infermieri nella progettazione dell’app?',
      'parent_post':
          'Proposta dimostrativa: costruire un’app sanitaria partendo dalle attività concrete di chi la usa.',
      'url': '',
      'done': false,
    });
    await save();
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  void clearError() {
    error = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    timer?.cancel();
    super.dispose();
  }
}
