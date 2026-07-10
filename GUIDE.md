# 📖 Manuale Operativo: MinecraftAdmin Network

> [!TIP]
> Benvenuto nella guida ufficiale! Questo documento è il punto di riferimento per l'amministrazione, i costruttori e i giocatori del network. Qui troverai una mappatura completa dei comandi, le migliori pratiche d'uso e schemi architetturali.

## 📋 Indice dei Contenuti
1. [🗺️ Architettura del Network](#-architettura-del-network)
2. [🛡️ Autenticazione e Profilo (Lobby)](#-1-autenticazione-e-profilo-lobby)
3. [⚖️ Moderazione e Anti-Cheat](#-2-moderazione-e-anti-cheat)
4. [💰 Economia (XConomy)](#-3-economia-xconomy)
5. [💬 Chat Sociale](#-4-chat-sociale)
6. [🚀 Movimento e Navigazione](#-5-movimento-e-navigazione)
7. [👑 Ruoli e Permessi (LuckPerms)](#-6-ruoli-e-permessi-luckperms)
8. [🏗️ Territorio (WorldEdit e WorldGuard)](#-7-territorio-worldedit-e-worldguard)
9. [💾 Dati e Backups con HuskSync](#-8-dati-e-backups-con-husksync)
10. [🧠 Intelligenza Artificiale (SentientMobs)](#-9-intelligenza-artificiale-sentientmobs)
11. [🐲 Gestione NPC e Mob Custom](#-10-gestione-npc-e-mob-custom)
12. [📊 Diagnostica e Prestazioni](#-11-diagnostica-e-prestazioni)
13. [⚡ Comandi Essenziali (EssentialsX)](#-12-comandi-essenziali-e-qualità-della-vita-essentialsx)

---

## 🗺️ Architettura del Network

Prima di esplorare i comandi, è fondamentale comprendere come il network gestisce i giocatori e i dati dietro le quinte.

```mermaid
flowchart TD
    Player["👤 Giocatore"] -->|Connessione| Proxy["⚡ Velocity Proxy"]
    
    subgraph Backend Servers
        Lobby["🏰 Lobby (AuthMe)"]
        Survival["🌲 Survival"]
        Creative["🎨 Creative"]
        Moto["🏍️ MotoLeo"]
        Medioeval["⚔️ Medioeval"]
    end

    Proxy -->|Login Obbligatorio| Lobby
    Lobby -->|BungeeTP / Portals| Survival
    Lobby -->|BungeeTP / Portals| Creative
    Lobby -->|BungeeTP / Portals| Moto
    Lobby -->|BungeeTP / Portals| Medioeval

    subgraph Data Layer
        DB[("MariaDB")]
        Redis[("Redis")]
    end
    
    Survival -.-> |Sincronizza Dati| DB
    Creative -.-> |Sincronizza Dati| DB
    Survival -.-> |Chat Globale| Redis
    Proxy -.-> |Punizioni / Permessi| DB
```

> [!IMPORTANT]
> Tutti i database (MariaDB e Redis) vivono in una rete Docker privata. Non esponiamo MAI queste porte all'esterno.

---

## 🛡️ 1. Autenticazione e Profilo (Lobby)

L'ingresso dei giocatori sp (Offline Mode) richiede un sistema solido per proteggere l'identità. Il login è centralizzato esclusivamente nel server **Lobby**.

```mermaid
sequenceDiagram
    participant P as Giocatore
    participant V as Velocity Proxy
    participant L as Lobby
    participant S as Ultimo Server
    
    P->>V: Connessione al Network
    V->>L: Instradamento forzato alla Lobby
    L->>P: Richiesta Password o Registrazione
    P->>L: /login password
    L-->>V: Segnale Login Success
    V->>S: Teletrasporto all'ultimo server!
```

### Gestione Account (AuthMe)

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/register <pw> <pw>` | 👤 Giocatore | Registra un nuovo account al primo ingresso. |
| `/login <pw>` | 👤 Giocatore | Effettua l'accesso per giocare. |
| `/changepassword <old> <new>` | 👤 Giocatore | Modifica la password personale. |
| `/authme unregister <giocatore>` | 👑 Admin | Elimina l'account (permette di rifare il setup). |
| `/authme changepassword <utente> <pw>` | 👑 Admin | Forza un cambio password per un utente smarrito. |

### Aspetto e Skin (SkinsRestorer)
Poiché l'account è offline, la skin non si aggiorna automaticamente dai server Mojang.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/skin <NomePremium>` | 👤 Giocatore | Imita la skin di un giocatore Premium esistente. |
| `/skin update` | 👤 Giocatore | Ricarica la skin in caso di aggiornamenti. |
| `/skin clear` | 👤 Giocatore | Torna alla skin di default (Steve/Alex). |
| `/sr set <giocatore> <skin>` | 👑 Admin | Assegna forzatamente una skin a qualcuno. |

---

## ⚖️ 2. Moderazione e Anti-Cheat

> [!WARNING]
> Grazie a **LibertyBans**, qualsiasi sanzione ha un raggio d'azione globale. Un ban dato nel server "Creative" chiude l'accesso a tutto il Network a livello Proxy (Velocity).

### Punizioni e Controllo

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/ban <giocatore> [tempo] [motivo]` | 🛡️ Staff | Es: `/ban Marco 2d Griefing`. |
| `/mute <giocatore> [tempo] [motivo]`| 🛡️ Staff | Silenzia il giocatore nella chat. |
| `/kick <giocatore> [motivo]` | 🛡️ Staff | Espelle momentaneamente dal network. |
| `/history <giocatore>` | 🛡️ Staff | Apre una dashboard GUI (interfaccia) con lo storico sanzioni. |
| `/alts <giocatore>` | 🛡️ Staff | Cerca altri account connessi dallo stesso IP per prevenire elusioni. |

### Sicurezza (BetterGrim)
Nessun comando necessario! L'anticheat agisce in modo passivo e asincrono per prevenire cheat (Speed, Killaura) bloccando le iterazioni a livello di protocollo.

---

## 💰 3. Economia (XConomy)

L'economia è persistente e unificata su database. I portafogli viaggiano da server a server.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/money` o `/balance` | 👤 Giocatore | Visualizza il saldo bancario attuale. |
| `/pay <giocatore> <importo>` | 👤 Giocatore | Dona denaro. |
| `/baltop` | 👤 Giocatore | Mostra la classifica generale dei più ricchi. |
| `/money set <giocatore> <importo>` | 👑 Admin | Inizializza un saldo preciso. |
| `/money give <giocatore> <importo>`| 👑 Admin | Genera e accredita fondi artificialmente. |

---

## 💬 4. Chat Sociale

La chat è potenziata da **RedisChat**, garantendo una comunicazione fluida senza barriere fisiche tra i server.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `[messaggio diretto]` | 👤 Giocatore | Parla nella chat Pubblica (visibile in *tutti* i server). |
| `/msg <utente> <messaggio>` | 👤 Giocatore | Messaggio privato (PM). |
| `/r <messaggio>` | 👤 Giocatore | Risponde automaticamente all'ultimo utente che ti ha scritto in privato. |
| `/ignore <utente>` | 👤 Giocatore | Nasconde i messaggi di un utente per il tuo account. |
| `/mail` | 👤 Giocatore | Sistema di posta elettronica interna per chi è temporaneamente offline. |

---

## 🚀 5. Movimento e Navigazione

```mermaid
flowchart LR
    Player(("Giocatore"))
    Portal["Portale Fisico<br>AdvancedPortals"]
    Command["Comando Chat<br>/server o /tpa"]
    
    Player -->|Attraversa| Portal
    Player -->|Digita| Command
    Portal -.->|BungeeTP| Destination[("Server Destinazione")]
    Command -.->|BungeeTP| Destination
```

### Spostamenti Diretti (BungeeTP)

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/server <nome>` | 👤 Giocatore | Viaggia istantaneamente. Esempio: `/server survival`. |
| `/tpa <giocatore>` | 👤 Giocatore | Chiede di teletrasportarsi verso il giocatore (cross-server). |
| `/tpaccept` | 👤 Giocatore | Accetta la richiesta TPA. |
| `/tp <giocatore>` | 👑 Admin | Teletrasporto silenzioso bypassando le richieste. |

### Portali Fisici (AdvancedPortals)

> [!NOTE]
> Per costruire i portali dimensionali, bisogna sempre sfruttare l'ascia magica di WorldEdit (`//wand`).

1. Seleziona i punti in cui vuoi che avvenga l'attivazione.
2. Esegui: `/portal create <nomeportale> bungeecord <nomedestinazione>`.
3. Attraversare il portale ti scaglierà direttamente nel server indicato (es. `survival`).

---

## 👑 6. Ruoli e Permessi (LuckPerms)

Il motore centrale della gerarchia (VIP, Helper, Mod, Admin) gestisce l'accesso **a livello di rete Proxy (Velocity)**.
> [!WARNING]
> LuckPerms in questa architettura è posizionato sul nodo Velocity e regola l'ingresso e i comandi proxy (es. `/skin`). Non governa i comandi dei server backend (come `/god`, `/mm` o WorldEdit). Per avere il totale controllo nei vari mondi, il giocatore Admin deve essere reso `OP` (Operatore) nei singoli nodi backend, scavalcando di fatto ogni restrizione.

> [!TIP]
> **Come usare il Web Editor (Fortemente Consigliato)**
> Non perdere tempo con mille comandi in chat. Digita `/lp editor`. Il plugin ti darà un link univoco; aprilo sul browser, usa la comoda interfaccia grafica per trascinare ruoli e aggiungere permessi, poi premi Salva. Otterrai un comando che inizierà per `/lp apply <hash>`, incollalo su Minecraft e le modifiche diverranno effettive all'istante!

| Comando di Base | Azione |
| :--- | :--- |
| `/lp user <giocatore> parent set <rank>` | Sostituisce il ruolo principale dell'utente. |
| `/lp user <giocatore> permission set <nodo>` | Assegna un permesso secco a un utente. |
| `/lp group <rank> meta setprefix <stringa>` | Personalizza le tag VIP/Admin visibili in TAB e Chat. |

---

## 🏗️ 7. Territorio (WorldEdit e WorldGuard)

Strumenti indispensabili per lo Staff (Builder/Mod).

### Terraformazione in Massa (WorldEdit)
| Comando | Azione / Descrizione |
| :--- | :--- |
| `//wand` | Ricevi lo strumento di selezione. |
| `//set <blocco>` | Riempie interamente la selezione geometrica. |
| `//replace <id1> <id2>`| Trasforma tutti i blocchi `id1` nell'area in `id2`. |
| `//undo` | Annulla (salva la vita in caso di errore disastroso!). |

### Protezione Zone (WorldGuard)
| Comando | Azione / Descrizione |
| :--- | :--- |
| `/rg define <nome_zona>` | Dichiara la zona selezionata (con ascia) protetta dal griefing. |
| `/rg flag <zona> pvp deny` | Proibisce il ferimento e il combattimento lì dentro. |
| `/rg flag <zona> mob-spawning deny` | Nessun mostro può apparirvi naturalmente. |
| `/rg addmember <zona> <utente>` | Concede solo all'utente indicato il permesso di rompere blocchi in quella zona. |

---

## 💾 8. Dati e Backups con HuskSync

HuskSync è vitale per trasportare XP, inventari, e vita da un server Backend all'altro senza creare loop di cloni.

> [!CAUTION]
> Maneggiare l'inventario degli altri è sensibile e impatta l'esperienza di gioco. Fallo solo per scopi diagnostici e di moderazione.

| Comando | Azione / Descrizione |
| :--- | :--- |
| `/husksync invsee <giocatore>` | Apre l'inventario live del giocatore (funziona anche se il giocatore non è in game!). |
| `/husksync echest <giocatore>` | Visualizza l'EnderChest globale dell'utente. |
| `/husksync restore <giocatore>` | Visualizza tutti gli **snapshot (backup orari e alla morte)** dell'utente. Consente a un Admin di ripristinare il setup se il giocatore è stato vittima di glitch o grief letali. |

---

## 🧠 9. Intelligenza Artificiale (SentientMobs)

I mob ostili in questo network non sono stupidi! Grazie a **SentientMobs**, l'AI base di Minecraft viene rimpiazzata con comportamenti situazionali avanzati (coordinamento per chiamare rinforzi, ritirate strategiche e tattiche di combattimento di gruppo). 

Il plugin opera passivamente senza richiedere grandi azioni da parte dei giocatori, ma offre alcuni comandi per lo staff.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/sm createlang <lingua>` | 👑 Admin | Crea un template di lingua in `plugins/SentientMobs/lang/` per tradurre l'interfaccia o personalizzare i nomi. |
| `/sm setlang <lingua>` | 👑 Admin | Cambia la lingua attiva al volo (es. `it-IT`). |

---

## 🐲 10. Gestione NPC e Mob Custom

Per popolare i mondi con personaggi non giocanti (NPC) interattivi o boss personalizzati, il server si avvale di **Citizens2** e **MythicMobs**.

### Citizens (Creazione NPC)
> [!WARNING]
> A causa di limitazioni di sicurezza nel download automatico di Citizens, l'amministratore **deve** scaricare manualmente il file `Citizens-*.jar` ufficiale e inserirlo nella cartella locale `custom-plugins/`. Successivamente, lanciando `./deploy.sh --server`, il plugin verrà installato su tutti i nodi e i comandi si abiliteranno.

Gli NPC sono utilissimi per fare da mercanti, guide o ologrammi viventi negli spawn.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/npc create <Nome>` | 👑 Admin | Crea un NPC nel punto in cui ti trovi. |
| `/npc sel` | 👑 Admin | Seleziona l'NPC che stai guardando per modificarlo. |
| `/npc type <tipo>` | 👑 Admin | Cambia il tipo di entità (es. `villager`, `zombie`, `skeleton`). |
| `/npc skin <NomePremium>` | 👑 Admin | Cambia la skin dell'NPC selezionato. |
| `/npc equip` | 👑 Admin | Apre l'editor per vestire l'NPC e dargli oggetti in mano. |
| `/npc text` | 👑 Admin | Permette di aggiungere frasi che l'NPC dirà quando ci si avvicina o si clicca. |
| `/npc remove` | 👑 Admin | Elimina l'NPC selezionato. |

### MythicMobs (Boss e Mob Custom)
MythicMobs permette di creare nemici formidabili con abilità, magie e drop unici.

> [!TIP]
> **Editor Visuale per i Mob!**
> Non impazzire scrivendo a mano righe di codice YAML se non vuoi! Dal **Pannello di Controllo Web**, recati nella sezione "Mobs". Li troverai un **Editor Visuale** guidato che ti permetterà di configurare con drop-down, caselle di controllo e campi numerici tutta la base dei tuoi mostri: restrizioni vanilla, movimento, barra della salute (BossBar) personalizzata e stato visivo. Il pannello riformatterà e sincronizzerà tutto in automatico!

> [!TIP]
> **Architettura Globale!** Tutti i mob, le abilità e gli oggetti creati con MythicMobs sono condivisi e sincronizzati in tempo reale su **tutti** i server (Lobby, Survival, Creative, ecc.) tramite volumi Docker centralizzati. Puoi spawnare qualsiasi boss in qualsiasi mondo!

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/mm m spawn <NomeMob>` | 👑 Admin | Spawna un mob custom definito nei file di configurazione (`plugins/MythicMobs/Mobs/`). |
| `/mm i get <NomeItem>` | 👑 Admin | Ottieni un oggetto magico/custom creato con MythicMobs. |
| `/mm s create <NomeSpawner> <NomeMob>` | 👑 Admin | Crea un punto di spawn automatico nel blocco che stai guardando. |
| `/mm s set <NomeSpawner> warmup <secondi>` | 👑 Admin | Modifica il tempo di ricarica dello spawner. |
| `/mm reload` | 👑 Admin | Ricarica le configurazioni (utile dopo aver modificato i file YAML). |

#### 👹 Lista Mob Custom Attualmente Disponibili
Di seguito la lista di tutti i boss e mob personalizzati pronti per essere spawnati (via comando o spawner) nel network:

| Nome Interno (`<NomeMob>`) | Descrizione / Caratteristiche | Difficoltà |
| :--- | :--- | :--- |
| `SkeletalKnight` | Cavaliere Wither con armatura in ferro e scudo. Droppa monete d'oro. | Media |
| `SkeletonKing` | **Boss!** Evoca minion, dialoga in chat e sferra attacchi esplosivi "Smash" letali. | Alta 💀 |
| `SkeletalMinion` | Semplice scheletro gregario evocato dal Re. | Bassa |
| `StaticallyChargedSheep` | Pecora immune ai fulmini che lancia dardi elettrici a chiunque le stia vicino. | Media |
| `AngrySludge` | Slime gigante formidabile che emette onde circolari velenose ad area. | Alta |
| `PurgeTitan` | **Evento di Purificazione!** Un Titano Gigante che evoca un'orda (25+) di Cacciatori Epuratori che eliminano tutti i mostri nel raggio. Dopo 60s si auto-distrugge con il suo esercito. | Estrema ☠️ |

---

## 📊 11. Diagnostica e Prestazioni

| Plugin / Tool | Comando | Utilizzo Principale |
| :--- | :--- | :--- |
| **spark** | `/spark profiler start` | Registra e profila il consumo RAM e CPU (generando link interattivi allo `stop`). Usalo in caso di Lag. |
| **BlueMap** | `/bluemap render prioritize <mondo>` | Aggiorna forzatamente la mappa 3D accessibile dal Web Panel per riflettere le nuove costruzioni. |

---

## ⚡ 12. Comandi Essenziali e Qualità della Vita (EssentialsX)

Molti dei classici comandi "Vanilla" potenziati o comandi di comodità per lo Staff sono forniti dal motore **EssentialsX**. Se sei Admin o OP, questi comandi ti semplificheranno la vita ovunque nel network.

| Comando | Esecutore | Azione / Descrizione |
| :--- | :--- | :--- |
| `/god` | 👑 Admin | Rende il giocatore invulnerabile a qualsiasi danno. |
| `/fly` | 👑 Admin | Permette di volare anche nella modalità Sopravvivenza. |
| `/heal [giocatore]` | 👑 Admin | Cura completamente la vita e riempie la fame. |
| `/feed [giocatore]` | 👑 Admin | Sazia istantaneamente il giocatore. |
| `/speed <velocità>` | 👑 Admin | Aumenta o diminuisce la velocità di volo/corsa (es. `/speed 2`). |
| `/invsee <giocatore>`| 👑 Admin | In alternativa a HuskSync, permette la manipolazione veloce. |
| `/vanish` o `/v` | 👑 Admin | Rende l'admin completamente invisibile agli altri giocatori. |

