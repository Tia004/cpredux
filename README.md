<p align="center">
  <img src="assets/branding/CPReduxLogo.png" alt="CPRedux Desktop — Cyberpunk RED Visualizer" width="520">
</p>

<p align="center">
  <img src="assets/branding/banner.svg" alt="CPRED Visualizer" width="100%">
</p>

<p align="center">
  <b>Suite Gestionale, Scheda Personaggio, Tavolo Dadi 3D e Mappa Interattiva di Night City.</b><br>
  Applicazione desktop nativa per <b>macOS</b>, <b>Windows</b> e <b>Linux</b>.<br>
  <i>(Software esclusivamente Desktop: nessun supporto né vincolo mobile per Android / iOS)</i><br>
  <sub>Progetto non ufficiale per Cyberpunk RED, sviluppato in conformità con la 
  <a href="https://rtalsoriangames.com/homebrew-content-policy/">Homebrew Content Policy</a> di R. Talsorian Games.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/release-v0.2.2-24d8e8?style=for-the-badge&logo=gitlab&logoColor=white" alt="Release v0.2.2">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-fcee0a?style=for-the-badge&logo=apple&logoColor=black" alt="Piattaforme">
  <img src="https://img.shields.io/badge/flutter-3.x-ff2e88?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter 3">
  <img src="https://img.shields.io/badge/license-MIT%20%2F%20Homebrew-blueviolet?style=for-the-badge" alt="Licenza">
</p>

<p align="center">
  <img src="assets/branding/divider.svg" width="100%">
</p>

## Release v0.2.2

Tutti i pacchetti ufficiali e gli installer sono scaricabili direttamente da [GitLab Releases](https://gitlab.com/Tia004/cpredux/-/releases).

### File di Rilascio

| Piattaforma | Architettura | Formato & Descrizione | Download Diretto |
| :--- | :--- | :--- | :--- |
| macOS | Apple Silicon (aarch64 / M1-M4) & Intel | Installer Disco Immagine (.dmg) | [Scarica Installer macOS DMG](https://gitlab.com/-/project/86426687/uploads/324cffde6104a5d091804d98e6eb9876/cpredux-v0.2.2-macos-arm64.dmg) |
| macOS | Universal (Apple Silicon & Intel) | Applicazione Standalone .app (ZIP) | [Scarica cpredux-macos-arm64.zip](https://gitlab.com/-/project/86426687/uploads/d4d340d8a904c0da78f5639e2f311f45/cpredux-v0.2.2-macos-arm64.zip) |
| Windows | x64 (Windows 10 / 11) | Installer Setup Diretto (.exe) | [Scarica Installer Windows EXE](https://gitlab.com/-/project/86426687/uploads/e695d891d296297fd487c2a0228df113/cpredux-v0.2.2-setup.exe) |
| Windows | x64 (Windows 10 / 11) | Pacchetto di Installazione Windows (.msi) | [Scarica Pacchetto Windows MSI](https://gitlab.com/-/project/86426687/uploads/4e0d935ae832b52d4f5580dcffad4112/cpredux-v0.2.2-setup.msi) |
| Linux | x86_64 / Desktop | Pacchetto Tarball + Launcher .desktop (.tar.gz) | [Scarica Pacchetto Linux Tar.gz](https://gitlab.com/-/project/86426687/uploads/e1aa4cdde0b1e18a0d2a49fa2b4a91b2/cpredux-v0.2.2-linux-x64.tar.gz) |
| Tutte le Release | Multi-Platform | Elenco completo versioni e archivio | [Pagina Releases Ufficiale GitLab](https://gitlab.com/Tia004/cpredux/-/releases) |
| Scheda Release v0.2.2 | Multi-Platform | Note di rilascio, novità e asset | [Release v0.2.2 Notes](https://gitlab.com/Tia004/cpredux/-/releases/v0.2.2) |
| Sorgenti (ZIP) | Multi-Platform | Archivio completo sorgenti v0.2.2 | [Scarica cpredux-v0.2.2.zip](https://gitlab.com/Tia004/cpredux/-/archive/v0.2.2/cpredux-v0.2.2.zip) |
| Sorgenti (Tar.gz) | Multi-Platform | Archivio compresso tarball v0.2.2 | [Scarica cpredux-v0.2.2.tar.gz](https://gitlab.com/Tia004/cpredux/-/archive/v0.2.2/cpredux-v0.2.2.tar.gz) |

### Novità introdotte

- **Compilazione diretta scheda vuota**: Possibilità di compilare immediatamente tutti i campi della scheda personaggio partendo da zero (statistiche, abilità, anagrafica, note, ecc.) senza dipendere da un file precaricato.
- **Guida e tooltip contestuali per la creazione personaggio**: Assistente integrato e tooltip informativi dettagliati che guidano passo-passo nell'assegnazione dei punti caratteristica, abilità e selezione del ruolo secondo le regole ufficiali di Cyberpunk RED.
- **Persistenza automatica dimensioni e posizione finestra**: Memorizzazione continua delle dimensioni della finestra alla chiusura e ripristino al successivo avvio, con avvio iniziale ampio predefinito impostato a 1360x900.
- **Sandboxing e protezione documenti utente**: Reindirizzamento rigoroso dei percorsi di test e archiviazione dati in sandbox temporanee di sistema, impedendo la scrittura di file o cartelle residue nella cartella Documenti reale dell'utente.
- **Installer Windows Nativo (.exe / .msi)**: Rilasciato il programma di installazione guidata nativo per Windows (.exe con procedura guidata NSIS e pacchetto .msi) con creazione automatica dei collegamenti sul Desktop e nel Menu Start, registrazione in App e Funzionalità di Windows e procedura di disinstallazione pulita, eliminando qualsiasi script .bat.
- **Dadi 3D poliedrici realistici**: Geometrie tridimensionali corrette per tutti i tipi di dadi:
  - D4: tetraedro regolare a 4 facce triangolari equilatere.
  - D6: cubo regolare a 6 facce quadrate.
  - D8: ottaedro regolare a 8 facce triangolari.
  - D10: trapezoedro pentagonale a 10 facce ad aquilone con apici antiprismatici.
  - D12: dodecaedro regolare a 12 facce pentagonali proporzionate con sezione aurea.
  - D20: icosaedro regolare a 20 facce triangolari.
  - D100: zocchiedro sferico geodetico a 100 facce poligonali disposte su fasce di latitudine.
  - Moneta: cilindro 3D con bordo poligonale a 16 facce, simboli EB e croce, con fisica di flip verticale puro lungo l'asse X.
- **Campi scheda allineati all'audit RED**: Campi anagrafici e attributi aggiuntivi sincronizzati con lo standard Cyberpunk RED (ruolo, reputazione, umanità attuale/massima, stili di vita, debiti e contatti).
- **Tiro della Morte (Death Save)**: Modulo di tiro conforme al manuale di Cyberpunk RED (p. 186): valore base pari a Fisico (BODY), contatore delle penalità cumulative per turno da Morente (+1/round), pulsante di tiro rapido 1d10 e rilevamento istantaneo di sopravvivenza o decesso per fallimento critico (10 naturale).
- **Riepilogo Rapido Armatura Equipaggiata**: Visualizzazione immediata di SP Testa, SP Corpo, SP Scudo e calcolo automatico delle penalità attive a Riflessi, Destrezza e Movimento.
- **Avatar Personaggio in Anagrafica**: Visualizzazione e caricamento rapido dell'immagine del personaggio direttamente dal pannello di anagrafica principale.
- **Layout Desktop a 2 colonne bilanciate**: Riorganizzazione delle macrosezioni della scheda (Personaggio, Statistiche/Abilità, Note, Background) per eliminare gli spazi bianchi vuoti e sfruttare l'intera larghezza dello schermo su monitor ampi.
- **Titolo Applicazione Uniformato**: Nome del software impostato a "CPRedux Desktop" su macOS, Windows e Linux.
- **Aggiornamenti Automatici**: Controllo autonomo della disponibilità di update all'avvio con avviso discreto.

<p align="center">
  <img src="assets/branding/divider.svg" width="100%">
</p>

## Caratteristiche Principali

<p align="center">
  <img src="assets/branding/card_dice.svg" width="100%">
</p>

### Tavolo Dadi 3D e Gestione Combattimento
- **Visualizzatore 3D Realistico:** I dadi rotolano su un tavolo tattico spazioso con fisica 3D di caduta, rimbalzo con attrito, illuminazione direzionale e ombre proiettate.
- **Poliedri Completi:** Supporto per tutti i dadi del sistema (D4, D6, D8, D10, D12, D20, D100, Moneta), sia per tiri singoli che per lanci multipli (es. `3d6`, `4d6`).
- **Attacchi & Danni dall'Inventario:** Ogni arma equipaggiata dispone di pulsanti rapidi per:
  - *Tiro per Colpire:* Calcola in automatico `1d10 + Stat + Abilità Arma`.
  - *Tiro Danni:* Lancia i dadi dell'arma con banner critici al neon.
  - *Rilevamento Ferita Grave:* Se escono due o più 6 sui dadi di danno, calcola in automatico il trauma critico e i **+5 PF bonus**.
- **Calcolatore Impatto & Ablazione SP:** Verifica in tempo reale se il danno penetra lo SP dell'armatura bersaglio, calcola i PF persi e scala automaticamente **-1 SP** per ablazione.
- **Gestione Munizioni:** Scarica colpi singoli, raffiche secondo la Cadenza di Tiro (CdT) e ricarica il caricatore con un tap.

<br>

<p align="center">
  <img src="assets/branding/card_map.svg" width="100%">
</p>

### Mappa Night City 2077 Full HD
- **Mappa Ufficiale Dettagliata:** Include l'intera metropoli, i percorsi della metropolitana NCART (linee A, B, C, D, E) e la legenda dettagliata da 01 a 84.
- **Etichette Pulite dei Distretti:** I nomi dei quartieri sono posizionati armoniosamente al centro delle zone senza fastidiosi poligoni opachi che coprono gli edifici.
- **Waypoints P2P Sincronizzati:** Il Master e i giocatori possono posizionare segnaposto personalizzati sulla mappa con note e icone dedicate in tempo reale durante la sessione.

<br>

<p align="center">
  <img src="assets/branding/card_wallet.svg" width="100%">
</p>

### Terminale Finanziario Eurodollari (Eddies)
- **Modifica Rapida con Tastierino:** Clicca sul saldo per inserire direttamente qualsiasi cifra desiderata.
- **Transazioni Immediate:** Chip dedicati `+100`, `+500`, `+1000`, `-50`, `-100`, `-500` EB per pagare cyberware, munizioni o affitto senza calcoli manuali.
- **Storico Movimenti:** Tracciamento di ogni spesa o ricompensa con timestamp e causale.
- **Patrimonio Netto (Net Worth):** Calcolo in tempo reale del valore complessivo: *Contanti + Equipaggiamento indosso + Oggetti nello zaino*.

<br>

<p align="center">
  <img src="assets/branding/card_session.svg" width="100%">
</p>

### Sessioni Internazionali e Cloud Sync Gratuito
- **Zero Port Forwarding:** Il Master può avviare la sessione e condividere link diretti `cpred://join?host=...` o comodi **Room Code a 6 caratteri**. Amici dall'estero (es. Germania) possono collegarsi all'istante senza toccare il router.
- **Chat di Tavolo & Sussurri Privati:** Chat integrata per comunicare tra tutti i partecipanti o inviare messaggi segreti al Master/giocatori con `/w [nome] [messaggio]`.
- **Cloud Backup Google (100% Gratuito):** Supporto cloud nativo basato su **Firebase Spark** (Google): accesso con account Google e salvataggio/ripristino schede senza costi né abbonamenti.

<br>

<p align="center">
  <img src="assets/branding/divider.svg" width="100%">
</p>

## Scheda Personaggio e Regole

- **Wizard di Creazione:** Creazione guidata e trasparente che visualizza ruoli (*Solo, Netrunner, Tech, Media, Lawman, Exec, Fixer, Nomad, Rockerboy, Medtech*), identità e ripartizione dei **62 punti caratteristica**.
- **Modifica Rapida a Matitina:** Modifica qualsiasi parametro della scheda in qualsiasi momento con ricalcolo immediato dei totali derivati.
- **68 Abilità con Tiro Diretto:** Ogni riga di abilità include una casella dado cliccabile per effettuare direttamente la prova sul tavolo 3D.
- **Cuore Vitale ad Alto Contrasto:** Monitoraggio dinamico di PF, Stato di Carico, Umanità e Cyberpsicosi.
- **Compatibilità Vecchie Schede:** Migratore automatico per convertire vecchie schede Java `.cpred_sheet` nel moderno formato `.cpredux`.

<p align="center">
  <img src="assets/branding/divider.svg" width="100%">
</p>

## Architettura e Sviluppo

Il software è sviluppato interamente in **Flutter/Dart** con architettura modulare a zero dipendenze pesanti:

```text
cpredux/
├── lib/
│   ├── app/           # Stato globale dell'app e navigazione (AppState)
│   ├── design/        # Palette cyberpunk, geometrie tagliate e tipografia
│   ├── domain/        # Regole di Cyberpunk RED, calcolo totali, tiri e formule
│   ├── features/      # Sezioni: Scheda, Mappa, Inventario, Sessione, Dadi, Wizard
│   ├── net/           # Protocollo TCP di sessione, updater, cloud sync
│   └── widgets/       # Tavolo dadi 3D, terminale wallet, dialog di combattimento
└── assets/            # Mappa HD Night City, grafica branding, catalogo SQLite
```

### Avvio in Locale

Prerequisiti: [Flutter SDK](https://flutter.dev) (v3.13 o superiore).

```bash
# Clona il repository
git clone https://gitlab.com/Tia004/cpredux.git
cd cpredux

# Scarica le dipendenze
flutter pub get

# Esegui tutti i test (283 test unit & widget)
flutter test

# Avvia l'applicazione sul tuo sistema operativo
flutter run -d macos    # su macOS
flutter run -d windows  # su Windows
flutter run -d linux    # su Linux
```

<p align="center">
  <img src="assets/branding/divider.svg" width="100%">
</p>

## Note Legali

Questo software è un progetto amatoriale **non ufficiale** creato da appassionati per appassionati.
Cyberpunk RED è un marchio registrato di **R. Talsorian Games, Inc.**. Tutti i diritti sui contenuti di gioco, ambientazione e manuali appartengono a R. Talsorian Games e CD PROJEKT S.A.
Realizzato in piena conformità con la *Homebrew Content Policy* di R. Talsorian Games.
