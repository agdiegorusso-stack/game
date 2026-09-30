# Verifiche Voce 0.2.0

Data: 30 settembre 2026.

## Effettuate

- Lettura DOM in sessione LinkedIn autenticata: 5 post personali, 2 commenti di altri autori sul post più recente, una risposta propria su un altro post distinguibile tramite URL autore.
- Feed: estrazione di autore, testo e numero di commenti in layout SDUI; contenuti sponsorizzati identificati. Link del menu Incorpora espone l’URN del post senza leggere cookie o chiamare endpoint privati.
- Menu “Più recenti” selezionabile per leggere i commenti; il controllo indica la selezione riuscita.
- 21 test Python superati: identità, deduplicazione, commenti gestiti, modifiche del contenuto, scadenza, snapshot parziali, blocchi, autenticazione API, generazione simulata e assenza di endpoint di pubblicazione.
- Sintassi JavaScript e Python verificata.

## GitHub Actions

Il workflow esegue analisi Flutter, test UI/archivio/sincronizzazione browser, controlli di ranking Dart e test Python prima di compilare l’APK. Salva le quattro anteprime UI, checksum e rapporto di firma. Fare riferimento al risultato del run del commit consegnato, non al precedente run 0.1.1.

## Ancora da verificare sul dispositivo e computer di destinazione

- Ciclo Playwright completo e ripetuto, riapertura del profilo dedicato e comportamento dopo modifiche del layout LinkedIn.
- Login Google nel browser dedicato (il login del browser di ChatGPT non viene trasferito).
- API HTTPS raggiungibile dal telefono, autenticazione con la propria chiave Voce.
- Risposta del modello AI reale; tutti i test di generazione usano risposte simulate.
- Installazione/aggiornamento Android, archivio cifrato e condivisione nativa sul telefono.
- Thread lunghi e repliche profonde: la raccolta è limitata e segnala copertura parziale, non garantisce lettura esaustiva.

Nessun hosting operativo attivato. Nessuna chiamata AI a pagamento o pubblicazione LinkedIn eseguita durante lo sviluppo.
