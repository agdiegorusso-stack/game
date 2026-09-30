# Verifiche — Voce 0.1.1

Eseguite il 30 settembre 2026 con GitHub Actions, Flutter 3.47.5 e JDK 17.

## Esito dei controlli

- `flutter pub get`: completato.
- `flutter analyze`: nessun problema rilevato.
- **4 test dell’interfaccia superati**: avvio senza dati fittizi; importazione e rilettura di autore/testo dopo ricreazione dell’app; navigazione sulle quattro schermate a larghezze di 360 e 430 pixel senza overflow. La persistenza nei widget test usa un canale Android simulato.
- **9 controlli Dart della logica superati**: ranking, dati mancanti, date future, parole duplicate, validazione degli indirizzi e controlli editoriali.
- **11 test Python superati**, incluso un test HTTP locale: autenticazione, limiti dei payload, assenza di pubblicazione automatica, accessi mancanti, URL/URN, deduplicazione, stato gestito, invalidazione bozze, paginazione, repliche, scadenza dati, rimozione monitoraggio, rate limit, OAuth, scope, formato AI e risposta automatica preparata una sola volta.
- `flutter build apk --release --target-platform android-arm64`: riuscito, inclusa compilazione Kotlin/Gradle.
- Firma APK v2 verificata da `apksigner`; certificato Android Debug per uso di prova.
- Pacchetto `it.diegorusso.voce_linkedin`, versione `0.1.1`, versionCode `2`, minSdk `24`, targetSdk `36`; sola ABI `arm64-v8a`.
- File APK: 17.596.552 byte. Il checksum locale coincide con quello generato su GitHub.
- Archivio Actions verificato contro il digest SHA256 fornito da GitHub. Controllate visivamente le quattro schermate renderizzate dai widget test con caratteri Roboto e icone Material.

SHA256 APK: `876f8ea7140697dfc4afc660cc96f29ea4c2b20dad3af1d45894d1036d606d7b`.

SHA256 del certificato: `7df78618e941682024044fc8ab57c4317fa0ec7935769d05b9a33e8771e46896`.

Run: https://github.com/agdiegorusso-stack/game/actions/runs/36714581170

Commit del codice sottoposto ai controlli: `f1b0b8e2e98bc3580b63c81805d6d015f01f73b0`.

## Da verificare sul telefono e con i servizi reali

- Installazione, Android Keystore, riapertura dopo arresto del processo, tastiera, accessibilità e condivisione Android a caldo/a freddo. I test di persistenza dell’interfaccia non sostituiscono una prova dell’archivio nativo.
- API LinkedIn e AI reali: credenziali e permessi non disponibili. Le risposte remote nei test sono simulate.
- Distribuzione del backend, DNS, HTTPS e collegamento dell’app al server.

La firma debug è destinata a prove personali. Per aggiornamenti continuativi e distribuzione configurare una propria chiave di firma stabile: una nuova chiave generata dal runner non permette di aggiornare un’installazione firmata diversamente.

## Prima prova sul dispositivo

1. Installare l’APK; importare un post e un commento, chiudere e riaprire l’app per verificare i testi salvati.
2. Provare Condividi da LinkedIn, modifica, copia e ritorno al post. La copia non pubblica e non contrassegna automaticamente il contenuto.
3. Configurare server HTTPS e modello AI; generare una bozza e controllare contesto e risultato.
4. Solo con i permessi già approvati: collegare LinkedIn, registrare un post con URN corretto e controllare nuovi commenti, repliche, modifiche e scadenza del token.

I test non attestano che LinkedIn abbia concesso l’accesso. Il radar ordina i post importati con un’euristica editoriale; non prevede crescita o impressioni.
