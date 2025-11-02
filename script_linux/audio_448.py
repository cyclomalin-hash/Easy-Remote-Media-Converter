#!/usr/bin/env python3
import os
import subprocess
import time

# ✅ Chemin local vers ton binaire FFmpeg
FFMPEG_PATH = "/mnt/user/scripts/ffmpeg"

# ✅ Répertoires et paramètres
HOST_WORKDIR = "/mnt/user/Torrent/encode_audio"
EXTS = (".mp4", ".mkv", ".avi", ".ts")
BITRATE = "448k"
SUFFIX = "_448"
SESSION = "audio_448"
LOG_FILE = f"/logs/{SESSION}.log"

def main():
    # Vérifie /logs et permissions
    if os.path.isdir("/logs"):
        subprocess.run(["chmod", "777", "/logs"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Vide le log précédent s’il existe
    if os.path.exists(LOG_FILE):
        open(LOG_FILE, "w").close()

    # Parcourt les fichiers à encoder
    for root, _, files in os.walk(HOST_WORKDIR):
        for f in files:
            if not f.lower().endswith(EXTS) or SUFFIX in f:
                continue

            src = os.path.join(root, f)
            base, ext = os.path.splitext(f)
            dst = os.path.join(root, f"{base}{SUFFIX}{ext}")

            # ✅ Empêche le double encodage du même fichier
            lockfile = f"/tmp/{SESSION}_{base}.lock"
            if os.path.exists(lockfile):
                continue
            open(lockfile, "w").close()

            # ✅ Commande FFmpeg locale (pas de Docker)
            cmd = (
                f"'{FFMPEG_PATH}' -hide_banner -loglevel info "
                f"-i '{src}' "
                f"-map 0:v? -map 0:a? -map 0:s? "
                f"-c:v copy -c:s copy -c:a ac3 -b:a {BITRATE} "
                f"-map_chapters 0 -y '{dst}' "
                f">> {LOG_FILE} 2>&1; "
                f"rm -f '{lockfile}'; "
                f"tail -n 60 {LOG_FILE} > {LOG_FILE}.tmp && mv {LOG_FILE}.tmp {LOG_FILE}"
            )

            # ✅ Lancement dans une session tmux indépendante
            tmux_session = f"{SESSION}_{int(time.time())}"
            subprocess.run([
                "tmux", "new-session", "-d", "-s", tmux_session, "bash", "-c", cmd
            ])

if __name__ == "__main__":
    main()
