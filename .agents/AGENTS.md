# Regole del Progetto e Informazioni Strutturali
Questa documentazione è dedicata a futuri Agenti (AI) per mantenere coerenza architettonica e consapevolezza del contesto storico e tecnico del progetto MinecraftAdmin.

## 1. Stack Tecnologico e Infrastruttura
- **Motore Server**: Paper (per i backend) e Velocity (per il proxy), basati sulle immagini Docker `itzg/minecraft-server` e `itzg/bungeecord`.
- **Backend (Web Panel)**: Next.js 16.2.9 (App Router) + TailwindCSS.
- **Rete Virtuale**: `mc_network` chiusa. Tutte le comunicazioni interne passano tramite DNS Docker (es. `http://panel:3000`).
- **Nginx Reverse Proxy**: Messo sulla porta `9800` (pubblica). Indirizza `/` al Web Panel e `/map/<mondo>/` alle mappe BlueMap.
- **Isolamento delle Porte**: Per sicurezza, porte come RCON (`25575-25579`) e database MySQL (`3306`) **non devono MAI essere esposte su 0.0.0.0**. Nel `docker-compose.yml` usano sempre il binding locale (es. `127.0.0.1:3306:3306`).

## 2. Problemi Affrontati (Lezioni Imparate)

### A. Il "Lock" del Data Bridge (Risolto con HuskSync)
- **Sintomo:** Il precedente plugin `mc-data-bridge` calciava i giocatori all'ingresso segnalando anomalie di sicurezza o firme errate (identity_hash mismatch), andando in timeout continuo.
- **Causa:** Nelle configurazioni dietro Proxy, gli UUID Offline generati cambiavano ad ogni minimo aggiornamento di configurazione di rete, e il plugin non tollerava questo cambio di firma.
- **Soluzione Attiva (Root Fix):** Il plugin `mc-data-bridge` è stato completamente rimosso dall'infrastruttura e sostituito con **HuskSync**, che è stato configurato per interfacciarsi allo stesso database MariaDB e a Redis. HuskSync gestisce nativamente le reti proxy (Velocity) senza falsi positivi sulle firme ed è molto più affidabile per la sincronizzazione di inventari, enderchest e statistiche. Attenzione: HuskSync **non** deve girare sul nodo Velocity.

### B. Il Paradosso di Localhost tra Nginx in Docker e App su Host
- **Sintomo:** Nginx (dentro Docker) dà errore `502 Bad Gateway` cercando di collegarsi a Next.js (PM2 sull'Host) tramite `host.docker.internal`.
- **Causa:** Next.js era stato blindato in ascolto solo su `127.0.0.1`. Docker non usa l'interfaccia di loopback locale per parlare con l'host, ma l'interfaccia `docker0` (es. 172.x.x.x), quindi la connessione veniva rifiutata.
- **Soluzione:** È stata creata un'infrastruttura 100% Docker. Il Web Panel è ora un container dedicato (`mc_panel`), permettendo a Nginx di usare semplicemente `proxy_pass http://panel:3000`. PM2 è stato eliminato.

### C. Deploy senza disconnettere l'utenza
- **Problema originario:** Lo script `deploy.sh` faceva un `docker compose stop` prima di ricaricare i container, disconnettendo brutalmente tutta l'utenza.
- **Soluzione attiva:** Il deploy si limita ora a copiare asincronamente i file (plugin `.jar`, configurazioni) e fa un `docker compose up -d` che impatta solo container di cui è cambiata la ricetta. 
- **Riavvio "Hot-Swap":** L'amministratore apre il Web Panel, clicca "Riavvia" su un singolo mondo (es. Survival), e il sistema avvia un conto alla rovescia di 30s. Scaduto il tempo, esegue `docker compose restart survival`. Velocity, grazie a `failover-on-unexpected-server-disconnect = true`, teletrasporta istantaneamente i giocatori dal mondo morente alla Lobby senza interrompere la connessione generale.

### D. Routing BlueMap e Nginx
- **Sintomo:** Iframe della mappa 3D restituiva errore 404.
- **Causa:** L'URL utilizzato per BlueMap nell'iframe era `/map/<mondo>/`, ma la configurazione di Nginx instrada le richieste ai container BlueMap tramite `/bluemap/<mondo>/`.
- **Soluzione:** Utilizzare sempre `/bluemap/` come base url per gli endpoint delle mappe.

### E. Next.js App Router e Client Components nel Layout
- **Sintomo:** Errore in fase di `next build` static export.
- **Causa:** L'utilizzo dell'hook `useSearchParams` in un Client Component non wrappato in `<Suspense>` disabilita parzialmente il rendering statico o rompe la build.
- **Soluzione:** Qualsiasi layout client che usi `useSearchParams` (es. `LayoutClient`) va wrappato in `<Suspense fallback={...}>` nel parent layout lato server.

### F. Inizializzazione Database
- **Sintomo:** Le query del pannello a MariaDB falliscono (es. `Table 'minecraft.server_metrics' doesn't exist`).
- **Causa:** I container del db si avviano senza le tabelle dell'appliance (es. AuthMe o profiler).
- **Soluzione:** Lo script `deploy.sh` utilizza `docker exec -i mc_db mysql` per eseguire la query `CREATE TABLE IF NOT EXISTS` e assicurare lo scaffolding automatico senza interventi manuali, evitando tool esterni.

### G. Latenze causate da child_process (exec)
- **Sintomo:** I comandi RCON (es. `mc-send-to-console`) e le interrogazioni di stato Docker andavano in timeout o saturavano la memoria Node.js creando processi orfani.
- **Soluzione per AI:** L'architettura è stata migrata al **ServiceManager** (Pattern Strategy) localizzato in `src/lib/services/`. Non utilizzare mai chiamate `exec` dirette per interagire con i container o l'RCON, ma utilizza `ServiceManager.getInstance().sendCommand()` instanziando un `DockerServiceClient` o un `RconServiceClient`.

### H. Architettura Provisioning Dinamico
- **Logica di Creazione (Clonazione/Template):** La route `/api/worlds/create` genera nuovi server calcolando le porte dinamicamente e iniettando configurazioni.
- **Dipendenze di Rete:** Quando crei un server, ricorda di configurare: `docker-compose.yml` (creazione service paper), `proxy/config.yml` (bungeecord upstream), e `nginx/nginx.conf` (reverse proxy BlueMap `/bluemap/<name>/`). Tutte le modifiche vengono applicate senza far cadere i giocatori, eseguendo un riavvio "Hot-Swap" tramite il ServiceManager (`compose-up` e `compose-restart`).

### I. Rientro Dinamico all'Ultimo Server / Persistenza Posizione
- **Sintomo:** Dopo un riavvio del proxy o quando un giocatore si riconnette, viene sempre riportato in Lobby, perdendo la sua posizione nell'ultimo mondo di gioco.
- **Problema di Sicurezza:** Inoltrare direttamente l'utente al server in cui si trovava (es. `survival`) scavalcherebbe il login di AuthMe presente solo nella `lobby`.
- **Soluzione (LastServerAddon):** È stato installato il plugin `AuthMeVelocity-LastServerAddon` sul nodo Velocity (proxy) e abilitato il flag `send-on-login: true` in `AuthMeVelocity`. L'utente entra e viene forzato in Lobby. Nell'istante in cui si logga in AuthMe, l'addon intercetta l'autenticazione completata dal proxy e lo teletrasporta istantaneamente al suo "ultimo server". Da lì, Minecraft nativamente lo fa spawnare alle esatte coordinate in cui aveva effettuato il quit.

### J. Architettura Porte Interne Docker
- **Ottimizzazione RCON e Minecraft:** Tutti i container dei server di backend si trovano nella stessa `mc_network`. Di conseguenza, comunicano tra di loro e con il Web Panel (anch'esso un container) tramite hostname (es. `mc_lobby`, `mc_motoleo`).
- **Regola:** Non incrementare dinamicamente le porte interne nei container (come `RCON_PORT=25576, 25577` ecc.). Tutti i server devono utilizzare internamente la porta standard `25575` per l'RCON e `25565` per il gioco. Non è più necessario esporre queste porte sull'host (`ports: - "127.0.0.1:2557x:25575"`) poiché il Web Panel contatta i server internamente. Questo semplifica la manutenzione ed evita errori incrociati come gli `ECONNREFUSED`.
### K. Gestione Disconnessioni Proxy e Plugin Superflui
- **Sintomo:** LibertyBans generava avvisi di "unrelocated library classes" a causa del plugin `reconnect` (SimpleReconnect) e SkinsRestorer consigliava di rimuovere `ViaVersion` dal proxy.
- **Soluzione:** Velocity supporta nativamente il reinstradamento dei giocatori in caso di server down o crash configurando `failover-on-unexpected-server-disconnect = true` nel `velocity.toml`. Di conseguenza, `SimpleReconnect` è stato eliminato per sempre. Inoltre, i plugin `ViaVersion` e `ViaBackwards` sono stati spostati dal proxy ai singoli server backend (nella cartella `custom-plugins/` gestita dallo script di deploy) per prevenire conflitti. `deploy.sh` è stato aggiornato per pulire forzatamente questi file `.jar` dal proxy per evitare reintroduzioni accidentali.

### M. Risoluzione Conflitti Comandi Bukkit (LibertyBans / RedisChat vs EssentialsX)
- **Sintomo:** Plugin come EssentialsX e CMI sovrascrivono nativamente i comandi di punizione (es. `/ban`) o messaggistica privata (es. `/msg`), impedendo il funzionamento globale di LibertyBans e RedisChat.
- **Soluzione:** È stato creato un file `shared/commands.yml` nel repository, che definisce gli `aliases` (es. `msg: - redischat:msg $1-`, `ban: - libertybans:ban $1-`). Lo script `deploy.sh` sincronizza questo file in tutti i backend server (lobby, survival, creative, ecc.). Bukkit dà sempre la priorità a `commands.yml`, aggirando l'hardcoding dei plugin e garantendo coerenza globale senza dover configurare manualmente i config di EssentialsX su ogni server.

### N. Bug Skript: Caricamento Aliases Asincrono (Severe Error)
- **Sintomo:** Durante riavvii massivi del network, Skript smette di riconoscere oggetti base di Minecraft (es. "Can't understand this structure: on right click with compass"), stampando un "Severe Error" in console al momento del boot.
- **Causa:** Nelle versioni recenti, Skript carica gli aliases in modo asincrono. Se la CPU del VPS subisce un picco prolungato (es. riavvio di 5 container in parallelo), il thread di caricamento degli alias va in crash/timeout e Skript disabilita l'intero dizionario.
- **Soluzione:** È sufficiente riavviare il singolo container interessato (es. `docker restart mc_lobby`) a bocce ferme. Il caricamento andrà a buon fine. Non è necessario modificare gli script `.sk`.

### O. Falsi Allarmi RedisChat (Startup Announcer)
- **Sintomo:** La console e la chat vengono spammate ogni 5 minuti con un messaggio rosso: "To EssentialsX and CMI users: disable /msg, /reply...".
- **Causa:** Non è un vero errore di avvio, ma l'annuncio predefinito (`announcementName: default`) nel file `config.yml` di RedisChat che l'autore ha inserito per ricordare di fare l'override dei comandi.
- **Soluzione:** L'annuncio è stato cancellato eliminando l'array `announcer` in tutti i `config.yml` locali. L'override reale è stato comunque garantito tramite `commands.yml` (vedi punto M).

### P. Parser YAML e Integrazioni Visuali (MythicMobs)
- **Sintomo:** Fornire unicamente un editor testuale per MythicMobs costringe gli admin a ricordare complesse configurazioni YAML, incoraggiando errori di sintassi e indentazione.
- **Soluzione (Architettura Web Panel):** Nel pannello Next.js (`(dashboard)/mobs/page.tsx`, `items/page.tsx`, `skills/page.tsx`) è stato implementato un "Visual Editor" a schede che trasforma il file YAML in componenti UI (Dropdown, Checkbox, Input numerici) coprendo Movimento, Restrizioni Vanilla (Anti-Grief), Condizioni, Attributi, Ecc. I file sono gestiti in modo globale e non necessitano di selettore per il server. È inoltre supportata la cancellazione globale del file YAML tramite il pulsante 🗑️.
- **Documentazione Ufficiale MythicMobs:** Per ulteriori implementazioni e chiavi YAML, fare sempre riferimento alla guida ufficiale: [https://git.mythiccraft.io/mythiccraft/MythicMobs/-/wikis/home](https://git.mythiccraft.io/mythiccraft/MythicMobs/-/wikis/home)
- **Regola di Sviluppo per AI:** Quando si aggiungono nuove opzioni visuali a questo editor, usare `handleCategoryChange` per le strutture nidificate. Tale logica ricrea e serializza l'oggetto in tempo reale via `yaml.dump({lineWidth: -1})`. È vitale eliminare le chiavi quando un valore diventa vuoto/undefined (es. `delete newData[category][field]`) affinché il parser non generi file YAML inquinati da nodi vuoti che causano crash su MythicMobs al reload.

### L. Gestione Permessi: Rete Globale (Proxy + Backend)
- **Sintomo Storico:** Comandi da amministratore come `/god` (backend) o `/skin` (proxy) non funzionavano, o i giocatori admin lamentavano di aver perso i privilegi dopo aver provato comandi per i quali mancavano i plugin fisici (es. Citizens/MythicMobs).
- **Nuova Architettura Permessi:** LuckPerms è ora installato **sia sul nodo Proxy (Velocity) sia su tutti i nodi Backend (Lobby, Survival, ecc.)**. Tutti i nodi sono configurati per leggere dallo stesso database MariaDB (`mc_db`) e si sincronizzano in tempo reale tramite la tabella `luckperms_messenger`.
- **Vantaggio:** Qualsiasi ruolo o permesso assegnato dal Web Panel (es. `*` per il gruppo Admins) viene riconosciuto istantaneamente e simultaneamente su tutta la rete. Non è più necessario gestire i poteri forzando gli utenti ad essere OP, garantendo maggiore granularità e sicurezza.

## 3. Policy di Sicurezza Obbligatorie per l'Agent
1. **Mai sovrascrivere `ONLINE_MODE="true"` nei server backend (Paper).** L'autenticazione è gestita dal Proxy Velocity o AuthMe. Mettere a `true` rompe l'ingresso dietro proxy.
2. **Web Panel Auth Secret:** Se viene ricreato l'ambiente, il file `.env` deve contenere una password cripticamente sicura e `AUTH_SECRET` non indovinabile. Il Rate Limit previene il brute-force ed è cablato in memoria nel container Next.js.
3. **Mappatura del Socket Docker e ServiceManager:** Il Web Panel richiede `/var/run/docker.sock` mappato come volume nel suo container. I comandi verso docker NON devono essere script bash via `exec`, ma devono obbligatoriamente utilizzare il `DockerServiceClient` richiamato dal `ServiceManager` per l'orchestrazione sicura dei nodi docker. Parimenti, le comunicazioni di console avvengono via RCON puro tramite `RconServiceClient`.
4. **Ambiente di Sviluppo vs Produzione:** In locale (questo ambiente) eseguiamo solo lo sviluppo del codice. Tutti i test operativi vengono eseguiti sulla VPS (deploy). Non eseguire comandi di test o installazioni invasive (es. npm install di pacchetti non puramente di dev) localmente; forza l'esecuzione di questi task all'ambiente VPS tramite script di deploy.

## 4. Next.js App Router (Avviso per Agenti AI)
This version of Next.js has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.

## 5. Vulnerabilità e Incongruenze Identificate (Stato Avanzamento)
Durante l'audit del codice del Web Panel, sono emerse le seguenti criticità, la maggior parte delle quali **ora RISOLTE**:

| Categoria | File / Contesto | Problema Identificato | Stato | Note / Soluzione |
| :--- | :--- | :--- | :--- | :--- |
| 🛡️ **Sicurezza** | `api/spark/action/route.ts` | Possibile *Command Injection* (mancava validazione `serverName`). | ✅ **RISOLTO** | Aggiunte regex e controlli di restrizione rigidi. |
| 🛡️ **Sicurezza** | `api/backups`, `api/files` | Rischio *Path Traversal*. | ✅ **RISOLTO** | Introdotto l'uso di `path.resolve` e controlli basati su `.startsWith(basePath)`. |
| 🛡️ **Sicurezza** | `api/staff/username/route.ts`| *Iniezione Env* (mancata sanitizzazione dello username). | ✅ **RISOLTO** | Applicata corretta sanitizzazione dell'input. |
| ⚡ **Performance** | Database Client | Mancanza di *Connection Pooling* (rischio saturazione pool usando `createConnection()`). | ✅ **RISOLTO** | Implementato pooler persistente avanzato in `db.ts` tramite `globalThis`. |
| ⚡ **Performance** | `api/auth/login/route.ts` | Possibile *Memory Leak* sulla mappa del Rate Limit. | ✅ **RISOLTO** | Utilizzato `globalThis` per associare la mappa all'istanza Node per prevenire leak su HMR. |
| ⚡ **Performance** | `(dashboard)/page.tsx` | *API Polling* pericoloso e bloccante usando `setInterval`. | ✅ **RISOLTO** | Convertito in un logico `setTimeout` ricorsivo asincrono. |
| 🐛 **Logica / Bug**| `api/server/command` | La pagina dei permessi (Web Panel) inviava comandi `lp` tramite RCON ai server backend, ma LuckPerms si trova solo sul Proxy (che non ha RCON). | ✅ **RISOLTO** | Creato un traduttore SQL nativo nella route API che converte i comandi `lp` in query dirette su MariaDB e invia un segnale di sync in `luckperms_messenger`, permettendo la gestione UI senza plugin RCON esterni. |
| 🐛 **Logica / Bug**| `(dashboard)/permissions/page.tsx` | Il Web Panel mostrava il badge "Negato" per permessi concessi poiché il DB MariaDB restituisce `1`, ma il frontend si aspettava il booleano `true` o stringa. | ✅ **RISOLTO** | Aggiornato il blocco condizionale JSX includendo `p.value === 1`. |
| 🐛 **Logica / Bug**| `SparkControls.tsx` | Il pulsante frontend inviava payload disallineati rispetto all'API attesa. | ✅ **RISOLTO** | Allineato il payload frontend alla route backend. |
| 🐛 **Logica / Bug**| `config.json` e `config.ts`| Mapping del Proxy errato. Puntava a `gate` e `Proxy Gate` in un percorso inesistente. | ✅ **RISOLTO** | Mappato correttamente a `velocity` e `Velocity Proxy` in cartella `/proxy`. I plugin ora appaiono. |
| 🐛 **Logica / Bug**| `scheduler.js` | Connessione verso `127.0.0.1:3000` invece del container docker `panel:3000`. | 🔍 **DA VERIFICARE** | Controllare che i job background riescano a parlare con l'API. |
| 🐛 **Logica / Bug**| API varie e `deploy.sh` | Le chiavi MariaDB RCON e MySQL sono scritte in chiaro (hardcoded). | ✅ **RISOLTO** | Chiavi spostate in variabili d'ambiente (creato `.env.example`). |

## 6. Inventario Servizi e Plugin (Stato Attuale)
**ATTENZIONE PER L'AGENTE (CRITICO):** È tua responsabilità assoluta mantenere **SEMPRE AGGIORNATA** questa lista. Ogni volta che aggiungi, rimuovi, o aggiorni un plugin o un servizio (container) in questo progetto, DEVI modificare questo file (`AGENTS.md`) per riflettere lo stato esatto dell'infrastruttura. Non lasciare mai questa lista obsoleta.

Questa è la mappatura esatta dei container e dei plugin attualmente attivi nell'infrastruttura. Usala come riferimento primario.

### Architettura Container (Docker)
| Container | Ruolo / Tipo | Descrizione & Entrypoint |
| :--- | :--- | :--- |
| `velocity` | Proxy di Rete | Nodo di ingresso primario (porta 25565). Gestisce routing e UUID. |
| `mc_lobby` | Server Paper | Hub principale d'ingresso. Contiene AuthMe per il login offline. |
| `mc_survival`, `mc_creative`<br>`mc_motoleo`, `mc_medioeval` | Server Paper | Server backend di gioco. Generati e gestiti dinamicamente via template/hot-swap. |
| `mc_db` | MariaDB | Database centralizzato (Permessi, Economia, Bans, Dati Web Panel). |
| `mc_redis` | Redis | Cache in-memory e sincronizzazione della chat globale (RedisChat). |
| `mc_panel` | Next.js App | Pannello Amministrativo Web (porta 3000 locale). |
| `mc_nginx` | Reverse Proxy | Maschera il Web Panel (porta 9800 pubblica) e mappa `/bluemap/<mondo>/`. |
| `mc_scheduler` | Node.js Daemon | Esegue i cronjob e raccoglie metriche (Docker stats) scrivendole su DB. |

### Elenco Plugin Installati

#### 1. Proxy (Velocity) - Cartella `proxy/plugins/`
| Plugin | Funzionalità Principale |
| :--- | :--- |
| **AdvancedPortals** | Gestione del routing fisico tra server (portali fluidi). |
| **AuthMeVelocity-Proxy**<br>**AuthMeVelocity-LastServerAddon** | Hook del login AuthMe e redirect automatico all'ultimo server frequentato. |
| **LibertyBans** | Sistema globale di ban e mute (sincronizzato via database). |
| **LuckPerms-Velocity** | Gestore ruoli e permessi a livello di rete. |
| **SkinsRestorer** | Ripristina le skin dei giocatori offline/cracked. |
| **TAB** & **VelocityScoreboardAPI** | Personalizzazione estetica dell'HUD (Tablist, Tag sopra la testa). |
| **spark** | Profiler prestazionale globale (Diagnosi lag proxy). |

#### 2. Plugin Condivisi (Tutti i Backend) - Cartella `custom-plugins/`
*Nota: Lo script `deploy.sh` inietta **automaticamente** questi plugin in: Lobby, Survival, Creative, MotoLeo, Medioeval.*

| Plugin | Funzionalità Principale |
| :--- | :--- |
| **BetterGrim** | Sistema Anti-cheat. |
| **BungeeTP** | Motore di teletrasporto cross-server. |
| **CommandAPI** | Astrazione API per la registrazione di comandi avanzati. |
| **DeluxeMenus** | Generazione di GUI interattive (Menù server). |
| **EssentialsX** | Motore di comandi base di Minecraft (es. /god, /fly, /heal). |
| **LibertyBans** | Ascoltatore lato backend per l'applicazione delle punizioni. |
| **LuckPerms** | Motore di gestione permessi. Configurazioni mappate allo stesso DB del Proxy per sync globale. |
| **MythicMobs** | Framework avanzato per creare mostri, boss e abilità custom. *(Configurazioni Mobs/Skills/Items condivise globalmente tra tutti i server via mount Docker).* |
| **Citizens** | API e sistema NPC (NOTA: download protetto, `Citizens-*.jar` va scaricato manualmente da [https://ci.citizensnpcs.co/job/Citizens2/](https://ci.citizensnpcs.co/job/Citizens2/) e inserito nella cartella `custom-plugins`). |
| **PlaceholderAPI** | Sostitutore di variabili dinamiche (PAPI). |
| **ProtocolLib** | Packet API per modifiche profonde a livello client-server. |
| **SentientMobs** | Sostituisce l'intelligenza artificiale (AI) di default per rendere i mostri strategici. |
| **Skript** & **skript-worldguard** | Linguaggio di scripting in-game e integrazioni per le regioni. |
| **Vault** & **XConomy** | Interfaccia ed engine del sistema di Economia centralizzata. |
| **worldedit** & **worldguard** | Sistemi di building massivo e protezione anti-griefing del territorio. |
| **bluemap-paper** | Rendering della web-map 3D in tempo reale. |
| **HuskSync** | Sincronizzazione automatica inventari, salute e avanzamenti a database. |
| **RedisChat** | Chat globale unificata tra tutti i mondi. |
| **ViaBackwards** & **ViaVersion** | Compatibilità di connessione per client vecchi o futuri. |

#### 3. Plugin Esclusivi LOBBY - Cartella `lobby/plugins/`
> **⚠ REGOLA CRITICA**: Lo script di deploy è programmato per **CANCELLARE** forzatamente qualsiasi `.jar` di AuthMe dagli altri server di backend, prevenendo auth-bypass. **AuthMe deve girare solo ed esclusivamente sulla Lobby.**

| Plugin | Funzionalità Principale |
| :--- | :--- |
| **AuthMe** | Core di registrazione e login per reti offline/cracked. |
| **AuthMeVelocity-Paper** | Invia il segnale "*login avvenuto con successo*" al Proxy Velocity. |
