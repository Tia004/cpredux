<p align="center">
  <img src="assets/branding/banner.svg" alt="CPRED Visualizer" width="820">
</p>

<p align="center">
  <b>Scheda del personaggio, campagna condivisa e mappa di Night City.</b><br>
  Applicazione desktop per macOS, Windows e Linux.<br>
  <sub>Strumento <b>non ufficiale</b> per Cyberpunk RED, ai sensi della
  <a href="https://rtalsoriangames.com/homebrew-content-policy/">Homebrew Content Policy</a>
  di R. Talsorian Games. Non approvato né sostenuto da RTG.</sub>
</p>

---

# CPRED Visualizer — riscrittura (cpredux)

<!--
  Il marchio di Cyberpunk RED non e' qui, ed e' una scelta: la Homebrew Content
  Policy vieta di usare il marchio e di imitare la veste grafica dei manuali.
  Se hai un permesso scritto di RTG, metti il file qui sotto e togli i commenti:

  <p align="center"><img src="assets/branding/logo.svg" alt="Cyberpunk RED" height="70"></p>
-->

Riscrittura di `CPRED_Visualizer` (JavaFX, ~17.100 righe di Java + 5.800 di FXML)
in **Flutter**, in un progetto parallelo. Il progetto Java resta intatto accanto
come riferimento e come specifica del comportamento da preservare.

Stato: **applicazione funzionante end-to-end** e **rilasciabile**. Il dominio e'
portato, il catalogo oggetti e' separato dalla scheda, il formato `.cpredux` e'
definito con il suo migratore e con l'aggiornamento automatico dal formato
precedente, la scheda ha tutte le sezioni, la campagna ha la sessione condivisa
con autorita' del master, Discord Rich Presence funziona senza dipendenze native,
e la pipeline costruisce i tre pacchetti (macOS universale, Windows, Linux) con
la pagina di download e il manifesto degli aggiornamenti.

**Scarica:** `<URL pubblicato da Pages>` — vedi *Il rilascio, passo per passo* per
com'e' composta la pagina e come si pubblica.

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
  ~124 KB, 306 voci) **spedito con l'app**. Si interroga — ricerca per nome,
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

### Importare gli oggetti da una vecchia scheda

Una precisazione che vale la pena scrivere, perche' e' facile aspettarsi il
contrario: **il vecchio progetto non spediva un catalogo di oggetti**. Nel suo
schema SQL le tabelle `items`, `weapons`, `armors` e `clothing` esistono, ma
sono vuote finche' non le riempie l'utente: gli oggetti vivevano dentro *la
singola scheda*, e ogni scheda aveva i suoi. Non c'e' nessun elenco di armi,
munizioni, armature, abbigliamento ed equipaggiamento da estrarre dal vecchio
programma — c'e' solo quello che l'utente ci ha messo.

Quindi l'importazione parte da dove i dati esistono davvero:

```bash
dart run tool/import_legacy_catalog.dart --dry-run ~/Documents/CPRED_Visualizer
```

Legge una o piu' `.cpred_sheet` (o una cartella), ne estrae gli oggetti come
voci di catalogo e li **fonde** con il seed. Le regole sono tre:

- **il seed esistente vince.** Le voci scritte a mano portano descrizioni e
  prezzi verificati: un oggetto omonimo importato da una vecchia scheda non li
  sovrascrive. Il catalogo si corregge in un posto solo;
- **il confronto e' per nome normalizzato piu' categoria**, non per
  identificativo: due schede diverse non hanno gli stessi identificativi, e
  "Pistola pesante" e' la stessa voce di "Pistola Pesante". Le voci gia'
  riconosciute vengono **elencate**, non fuse in silenzio;
- **gli identificativi non si duplicano**: uno slug gia' usato prende un
  suffisso invece di sostituire la voce precedente.

Il ponte fra i due formati e' meccanico e si vede: identificativi numerici
delle enumerazioni del vecchio database verso i valori stabili del dominio
(`weapon_skill` e' gia' l'id dell'abilita' nel nuovo `Skill`), piu' le
conversioni consapevoli — le munizioni caricate **non** entrano nel catalogo,
perche' descrivono un esemplare e non l'oggetto, e nemmeno le immagini Base64,
che sono un dato dell'utente e nel nuovo formato vivono nelle personalizzazioni
della scheda. Ogni cosa che non entra viene **detta**: l'anteprima elenca le note
(abilita' fuori scala, categoria inesistente, SP negativa, righe senza nome)
invece di produrre un catalogo silenziosamente incompleto.

Lo script e `tool/build_catalog.dart` leggono lo stesso formato attraverso
`lib/data/catalog_seed.dart`: una copia sola del formato, cosi' non puo'
succedere che il catalogo venga scritto con una struttura e letto con un'altra.

Sulla macchina in cui e' stato scritto, l'unica `.cpred_sheet` presente
(`SchedaPersonaggio.cpred_sheet`, creata col vecchio programma) ha **zero
oggetti**: e' una scheda appena creata. L'importatore lo dice in una riga
("oggetti letti: 0") e non scrive niente. Gli stessi test coprono il caso pieno:
una scheda con arma, armatura e capo d'abbigliamento diventa tre voci di
catalogo validate, e i due omonimi del catalogo esistente vengono riconosciuti
invece di duplicati.

### Importare gli oggetti da un dataset esterno

Le schede vuote non riempiono un catalogo, quindi la seconda fonte e' il sistema
**Foundry VTT "Cyberpunk RED - Core"** (Project Red Team), contenuto non
ufficiale pubblicato sotto la Homebrew Content Policy di R. Talsorian Games:
355 voci con danno, cadenza di tiro, capienza del caricatore, SP e penalita'.

```bash
git clone --depth 1 --filter=blob:none --sparse \
  https://gitlab.com/cyberpunk-red-team/fvtt-cyberpunk-red-core.git /tmp/fvtt-cpred
cd /tmp/fvtt-cpred && git sparse-checkout set src/packs/core

cd <questo progetto>
dart run tool/import_dataset_catalog.dart --source /tmp/fvtt-cpred --dry-run
dart run tool/import_dataset_catalog.dart --source /tmp/fvtt-cpred
dart run tool/build_catalog.dart
```

`--filter=blob:none --sparse` non e' un dettaglio: scarica 5,7 MB invece di
tutto il repository, perche' serve **solo** `src/packs/core` (i file YAML). Il
dataset non viene copiato in questo progetto: si scarica a parte, e nel catalogo
entra soltanto cio' che ne deriva.

Cosa entra: **62 armi**, **55 munizioni**, **5 armature**, **83 capi
d'abbigliamento**, **38 equipaggiamenti**. Cosa non entra, e perche':

| Non entra | Perche' |
|---|---|
| varianti di qualita' (Excellent/Poor), 58 file | sono voci separate con prezzi e modificatori propri, ma il catalogo non ha un campo "qualita'": due voci con lo stesso nome e dati diversi sarebbero indistinguibili |
| i 16 tipi generici di arma, 11 armature, 7 capi, 14 equipaggiamenti | sono **gli stessi oggetti** delle voci gia' nel seed, che hanno il nome italiano ("Pistola Pesante" = "Heavy Pistol"): la tabella delle equivalenze sta in `_curatedCounterparts`, ed e' scritta a mano perche' e' una decisione, non un'euristica |
| impianti (`cyberware`) | hanno un modello proprio, con il costo in umanita' |
| protesi dermiche (`skin_weave`, `subdermal_armor`) | stanno nella cartella delle armature perche' il sistema le usa per calcolare la protezione, ma sono cyberware: nel catalogo sarebbero armature da 0 eb |
| profili di attacco a mani nude (`unarmed`, `martial arts`) | non sono oggetti: nessuno li compra o li mette nello zaino |
| peso | **il dataset non registra il peso**. Le voci importate pesano 0 e si correggono dalla scheda, che ha gia' le personalizzazioni per farlo |

La tabella delle equivalenze si applica **solo se l'identificativo curato esiste
davvero nel seed**: se un giorno quella voce sparisce, l'oggetto del dataset
viene importato invece di essere saltato verso il nulla, e c'e' un test che lo
verifica.

Ogni voce importata porta `source: fvtt-cpred`, e l'app lo mostra: nel selettore
degli oggetti le voci non curate hanno un'etichetta con la loro provenienza. Non
e' decorazione: sono dati di terzi che questo progetto non ha verificato, e
l'utente deve poterlo sapere prima di fidarsene.

Il convertitore e' in `tool/` e non in `lib/` per una ragione precisa: legge
YAML, e `yaml` e' una dipendenza di **sviluppo**. L'applicazione spedita non la
contiene.

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

## La scheda (13 sezioni)

Personaggio (cuore PV + spira Umanita', comandi rapidi di danno/cura), Statistiche
e abilita' (con competenze e correzioni manuali), Inventario (con carico e
soglie), Equipaggiamento, Cyberware, Effetti, **Sessione**, **Mappa**, Note,
Background (lifepath completo), Descrizione fisica, Dadi, Impostazioni scheda.

## Confronto fra due schede

Due schede a confronto, **riga per riga**: due colonne allineate, cosi' l'occhio
scorre in verticale e trova la differenza invece di ricostruirla a mente. Si
apre in due modi, che sono due domande diverse:

- **dal menu principale** — "che differenza c'e' fra questi due documenti?";
- **dalle impostazioni della scheda** — "cosa e' cambiato da quando ho salvato
  quella copia?". Qui un lato e' la scheda **aperta**, con le sue modifiche non
  ancora salvate: e' l'unica versione che non esiste altrove, e il dialogo lo
  dichiara. La copia si sceglie anche fra i backup (`Nome.cpredux.backup`), che
  non hanno l'estensione del formato e quindi non comparirebbero in un elenco
  filtrato per estensione.

Le scelte che determinano il risultato stanno in `lib/domain/sheet_diff.dart`, e
sono tre:

- **si confrontano i valori, non i file.** Due `.cpredux` contengono anche
  identificativi di riga, date e ordine degli elenchi: un confronto testuale
  produrrebbe decine di differenze che non interessano a nessuno, nascondendo
  quelle vere;
- **le voci si agganciano per nome normalizzato** (maiuscole, punteggiatura e
  accenti ignorati), non per identificativo: due schede diverse non hanno gli
  stessi identificativi, e "Armorjack leggero !" e "Armorjack leggero" sono lo
  stesso oggetto. Conseguenza voluta: **l'ordine non conta**, e una riga spostata
  in fondo all'inventario non risulta cambiata;
- **si confrontano anche i valori calcolati** — PV massimi, umanita' persa,
  carico, stato di carico — perche' sono quelli che contano al tavolo, e la
  riga di una caratteristica mostra il **totale** con sotto la base quando e'
  cambiata. Un totale identico con la base cambiata resta una differenza, e
  nasconderlo renderebbe il confronto inutile proprio quando serve.

Quattordici sezioni: documento, personaggio, valori calcolati, caratteristiche,
abilita', denaro, correzioni manuali, competenze, inventario, cyberware, effetti,
note, background, descrizione fisica. La vista parte dalle **differenze** e
"tutto" e' a un clic; le sezioni senza differenze in quella vista restano chiuse,
perche' "Abilita" sono 68 righe e in mezzo a quelle la differenza che interessa
si perde.

Un dettaglio che sembra un dettaglio e non lo e': **l'immagine si confronta per
presenza, non per percorso**. La stessa scheda su due computer ha percorsi
diversi, e una differenza che e' solo la cartella di un altro utente non e' una
differenza.

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

## La mappa di Night City

E' un **riferimento condiviso**, non un motore di gioco: non muove i personaggi,
non applica regole di movimento, non tira dadi. Serve a sostenere la
conversazione — "siamo qui, il bersaglio e' li'" — mentre il tavolo parla. Chi
cerca un motore di gioco ha sbagliato sezione, e la sezione lo dice.

La sezione sta in **due posti** con permessi diversi: nella campagna (il master,
che decide) e nella scheda (il giocatore, che guarda e propone). E' la stessa
sezione, non due schermate da tenere allineate.

**Una geometria, due aspetti.** La mappa e' un insieme di poligoni disegnati a
mano in `lib/domain/night_city.dart`, non un'immagine. "Realistica" (colori
spenti, terreno, strade) e "digitale" (griglia, neon, contorni luminosi) sono
due modi di disegnare gli stessi poligoni: un waypoint sta nello stesso posto in
entrambi, correggere un confine lo corregge per tutti e due, e non esiste il caso
"sulla mappa realistica il quartiere si chiama diverso". Essendo geometria si
adatta a qualunque finestra senza sfocare, e un test verifica che ogni vertice
stia dentro la mappa e che il nome di un distretto cada dentro il suo poligono.

**Perche' disegnata e non scaricata.** La mappa ufficiale e' materiale di
R. Talsorian Games e CD Projekt RED: la Homebrew Content Policy permette di
creare contenuti propri e di citare i nomi dei luoghi, non di ridistribuire la
loro grafica. Qui non c'e' nessun pixel di quella mappa. Vedi le note in fondo,
con le fonti.

**Mappa tua, se ne hai una.** Chi possiede una mappa — comprata, scansionata o
disegnata — puo' importarla e posizionarla con **quattro angoli**, che finiscono
nello stesso sistema di coordinate 0..1 dei waypoint: i segni restano al loro
posto anche ingrandendo. Il file resta **sulla macchina del master** e non viene
spedito al tavolo: chi gioca vede la geometria disegnata dal programma. Un test
salva e rilegge gli angoli, e uno verifica che un'immagine illeggibile lo dica
invece di far sparire la mappa.

**I waypoint.** Nome, nota, categoria (luogo, pericolo, persona, lavoro,
negozio, nota) e visibilita'. Il master puo' metterli *solo per se'*: una
posizione privata non lascia la sua macchina, e non e' un filtro applicato dalla
schermata ma un percorso che non esiste — `_publishWaypoint` esce prima di
qualunque invio, e il test lo verifica **sul socket**, non nella logica.

Un giocatore che mette un segno produce una **proposta**: la vede subito lui,
arriva al master, e resta li' finche' lui non decide. E' l'unico modo perche'
"condivido un punto" non diventi "scrivo sulla mappa di tutti mentre il master
descrive". Un test verifica anche il contrario: un client che manda la rimozione
di un waypoint **non suo** viene ignorato.

L'aspetto scelto dal master viaggia con il resto dello stato; chi rientra a meta'
serata riceve la mappa gia' fatta (`mapSync`) e non una mappa vuota mentre al
tavolo ne stanno parlando.

## La schermata iniziale: creare, riprendere, convertire

Il menu' di partenza ha tre strade e le mostra tutte e tre subito, perche' chi
apre il programma sta in uno di questi tre casi: non ha ancora un personaggio,
ne ha gia' uno, oppure arriva dal vecchio programma con una `.cpred_sheet`.

**"Apri scheda"** e **"Apri campagna"** sono menu' a tendina: si aprono sulla
riga e elencano i documenti che **esistono davvero** sul disco, con cartella e
ultima modifica. L'elenco (`DocumentLibrary`) legge il **contenuto** di ogni
file per dire se e' una scheda o una campagna, perche' entrambe usano
`.cpredux`: fidarsi del nome del file significherebbe elencare una campagna
rinominata fra le schede. Le fonti sono due e si completano — i documenti
recenti (che possono stare ovunque) e la cartella dell'app (esplorata con un
tetto su file, cartelle e profondita', perche' questa lettura avviene entrando
nel menu'): un file rotto o sparito compare **segnato**, non sparisce
silenziosamente dall'elenco, che farebbe credere di averlo perso.

**"Crea o partecipa a una campagna"** e' una riga sola perche' e' una decisione
sola: aprire un tavolo da master o entrare in quello di un altro. Partecipare
chiede **con chi** si va al tavolo (la scheda che si porta) e **dove**
(indirizzo, porta, password), e aspetta la risposta del master prima di dire che
il collegamento e' riuscito: `joinSession` ritorna quando il socket e' aperto,
non quando il tavolo ha accettato il giocatore, e confondere le due cose
significa dichiarare un successo che non c'e' ancora stato.

### Trascinare la scheda vecchia sulla riga della conversione

La riga "Converti scheda vecchia" e' anche una **zona di rilascio**: si puo'
cliccare per scegliere il file, oppure trascinare la `.cpred_sheet` dal Finder,
da Esplora risorse o dal file manager. Mentre il file e' sopra, la zona **lo
dice** (bordo acceso, alone, "RILASCIA QUI" col formato atteso); al rilascio si
apre la stessa anteprima della conversione, che chiede **dove salvare** — fra i
dati dell'app per impostazione predefinita — e mostra cosa verra' convertito
prima di scrivere qualcosa.

Due dettagli che sono li' per una ragione:

- **il trascinamento dal sistema operativo non esiste in Flutter.** `DragTarget`
  funziona solo fra widget della stessa applicazione, e un file che arriva dal
  Finder e' un evento della piattaforma, non ottenibile da `dart:io`. Per questo
  c'e' un plugin nativo (`desktop_drop`), l'unico del progetto;
- **la zona si spegne mentre un dialogo e' aperto.** Una zona coperta continua a
  ricevere i rilasci: senza questo, un file lasciato sul dialogo di conversione
  finirebbe sulla zona sotto, che l'utente non sta guardando.

Il test di questa parte **non usa `tap` ne' `drag`**: quelli sono eventi interni
a Flutter e non toccano la zona. Scrive sul canale nativo `desktop_drop`, cioe'
fa esattamente quello che fa il sistema operativo quando l'utente lascia il file
sopra la finestra — ingresso, avviso a schermo, rilascio, e i rifiuti (cartella,
extensione sbagliata, zona spenta). E' l'unico modo di verificare questa parte
senza una mano umana, e una regressione qui si vedrebbe altrimenti solo
dall'utente.

### Il difetto che ha rivelato il test del menu'

I primi test del menu' fallivano in un modo istruttivo: `find.text('Partecipa a
una campagna')` trovava la voce, ma il tocco "non colpiva" niente. Il motivo non
era il test: **`AnimatedSize` decide la propria altezza durante
l'impaginazione**, quindi il primo fotogramma dopo l'apertura misura il contenuto
e *avvia* l'animazione. Con un solo `pump` lungo l'animazione resta a zero: il
corpo del menu' e' disegnato alla sua altezza finale mentre la colonna gli
riserva spazio zero, e finisce **sopra** le righe successive. In un'applicazione
vera i fotogrammi arrivano uno dopo l'altro e l'animazione si vede; in un test
un `pump` solo non e' un'applicazione vera. I test adesso avanzano a fotogrammi,
come il programma.

### Una cosa che va saputa sui test

I test che aprono **socket veri** (la sessione della campagna, la mappa condivisa)
e quelli che aspettano un'animazione hanno scadenze di tempo. Su una macchina
sotto carico — mentre gira una `flutter build`, o con la suite in parallelo a
altro — possono fallire **a caso**, e il fallimento non dice "c'e' un bug", dice
"questa macchina era occupata". Osservato piu' volte: gli stessi test passano
sempre da soli, e in tre giri consecutivi della suite intera non hanno mai
fallito due volte lo stesso.

Non e' una scusa per ignorare un rosso: e' il motivo per cui, davanti a un
fallimento in uno di quei file, la prima cosa da fare e' rieseguire quel file da
solo prima di cercare un difetto. Nella pipeline la verifica gira in un job suo,
che non costruisce nello stesso momento, e questo riduce molto il problema.

## Struttura

```
lib/
  app/            stato applicativo (AppState) e radice dell'interfaccia
  data/           percorsi, contenitore .cpredux, catalogo, migratore, upgrade
  design/         token: palette, tipografia, movimento, geometria, tema
  domain/         caratteristiche, abilita', oggetti, cyberware, effetti, regole,
                  Night City (geometria), waypoint
  features/       schermate: home, scheda, campagna, impostazioni, file browser,
                  aggiornamento, mappa (canvas, painter, sezione, dialogo del
                  waypoint), confronto (schermata e selettore)
  net/            protocollo di sessione, Discord RPC, manifest e updater
  widgets/        componenti riutilizzabili (menu', input, dialoghi, zona di
                  rilascio)
tool/             seed leggibile del catalogo, generatore dell'asset, pubblicazione
test/             regole, catalogo, migratore, upgrade, sessione, documenti,
                  menu' principale, impostazioni, trascinamento, confronto,
                  mappa, aggiornamenti
```

I token stanno tutti in `lib/design/`: cambiare la palette o la velocita' di
tutta l'app significa toccare un file solo.

## Verifiche

```bash
flutter analyze     # No issues found
flutter test        # 189 test
flutter build macos # costruisce cpredux.app
```

### I bug trovati disegnando la mappa

Il painter non era mai stato eseguito: nessun analizzatore statico vede un
`Gradient` costruito male o una coordinata sbagliata. Scrivere un test che
disegna davvero la sezione ha prodotto due difetti che sarebbero arrivati
all'utente:

- **`Gradient.linear` con tre colori e senza posizioni.** `Gradient` accetta tre
  colori solo se si dicono le posizioni; senza, il disegno fallisce **a ogni
  pittura**. La mappa digitale e' l'aspetto predefinito, quindi la sezione
  sarebbe stata un riquadro di errore rosso al primo avvio.
- **`isJoined` era vero appena il socket si apriva**, non quando il tavolo
  accettava. La schermata diceva "in sessione" a chi aveva sbagliato la password
  e a chi il master non aveva ancora accettato — e in quella finestra il master
  non aveva ancora registrato il giocatore, quindi **tutto cio' che trasmetteva
  andava perso senza avviso**. E' il tipo di difetto che si scopre solo
  trasmettendo qualcosa in quel preciso istante: adesso `isJoined` legge la
  conferma del tavolo, esiste `isJoining` per dire "sto aspettando", e due test
  lo bloccano.

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

Sulla mappa i test coprono la geometria (vertici dentro la mappa, etichette
dentro il distretto), la conversione di coordinate nei due versi, la
serializzazione dei waypoint e degli angoli, il disegno vero della sezione in
entrambi gli aspetti e con un'immagine importata, il **clic che mette il segno
dove si e' cliccato**, e sul socket: consegna dei waypoint del tavolo, silenzio
totale su quelli privati, proposte che non si diffondono finche' il master non
le accetta, rimozioni di altri ignorate, `mapSync` a chi rientra.

## Comandi

```bash
flutter run -d macos      # app desktop
flutter test              # suite completa
flutter analyze           # analisi statica

dart run tool/build_catalog.dart            # rigenera assets/catalog/catalog.sqlite dal seed
dart run tool/import_legacy_catalog.dart    # importa gli oggetti dalle vecchie .cpred_sheet
dart run tool/import_dataset_catalog.dart   # importa gli oggetti da un dataset esterno (YAML)
dart run tool/publish.dart                  # pacchetti e manifesto di aggiornamento
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
| macOS | `cpredux-macos.zip` | `ditto -x -k` in un'area di lavoro, poi sostituzione del `.app` |
| Windows | `cpredux-windows.zip` (portable) | scompattato sopra la cartella di installazione |
| Linux | `cpredux-linux.AppImage` | copia accanto e `mv`, poi `chmod 755` |

Il pacchetto macOS **vale per entrambe le architetture dei Mac**, e non per
fortuna: `flutter build macos` produce un bundle universale, e ogni eseguibile
che ci sta dentro ha le due slice. Verificato sulla build vera:

```
$ find cpredux.app -type f -exec lipo -archs {} \;
       x86_64 arm64   Contents/MacOS/cpredux
       x86_64 arm64   Contents/Frameworks/FlutterMacOS.framework/.../FlutterMacOS
       x86_64 arm64   Contents/Frameworks/App.framework/.../App
       x86_64 arm64   Contents/Frameworks/sqlite3.framework/.../sqlite3
```

Lo zip universale pesa **20 MB**: due archivi separati non sarebbero la meta'
ciascuno, sarebbero lo stesso contenuto due volte, e per ottenerli davvero
bisognerebbe assottigliare e ri-firmare **ogni** file del bundle. E' per questo
che la pipeline controlla con `lipo` che le due slice ci siano, invece di
costruire due volte: e' il controllo che serve davvero — accorgersi se un giorno
il bundle diventasse a architettura singola, cosa che nessuno vedrebbe, perche'
l'archivio continuerebbe a chiamarsi allo stesso modo.

Nonostante questo il manifesto distingue **`macos-arm64`** e **`macos-x64`**, e
non e' un residuo: il programma chiede il pacchetto della propria architettura, e
l'architettura che conta e' quella del *processo in esecuzione* (`Abi.current()`),
non quella della macchina. Un processo x64 su un Mac Apple Silicon — cioe' sotto
Rosetta — **e'** x64, e deve ricevere il pacchetto Intel. Oggi le due chiavi
puntano allo stesso file universale; se un giorno si volessero due build separate
per risparmiare qualche megabyte, il manifesto, l'aggiornatore e la pagina sono
gia' quelli giusti e non va cambiato niente.

Su Windows si pubblica un pacchetto x64 per tutte le macchine: su quelle ARM gira
per emulazione. Su Linux un sistema ARM **non** riceve l'AppImage x64, che non
partirebbe: il programma dice che non c'e' un pacchetto per la sua macchina e
manda alla pagina dei rilasci, invece di scaricare ottanta megabyte inutili.

Su Linux l'aggiornamento funziona **solo** con l'AppImage: per un pacchetto della
distribuzione il file appartiene al gestore di pacchetti, e sostituirsi da soli
sarebbe sbagliato. In quel caso il programma lo dice invece di provarci.

Su una build di sviluppo (`build/…`) l'aggiornamento automatico e' **disattivato
e dichiarato**: sostituire il bundle dentro `build/` cancellerebbe il risultato di
una compilazione, o un bundle aperto a meta'.

## Il repository e la CI

Il "repository" a cui punta l'aggiornatore e' un **dominio**, non un'API. Quello
che la pipeline pubblica su quel dominio:

```
https://<namespace>.gitlab.io/cpredux/
├── index.html              la pagina di download (legge latest.json a runtime)
├── latest.json             il manifesto degli aggiornamenti
├── cpredux-macos.zip       nomi stabili: il link che hai mandato resta valido
├── cpredux-windows.zip
└── cpredux-linux.AppImage
```

La pagina di download **non** viene rigenerata a ogni rilascio: legge il
manifesto a runtime. Cosi' esiste un solo posto che sa qual e' la versione
corrente, e non puo' succedere che la pagina annunci una versione e il manifesto
ne pubblichi un'altra. I riquadri si riempiono dal manifesto, e una piattaforma
senza pacchetto resta **visibile e disattivata** invece di sparire: "non c'e' per
il tuo sistema" e' un'informazione, un riquadro mancante e' un dubbio. La pagina
sa due cose in piu': se le due voci macOS puntano allo
stesso archivio le mostra come **una** (universale, "Apple Silicon e Intel"), e
se invece fossero due file diversi **evidenzia quello giusto per il computer dal
cui la si guarda** — perche' in quel caso scaricare l'archivio dell'altra
architettura significa un'applicazione che non parte, dopo aver sostituito quella
che funzionava.

Entrambe le pipeline chiamano `dart run tool/publish.dart`, che calcola le
impronte, copia gli archivi con nome stabile, copia la pagina e scrive il
manifesto **con la stessa classe che lo legge l'applicazione**. Un generatore
scritto in un altro linguaggio puo' divergere in silenzio — un campo rinominato,
un numero scritto come stringa — e il sintomo sarebbe "gli aggiornamenti non
arrivano piu'", che nessuno collega a una modifica di mesi prima.

C'e' anche un test che tiene allineate le due liste: per ogni piattaforma che si
pubblica deve esistere un riquadro nella pagina. La pagina puo' non avere un
riquadro, e allora il pacchetto esisterebbe senza che nessuno sappia dove
prenderlo.

### Le due pipeline

| | GitHub (`.github/workflows/release.yml`) | GitLab (`.gitlab-ci.yml`) |
|---|---|---|
| Linux | `ubuntu-latest`, funziona subito | immagine Docker, funziona subito |
| Windows | `windows-latest`, funziona subito | runner `saas-windows-medium-amd64` |
| macOS | `macos-14` | runner `saas-macos-medium-m1` |

Tre pacchetti, tre costruzioni, un runner macOS solo: il bundle e' universale,
quindi non serve nessuna macchina Intel — nemmeno `macos-15-intel`, che era
l'ultima immagine Intel di GitHub e sara' ritirata nel 2027. Questa e' la ragione
per cui la separazione macOS ARM/Intel non e' finita nella pipeline: c'era, ed e'
stata tolta dopo aver guardato il bundle invece di presumere che fosse a
architettura singola.

Se un pacchetto manca — un runner assente, una build fallita — il rilascio si fa
lo stesso con quelli che ci sono: il manifesto elenca le piattaforme presenti,
quelle assenti compaiono nella pagina disattivate, e quel sistema vede che per la
sua macchina non c'e' niente invece di scaricare l'archivio di un altro.

### Il dominio

Non serve comprarne uno: Pages da' un URL pubblico (`https://<namespace>.gitlab.io/cpredux/`),
e basta incollarlo in **Impostazioni → Aggiornamenti** perche' l'aggiornamento
automatico funzioni. Il campo e' modificabile proprio per questo.

Se preferisci un dominio tuo (`tiadesigns.it` e' gia' tuo, quindi il candidato e'
`cpredux.tiadesigns.it`), serve il CNAME nel DNS — quello richiede l'accesso al
registrar — e poi la variabile di progetto `CPREDUX_PAGES_BASE` con l'indirizzo
definitivo: la pipeline la usa al posto di quello di GitLab, e il manifesto e i
link del rilascio seguono.

## Il rilascio, passo a passo

Quello che serve **una volta sola**, prima del primo rilascio:

1. **il progetto** su GitLab (o su GitHub: la pipeline c'e' per entrambi);
2. **i runner**. Linux gira subito. Windows e macOS girano sui runner di
   GitLab.com se il piano li include — il runner macOS basta uno, perche' il
   bundle e' universale;
3. **Pages** attivo (lo e' di default quando esiste un job `pages`) e
   l'indirizzo pubblicato incollato in Impostazioni → Aggiornamenti.

Poi, per **ogni** rilascio:

```bash
# 1. la versione, in due posti che un test tiene allineati
dart run tool/bump_version.dart 0.3.0     # oppure a mano: lib/version.dart + pubspec.yaml

# 2. il changelog e' l'annotazione del tag: la pagina del rilascio la usa come descrizione
git commit -am "..."
git tag -a v0.3.0 -m "Mappa condivisa al tavolo, confronto fra schede"
git push && git push --tags

# 3. nella pipeline del tag: avvia le costruzioni che ti servono, poi "pagine"
#    (manifesto + pagina) e infine "rilascio" (i link agli archivi)
```

I quattro job di costruzione sono `when: manual` con `allow_failure: true`: un
runner che non esiste lascerebbe altrimenti un job in attesa **per sempre**, e
una pipeline che aspetta per sempre e' peggio di una che pubblica tre pacchetti
su quattro — a patto che il manifesto dica quale manca, cosa che fa.
Se i tuoi runner ci sono tutti, si ottiene un rilascio in un clic solo
cambiando `when: manual` in `when: on_success` su costruzioni, `pagine` e
`rilascio`.

### Provare la pagina e il manifesto senza pubblicare

```bash
dart run tool/publish.dart --dist dist --site site --version 0.3.0 \
    --base-url https://esempio.test && open site/index.html
```

La pagina legge `latest.json` con una richiesta **relativa**, quindi funziona
anche aperta da disco: si vede esattamente quello che vedra' un utente, impronte
comprese.

### Rilasciare senza CI

Se un pacchetto manca — un runner assente, o una piattaforma che non hai — si
costruisce dove c'e' quella macchina, si mette l'archivio in `dist/` e si
rigenera il sito. `tool/publish.dart` prende **qualunque** archivio in `dist/` e
lo riconosce dal nome:

```bash
flutter build macos --release
cd build/macos/Build/Products/Release
ditto -c -k --keepParent cpredux.app ../../../../../dist/cpredux-macos.zip

# con gli altri archivi scaricati dagli artefatti della pipeline, sempre in dist/
dart run tool/publish.dart --dist dist --site public --version 0.3.0
```

E' anche il motivo per cui il nome del file conta. Un archivio che **non**
dichiara l'architettura viene trattato come universale e pubblicato col nome
stabile, valido per entrambi i Mac. Uno che la dichiara (`...-arm64.zip`,
`...-x64.zip`) tiene il proprio nome: sono due build separate, e rinominarle
entrambe `cpredux-macos.zip` farebbe sovrascrivere l'una con l'altra — cioe'
pubblicare il pacchetto Intel sotto il nome che il Mac Apple Silicon sta per
scaricare. E' l'unico errore di questa procedura che l'utente non si
accorgerebbe di stare subendo.

## Grafica e marchio

Il banner in testa a questo README e' in `assets/branding/banner.svg`: disegnato
qui, e' geometria come la mappa — griglia, neon, spigoli tagliati. Non riproduce
materiale di R. Talsorian Games, ed e' la stessa ragione per cui non c'e' il
marchio di Cyberpunk RED: la loro Homebrew Content Policy vieta di usare il
marchio **e** di imitare la veste grafica dei manuali ("no homebrew can mimic
our trade dress, from layout to font"). Il nome del progetto — `CPRED
Visualizer` — e' pensato per stare dentro quelle regole: il richiamo al gioco sta
nel sottotitolo descrittivo, che la policy permette, non nel titolo.

Se hai un permesso scritto di RTG, il posto per il logo e' gia' pronto:
`assets/branding/logo.svg` e la riga commentata in cima a questo file.

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

## Il bug che faceva cadere le impostazioni

"Crasha quando apro le impostazioni" era, alla lettera, un'eccezione di
impaginazione:

```
RenderFlex children have non-zero flex but incoming width constraints are unbounded.
  Row ← TechSegmented<bool> ← Row ← _ToggleRow ← … ← ChamferPanel
```

In una `Row` un figlio **non flessibile** riceve larghezza **illimitata**: e'
cosi' che i widget possono dichiarare da soli quanto sono larghi. Un controllo
che usa `Expanded` al proprio interno — "riempi lo spazio che avanza" — in quel
contesto chiede di riempire uno spazio infinito, e Flutter lo rifiuta invece di
adattarsi. Il selettore Attivo/Spento sta accanto a un'etichetta, non dentro una
colonna, quindi ogni riga con un interruttore sollevava un'eccezione.

La correzione e' nel **selettore**, non nelle due schermate che lo usavano male:
con larghezza limitata occupa lo spazio (l'aspetto che ha nelle colonne della
scheda), senza, si stringe sul contenuto tenendo i segmenti della stessa
larghezza. Cosi' funziona in qualunque contenitore, che e' quello che ci si
aspetta da un componente condiviso.

Lo stesso difetto aspettava **nella scheda**, in una riga di alterazione con un
attivo/spenta accanto all'etichetta: non si era ancora visto perche' quella riga
compare solo quando si aggiunge una correzione manuale. Lo ha trovato il test
del selettore, non una segnalazione — ed e' il motivo per cui il test verifica
la **regola** (funziona con e senza vincolo di larghezza) invece del solo caso
che aveva fatto rumore.

## Cosa manca

1. **Repository su GitLab**: i file sono pronti e la pipeline e' scritta, ma il
   progetto va creato sull'account GitLab (`glab auth login`, oppure un token con
   scope `api`) — il token fornito finora non aveva i permessi per creare un
   progetto (`insufficient_granular_scope`).
2. **Firma e notarizzazione di macOS**: senza un certificato Apple a pagamento,
   l'utente deve sbloccare l'applicazione al primo avvio da Privacy e Sicurezza.
   La pipeline funziona, ma la pagina di download deve spiegarlo (lo fa).
3. **Installer nativi** — MSI, DMG, deb/rpm con il runtime incluso. Oggi
   l'aggiornamento usa zip e AppImage, che funzionano ma non si presentano come
   un'installazione.
4. **Il peso degli oggetti importati**: il dataset non lo registra, quindi 243
   voci pesano 0 e il calcolo del carico le tratta come se non pesassero. Manca
   un modo per compilarlo in blocco — oggi si corregge oggetto per oggetto
   dalla scheda.
   Restano fuori dal catalogo, di proposito, i pacchetti `cyberware` (109
   voci), `drugs` (10), `programs` (15), `vehicles` (14) e `upgrades` (51):
   sono contenuti con un modello diverso dal catalogo oggetti.
5. **Aggiornamento del catalogo a runtime**: oggi il catalogo e' quello spedito;
   manca il modo di importare un catalogo piu' nuovo senza reinstallare l'app.
6. **Import/export di singoli elementi** (`.cpred_element`) del vecchio progetto.
7. **Tema chiaro**: i widget leggono ancora i colori scuri come costanti; serve
   prima un insieme di token risolti in base al tema. L'opzione resta nascosta
   finche' non funziona davvero.
8. **Mappa**: la geometria e' schematica e i confini dei distretti si possono
   correggere — e' un file solo, e c'e' un test che tiene oneste le coordinate.
   Manca anche il modo di condividere l'immagine importata con il tavolo.

## Note sulla mappa di Night City (fonti e licenze)

Tre cose da sapere sulla scelta di disegnarla invece di importarla.

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

**La scelta fatta.** Una sola geometria e due aspetti, piu' l'import con
georeferenziazione a quattro angoli per chi una mappa ce l'ha gia'. Vedi "La
mappa di Night City" sopra per come e' implementata.

Il vantaggio di disegnarla e' che diventa tua: nessuno potra' chiederti di
rimuoverla, e la mappa puo' diventare la cosa per cui il programma viene
ricordato — come i tuoi contatori sul sito.

**Limiti dichiarati.**

1. La geometria e' **schematica**: le posizioni relative dei distretti sono
   giuste, i confini sono verosimili, non sono un rilevamento. E' una mappa da
tavolo, non una carta geografica.
2. Un'immagine importata con una prospettiva **forte** resta piegata lungo la
   diagonale: `Canvas` non offre una trasformazione prospettica per i bitmap e si
   usano due triangoli. Con angoli quasi rettangolari — cioe' sempre, cliccando i
   quattro angoli di una scansione — non si vede.
3. I waypoint messi da un **giocatore** non sono salvati su disco finche' il
   master non li accetta: vivono nella sessione. La mappa preparata e' quella del
   master, ed e' l'unica che ha senso conservare.
4. L'immagine importata **non e' condivisa**: e' un file del master. Chi gioca
   vede la geometria del programma. Condividerla significherebbe spedire un file
   dell'utente senza che l'abbia chiesto.

## Note sul catalogo (fonti e licenze)

Il catalogo ha **due origini**, e ogni voce dichiara la sua.

**Le 63 voci curate** (`source: core`) le ho scritte io a mano dal manuale
base, e sono tipi generici: "Pistola Media", "Kevlar", "Armaturajack Leggera".
Sono comode per inventare un personaggio in fretta e non sono verificabili in
questo repository — valgono come punto di partenza, non come regola.

**Le 243 voci importate** (`source: fvtt-cpred`) vengono dal sistema Foundry
VTT "Cyberpunk RED - Core" del Project Red Team, distribuito sotto la Homebrew
Content Policy di R. Talsorian Games. Quella policy copre esplicitamente le
applicazioni e permette di importare le **statistiche** degli oggetti; non
permette di riprodurre illustrazioni o loghi dei manuali, e l'uso deve restare
gratuito. Quindi:

- nessun artwork ufficiale e' nel catalogo, ne' come asset ne' come Base64
  (c'e' un test che lo verifica);
- quello che c'e' sono **nomi e numeri** — danno, capienza, SP, prezzo — piu' il
  riferimento alla pagina del manuale, che serve proprio a poterli controllare;
- il dataset **non e' nel repository**: si scarica a parte, e la conversione e'
  uno script che chiunque puo' rieseguire e controllare;
- togliere tutte le voci importate e' una riga di filtro su `source` nel seed,
  e un test verifica che le voci curate siano rimaste esattamente 63.

La stessa disciplina della mappa, applicata agli oggetti: dati di terzi
**dentro la policy**, artwork di terzi fuori, e nessuna pretesa di autorevolezza
che il progetto non puo' garantire.
