#!/usr/bin/env python3
import os
import subprocess
import shlex
from pathlib import Path

# ===============================
# ⚙️ CONFIGURATION
# ===============================
FFMPEG_BIN = "/mnt/user/scripts/ffmpeg"  # ton binaire complet FFmpeg
ROOT_DIR = Path("/mnt/user/Torrent")
IGNORE_DIRS = [".Recycle.Bin"]
EXTENSIONS = [".mp4", ".mkv", ".avi", ".ts"]

# Paramètres d'encodage mobile (CQ + NVENC)
HWACCEL = "-hwaccel cuda -vsync passthrough"
VIDEO = "-vcodec hevc_nvenc -preset p3 -rc vbr -cq 30 -b:v 200k -maxrate 250k -bufsize 400k"
AUDIO = "-c:a aac -b:a 32k -ac 2"
SCALE = '-vf "scale_cuda=w=640:h=360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2,format=nv12"'
MAPS = "-map 0:v:0 -map 0:a? -map 0:s?"
OUT_SUFFIX = "_mobile"

# ===============================
# 🧠 FONCTIONS
# ===============================

def run_conversion(src_path):
    base = src_path.stem
    out_path = src_path.with_name(f"{base}{OUT_SUFFIX}.mkv")

    # évite les doublons
    counter = 1
    while out_path.exists():
        out_path = src_path.with_name(f"{base}{OUT_SUFFIX}_{counter}.mkv")
        counter += 1

    # commande FFmpeg complète
    cmd = f'{FFMPEG_BIN} {HWACCEL} -c:v h264_cuvid -i "{src_path}" {SCALE} {VIDEO} {MAPS} {AUDIO} -c:s copy "{out_path}" -y'

    print(f"\n🎬 {src_path.name}")
    print(f"→ Commande : {cmd}\n")

    try:
        subprocess.run(shlex.split(cmd), check=True)
        print(f"✅ Conversion terminée : {out_path}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Erreur sur {src_path.name} : {e}")


def main():
    print("🚀 Conversion mobile HEVC NVENC 640x360 AAC 32k (p3, CQ30)\n")
    for root, _, files in os.walk(ROOT_DIR):
        for f in files:
            path = Path(root) / f
            if path.suffix.lower() in EXTENSIONS and OUT_SUFFIX not in f:
                run_conversion(path)
    print("\n✨ Toutes les conversions sont terminées !")


if __name__ == "__main__":
    main()
