#!/bin/bash

# ==========================================
# Configurazione Deploy (Modifica questi dati)
# ==========================================
VPS_USER="debian"
VPS_IP="51.75.77.248"
SSH_KEY_PATH="~/.ssh/ovh_rsa" # Modifica con il percorso della tua chiave privata
REMOTE_DIR="/home/debian/minecraft-server/admin" # Cartella di destinazione per il web panel sulla VPS
SERVER_DIR="/home/debian/minecraft-server" # Cartella di destinazione per i server Minecraft

DEPLOY_WEB=true
DEPLOY_SERVER=true

if [[ "$1" == "--web" ]]; then
  DEPLOY_SERVER=false
elif [[ "$1" == "--server" ]]; then
  DEPLOY_WEB=false
fi

echo "=========================================="
echo "🚀 Avvio deploy..."
if [ "$DEPLOY_WEB" = true ] && [ "$DEPLOY_SERVER" = true ]; then
  echo "Modalità: Globale (Panel + Server Minecraft)"
elif [ "$DEPLOY_WEB" = true ]; then
  echo "Modalità: Solo Web Panel"
elif [ "$DEPLOY_SERVER" = true ]; then
  echo "Modalità: Solo Server Minecraft"
fi
echo "=========================================="

# 0. Verifica e installazione dipendenze (Docker, Node.js)
echo "0️⃣ Verifica e installazione dipendenze di sistema sulla VPS..."
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new $VPS_USER@$VPS_IP << 'EOF'
  if ! command -v docker &> /dev/null; then
      echo "🐳 Docker non trovato. Installazione in corso..."
      curl -fsSL https://get.docker.com -o get-docker.sh
      sudo sh get-docker.sh
      sudo usermod -aG docker $USER || true
      rm get-docker.sh
  fi

  if ! docker compose version &> /dev/null; then
      echo "🐳 Docker Compose non trovato. Installazione in corso..."
      sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin
  fi

  if ! command -v node &> /dev/null; then
      echo "🟢 Node.js non trovato. Installazione in corso (versione 20.x)..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
  fi
EOF

# 1. Creazione cartelle remote
echo "1️⃣ Creazione directory remote..."
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new $VPS_USER@$VPS_IP << EOF
  mkdir -p $REMOTE_DIR
  mkdir -p $SERVER_DIR/proxy/plugins
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
  echo "2️⃣ Trasferimento file server Minecraft ($VPS_IP)..."
  rsync -avz --delete -e "ssh -i $SSH_KEY_PATH" custom-plugins/ $VPS_USER@$VPS_IP:$SERVER_DIR/custom-plugins/

  ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP << EOF
    # Pulisce i vecchi file .jar per evitare conflitti (es. Ambiguous plugin name)
    find $SERVER_DIR/lobby/plugins/ -maxdepth 1 -name "*.jar" -delete
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

    # MythicMobs ora è globale, non lo rimuoviamo più da lobby e creative.
    
    # Distribuisce il file commands.yml condiviso a tutti i server backend
    cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/lobby/commands.yml || true
    cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/survival/commands.yml || true
    cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/creative/commands.yml || true
    cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/medioeval/commands.yml || true
    cp $SERVER_DIR/shared/commands.yml $SERVER_DIR/motoleo/commands.yml || true

    # Rimuove ViaVersion, ViaBackwards e SimpleReconnect dal Proxy (il Proxy Velocity supporta fallback nativamente)
    rm -rf $SERVER_DIR/proxy/plugins/ViaVersion*.jar
    rm -rf $SERVER_DIR/proxy/plugins/ViaBackwards*.jar
    rm -rf $SERVER_DIR/proxy/plugins/SimpleReconnect*.jar
    
    # Rimuove LibertyBans dal proxy per evitare crash (Kyori Adventure NoSuchMethodError)
    # L'applicazione delle punizioni avverrà direttamente nei server backend via MariaDB.
    rm -rf $SERVER_DIR/proxy/plugins/LibertyBans*.jar
EOF

  scp -i $SSH_KEY_PATH docker-compose.yml $VPS_USER@$VPS_IP:$SERVER_DIR/
  # Copia il file di esempio .env se non esiste sulla VPS, così i container si avviano
  scp -i $SSH_KEY_PATH .env.example $VPS_USER@$VPS_IP:$SERVER_DIR/.env
  rsync -avz -e "ssh -i $SSH_KEY_PATH" shared/ $VPS_USER@$VPS_IP:$SERVER_DIR/shared/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" proxy/ $VPS_USER@$VPS_IP:$SERVER_DIR/proxy/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" lobby/ $VPS_USER@$VPS_IP:$SERVER_DIR/lobby/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" survival/ $VPS_USER@$VPS_IP:$SERVER_DIR/survival/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" creative/ $VPS_USER@$VPS_IP:$SERVER_DIR/creative/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" medioeval/ $VPS_USER@$VPS_IP:$SERVER_DIR/medioeval/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" motoleo/ $VPS_USER@$VPS_IP:$SERVER_DIR/motoleo/
  rsync -avz -e "ssh -i $SSH_KEY_PATH" nginx/ $VPS_USER@$VPS_IP:$SERVER_DIR/nginx/

  echo "3️⃣ Configurazione plugin e avvio dei server Minecraft (Docker)..."
  ssh -i $SSH_KEY_PATH $VPS_USER@$VPS_IP << EOF
    cd $SERVER_DIR
    
    echo "🔐 Configurazione AuthMe per Geyser/Floodgate..."
    if [ -f "$SERVER_DIR/lobby/plugins/AuthMe/config.yml" ]; then
      sed -i "s/allowedNicknameCharacters: '\[a-zA-Z0-9_\]\*'/allowedNicknameCharacters: '\[a-zA-Z0-9_\*\]\*'/g" $SERVER_DIR/lobby/plugins/AuthMe/config.yml
      sed -i "s/floodgate: false/floodgate: true/g" $SERVER_DIR/lobby/plugins/AuthMe/config.yml
    fi

    echo "🐳 Applico le modifiche all'infrastruttura (se presenti)..."
    docker compose up -d --remove-orphans
EOF
fi

if [ "$DEPLOY_WEB" = true ]; then
  echo "4️⃣ Trasferimento e build del Web Panel sul VPS..."
  rsync -avz --delete \
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
    echo "🐳 Costruisco e avvio i container del Web Panel (Next.js) e Scheduler..."
    docker compose up -d --build panel scheduler nginx
    
    echo "🗄️ Inizializzazione tabelle database..."
    # Attende che il database MariaDB sia pronto
    until docker exec mc_db sh -c 'mysqladmin ping -h localhost -uroot -p"\$MYSQL_ROOT_PASSWORD" --silent'; do
      echo 'In attesa che MariaDB sia pronto...'
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

echo "=========================================="
echo "✅ Deploy completato con successo!"
if [ "$DEPLOY_WEB" = true ]; then
  echo "🌐 Il pannello è raggiungibile all'indirizzo http://$VPS_IP:9800"
fi
echo "=========================================="
