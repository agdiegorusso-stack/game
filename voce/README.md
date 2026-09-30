# Voce — assistente LinkedIn personale

Prima versione Flutter per **Android**, personalizzata sul dossier editoriale di Diego Russo. Versione 0.1.1, 30 settembre 2026. App indipendente, non affiliata a LinkedIn.

## Stato reale della consegna

**APK Android ARM64 compilato e verificato su GitHub Actions.** Il [run riuscito](https://github.com/agdiegorusso-stack/game/actions/runs/36714581170) include il file `Voce-0.1.1-Android-arm64.apk` (17,6 MB), checksum e verifica della firma. Richiede Android 7.0 o successivo. Build release ottimizzata con firma debug per prove personali.

Sono superati analisi Flutter, quattro test dell’interfaccia, nove controlli della logica Dart e undici test Python. Le quattro schermate sono state renderizzate e controllate visivamente nei widget test; vedi `docs/VERIFICHE.md`.

**AI e collegamento LinkedIn non sono ancora attivi:** occorre configurare il backend e le proprie credenziali. Installazione, archivio cifrato e condivisione vanno provati sul telefono. Non sono state eseguite chiamate live a LinkedIn o all’AI. Il radar lavora sui post importati.

## Le tre funzioni

| Sezione | Implementazione | Cosa serve |
|---|---|---|
| Risposte | Commenti con post originale, coda da gestire/gestiti, generazione di risposte, modifica e copia. Polling sul server dei post registrati, deduplicazione, lettura delle repliche dirette, errori visibili. | Importazione manuale subito dopo l’installazione. Per la lettura automatica servono permessi LinkedIn già approvati e URN dei post. Per generare serve l’AI configurata. |
| Studio | Post coerenti con profilo e voce, istruzioni per singola bozza, estratti delle fonti, esempi approvati, archivio bozze. | Server e chiave API AI. I link da soli non vengono aperti; fornire il testo delle fonti. |
| Radar | Ordinamento dei post importati per temi, recenza, numero di commenti e quantità di contesto. Spiegazione del punteggio, filtro e proposta di commento. | Condividere o incollare i post dal feed. Il feed LinkedIn personale **non viene letto automaticamente**. |

Non ci sono endpoint di pubblicazione, reazioni o messaggistica automatica. Copiare una risposta non la segna come pubblicata. “Gestito” e “Ho pubblicato” sono contrassegni manuali. Il punteggio del radar è un’euristica trasparente, non una previsione di impressioni, follower o Top Voice.

## Compilare e aprire l’app

Toolchain di riferimento: Flutter **3.47.5**, JDK 17 e Android SDK configurato con `flutter doctor`. Il progetto Android è stato creato con questa versione del template Flutter; usare la stessa versione evita incompatibilità con il Gradle generato. Solo Android è implementato: i canali di archiviazione e condivisione non hanno una versione iOS/web.

```bash
flutter pub get
flutter analyze
flutter test test/widget_test.dart
flutter build apk --release --target-platform android-arm64
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. Installarlo con `adb install -r build/app/outputs/flutter-apk/app-release.apk` oppure aprirlo sul telefono. La firma debug serve per prove personali; configurare una firma release propria prima di distribuire. La configurazione generata di release usa ancora la firma debug.

Il progetto è nel repository [agdiegorusso-stack/game](https://github.com/agdiegorusso-stack/game/tree/voce/flutter-apk/voce), ramo `voce/flutter-apk`, cartella `voce/`. Il workflow **Voce Flutter APK** parte a ogni modifica del progetto su questo ramo e si può avviare manualmente. Compila solo se analisi e test passano e salva l’APK ARM64, il checksum e i rapporti di verifica come artifact del run. Il ramo principale del repository resta separato.

## Attivare il servizio AI

Il backend usa Python 3.11+ e la sola libreria standard. È per un solo utente; non esporlo come servizio multiutente. La chiave AI resta sul server. L’app conserva una chiave separata di accesso a Voce, cifrata sul telefono.

```bash
python3 scripts/configure.py
```

Lo script crea `.env` con una chiave casuale e lascia vuote le credenziali esterne. Modificare il file privatamente, impostando:

- `OPENAI_API_KEY`: chiave del proprio progetto API;
- `OPENAI_MODEL`: ID di un modello disponibile nel proprio account, compatibile con Chat Completions, JSON mode e `max_completion_tokens`;
- `VOCE_DOMAIN`: dominio con DNS diretto al proprio server, se si usa Docker/Caddy.

La generazione invia profilo, voce, contenuto, fonti incollate e ultime bozze al modello. Non è alimentata dall’abbonamento a questa conversazione e usa il proprio account API. Non è stata effettuata alcuna chiamata AI a pagamento durante la creazione del progetto. Non inserire dati identificativi dei pazienti.

Avvio locale per sviluppo:

```bash
python3 scripts/run_server.py
```

In un emulatore Android, con build debug, impostare in Profilo `http://10.0.2.2:8787` e la `VOCE_APP_TOKEN` generata. Per un telefono collegato via USB si può usare `adb reverse tcp:8787 tcp:8787` e `http://127.0.0.1:8787` nella build debug. Il traffico HTTP è limitato agli host locali/emulatore; la build release richiede HTTPS.

Per un telefono via Internet è necessario un server HTTPS. Il progetto include `compose.yaml` e `backend/Caddyfile`: dopo aver configurato dominio, DNS e `.env`, eseguire:

```bash
docker compose up -d --build
```

Aprire le porte 80/443 per Caddy. In Profilo inserire `https://<VOCE_DOMAIN>`, la chiave Voce, poi **Salva impostazioni**. Il servizio non è stato distribuito online durante questa attività.

## Collegare i commenti LinkedIn

Il semplice “Sign in with LinkedIn” non concede automaticamente lettura di commenti o feed. Le API Comments distinguono permessi personali e delle organizzazioni; `r_member_social_feed` è riservato a sviluppatori selezionati. LinkedIn indica anche `r_member_social` come permesso chiuso. Non esiste in questo progetto un aggiramento di questi limiti.

Se si dispone già dell’accesso approvato:

1. Impostare `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` e `LINKEDIN_REDIRECT_URI=https://<dominio>/oauth/linkedin/callback` anche nel portale sviluppatori.
2. Impostare in `LINKEDIN_SCOPES` **solo** i permessi effettivamente concessi alla propria app, personali oppure organizzativi. Non richiedere permessi di scrittura: qui non servono.
3. Nell’app premere **Collega LinkedIn**. La schermata di accesso è quella ufficiale, nel browser esterno; Voce non chiede la password LinkedIn.
4. Tornare nell’app e premere **Verifica connessione**. “Permesso dichiarato” è un controllo di configurazione; una lettura riuscita del post verifica davvero l’accesso.
5. Registrare i propri post con testo, link e URN ufficiale `urn:li:share:…` o `urn:li:ugcPost:…`, ottenuto dalle API del proprio account. Non sostituire arbitrariamente il prefisso di un activity ID: non è sempre lo stesso ID.
6. Aggiornare la coda o attendere il ciclo server. La scadenza del token richiede un nuovo collegamento. Errori 401/403/429 sono esposti, non presentati come sincronizzazioni riuscite.

In alternativa, per uno sviluppo già autorizzato, impostare un access token nel solo ambiente server (`LINKEDIN_ACCESS_TOKEN`) e i relativi scope. Il pulsante Scollega chiederà di rimuovere questa variabile: un token imposto nell’ambiente non può essere revocato cancellando il database locale.

Facoltativo: `LINKEDIN_OWN_ACTORS` (URN personali/organizzativi separati da spazi) esclude le proprie risposte dalla coda. Senza questo filtro possono comparire anche commenti propri.

Il server controlla al massimo 20 post, ogni 15 minuti per impostazione iniziale (minimo 5 minuti), fino a 2.000 elementi per thread. Non scopre automaticamente tutti i post del profilo e non segue ricorsivamente livelli arbitrari di repliche. Gli errori o limiti interrompono il relativo controllo e restano visibili. Nessuna notifica push è implementata: il server continua quando il telefono è chiuso, l’app aggiorna la coda in primo piano ogni minuto.

Per trovare risposte già preparate, dopo aver salvato il profilo sul server, impostare `AUTO_DRAFT=true`. Ogni ciclo genera al massimo tre bozze per commenti non gestiti e senza bozza, usando il proprio account API. È disattivato all’inizio per rendere la configurazione e l’uso del servizio espliciti.

## Usare il radar senza accesso API

Da LinkedIn: **Condividi → altre opzioni → Voce**, quando questa opzione è disponibile. Oppure copiare testo/link e aggiungerli nell’app. Android può consegnare solo l’URL: in questo caso l’importazione resta vuota finché non si aggiunge il testo.

Compilare autore, testo, link e, se disponibili, età del post e numero di commenti. Il radar non inventa i dati mancanti. Le parole chiave sono modificabili. Un post molto pertinente può meritare attenzione anche con poche reazioni; la correttezza del contenuto va valutata leggendo il testo.

Il pulsante **Carica due esempi dimostrativi** serve per esplorare la UI: ogni contenuto è marcato “ESEMPIO • NON REALE”. All’avvio non ci sono post, commenti o statistiche inventati.

## File principali

- `lib/main.dart`: schermate e flussi di modifica/importazione;
- `lib/domain.dart`: ranking e controlli editoriali;
- `lib/store.dart`: stato, sincronizzazione e archivio;
- `lib/platform_services.dart`: client HTTP e ponte Android;
- `android/.../MainActivity.kt`: condivisione, link esterni e archivio AES-GCM con Android Keystore;
- `backend/server.py`: API personale, OAuth LinkedIn, polling, deduplicazione e generazione AI;
- `backend/test_server.py`, `test/`: test del servizio, della logica e della UI;
- `docs/VERIFICHE.md`: cosa è stato effettivamente verificato e cosa resta da provare.

## Dati e limiti

L’archivio Android è cifrato e il backup automatico è disattivato. Se la chiave locale non è più disponibile, non si possono recuperare i dati cifrati; l’app evita di sovrascrivere un archivio non leggibile. Importazioni e bozze manuali restano finché vengono rimosse. I commenti ottenuti dalle API e le bozze derivate scadono dopo 48 ore dalla lettura memorizzata; un dato può essere acquisito nuovamente in una sincronizzazione successiva.

Sul server SQLite è protetto da permessi filesystem, **non** cifrato dall’app: usare un disco cifrato, proteggere `.env` e non includere database/token in backup condivisi. Il backend non registra URL OAuth completi, token o testi nei log. La rimozione su LinkedIn potrebbe restare visibile fino a un aggiornamento o alla scadenza. Verificare inoltre i vincoli del proprio accordo LinkedIn prima di mettere in produzione il trattamento e l’invio di dati API a un fornitore AI: la presenza degli scope non certifica ogni uso previsto.

## Fonti tecniche consultate il 30/09/2026

- Comments API e scope: https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/comments-api?view=li-lms-2026-09
- Community Management: https://learn.microsoft.com/en-us/linkedin/marketing/community-management/community-management-overview
- FAQ accessi: https://learn.microsoft.com/en-us/linkedin/marketing/lms-faq
- Usi consentiti e conservazione: https://learn.microsoft.com/en-us/linkedin/marketing/restricted-use-cases
- OpenAI Chat Completions: https://developers.openai.com/api/reference/resources/chat
- Flutter SDK: https://docs.flutter.dev/install/archive

La configurazione editoriale iniziale deriva dalle versioni correnti lette dei file `LINKEDIN_00_LEGGIMI.md`, `LINKEDIN_01_PROFILO_E_AUDIT.md`, `LINKEDIN_02_VOCE_EDITORIALE.md` e `LINKEDIN_03_REVISIONE_NATURALEZZA.md`. Nessuna vecchia bozza è stata inserita come campione approvato della voce dell’autore.
