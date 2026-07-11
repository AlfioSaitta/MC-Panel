import os

servers = ["lobby", "survival", "creative", "medioeval", "motoleo"]
base_dir = "/home/alfio/Projects/MinecraftAdmin"

config_content = """# ==========================================
# zMenu Global Configuration
# ==========================================

# 1. Asynchronous processing for performance
async:
  placeholders: true
  inventory: true
  data: true

# 2. Hook and Integrations
hooks:
  placeholderapi: true
  luckperms: true

# 3. Formatting
formatting:
  minimessage: true # Enables <gradient:#ff0000:#00ff00>Text</gradient>

# 4. Cross-Play Geyser / Floodgate Integration
geyser:
  enabled: true
  # Render menus as native Bedrock Forms instead of Java Chest GUIs
  bedrock-forms: true
"""

menu_content = """# ==========================================
# /hub_menu - Network Navigator
# ==========================================
name: "<gradient:#ff0000:#00ff00>Network Menu</gradient>"
size: 27
# Specifica che questo menu si comporterà come form su Bedrock
bedrock-form:
  title: "Network Menu"
  type: simple

items:
  survival:
    slot: 11
    item:
      material: GRASS_BLOCK
      name: "<green>🌲 Survival</green>"
      lore:
        - "<gray>Giocatori online: <white>%bungee_survival%</white></gray>"
        - ""
        - "<yellow>Clicca per connetterti!</yellow>"
    # Bedrock native form button configuration
    bedrock-form:
      text: "🌲 Survival\n[%bungee_survival% Giocatori]"
    actions:
      - "console: server %player_name% survival"
      - "close:"
      
  profilo:
    slot: 13
    item:
      material: PLAYER_HEAD
      name: "<gold>👤 Profilo Utente</gold>"
      lore:
        - "<gray>Nome: <white>%player_name%</white></gray>"
        - "<gray>Grado: <white>%luckperms_primary_group_name%</white></gray>"
        - "<gray>Bilancio: <white>%vault_eco_balance_formatted%</white></gray>"
    bedrock-form:
      text: "👤 Profilo\n%luckperms_primary_group_name% - %vault_eco_balance_formatted%"
      
  chiudi:
    slot: 15
    item:
      material: BARRIER
      name: "<red>❌ Chiudi</red>"
    bedrock-form:
      text: "❌ Chiudi"
    actions:
      - "close:"
"""

for srv in servers:
    path = f"{base_dir}/{srv}/plugins/zMenu"
    os.makedirs(f"{path}/menus", exist_ok=True)
    
    with open(f"{path}/config.yml", "w") as f:
        f.write(config_content)
        
    with open(f"{path}/menus/hub_menu.yml", "w") as f:
        f.write(menu_content)

print("zMenu configs created successfully for all servers locally.")
