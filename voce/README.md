# Voce — assistente LinkedIn personale

Flutter Android, versione **0.2.0+3**, 30 settembre 2026. Progetto personale per Diego Russo, indipendente da LinkedIn. Raccolta tramite browser dedicato, senza Unipile.

## Cosa fa

- **Risposte:** scopre i post del profilo, legge i commenti caricati e prepara risposte con il contesto del post. Esclude i propri commenti e riconosce le proprie repliche quando sono caricate.
- **Radar:** legge il feed, esclude sponsorizzazioni e post propri, ordina per temi, recenza e spazio nella discussione; prepara un commento per i contenuti più pertinenti. Il punteggio è una regola editoriale, non una previsione di visibilità.
- **Studio:** genera post usando profilo, voce, argomento e fonti testuali forniti nell’app.
- **Profilo:** stato della raccolta, ultima lettura, copertura parziale, pausa/ripresa, configurazione server e temi.

Il computer raccoglie e prepara le bozze anche con il telefono chiuso. L’app scarica i risultati quando è aperta, ogni minuto. Nessuna notifica push o pubblicazione automatica: l’utente legge, modifica e copia le bozze.

## Stato verificato

Il lettore DOM è stato provato in una sessione LinkedIn autenticata: cinque post personali riconosciuti, due commenti ricevuti sul post più recente, feed e sponsorizzazioni distinguibili. Verificato anche il menu “Più recenti”. Sono prove di lettura, **non una verifica del servizio continuo su un computer di produzione**.

Il backend supera 21 test automatici, con AI simulata. La build Android 0.2.0 è compilata e verificata: [run riuscito 36783249049](https://github.com/agdiegorusso-stack/game/actions/runs/36783249049), con 6 test Flutter e 9 controlli Dart oltre ai test Python. Non è stato configurato un server operativo né effettuata una chiamata AI a pagamento: installare l’APK da solo non attiva l’automazione. Occorrono computer/server, sessione LinkedIn dedicata e chiave API AI.

## Avvio sul proprio computer

Servono Python 3.11+, un desktop disponibile per l’accesso iniziale e un account AI API. Usare un computer acceso durante la raccolta. Dal checkout del repository, entrare in `voce/`:

```bash
python3 -m venv .venv
# Linux/macOS:
source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install -r browser/requirements.txt
python -m playwright install chromium
python scripts/configure.py
```

Aprire privatamente `.env`. Impostare:

- `LINKEDIN_MODE=browser`;
- `LINKEDIN_PROFILE_URL`: URL del proprio profilo (già predisposto per Diego Russo);
- `OPENAI_API_KEY` e `OPENAI_MODEL`: chiave e modello del proprio account API compatibile con Chat Completions e output JSON;
- `AUTO_DRAFT=true` per preparare le bozze senza premere Genera;
- `POLL_SECONDS=900`: intervallo, minimo 15 minuti in modalità browser.

`configure.py` genera `VOCE_APP_TOKEN`, una chiave distinta per collegare il telefono. Non incollare password, cookie o chiavi in chat e non caricare `.env` su GitHub.

```bash
python -m browser.collector login
```

Si apre un browser dedicato: accedere direttamente a LinkedIn, con Google se disponibile, e completare eventuali verifiche. Quando compare il feed, premere Invio nel terminale. La sessione resta nel profilo locale `browser/private-profile`, escluso da Git. Il login effettuato nel browser di ChatGPT non viene esportato in questo profilo.

```bash
python scripts/start_browser.py
```

Il comando avvia API e raccoglitore sullo **stesso computer e database**. Lasciare aperto il processo; Ctrl+C chiude entrambi. Per provare un solo ciclo: `python -m browser.collector once`. Per riavviare dopo un blocco/sessione scaduta, chiudere il servizio, eseguire nuovamente `login`, poi `start_browser.py`. Non avviare due processi sullo stesso profilo browser.

### Collegare l’APK

Per il telefono la build release richiede **HTTPS**. Esporre l’API locale attraverso un reverse proxy HTTPS configurato sul proprio dominio, lasciando il servizio Python su `127.0.0.1:8787`. Nell’app, sezione Profilo, inserire URL HTTPS e `VOCE_APP_TOKEN`; salvare profilo, voce e temi. Questo invia al server le impostazioni editoriali necessarie alla generazione automatica.

La cartella include un esempio Caddy/Docker per la sola API. **`docker compose up` non avvia il browser**: per questa modalità usare il comando sopra e un reverse proxy che raggiunga quel processo. Una futura distribuzione su server richiede un desktop remoto per il login e lo stesso database condiviso fra API e raccoglitore. Non sono inclusi hosting, dominio o chiavi API.

Per sviluppo, una build debug può usare `http://10.0.2.2:8787` sull’emulatore o `adb reverse tcp:8787 tcp:8787` con `http://127.0.0.1:8787` via USB. HTTP remoto non è consentito dall’app.

## Funzionamento e limiti della raccolta

Ogni ciclo esamina fino a 10 post personali e 20 schede del feed caricate, selezionandone fino a 10. Usa i controlli normali della pagina, fino a quattro scorrimenti e dodici espansioni per thread. Non rappresenta tutto il feed né tutta la cronologia. Un thread non completamente caricato resta indicato come parziale; non cancella commenti precedenti soltanto perché non sono più visibili nella pagina.

Il browser legge la pagina renderizzata e i link dei menu, senza chiamare endpoint privati, esportare cookie o alterare l’identità del browser. Il percorso attività con `skipRedirect=true` conserva il layout osservato per i commenti; non è un’interfaccia stabile. Modifiche a LinkedIn possono richiedere manutenzione. La selezione dei post e i testi estratti sono stati verificati; il ciclo Playwright completo sul computer di destinazione resta da provare.

Il processo si ferma quando vede login, verifiche di sicurezza o richieste rifiutate. Non risolve CAPTCHA né aggira blocchi. LinkedIn vieta varie forme di automazione non autorizzata e può limitare l’account: l’uso del browser non elimina questo rischio.

L’AI riceve testo raccolto, contesto e impostazioni editoriali. Non apre i link presenti nei post. I commenti composti da solo URL restano in coda senza risposta automatica. Ogni passaggio prepara al massimo tre risposte e tre commenti, con una pausa di un minuto fra passaggi e cinque minuti dopo un errore. L’uso consuma il proprio credito API. Le bozze devono essere controllate prima di pubblicarle.

## Dati

- Archivio Android cifrato con Android Keystore, backup automatico disattivato.
- Contenuti raccolti e bozze associate scadono dopo 48 ore dalla prima acquisizione o da una modifica del testo. Un contenuto può essere acquisito nuovamente dopo la scadenza.
- Per 30 giorni il server conserva hash/identificatori dei commenti e stato gestito per evitare che commenti invariati ricompaiano come nuovi.
- Importazioni e bozze manuali restano finché rimosse. Dati di sessione restano nel profilo browser fino al logout/rimozione locale.
- SQLite e profilo browser sono protetti da permessi filesystem, non cifrati dall’app: conservarli su un disco protetto. Log senza cookie, token o testi dei post.

## Compilazione e test

Flutter **3.47.5**, JDK 17, Android SDK. Android soltanto; i canali di archiviazione/condivisione non hanno implementazione iOS/web.

```bash
flutter pub get
flutter analyze
flutter test
dart test/domain_smoke.dart
python3 -m unittest discover -s backend -p 'test*.py' -v
flutter build apk --release --target-platform android-arm64
```

APK ARM64 in `build/app/outputs/flutter-apk/app-release.apk`. Firma debug per prove personali, non per distribuzione pubblica. La firma generata da un nuovo runner può differire dalla versione precedente: in tal caso Android rifiuta l’aggiornamento. Salvare le bozze importanti prima di un’eventuale disinstallazione, che cancella l’archivio.

Codice: [agdiegorusso-stack/game, ramo voce/flutter-apk](https://github.com/agdiegorusso-stack/game/tree/voce/flutter-apk/voce). Workflow `Voce Flutter APK`, artifact con APK, checksum e verifica firma. `main` non è modificato.

## File principali

- `browser/collector.py`, `browser/extract.js`: raccolta e lettura del DOM;
- `browser/support.py`: identità, collegamenti e ranking;
- `backend/server.py`: sincronizzazione, deduplicazione, generazione AI e API per l’app;
- `lib/store.dart`, `lib/main.dart`: sincronizzazione, code e stato del browser;
- `backend/test*.py`, `test/`: verifiche del servizio e dell’app;
- `docs/VERIFICHE.md`: evidenze e prove ancora necessarie.

La modalità API ufficiale precedente rimane disponibile con `LINKEDIN_MODE=api` per chi ha permessi LinkedIn approvati; non offre la lettura automatica del feed personale.

Fonti tecniche: [Playwright Python](https://playwright.dev/python/docs/api/class-browsertype), [LinkedIn Comments API](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/comments-api), [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat), [Flutter SDK](https://docs.flutter.dev/install/archive).
