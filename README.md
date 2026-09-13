# CPRED Visualizer — riscrittura (cpredux)

Riscrittura di `CPRED_Visualizer` (JavaFX, ~17.100 righe di Java + 5.800 di FXML)
in **Flutter**, in un progetto parallelo. Il progetto Java resta intatto accanto
come riferimento e come specifica del comportamento da preservare.

Stato: **applicazione funzionante end-to-end**. Il dominio e' portato, il
catalogo oggetti e' separato dalla scheda, il formato `.cpredux` e' definito con
il suo migratore e con l'aggiornamento automatico dal formato precedente, la
scheda ha tutte le sezioni, la campagna ha la sessione condivisa con autorita'
del master, Discord Rich Presence funziona senza dipendenze native.

## Perche' Flutter

L'obiettivo era una UI animata di livello pari a `tiadesigns.it`, su
macOS/Windows/Linux, senza dipendenze di sistema. Flutter rende tutto con il
proprio motore (Impeller/Skia) invece di appoggiarsi a controlli nativi: il
risultato e' **identico sui tre sistemi operativi**, il che elimina la classe di
problemi "sul mio Mac si vede bene e su Linux no". E' la ragione principale per
cui e' stato preferito a Tauri, che su Linux dipende dal WebKitGTK della distro.

Il costo e' che il codice di dominio Java non e' riutilizzabile: e' stato
riscritto. E' una scelta consapevole, presa sapendo che si perde quel vantaggio.

## Il dominio portato

Trascritto **fedelmente** dal Java, valori compresi:

- **10 caratteristiche** con gli stessi id stabili del database originale;
- **68 abilita'** con caratteristica di riferimento, categoria, e i marcatori di
  regola (`isMaster`, `isEssential`, `isDoubleCost`);
- **cyberware** con costo in umanita', effetti su PV/Carico e alterazioni;
- **effetti** con `EffectKnowledge` (Sconosciuto/No/Si');
- **oggetti** con sottotipi arma/armatura/abbigliamento.

Le formule sono quelle del progetto originale:

| Grandezza | Formula |
|---|---|
| PV massimi | `10 + 5 · ceil((FIS + VOL) / 2)`, poi PV% e PV assoluti degli effetti |
| Soglia ferite gravi | `ceil(PV max / 2)` |
| Umanita' massima | `EMP calcolata × 10` |
| Carico massimo | `FIS calcolata × 10`, poi i percentuali/assoluti di effetti e impianti |
| Penalita' di carico | Leggero **+1**, Normale 0, Pesante −1, Sovraccarico −2 su Destrezza e Velocita' |
| Tiro di abilita' | `1d10 + caratteristica + abilita'` (10 = critico, 1 = fallimento) |

Nota sul carico: `LIGHT (+1)` **non** e' un refuso. Nel progetto originale essere
scarichi da' un bonus a Destrezza e Velocita', e il port mantiene la regola
perche' i valori delle schede esistenti sono calcolati cosi'. C'e' un test che
lo fissa.

Nessun totale derivato viene salvato su disco: la scheda memorizza solo i valori
base, le correzioni e gli oggetti, e **tutto il resto si ricalcola**. Cosi' e'
impossibile che un file contenga un totale incoerente con i dati che lo
generano.

## Formato `.cpredux`

Un file SQLite con una sola tabella di contenuto che tiene il documento come
**JSON**, piu' i metadati (id, nome, tipo, versione del formato, date).

Perche' questo e non venti tabelle:

- **SQLite come contenitore** — file singolo, scritture atomiche, resistente
  alle chiusure improvvise, leggibile da qualunque linguaggio. Se domani vuoi
  esportare i dati, non serve codice nostro.
- **JSON come contenuto** — una scheda e' un aggregato che si carica e si salva
  sempre per intero: normalizzarla non portava vantaggi, portava tabelle ponte,
  cascade e ricostruzione a ogni apertura.
- **journal DELETE, non WAL** — in WAL SQLite crea due file affiancati (`-wal` e
  `-shm`). Per un documento che l'utente copia, sposta e manda al master,
  copiare solo il `.cpredux` significherebbe copiare un database senza le ultime
  scritture.

La lettura usa **`sqlite3` via FFI sul SQLite di sistema**: nessun plugin nativo,
quindi niente CocoaPods su macOS e build piu' semplici sulla CI dei tre sistemi.

Le immagini (ritratto, oggetti, impianti) **non** stanno dentro il documento:
il migratore le estrae in una cartella `Nome.assets/` affiancata, e la scheda
salva percorsi relativi quando possibile, cosi' spostare o condividere la scheda
porta con se' le immagini.

## Il catalogo oggetti: separato dalla scheda

Nel vecchio formato ogni scheda conteneva una **copia** di ogni oggetto,
immagine Base64 inclusa. Con cinquanta oggetti erano schede da decine di MB, e
correggere un prezzo sbagliato nel programma non correggeva le schede gia'
create.

Adesso:

- **il catalogo** e' un database SQLite in sola lettura (`assets/catalog/catalog.sqlite`,
  ~40 KB, 63 voci) **spedito con l'app**. Si interroga — ricerca per nome,
filtro per categoria e rarita', ordinamento — e si apre con qualunque strumento
SQLite: se un giorno vuoi controllare un prezzo, apri il file;
- **la scheda** salva solo `{id di catalogo, quantita', equipaggiato, munizioni,
  differenze}`. Una scheda da cinquanta oggetti pesa pochi KB;
- **le differenze** (`ItemOverride`) sono **solo i campi modificati**, non una
  copia. Cosi' una correzione futura del catalogo raggiunge tutte le schede
  tranne i campi che l'utente ha deliberatamente cambiato: copiare la voce
  intera avrebbe riprodotto, in piccolo, lo stesso problema di prima;
- **gli oggetti creati a mano** restano definiti per intero dentro la scheda:
  sono l'unica cosa che il catalogo non puo' conoscere, quindi la definizione
  *deve* viaggiare con il documento, altrimenti esisterebbe su una macchina sola.

L'UI non legge mai la voce grezza: legge un `ResolvedItem`, cioe' catalogo e
differenze gia' fuse. E' la regola che rende impossibile mostrare un prezzo che
ignora la personalizzazione o un peso che ignora il catalogo — l'incoerenza che
nasce quando la fusione viene fatta "a mano" in ogni punto in cui serve.

### Rigenerare il catalogo

```bash
dart run tool/build_catalog.dart
```

Il seed leggibile e' `tool/catalog_seed.json` (una voce per riga, revisionabile
in una diff); lo script valida, genera il database e **stampa un errore** invece
di produrre un catalogo incoerente. Il file generato va committato: e' un asset
spedito con l'app, e un test verifica che sia presente e coerente.

Il controllo che ha gia' ripagato il suo costo: **le penalita' di armatura
devono essere positive**. Nel seed erano negative, e il motore applica la
penalita' solo se il totale e' maggiore di zero — quindi Metalgear, la corazza
piu' pesante del gioco, non penalizzava nulla. Un errore dei dati che non fa
fallire niente a occhio: adesso lo intercetta `ItemCatalog.validate()`, e il test
sul catalogo spedito lo blocca prima dell'utente.

### Immagini

L'artwork degli oggetti di Cyberpunk RED e' IP di R. Talsorian Games e **non
viene spedito**: le voci di catalogo hanno lo slot immagine vuoto e l'utente puo'
metterne una propria, che resta nella scheda come personalizzazione e non si
perde mai in una conversione. C'e' un test che verifica che nessuna voce spedita
porti un'immagine, cosi' aggiungerne una resta una scelta consapevole invece che
un effetto collaterale del generatore.

## Migratore dal vecchio formato

`SheetMigrator` legge un `.cpred_sheet` e produce un `.cpredux`, con:

- **anteprima prima di scrivere** — conteggi per sezione e avvertenze su cosa non
  e' stato riconosciuto;
- **backup dell'originale** (`Vecchia.cpred_sheet.backup`) creato *prima* di
  qualunque scrittura; l'originale non viene mai modificato ne' cancellato;
- **mappatura per valore, non per ordinale** — tutte le enum hanno
  `databaseId`/`databaseValue` stabili, quindi la conversione e' deterministica.
  L'unica eccezione e' `EffectKnowledge`, i cui valori su disco sono −1/0/1
  mentre gli ordinali sarebbero 0/1/2: mappare per ordinale trasformerebbe ogni
  "Sconosciuto" in "No" e ogni "No" in "Si'";
- **alterazioni attribuite al proprietario giusto** — le tabelle ponte dicono se
  un'alterazione appartiene a un impianto o a un effetto; quelle non collegate a
  nulla finiscono fra le correzioni manuali della scheda, e il resoconto lo dice;
- **estrazione delle immagini Base64** in file, cosi' la scheda non pesa decine
  di MB;
- **aggancio al catalogo** — le voci riconosciute diventano **riferimenti**
  invece di copie, e da quel momento seguono gli aggiornamenti; le differenze
  rispetto al catalogo diventano personalizzazioni esplicite, il resto no.

Se il file e' di una versione diversa, la conversione **avvisa e prosegue**; se
non e' una scheda, si ferma con un messaggio comprensibile.

Il riconoscimento e' per nome normalizzato (senza maiuscole ne' punteggiatura) e
categoria. Scrivendo il test con il catalogo vero e' emerso un bug silenzioso:
il prefiltro usava il nome grezzo, quindi `LIKE '%armorjack leggero !%'` non
trovava "Armorjack leggero" e l'oggetto diventava **personalizzato** senza che
nulla lo segnalasse — cioe' esattamente cio' che questa funzione esiste per
evitare. Il prefiltro adesso usa il token piu' lungo del nome normalizzato.

## Aggiornamento automatico del formato

Aprire un documento scritto prima del catalogo lo aggiorna da v1 a v2 **prima**
di mostrarlo, con le stesse due garanzie del migratore: backup dell'originale e
nessun campo buttato. Il conteggio delle voci non cambia mai, e le note
("12 oggetti agganciati al catalogo, 3 non riconosciuti, 2 con modifiche tue")
vengono mostrate **dopo** l'apertura: un aggiornamento di formato che avviene in
silenzio e' la ricetta per la telefonata "mi hai cambiato i file senza dirmelo".

L'aggiornamento si applica anche quando la versione *dichiarata* nel file e'
sbagliata, se la forma dei dati e' quella vecchia: i documenti prodotti durante
lo sviluppo dichiarano versioni che non corrispondono al contenuto.

## La scheda (12 sezioni)

Personaggio (cuore PV + spira Umanita', comandi rapidi di danno/cura), Statistiche
e abilita' (con competenze e correzioni manuali), Inventario (con carico e
soglie), Equipaggiamento, Cyberware, Effetti, **Sessione**, Note, Background
(lifepath completo), Descrizione fisica, Dadi, Impostazioni scheda.

## La campagna: il master e' l'autorita'

I giocatori inviano **intenzioni** ("uso un Medkit"), il master le applica e
trasmette lo **stato risultante**. Il master modifica direttamente PV, umanita',
fortuna, ferite, e puo' allontanare o riammettere un giocatore; ogni modifica e'
un **evento** che finisce nel registro di sessione e nel documento.

Il protocollo e' **una riga di JSON per messaggio su TCP**: si legge con
`netcat`, si registra in un file, si ispeziona senza strumenti. Il vecchio frame
`lunghezza + SHA-256 + Base64` proteggeva da errori che TCP gia' gestisce e
gonfiava ogni messaggio di un terzo.

Dettagli che sono costati tempo e che ora hanno un test:

- **riconnessione** — lo stesso identificativo sostituisce il socket precedente
  invece di creare un doppione; la chiusura del vecchio socket non deve togliere
  dal tavolo il giocatore che e' appena rientrato;
- **password del tavolo** (vuota = tavolo aperto);
- **ban persistente** — chi e' stato allontanato non rientra riavviando l'app,
  perche' il ban vive nel documento della campagna;
- gli indirizzi IPv4 locali sono mostrati al master con un pulsante "Copia".

## Discord Rich Presence

Implementato parlando **direttamente con l'IPC di Discord** (named pipe su
Windows, socket Unix altrove), zero binari nativi: e' la libreria
`java-discord-rpc` la causa del malfunzionamento su Mac ARM nel vecchio
progetto. I percorsi del socket si provano in ordine, comprese le installazioni
Snap e Flatpak.

Serve un **Application ID** (gratuito su discord.com/developers → New
Application) da inserire in Impostazioni → Integrazione. Senza, la presenza
resta spenta invece di fallire.

## Struttura

```
lib/
  app/            stato applicativo (AppState) e radice dell'interfaccia
  data/           percorsi, contenitore .cpredux, catalogo, migratore, upgrade
  design/         token: palette, tipografia, movimento, geometria, tema
  domain/         caratteristiche, abilita', oggetti, cyberware, effetti, regole
  features/       schermate: home, scheda, campagna, impostazioni, file browser
  net/            protocollo di sessione e Discord RPC
  widgets/        componenti riutilizzabili
tool/             seed leggibile del catalogo e generatore dell'asset
test/             regole, catalogo, migratore, upgrade, sessione, documenti
```

I token stanno tutti in `lib/design/`: cambiare la palette o la velocita' di
tutta l'app significa toccare un file solo.

## Verifiche

```bash
flutter analyze     # No issues found
flutter test        # 90 test
flutter build macos # costruisce cpredux.app
```

L'intera catena di rilascio e' stata eseguita a mano una volta, in locale, prima
di scrivere la CI:

```bash
flutter build macos --release
ditto -c -k --keepParent cpredux.app dist/cpredux-macos.zip
dart run tool/publish.dart --dist dist --site site --version 0.2.0 \
  --base-url https://cpredux.tiadesigns.it
```

E poi verificata per davvero: manifesto servito da un server locale e applicazione
avviata puntandoci — la richiesta arriva, il manifesto si legge, la versione nuova
viene riconosciuta. E' cosi' che e' emerso il problema della sandbox.

I test coprono le cose che si rompono in silenzio: le formule dei valori
derivati, il catalogo **spedito** (asset presente, voci coerenti, ricerca,
riconoscimento per nome, penalita' delle armature), l'aggancio catalogo nelle due
direzioni (una voce v1 riconosciuta si alleggerisce, una sconosciuta non perde
nulla), il migratore su un file costruito con lo schema legacy esatto, il ciclo
di vita dei documenti (crea → modifica → autosalvataggio → riapri), il
riconoscimento di schede e campagne dal contenuto, la schermata dell'inventario
con un catalogo vero, e la sessione di rete su socket reali (benvenuto, chat,
tiri, intenzioni, espulsione, riconnessione).

## Comandi

```bash
flutter run -d macos      # app desktop
flutter test              # suite completa
flutter analyze           # analisi statica
```

## Aggiornamenti automatici

Il controllo all'avvio chiede **un file statico** (`latest.json`, poche centinaia
di byte) e, se c'e' una versione nuova, la **chiede** all'utente con tre scelte:

| Scelta | Cosa succede |
|---|---|
| Aggiorna adesso | scarica, verifica l'impronta, avvia l'aggiornatore ed esce |
| Salta questa versione | non lo ripropone per **quella** versione, non per sempre |
| Alla chiusura | scarica **subito**, applica quando il programma si chiude |

Che sia un file statico e non una chiamata alle API di GitLab o GitHub e' una
scelta con quattro conseguenze concrete: nessun token da distribuire dentro
un'applicazione desktop, nessun limite di frequenza, lo stesso manifesto su
qualunque hosting, e gli `sha256` generati **dalla stessa esecuzione** che
costruisce gli archivi — quindi il manifesto non puo' descrivere una versione
diversa da quella che pubblica.

### "Alla chiusura" non significa "chissa' quando"

Il pacchetto si scarica quando l'utente scegli, e viene **verificato con lo
SHA-256** prima di essere messo da parte. Alla chiusura resta un `mv` locale: non
c'e' piu' la rete di mezzo, quindi non puo' fallire per un motivo che l'utente
non puo' controllare. Il rinvio sopravvive alla chiusura perche' e' scritto
nelle impostazioni, non tenuto in memoria.

Alla chiusura il programma **non tocca i propri file**: avvia una copia di se
stesso in modalita' `--apply-update`, che mostra una finestra, installa e poi
riapre l'applicazione con `--just-updated`, che dice una volta sola che e'
andata bene. Una copia nuova che fa il lavoro mentre la vecchia esce e' l'unico
modo di sostituire un'applicazione in esecuzione senza rischiare un file a
meta'.

Se l'installazione fallisce, l'errore viene **scritto** e lo si ritrova nel
pannello Aggiornamenti dell'applicazione riaperta — insieme al pulsante per
riprovare. La finestra dell'aggiornatore vive pochi secondi: un errore mostrato
solo li' dentro non lo vedrebbe nessuno.

### I formati per piattaforma

| | Archivio | Come si applica |
|---|---|---|
| macOS | `.zip` con il bundle | `ditto -x -k` in un'area di lavoro, poi sostituzione del `.app` |
| Windows | `.zip` portable | scompattato sopra la cartella di installazione |
| Linux | `.AppImage` | copia accanto e `mv`, poi `chmod 755` |

Su Linux l'aggiornamento funziona **solo** con l'AppImage: per un pacchetto della
distribuzione il file appartiene al gestore di pacchetti, e sostituirsi da soli
sarebbe sbagliato. In quel caso il programma lo dice invece di provarci.

Su una build di sviluppo (`build/…`) l'aggiornamento automatico e' **disattivato
e dichiarato**: sostituire il bundle dentro `build/` cancellerebbe il risultato di
una compilazione, o un bundle aperto a meta'.

## Il repository e la CI

Il "repository" a cui punta l'aggiornatore e' un **dominio**, non un'API:

```
https://cpredux.tiadesigns.it/
├── index.html            la pagina di download (legge latest.json a runtime)
├── latest.json           il manifesto degli aggiornamenti
├── cpredux-macos.zip     nomi stabili: il link che hai mandato resta valido
├── cpredux-windows.zip
└── cpredux-linux.AppImage
```

La pagina di download **non** viene rigenerata a ogni rilascio: legge il
manifesto a runtime. Cosi' esiste un solo posto che sa qual e' la versione
corrente, e non puo' succedere che la pagina annunci una versione e il manifesto
ne pubblichi un'altra.

Due pipeline, lo stesso risultato, perche' non si sa dove vivra' il repository:

- **`.github/workflows/release.yml`** — funziona subito, senza attivare niente;
- **`.gitlab-ci.yml`** — l'equivalente GitLab, con i runner macOS/Windows di
  GitLab.com (da abilitare) in `when: manual` e il resto che gira comunque.

Entrambe chiamano `dart run tool/publish.dart`, che calcola le impronte, copia
gli archivi con nome stabile e scrive il manifesto **con la stessa classe che lo
legge l'applicazione**. Un generatore scritto in un altro linguaggio puo'
divergere in silenzio — un campo rinominato, un numero scritto come stringa — e
il sintomo sarebbe "gli aggiornamenti non arrivano piu'", che nessuno collega a
una modifica di mesi prima.

### Il dominio

`tiadesigns.it` e' gia' tuo, quindi il candidato naturale e' un sottodominio
`cpredux.tiadesigns.it`. Serve una cosa sola che non posso fare io: il CNAME nel
DNS, che richiede l'accesso al registrar.

In alternativa **non serve nessun dominio**: sia GitLab Pages sia GitHub Pages
danno un URL pubblico (`https://<account>.gitlab.io/cpredux/`, `https://<account>.github.io/cpredux/`),
e basta incollarlo in Impostazioni → Aggiornamenti perche' tutto funzioni. Il
campo e' modificabile proprio per questo.

## Dove l'app scrive

| | |
|---|---|
| macOS | `~/Library/Containers/it.tiadesigns.cpredux/Data/Library/Application Support/CPREDVisualizer/` |
| Windows | `%APPDATA%\CPREDVisualizer\` |
| Linux | `$XDG_CONFIG_HOME/CPREDVisualizer/` (o `~/.config`) |

Dentro: `settings.json`, i recenti, e `catalog/catalog.sqlite` (copiato
_dall'asset_ al primo avvio, identificato da un checksum: se il catalogo spedito
cambia, la copia vecchia viene sostituita invece di essere usata a sorpresa).

Su macOS l'app e' **sandboxata** (il template Flutter lo fa di serie), quindi il
percorso reale e' dentro il container — non in `~/Library/Application Support`.
Ci si accorge della differenza solo cercando i file "dove dovrebbero essere" e
non trovandoli: per questo e' scritto qui.

I documenti (`.cpredux`) **non** stanno li': si aprono e si salvano dove decide
l'utente, e l'app propone la cartella Documenti.

## Un bug trovato avviando l'app davvero

Il template macOS di Flutter attiva la **sandbox**. Con la sandbox attiva e senza
l'entitlement `com.apple.security.network.client`:

- il controllo degli aggiornamenti fallisce **in silenzio** (nessuna connessione
  in uscita: il `getText` lancia, il `catch` restituisce "nessun aggiornamento");
- il collegamento al tavolo del master fallisce;
- Discord non e' raggiungibile, perche' il suo IPC e' un socket Unix, cioe' una
  connessione in uscita;
- senza `network.server`, in release, **il master non puo' nemmeno aprire il
tavolo** (in debug l'entitlement c'e', quindi il problema si vede solo nella
versione installata);
- l'accesso ai file e' limitato alla cartella dell'applicazione, quindi aprire una
  scheda da Documenti fallirebbe — il browser dei file e' interno e non e' il
  pannello di sistema, quindi il permesso "file scelti dall'utente" non si
  applica.

Tutte cose che si presentano all'utente come "non funziona", senza nessun indizio
sulla causa. La sandbox e' quindi **disattivata** in entrambi gli entitlement
file, ed e' verificabile con:

```bash
codesign -d --entitlements - build/macos/Build/Products/Release/cpredux.app
```

Questa applicazione si distribuisce fuori dal Mac App Store, dove la sandbox non
e' obbligatoria. Se un giorno volessi pubblicare sull'App Store, andrebbe
riattivata insieme a un pannello di sistema per scegliere i file — cioe' un
ripensamento di una parte dell'interfaccia, non un interruttore.

## Cosa manca

1. **Mappa di Night City** — non ancora implementata: la ricerca e' fatta, il
   codice no. Vedi le note qui sotto.
2. **Repository su GitLab**: i file sono pronti e la pipeline e' scritta, ma il
   progetto va creato sull'account GitLab (`glab auth login`, oppure un token) —
   non ci sono credenziali per quell'account su questa macchina.
3. **Firma e notarizzazione di macOS**: senza un certificato Apple a pagamento,
   l'utente deve sbloccare l'applicazione al primo avvio da Privacy e Sicurezza.
   La pipeline funziona, ma la pagina di download deve spiegarlo (lo fa).
4. **Installer nativi** — MSI, DMG, deb/rpm con il runtime incluso. Oggi
   l'aggiornamento usa zip e AppImage, che funzionano ma non si presentano come
   un'installazione.
5. **Aggiornamento del catalogo a runtime**: oggi il catalogo e' quello spedito;
   manca il modo di importare un catalogo piu' nuovo senza reinstallare l'app.
6. **Import/export di singoli elementi** (`.cpred_element`) del vecchio progetto.
7. **Tema chiaro**: i widget leggono ancora i colori scuri come costanti; serve
   prima un insieme di token risolti in base al tema. L'opzione resta nascosta
   finche' non funziona davvero.

## Note sulla mappa di Night City

La ricerca e' fatta, il codice no. Tre cose da sapere prima di scriverlo.

**Cosa esiste.** Il `.json` dei dati della mappa interattiva ufficiale di
Cyberpunk 2077 (progetto `sharkAndshark/Cyberpunk-2077-MapData`), i tile set di
`nczoning/nc-zoning-board`, e diverse mappe di Night City 2045 per il gioco da
tavolo pubblicate dalla comunita' (una su GitHub con i distretti e i punti
`ATLAS`). Nessuna di queste e' utilizzabile come asset **spedito**: sono
lavori derivati da materiale di terzi, e la policy di RTG dice esplicitamente di
non includere il lavoro altrui senza permesso.

**Cosa permette la policy.** La Homebrew Content Policy copre esplicitamente
gli *app*: si possono importare statistiche di oggetti e mostrare i risultati dei
tiri, ma **non** si possono riprodurre illustrazioni ne' loghi dei manuali, e
l'uso deve restare gratuito. I **nomi** dei luoghi si possono citare ("un ufficio
nei pressi di Little Europe" e' un riferimento ammesso). Quindi: una mappa
disegnata da zero con i nomi dei distretti come riferimenti e' dentro la policy;
una mappa ufficiale scansionata non lo e'.

**La proposta.** Una sola geometria e due aspetti: "realistica" (colori spenti,
ombre, etichette discrete) e "digitale" (griglia neon, contorni, glow) sono due
stili dello stesso disegno, non due mappe da mantenere. In piu' un import con
georeferenziazione a quattro angoli, cosi' chi possiede una mappa — comprata,
scansionata o fatta da lui — puo' usarla **senza** che il programma la spedisca.
I waypoint viaggiano sul protocollo di sessione che esiste gia': visibili a chi e'
al tavolo, con una categoria privata per il master.

Il vantaggio di disegnarla e' che diventa tua: nessuno potra' chiederti di
rimuoverla, e la mappa puo' diventare la cosa per cui il programma viene
ricordato — come i tuoi contatori sul sito.
