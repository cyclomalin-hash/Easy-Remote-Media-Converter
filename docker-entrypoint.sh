#!/bin/bash
set -e

# [MODIF PRO] Variables pour les chemins des modèles
USER_SKEL_DIR="/usr/local/share/user_skel"

# --- 1. Initialisation du volume /data (si vide) ---
if [ ! -f "/data/config/users.conf" ]; then
    echo "--- Première exécution détectée : Initialisation de /data ---"
    
    # [MODIFICATION] Ajout de /data/private_keys ici
    mkdir -p /data/config /data/keys /data/userkeys /data/private_keys /data/bin /data/home 

    echo "Copie des binaires ffmpeg par défaut..."
    cp /usr/local/bin/ffmpeg_defaults/* /data/bin/

    echo "Création de /data/config/users.conf par défaut..."
    cat <<EOT > /data/config/users.conf
# Format: user:pass:UID:GID
user1:ignored:1000:100
user2:ignored:1001:100
EOT

    echo "Création de /data/config/sshd_config sécurisé..."
    cat <<EOT > /data/config/sshd_config
Port 22
Protocol 2
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
AllowTcpForwarding yes
X11Forwarding yes
HostKey /data/keys/ssh_host_rsa_key
HostKey /data/keys/ssh_host_ecdsa_key
HostKey /data/keys/ssh_host_ed25519_key
EOT
fi

# Force l'exécution des binaires FFmpeg
echo "Application des permissions d'exécution sur /data/bin..."
chmod +x /data/bin/*


# --- 2. Génération/Liaison des clés d'hôte SSH ---
echo "Configuration du serveur SSH..."
if [ ! -f "/data/keys/ssh_host_rsa_key" ]; then
    echo "Génération des clés d'hôte SSH persistantes..."
    ssh-keygen -t rsa -b 4096 -f /data/keys/ssh_host_rsa_key -N ""
    ssh-keygen -t ecdsa -f /data/keys/ssh_host_ecdsa_key -N ""
    ssh-keygen -t ed25519 -f /data/keys/ssh_host_ed25519_key -N ""
fi
chmod 600 /data/keys/*_key
chmod 644 /data/keys/*.pub
rm -f /etc/ssh/ssh_host_*
ln -s /data/keys/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
ln -s /data/keys/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
ln -s /data/keys/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
ln -s /data/keys/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
ln -s /data/keys/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
ln -s /data/keys/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
ln -sf /data/config/sshd_config /etc/ssh/sshd_config

# --- [MODIF PRO] 2b. Vérification de l'utilisateur de service 'main' ---
echo "Vérification de l'utilisateur de service 'main' (9000:100)..."
if ! id "main" >/dev/null 2>&1; then
    echo "  -> 'main' non trouvé. Recréation..."
    groupadd -g 100 users || true
    useradd -N -s /bin/bash -u 9000 -g 100 main
else
    echo "  -> 'main' existe."
fi

# --- 3. Synchronisation des utilisateurs (CORRIGÉ) ---
echo "Synchronisation des utilisateurs..."

# UID minimum pour les utilisateurs que nous gérons
MIN_UID=1000

# --- Étape 3a: Suppression des utilisateurs orphelins (Votre Étape 2 partiel) ---
VALID_USERS=$(grep -vE "^#|^$" /data/config/users.conf | cut -d: -f1 | xargs)
echo "Utilisateurs valides dans users.conf: $VALID_USERS"

MANAGED_USERS=$(awk -F: -v min_uid="$MIN_UID" '$3 >= min_uid && $1 != "main" { print $1 }' /etc/passwd | xargs)
echo "Utilisateurs gérés (excl. main) trouvés dans le conteneur: $MANAGED_USERS"

for user in $MANAGED_USERS; do
    if ! echo "$VALID_USERS" | grep -qw "$user"; then
        echo "--- Suppression de l'utilisateur orphelin: $user ---"
        deluser "$user"
    fi
done

# --- Étape 3b: Création/Mise à jour des utilisateurs (Votre Étape 1 et 2) ---
echo "Traitement des utilisateurs depuis /data/config/users.conf..."

tail -n +2 "/data/config/users.conf" | while IFS=: read -r TARGET_USER TARGET_PASS TARGET_PUID TARGET_PGID || [ -n "$TARGET_USER" ]; do
    
    if [ -z "$TARGET_USER" ] || [[ "$TARGET_USER" = \#* ]]; then
        continue
    fi

    echo "--- Traitement de: $TARGET_USER (UID: $TARGET_PUID, GID: $TARGET_PGID) ---"

    TARGET_HOME_DIR="/data/home/$TARGET_USER"
    TARGET_SCRIPTS_DIR="$TARGET_HOME_DIR/scripts"

    if ! getent group "$TARGET_PGID" >/dev/null; then
        echo "Création du groupe (GID: $TARGET_PGID)..."
        addgroup --gid "$TARGET_PGID" "group-$TARGET_PGID"
    fi

    # --- Votre Étape 2 (Créer user) ---
    if ! getent passwd "$TARGET_PUID" >/dev/null; then
        echo "Création de l'utilisateur $TARGET_USER..."
        adduser --disabled-password --gecos "" \
            --uid "$TARGET_PUID" --gid "$TARGET_PGID" \
            --home "$TARGET_HOME_DIR" \
            --shell "/bin/bash" "$TARGET_USER"
    fi
    
    echo "Vérification de l'arborescence pour $TARGET_USER..."
    mkdir -p "$TARGET_HOME_DIR/.ssh"
    mkdir -p "$TARGET_SCRIPTS_DIR"
    touch "$TARGET_HOME_DIR/.profile"

    # --- [NOUVELLE LOGIQUE] Votre Étape 3, 4 et 5 ---
    
    PUB_KEY_FILE="/data/userkeys/$TARGET_USER.pub"
    PRIVATE_KEY_FILE_PATH="/data/private_keys/${TARGET_USER}_ssh_key"
    
    # Étape 3: Analyser si la clé publique manque (en se basant sur /data/userkeys)
    if [ ! -f "$PUB_KEY_FILE" ]; then
        echo "--- (Étape 4) Clé publique non trouvée pour $TARGET_USER. Génération... ---"
        
        # Générer la clé (type ed25519, rapide et sécurisé)
        ssh-keygen -t ed25519 -f "$PRIVATE_KEY_FILE_PATH" -N ""
        
        echo "Clé privée générée dans: $PRIVATE_KEY_FILE_PATH"
        
        # Déplacer la clé publique générée vers /data/userkeys/
        mv "${PRIVATE_KEY_FILE_PATH}.pub" "$PUB_KEY_FILE"
        
        # Sécuriser la clé privée (pour quand vous la récupérez)
        chmod 600 "$PRIVATE_KEY_FILE_PATH"
        
        echo "Clé publique déplacée vers: $PUB_KEY_FILE"
    else
        echo "--- (Étape 3) Clé publique $PUB_KEY_FILE déjà présente. ---"
    fi

    # Étape 5: Regarder /data/userkeys et installer dans authorized_keys
    # (S'exécute que la clé ait été trouvée ou générée à l'instant)
    if [ -f "$PUB_KEY_FILE" ]; then
        echo "--- (Étape 5) Installation de la clé publique dans authorized_keys pour $TARGET_USER... ---"
        # On garde dos2unix, c'est une bonne pratique
        cat "$PUB_KEY_FILE" | dos2unix > "$TARGET_HOME_DIR/.ssh/authorized_keys"
    else
        # Sécurité : si la génération a échoué, on s'assure que le fichier est vide
        echo "--- (Étape 5) ATTENTION: Clé publique $PUB_KEY_FILE non trouvée, authorized_keys sera vide. ---"
        rm -f "$TARGET_HOME_DIR/.ssh/authorized_keys"
    fi
    # --- [FIN DE LA NOUVELLE LOGIQUE] ---


    # --- [MISE A JOUR] Copie des fichiers de squelette utilisateur (selon votre liste) ---
    echo "  -> Copie des fichiers de squelette utilisateur..."
    
    # Fichiers de script (dans /scripts)
    if [ -f "$USER_SKEL_DIR/menu.sh" ]; then
        cp "$USER_SKEL_DIR/menu.sh" "$TARGET_SCRIPTS_DIR/menu.sh"
        chmod +x "$TARGET_SCRIPTS_DIR/menu.sh"
    fi

    # Fichiers de lancement (à la racine du home)
    if [ -f "$USER_SKEL_DIR/lautch_menu.bat" ]; then
        cp "$USER_SKEL_DIR/lautch_menu.bat" "$TARGET_HOME_DIR/lautch_menu.bat"
    fi
    if [ -f "$USER_SKEL_DIR/lautch_menu.sh" ]; then
        cp "$USER_SKEL_DIR/lautch_menu.sh" "$TARGET_HOME_DIR/lautch_menu.sh"
        chmod +x "$TARGET_HOME_DIR/lautch_menu.sh"
    fi
    # --- [FIN DE LA MISE A JOUR] ---

    
    # Force le umask
    if ! grep -q "umask 022" "$TARGET_HOME_DIR/.profile"; then
        echo "umask 022" >> "$TARGET_HOME_DIR/.profile"
    fi
    
    # Force le PATH
    PATH_STRING='export PATH="/data/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"'
    if ! grep -q "$PATH_STRING" "$TARGET_HOME_DIR/.profile"; then
        echo "Ajout de /data/bin au PATH de $TARGET_USER"
        echo "$PATH_STRING" >> "$TARGET_HOME_DIR/.profile"
    fi

    echo "Application des permissions pour $TARGET_HOME_DIR..."
    
    # Force les permissions (après la copie des fichiers de menu)
    chown -R "$TARGET_PUID":"$TARGET_PGID" "$TARGET_HOME_DIR"
    chmod 700 "$TARGET_HOME_DIR"
    chmod 700 "$TARGET_HOME_DIR/.ssh"
    [ -f "$TARGET_HOME_DIR/.ssh/authorized_keys" ] && chmod 600 "$TARGET_HOME_DIR/.ssh/authorized_keys"
    
    # Force les ACL pour les scripts (si supporté par l'hôte)
    echo "Application des ACL sur $TARGET_SCRIPTS_DIR pour l'auto-exécution..."
    setfacl -d -m u::rwx,g::rx,o::rx "$TARGET_SCRIPTS_DIR"
    setfacl -m u::rwx,g::rx,o::rx "$TARGET_SCRIPTS_DIR"

done

# --- [MODIF PRO] 4. CORRECTION DE LA COHÉRENCE AVEC LE DOCKER FLASK (Tâche 3) ---
echo "Assurance de la propriété du dossier /data/config à l'UID 9000 (main)..."
chown -R 9000:100 /data/config

# --- 5. Lancement du service (Votre Étape 6) ---
echo "--- (Étape 6) Démarrage du serveur SSH (en tant que root) ---"
exec "$@"