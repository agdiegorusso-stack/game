# Verifiche Voce 0.2.0

Data: 30 settembre 2026.

## Effettuate

- Lettura DOM in sessione LinkedIn autenticata: 5 post personali, 2 commenti di altri autori sul post più recente, una risposta propria su un altro post distinguibile tramite URL autore.
- Feed: estrazione di autore, testo e numero di commenti in layout SDUI; contenuti sponsorizzati identificati. Link del menu Incorpora espone l’URN del post senza leggere cookie o chiamare endpoint privati.
- Menu “Più recenti” selezionabile per leggere i commenti; il controllo indica la selezione riuscita.
- 21 test Python superati: identità, deduplicazione, commenti gestiti, modifiche del contenuto, scadenza, snapshot parziali, blocchi, autenticazione API, generazione simulata e assenza di endpoint di pubblicazione.
- Sintassi JavaScript e Python verificata.

## GitHub Actions

Nel run 36783249049 sono passati analisi Flutter, 6 test UI/archivio/sincronizzazione browser, 9 controlli di ranking Dart e 21 test Python prima della compilazione APK. Build completata con successo: [run 36783249049](https://github.com/agdiegorusso-stack/game/actions/runs/36783249049), commit `7aec74dce08142da00bce79c53c8842870b3d1d0`. APK 17.596.628 byte, SHA-256 `23efae916671d53794413e618075d6aa414cbdf29519c1ff9fa00adae5af276b`; firma APK v2 verificata. Android 7.0+, ARM64.

La firma debug è diversa da 0.1.1: non è possibile aggiornare direttamente quella installazione. Salvare le bozze prima di disinstallare; l’archivio locale viene cancellato. Fare riferimento al risultato del run del commit consegnato, non al precedente run 0.1.1.

## Ancora da verificare sul dispositivo e computer di destinazione

- Ciclo Playwright completo e ripetuto, riapertura del profilo dedicato e comportamento dopo modifiche del layout LinkedIn.
- Login Google nel browser dedicato (il login del browser di ChatGPT non viene trasferito).
- API HTTPS raggiungibile dal telefono, autenticazione con la propria chiave Voce.
- Risposta del modello AI reale; tutti i test di generazione usano risposte simulate.
- Installazione/aggiornamento Android, archivio cifrato e condivisione nativa sul telefono.
- Thread lunghi e repliche profonde: la raccolta è limitata e segnala copertura parziale, non garantisce lettura esaustiva.

Nessun hosting operativo attivato. Nessuna chiamata AI a pagamento o pubblicazione LinkedIn eseguita durante lo sviluppo.
