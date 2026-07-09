# 🌐 MinecraftAdmin: BungeeCord Network & Web Panel

Benvenuto su **MinecraftAdmin**, l'ecosistema completo per la gestione di un Network Minecraft moderno (BungeeCord/Velocity + PaperMC) completamente containerizzato con Docker, affiancato da un potente **Web Panel (Next.js)** per l'amministrazione remota totale.

---

## 🏗️ Architettura del Progetto

L'infrastruttura si basa su un'architettura a microservizi gestita tramite Docker Compose. Ogni server del network gira nel proprio container isolato, comunicando con il database e il pannello web in tempo reale.

### Componenti Principali:
- **`proxy` (Velocity):** Il punto d'accesso principale per tutti i giocatori (porta `25565`). Gestisce l'instradamento intelligente e l'autenticazione tramite `AuthMeVelocity`.
- **Mondi PaperMC (`lobby`, `survival`, `creative`, `medioeval`, `motoleo`):** I server di gioco indipendenti. Il proxy smista i giocatori tra di essi.
- **`redis` (`mc_redis`):** Database in-memory ad altissime prestazioni usato per sincronizzare la chat globale, i dati tra i server (es. RedisChat), e i trasferimenti di valuta dell'economia in tempo reale.
- **`mariadb` (`mc_db`):** Database relazionale centralizzato. Memorizza i dati dei bans globali (LibertyBans), i permessi (LuckPerms), gli account (AuthMe) e il bilancio globale dell'economia dei giocatori (XConomy).
- **Web Panel (Next.js):** La dashboard amministrativa che comunica con i mondi via RCON, API Docker e API del FileSystem per provisionare nuovi mondi, gestire plugin, giocatori e prestazioni.
- **`custom-plugins`:** Cartella globale centralizzata in cui risiedono i plugin di base che vengono automaticamente ereditati e sincronizzati in ogni server creato.

### 🧩 Plugin Installati di Default (Lista Completa)
Il network è pre-configurato con una suite essenziale di plugin moderni, divisi strategicamente in base al loro ruolo infrastrutturale:

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
| **MythicMobs** | Framework avanzato per creare mostri, boss e abilità custom. *(Configurazioni condivise globalmente).* |
| **Citizens** | API e sistema NPC. |
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


---

## 🚀 Guida all'Uso: Il Web Panel

Il pannello web è il cuore nevralgico dell'amministrazione. Ecco le sue sezioni principali:

### 1. Gestione dei Mondi (Network Provisioning)
Dalla pagina **Mondi**, puoi orchestrare l'intero cluster:
- **Avvia / Ferma / Riavvia:** Spegnimento controllato con un countdown in chat (gestibile in Impostazioni).
- **Crea Nuovo Mondo:** Processo magico a 1 click (genera file, RCON, spigot.yml, e riavvia il Proxy).
- **Editor Visuale Proprietà:** Configurazione diretta e semplificata per `server.properties` e il `config.yml` del proxy.
- **Ottimizzazioni PaperMC:** Configurazione semplificata in UI per i motori Anti-Xray nativi e ottimizzazioni server.

### 2. Gestione Plugin Globale
I plugin seguono un'architettura **"Single Source of Truth"**:
- **Upload:** Carica un file `.jar` tramite il pannello e verrà automaticamente distribuito a **tutti** i server.
- **Abilita/Disabilita (Per Server):** Rinominazione a `.disabled` senza eliminarlo dalla rete.

### 3. Gestione Giocatori e Prestazioni
- **Monitoraggio Live (Docker):** CPU e RAM in tempo reale per ogni mondo direttamente dalle API del demone Docker.
- **Global Player Manager:** Visualizza tutti i giocatori online nella rete e interagisci rapidamente tramite comandi RCON (Kick, Ban, Mute, Teleport).
- **Integrazione LuckPerms:** Clicca un bottone per generare e aprire automaticamente l'Editor Web di LuckPerms per gestire gruppi e ranghi in modo visuale.

### 4. Console e Log in Tempo Reale
Sfrutta le connessioni RCON per mostrare l'output live dei server. Scegli il server dal menu a tendina e invia comandi proprio come dal terminale.

---

## 🛠️ Guida al Deploy (Per Sviluppatori)

Il progetto è pensato per un rapido sviluppo locale e deploy remoto su VPS.

1. **Pre-requisiti locali:** Node.js 18+, Docker.
2. **Sviluppo Web Panel locale:**
   ```bash
   cd web-panel
   npm install
   npm run dev
   ```
3. **Deploy su VPS:**
   Il progetto include il potente script `deploy.sh` che aggiorna il VPS tramite SSH e rsync.
   Lo script è "Auto-Pulente" in modo intelligente: se elimini o aggiorni un plugin dalla cartella `custom-plugins` locale, lo script scansiona ed elimina i vecchi `.jar` direttamente dalle directory dei server remoti prima di copiare quelli nuovi, sventando l'accumulo e gli errori di `Ambiguous plugin name`.
   Supporta deploy modulari per velocizzare l'aggiornamento quando modifichi solo una parte del progetto:
   - **Deploy Globale:** `./deploy.sh` (Sincronizza file, pulisce e aggiorna i plugin in tutti i 5 mondi, riavvia Docker e builda il Web Panel).
   - **Solo Server:** `./deploy.sh --server` (Sincronizza plugin e file di configurazione, pulendo preventivamente le directory dei plugin dei singoli server, e riavvia i container Minecraft/Proxy).
   - **Solo Web Panel:** `./deploy.sh --web` (Evita il riavvio dei server Minecraft, carica solo il codice Next.js, lo compila e riavvia il container `mc_panel`).

---

## 🔮 Roadmap Prossimi Sviluppi
Puoi monitorare lo stato di completamento dei vari traguardi infrastrutturali (Fasi da 1 a 4) all'interno del file `project_roadmap.md` nella directory principale.
