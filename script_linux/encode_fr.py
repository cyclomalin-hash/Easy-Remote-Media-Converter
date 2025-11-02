#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import argparse
from datetime import datetime

# ================= CONFIG =================
FFMPEG_PATH = "/mnt/user/scripts/ffmpeg"
FFPROBE_PATH = "/mnt/user/scripts/ffprobe"
IGNORE_DIRS = [".Recycle.Bin"]
WORKDIRS = ["/mnt/user/Torrent"]
OUTPUT_DIR = "/mnt/user/Torrent"
EXTS = (".mp4", ".mkv", ".avi", ".ts")
SUFFIX_OUT = "_FR"


# ================= MAIN =================
def process_directory(folder, recursive=False):
    """Analyse et extrait uniquement les pistes FR"""
    for root, dirs, files in os.walk(folder):
        # Ignore certains dossiers
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

        if not recursive:
            dirs.clear()

        for f in files:
            fl = f.lower()
            if not fl.endswith(EXTS):
                continue
            if SUFFIX_OUT.lower() in fl:
                # Évite la boucle infinie sur ses propres sorties
                continue

            src_path = os.path.join(root, f)
            base, _ = os.path.splitext(f)
            dst_path = os.path.join(OUTPUT_DIR, f"{base}{SUFFIX_OUT}.mkv")

            # --- ffprobe pour détecter les flux FR ---
            probe = subprocess.run(
                [
                    FFPROBE_PATH, "-v", "error",
                    "-show_entries", "stream=index,codec_type:stream_tags=language",
                    "-of", "csv=p=0", src_path
                ],
                capture_output=True, text=True
            )

            lines = [ln for ln in probe.stdout.strip().split("\n") if ln]
            fr_audio_idx = []
            fr_sub_idx = []

            for line in lines:
                parts = line.split(",")
                if len(parts) < 2:
                    continue
                try:
                    idx = int(parts[0])
                except ValueError:
                    continue

                codec_type = parts[1].strip().lower()
                line_lower = line.lower()
                is_fr = any(tag in line_lower for tag in ["fra", "fre", "fr", "french"])

                if codec_type == "audio" and is_fr:
                    fr_audio_idx.append(idx)
                elif codec_type == "subtitle" and is_fr:
                    fr_sub_idx.append(idx)

            # 🧠 rien à faire si pas de flux FR
            if not fr_audio_idx and not fr_sub_idx:
                print(f"⚠️  Aucune piste FR trouvée → ignoré : {f}")
                continue

            print(f"\n🎬 Extraction FR : {f}")

            # Construction des -map
            maps = ["-map", "0:v:0"]
            for idx in fr_audio_idx:
                maps += ["-map", f"0:{idx}"]
            for idx in fr_sub_idx:
                maps += ["-map", f"0:{idx}"]

            cmd = [
                FFMPEG_PATH,
                "-hide_banner", "-loglevel", "error",  # silencieux
                "-i", src_path,
                *maps,
                "-c", "copy",
                "-map_chapters", "0",
                dst_path, "-y"
            ]

            try:
                subprocess.run(cmd, check=True)
                print(f"✅ Terminé : {dst_path}")
            except subprocess.CalledProcessError:
                print(f"❌ Erreur sur {f}")


def main():
    parser = argparse.ArgumentParser(description="Extraction des pistes FR, avec ou sans sous-répertoires")
    parser.add_argument("-sf", "--subfolders", action="store_true",
                        help="Inclure les sous-répertoires")
    args = parser.parse_args()

    for folder in WORKDIRS:
        if not os.path.isdir(folder):
            print(f"❌ Dossier introuvable : {folder}")
            continue

        print(f"📁 Traitement du dossier : {folder}")
        process_directory(folder, recursive=args.subfolders)


if __name__ == "__main__":
    print(f"=== [START] Extraction FR {datetime.now():%H:%M:%S} ===")
    main()
    print(f"--- [END] {datetime.now():%H:%M:%S} ---")
