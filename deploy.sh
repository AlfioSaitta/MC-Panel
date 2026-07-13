#!/bin/bash

# ==========================================
# Configurazione Deploy (Modifica questi dati)
# ==========================================
VPS_USER="debian"
VPS_IP="51.75.77.248"
SSH_KEY_PATH="~/.ssh/ovh_rsa" # Modifica con il percorso della tua chiave privata
REMOTE_DIR="/home/debian/minecraft-server/admin" # Cartella di destinazione per il web panel sulla VPS
SERVER_DIR="/home/debian/minecraft-server" # Cartella di destinazione per i server Minecraft

# ==========================================
# Colori e UI
# ==========================================
C_RESET='\033[0m'
C_CYAN='\033[1;36m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_PURPLE='\033[1;35m'
C_BOLD='\033[1m'

DEPLOY_WEB=true
DEPLOY_SERVER=true

if [[ "$1" == "--web" ]]; then
  DEPLOY_SERVER=false
elif [[ "$1" == "--server" ]]; then
  DEPLOY_WEB=false
fi

echo -e "${C_CYAN}${C_BOLD}"
echo "=========================================="
echo " 🚀 AVVIO DEPLOY MINECRAFT ADMIN"
echo "==========================================${C_RESET}"

if [ "$DEPLOY_WEB" = true ] && [ "$DEPLOY_SERVER" = true ]; then
  echo -e "${C_PURPLE}Modalità: ${C_BOLD}Globale (Panel + Server Minecraft)${C_RESET}"
elif [ "$DEPLOY_WEB" = true ]; then
  echo -e "${C_PURPLE}Modalità: ${C_BOLD}Solo Web Panel${C_RESET}"
elif [ "$DEPLOY_SERVER" = true ]; then
  echo -e "${C_PURPLE}Modalità: ${C_BOLD}Solo Server Minecraft${C_RESET}"
fi
echo -e "${C_CYAN}==========================================${C_RESET}\n"

# 0. Verifica e installazione dipendenze (Docker, Node.js)
echo -e "\n${C_CYAN}0️⃣ Verifica e installazione dipendenze di sistema sulla VPS...${C_RESET}"
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new $VPS_USER@$VPS_IP << 'EOF'
  if ! command -v docker &> /dev/null; then
      echo -e "\033[1;36m🐳 Docker non trovato. Installazione in corso...\033[0m"
      curl -fsSL https://get.docker.com -o get-docker.sh
      sudo sh get-docker.sh
      sudo usermod -aG docker $USER || true
      rm get-docker.sh
  fi

  if ! docker compose version &> /dev/null; then
      echo -e "\033[1;36m🐳 Docker Compose non trovato. Installazione in corso...\033[0m"
      sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin
  fi

  if ! command -v node &> /dev/null; then
      echo -e "\033[1;32m🟢 Node.js non trovato. Installazione in corso (versione 20.x)...\033[0m"
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
  fi
  
  if ! dpkg -l | grep -q python3-yaml; then
      echo -e "\033[1;33m🐍 Installazione dipendenze Python (PyYAML)...\033[0m"
      sudo apt-get update -y && sudo apt-get install -y python3-yaml
  fi
EOF

# 1. Creazione cartelle remote
echo -e "\n${C_CYAN}1️⃣ Creazione directory remote...${C_RESET}"
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new $VPS_USER@$VPS_IP << EOF
  mkdir -p $REMOTE_DIR
  mkdir -p $SERVER_DIR/proxy/plugins
  mkdir -p $SERVER_DIR/geyser
  mkdir -p $SERVER_DIR/lobby/plugins/MythicMobs
  mkdir -p $SERVER_DIR/survival/plugins/MythicMobs
  mkdir -p $SERVER_DIR/creative/plugins/MythicMobs
  mkdir -p $SERVER_DIR/medioeval/plugins/MythicMobs
  mkdir -p $SERVER_DIR/motoleo/plugins/MythicMobs
  mkdir -p $SERVER_DIR/shared/MythicMobs/Mobs
  mkdir -p $SERVER_DIR/shared/MythicMobs/Skills
  mkdir -p $SERVER_DIR/shared/MythicMobs/Items
  mkdir -p $SERVER_DIR/shared/MythicMobs/Drops
  mkdir -p $SERVER_DIR/shared/MythicMobs/RandomSpawns
EOF

if [ "$DEPLOY_SERVER" = true ]; then
  echo -e "\n${C_CYAN}2️⃣ Patching e Trasferimento file server Minecraft ($VPS_IP)...${C_RESET}"
  
  echo -e "\033[1;33m🔧 Patching LibertyBans.jar (Priorità di Caricamento vs EssentialsX)...\033[0m"
  if [ -f "custom-plugins/LibertyBans.jar" ]; then
    unzip -p custom-plugins/LibertyBans.jar plugin.yml > /tmp/lb_plugin.yml
    if ! grep -q "loadbefore:" /tmp/lb_plugin.yml; then
      echo "loadbefore: [Essentials]" >> /tmp/lb_plugin.yml
      cd custom-plugins
      cp /tmp/lb_plugin.yml plugin.yml
      zip LibertyBans.jar plugin.yml > /dev/null
      rm plugin.yml
      cd ..
    fi
  fi

  rsync -az --info=progress2 --delete -e "ssh -i $SSH_KEY_PATH" custom-plugins/ $VPS_USER@$VPS_IP:$SERVER_DIR/custom-plugins/

  # Sincronizza ESATTAMENTE i .jar di proxy e lobby, eliminando quelli obsoleti ma preservando i dati
  rsync -az --include="*.jar" --exclude="*" --delete -e "ssh -i $SSH_KEY_PATH" proxy/plugins/ $VPS_USER@$VPS_IP:$SERVER_DIR/proxy/plugins/
  rsync -az --include="*.jar" --exclude="*" --delete -e "ssh -i $SSH_KEY_PATH" lobby/plugins/ $VPS_USER@$VPS_IP:$SERVER_DIR/lobby/plugins/

  scp -i $SSH_KEY_PATH docker-compose.yml $VPS_USER@$VPS_IP:$SERVER_DIR/
  # Copia il file di esempio .env se non esiste sulla VPS, così i container si avviano
  scp -i $SSH_KEY_PATH .env.example $VPS_USER@$VPS_IP:$SERVER_DIR/.env
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" shared/ $VPS_USER@$VPS_IP:$SERVER_DIR/shared/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" proxy/ $VPS_USER@$VPS_IP:$SERVER_DIR/proxy/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" geyser/ $VPS_USER@$VPS_IP:$SERVER_DIR/geyser/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" lobby/ $VPS_USER@$VPS_IP:$SERVER_DIR/lobby/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" survival/ $VPS_USER@$VPS_IP:$SERVER_DIR/survival/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" creative/ $VPS_USER@$VPS_IP:$SERVER_DIR/creative/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" medioeval/ $VPS_USER@$VPS_IP:$SERVER_DIR/medioeval/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" motoleo/ $VPS_USER@$VPS_IP:$SERVER_DIR/motoleo/
  rsync -az --info=progress2 -e "ssh -i $SSH_KEY_PATH" nginx/ $VPS_USER@$VPS_IP:$SERVER_DIR/nginx/

  ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP << EOF
    # Pulisce i vecchi file .jar per evitare conflitti (es. Ambiguous plugin name)
    find $SERVER_DIR/lobby/plugins/ -maxdepth 1 -name "*.jar" ! -name "AuthMe*.jar" -delete
    find $SERVER_DIR/survival/plugins/ -maxdepth 1 -name "*.jar" -delete
    find $SERVER_DIR/creative/plugins/ -maxdepth 1 -name "*.jar" -delete
    find $SERVER_DIR/medioeval/plugins/ -maxdepth 1 -name "*.jar" -delete
    find $SERVER_DIR/motoleo/plugins/ -maxdepth 1 -name "*.jar" -delete
    
    # Copia i nuovi file .jar
    cp $SERVER_DIR/custom-plugins/*.jar $SERVER_DIR/lobby/plugins/ || true
    cp $SERVER_DIR/custom-plugins/*.jar $SERVER_DIR/survival/plugins/ || true
    cp $SERVER_DIR/custom-plugins/*.jar $SERVER_DIR/creative/plugins/ || true
    cp $SERVER_DIR/custom-plugins/*.jar $SERVER_DIR/medioeval/plugins/ || true
    cp $SERVER_DIR/custom-plugins/*.jar $SERVER_DIR/motoleo/plugins/ || true
    
    # Rimuove AuthMe dai backend server, deve esistere solo nella Lobby!
    rm -rf $SERVER_DIR/survival/plugins/AuthMe*.jar
    rm -rf $SERVER_DIR/creative/plugins/AuthMe*.jar
    rm -rf $SERVER_DIR/medioeval/plugins/AuthMe*.jar
    rm -rf $SERVER_DIR/motoleo/plugins/AuthMe*.jar

    # Rimuove BungeeTP in quanto sostituito interamente da HuskHomes
    rm -rf $SERVER_DIR/*/plugins/BungeeTP*.jar

    # MythicMobs ora è globale, non lo rimuoviamo più da lobby e creative.
    
    # Carica le variabili d'ambiente
    set -a
    source $SERVER_DIR/.env
    set +a

    # Distribuisce il file commands.yml condiviso a tutti i server backend e i nuovi file di configurazione
    for s in lobby survival creative medioeval motoleo; do
      cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/\$s/commands.yml || true
      
      # Distribuzione Configurazioni HuskHomes
      mkdir -p $SERVER_DIR/\$s/plugins/HuskHomes
      cp $SERVER_DIR/shared/HuskHomes/config.yml $SERVER_DIR/\$s/plugins/HuskHomes/config.yml || true
      
      sed -i "s/__MYSQL_HOST__/\$DB_HOST/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_PORT__/3306/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_DB__/\$DB_DATABASE/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_USER__/\$DB_USER/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_PASSWORD__/\$DB_PASSWORD/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__REDIS_HOST__/mc_redis/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__REDIS_PORT__/6379/g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      sed -i "s/__REDIS_PASSWORD__//g" $SERVER_DIR/\$s/plugins/HuskHomes/config.yml 2>/dev/null || true
      
      # Distribuzione Configurazioni SimplePortals
      mkdir -p $SERVER_DIR/\$s/plugins/SimplePortals
      cp $SERVER_DIR/shared/SimplePortals/config.yml $SERVER_DIR/\$s/plugins/SimplePortals/config.yml || true

      sed -i "s/__MYSQL_HOST__/\$DB_HOST/g" $SERVER_DIR/\$s/plugins/SimplePortals/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_PORT__/3306/g" $SERVER_DIR/\$s/plugins/SimplePortals/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_DB__/\$DB_DATABASE/g" $SERVER_DIR/\$s/plugins/SimplePortals/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_USER__/\$DB_USER/g" $SERVER_DIR/\$s/plugins/SimplePortals/config.yml 2>/dev/null || true
      sed -i "s/__MYSQL_PASSWORD__/\$DB_PASSWORD/g" $SERVER_DIR/\$s/plugins/SimplePortals/config.yml 2>/dev/null || true
    done

    # Rimuove ViaVersion, ViaBackwards e SimpleReconnect dal Proxy (il Proxy Velocity supporta fallback nativamente)
    rm -rf $SERVER_DIR/proxy/plugins/ViaVersion*.jar
    rm -rf $SERVER_DIR/proxy/plugins/ViaBackwards*.jar
    rm -rf $SERVER_DIR/proxy/plugins/SimpleReconnect*.jar
    
    # Rimuove LibertyBans dal proxy per evitare crash (Kyori Adventure NoSuchMethodError)
    # L'applicazione delle punizioni avverrà direttamente nei server backend via MariaDB.
    rm -rf $SERVER_DIR/proxy/plugins/LibertyBans*.jar
    
    # Rimuove vecchie versioni e cartelle del plugin Geyser-Velocity (migrato a Standalone)
    rm -rf $SERVER_DIR/proxy/plugins/Geyser-Velocity*.jar
    rm -rf $SERVER_DIR/proxy/plugins/Geyser-Velocity/
EOF

  echo -e "\n${C_CYAN}3️⃣ Configurazione plugin e avvio dei server Minecraft (Docker)...${C_RESET}"
  ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP << EOF
    cd $SERVER_DIR
    
    echo -e "\033[1;35m🔐 Configurazione AuthMe per Geyser/Floodgate...\033[0m"
    if [ -f "$SERVER_DIR/lobby/plugins/AuthMe/config.yml" ]; then
      sed -i "s/allowedNicknameCharacters: '\[a-zA-Z0-9_\]\*'/allowedNicknameCharacters: '\[a-zA-Z0-9_\*\]\*'/g" $SERVER_DIR/lobby/plugins/AuthMe/config.yml
      sed -i "s/floodgate: false/floodgate: true/g" $SERVER_DIR/lobby/plugins/AuthMe/config.yml
    fi

    echo -e "\033[1;36m🌍 Download Database GeoIP per AuthMe...\033[0m"
    mkdir -p $SERVER_DIR/lobby/plugins/AuthMe
    curl -sSL https://github.com/du5/geoip/raw/refs/heads/main/GeoLite2-Country.mmdb -o $SERVER_DIR/lobby/plugins/AuthMe/GeoLite2-Country.mmdb

    echo -e "\033[1;36m🐳 Applico le modifiche all'infrastruttura (se presenti)...\033[0m"
    
    # Previene bug Docker mount: crea key.pem vuoto se Floodgate non lo ha ancora generato
    mkdir -p $SERVER_DIR/proxy/plugins/floodgate
    touch $SERVER_DIR/proxy/plugins/floodgate/key.pem

    echo -e "\033[1;33m🔧 Patching Velocity configuration su Paper (paper-global.yml e spigot.yml)...\033[0m"
    # Assicurati che BungeeCord sia falso in spigot.yml per Modern Forwarding
    find $SERVER_DIR/*/spigot.yml -type f -exec sed -i 's/bungeecord: true/bungeecord: false/g' {} + 2>/dev/null || true
    
    # Assicurati che Velocity sia abilitato in paper-global.yml
    python3 -c "
import yaml
import glob
for f in glob.glob('$SERVER_DIR/*/config/paper-global.yml'):
    try:
        with open(f, 'r') as file:
            data = yaml.safe_load(file) or {}
        if 'proxies' not in data: data['proxies'] = {}
        if 'velocity' not in data['proxies']: data['proxies']['velocity'] = {}
        data['proxies']['velocity']['enabled'] = True
        data['proxies']['velocity']['online-mode'] = False
        data['proxies']['velocity']['secret'] = 'S3cr3tV3locityF0rw4rdingK3y!'
        with open(f, 'w') as file:
            yaml.dump(data, file)
    except Exception as e:
        pass
" 2>/dev/null || true

    echo -e "\033[1;33m🔧 Patching EssentialsX configuration (disabled-commands)...\033[0m"
    python3 -c "
import yaml
import glob
for f in glob.glob('$SERVER_DIR/*/plugins/Essentials/config.yml'):
    try:
        with open(f, 'r') as file:
            data = yaml.safe_load(file) or {}
        disabled = data.get('disabled-commands', [])
        to_disable = ['balance', 'bal', 'pay', 'baltop', 'eco', 'economy', 'home', 'sethome', 'delhome', 'homes', 'warp', 'warps', 'setwarp', 'delwarp', 'tpa', 'tpaccept', 'tpdeny', 'tpahere', 'spawn', 'banip', 'unbanip', 'tempban', 'tempmute', 'ban', 'unban', 'mute', 'unmute', 'kick', 'warn', 'msg', 'w', 'm', 't', 'pm', 'tell', 'whisper', 'reply', 'r', 'broadcast', 'bc']
        for cmd in to_disable:
            if cmd not in disabled:
                disabled.append(cmd)
        data['disabled-commands'] = disabled
        
        overridden = data.get('overridden-commands', [])
        if overridden is None:
            overridden = []
        for cmd in to_disable:
            if cmd not in overridden:
                overridden.append(cmd)
        data['overridden-commands'] = overridden
        
        with open(f, 'w') as file:
            yaml.dump(data, file)
    except Exception as e:
        pass
" 2>/dev/null || true
    
    docker compose up -d --remove-orphans

    echo -e "\033[1;32m⚙️ Schedulazione automatica download PlaceholderAPI Expansions...\033[0m"
    nohup bash -c 'sleep 45; for s in mc_lobby mc_survival mc_creative mc_medioeval mc_motoleo; do docker exec -i \$s rcon-cli "papi ecloud download Bungee" || true; docker exec -i \$s rcon-cli "papi ecloud download Vault" || true; docker exec -i \$s rcon-cli "papi ecloud download LuckPerms" || true; docker exec -i \$s rcon-cli "papi reload" || true; done' >/dev/null 2>&1 &
EOF
fi

if [ "$DEPLOY_WEB" = true ]; then
  echo -e "\n${C_CYAN}4️⃣ Trasferimento e build del Web Panel sul VPS...${C_RESET}"
  rsync -az --info=progress2 --delete \
             --exclude 'node_modules' \
             --exclude '.next' \
             --exclude '.env' \
             --exclude '.git' \
             --exclude 'data/' \
             -e "ssh -i $SSH_KEY_PATH" \
             web-panel/ $VPS_USER@$VPS_IP:$REMOTE_DIR/

  # Copia il .env per il web panel (condivide le stesse variabili del root, o funge da base)
  scp -i $SSH_KEY_PATH .env.example $VPS_USER@$VPS_IP:$REMOTE_DIR/.env

  ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP << EOF
    cd $SERVER_DIR
    echo -e "\033[1;36m🐳 Costruisco e avvio i container del Web Panel (Next.js) e Scheduler...\033[0m"
    docker compose up -d --build panel scheduler nginx
    
    echo -e "\033[1;35m🗄️ Inizializzazione tabelle database...\033[0m"
    # Attende che il database MariaDB sia pronto
    until docker exec mc_db sh -c 'mysqladmin ping -h localhost -uroot -p"\$MYSQL_ROOT_PASSWORD" --silent'; do
      echo -e "\033[1;33mIn attesa che MariaDB sia pronto...\033[0m"
      sleep 2
    done

    # Creazione delle tabelle necessarie
    docker exec -i mc_db sh -c 'mysql -u root -p"\$MYSQL_ROOT_PASSWORD" minecraft' << 'SQL'
      CREATE TABLE IF NOT EXISTS server_metrics (
        id INT AUTO_INCREMENT PRIMARY KEY,
        server_id VARCHAR(50) NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        tps FLOAT,
        mspt FLOAT,
        cpu_process FLOAT,
        cpu_system FLOAT,
        ram_used FLOAT,
        ram_max FLOAT,
        disk_used FLOAT,
        disk_max FLOAT,
        ping_avg FLOAT,
        INDEX(server_id, timestamp)
      );

      CREATE TABLE IF NOT EXISTS authme (
        id INTEGER AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        realname VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL,
        ip VARCHAR(40) DEFAULT '127.0.0.1',
        lastlogin BIGINT DEFAULT 0,
        x DOUBLE DEFAULT 0,
        y DOUBLE DEFAULT 0,
        z DOUBLE DEFAULT 0,
        world VARCHAR(255) DEFAULT 'world',
        regip VARCHAR(40) DEFAULT '127.0.0.1',
        regdate BIGINT DEFAULT 0,
        yaw FLOAT DEFAULT 0,
        pitch FLOAT DEFAULT 0,
        email VARCHAR(255) DEFAULT NULL,
        isLogged SMALLINT DEFAULT 0,
        hasSession SMALLINT DEFAULT 0,
        totp VARCHAR(32) DEFAULT NULL
      );
SQL
EOF
fi

echo -e "\n${C_GREEN}${C_BOLD}"
echo "=========================================="
echo "✅ DEPLOY COMPLETATO CON SUCCESSO!"
if [ "$DEPLOY_WEB" = true ]; then
  echo -e "🌐 Il pannello è raggiungibile all'indirizzo http://$VPS_IP:9800"
fi
echo "=========================================="
echo -e "${C_RESET}"
