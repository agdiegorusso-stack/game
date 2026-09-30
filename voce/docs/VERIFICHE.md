# Verifiche — Voce 0.1.0

Eseguite il 30 settembre 2026.

## Esito

- **11 test del backend Python superati**, incluso un test HTTP locale: autenticazione, limiti dei payload, assenza di endpoint di pubblicazione, accessi mancanti, validazione URL/URN, deduplicazione, conservazione dello stato gestito, invalidazione della bozza dopo una modifica, paginazione, repliche, scadenza dati, rimozione monitoraggio, rate limit, OAuth monouso/scaduto, scadenza token e scope concessi, formato AI, risposta automatica preparata una sola volta e consegnata nella coda.
- **9 controlli Dart della logica superati**: ordinamento pertinente/recente, dati mancanti, date future, parole duplicate, host ingannevoli, credenziali in URL, link validi e controlli editoriali.
- `dart format` completato su tutti i file Dart.
- `dart analyze lib`: **No issues found**. Analisi effettuata collegando il codice alle librerie Flutter/sky_engine dell’SDK 3.47.5 disponibile; non equivale a una compilazione Android con tutte le dipendenze risolte da Pub.
- XML Android, YAML e sintassi Python validati.

## Blocchi effettivamente osservati

`flutter pub get --offline` non riesce: il pacchetto `leak_tracker_flutter_testing` richiesto da `flutter_test` non è nella cache. Il tentativo di contattare Pub dalla rete di esecuzione non ha raggiunto il servizio.

`flutter build apk --debug --no-pub` termina con **No Android SDK found**. Nessun APK è stato creato. Il pacchetto contiene il progetto sorgente; il file `.dart_tool/package_config.json` usato per l’analisi locale non è distribuito. Eseguire `flutter pub get` su un ambiente completo.

## Non eseguito

- Compilazione Kotlin/Gradle e installazione su telefono/emulatore.
- Esecuzione dei due widget test in `test/widget_test.dart` (inclusi per il prossimo ambiente completo).
- Ispezione visiva delle schermate renderizzate e prova con tastiera, accessibilità e dimensioni diverse.
- Android Keystore, riapertura dopo arresto del processo, condivisione a caldo/a freddo e apertura del browser su dispositivo.
- API LinkedIn e OpenAI reali: credenziali e permessi non disponibili. Le risposte remote nei test sono simulate, non traffico dell’account di Diego.
- Deploy Docker/Caddy, HTTPS pubblico e workflow GitHub: inclusi come configurazione, non attivati.

## Prova da completare prima dell’uso abituale

1. `flutter pub get`, `flutter analyze`, `flutter test test/widget_test.dart`, `flutter build apk --debug`.
2. Aprire app vuota, importare un post e un commento, chiudere/riaprire e verificare che i testi restino.
3. Provare Condividi da LinkedIn (link solo e link+testo), modifica bozza, salvataggio, copia e ritorno da LinkedIn. La copia non deve pubblicare o contrassegnare automaticamente.
4. Configurare il proprio server HTTPS e modello; generare una bozza e verificare il contesto inviato e il risultato.
5. Solo se i permessi sono approvati: autorizzare LinkedIn, registrare un proprio post con URN corretto e verificare commento nuovo, replica, modifica, token scaduto e limite API.
6. Provare la cancellazione e la scadenza del contenuto API; verificare la conservazione dei dati anche sul proprio hosting e nei backup.

Il superamento dei test offline non dimostra che LinkedIn abbia concesso l’accesso o che il servizio produca crescita di visibilità. La selezione del radar è un’euristica editoriale dichiarata nell’app.
