@echo off
REM ==================================================
REM  Fichier unique : encode_menu.bat
REM  Contient ton PowerShell complet + fermeture propre
REM ==================================================
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "& { $PSCode = (Get-Content '%~f0' -Raw) -split ':POWERSHELL' | Select-Object -Last 1; Invoke-Expression $PSCode }"
exit /b

:POWERSHELL
# ==================================================
#  Début du code PowerShell complet
# ==================================================

$Server = "192.168.1.2"
$User = "root"
$RemotePath = "/mnt/user/scripts"
chcp 65001 > $null

function Show-SessionsMenu {
    while ($true) {
        Clear-Host
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "         GESTION DES SESSIONS TMUX       "
        Write-Host "========================================"

        $SessionsRaw = ssh $User@$Server "bash -lc 'tmux ls 2>/dev/null'" 2>$null

        if (-not $SessionsRaw) {
            Write-Host "Aucune session tmux active." -ForegroundColor Yellow
            Read-Host "Appuie sur Entrée pour revenir au menu principal"
            return
        }

        $List = @()
        foreach ($line in $SessionsRaw -split "`n") {
            if ($line -match "^(?<name>[a-zA-Z0-9_\-]+):") {
                $List += $matches['name']
            }
        }

        Clear-Host
        Write-Host "===== Sessions actives =====" -ForegroundColor Cyan
        $i = 1
        foreach ($name in $List) { Write-Host "$i) Voir la session $name"; $i++ }
        foreach ($name in $List) { Write-Host "$i) Tuer la session $name"; $i++ }
        Write-Host "0) Retour"
        $choix = Read-Host "Ton choix"

        if ($choix -eq "0" -or -not $choix) { return }

        $count = $List.Count
        if ($choix -as [int] -and [int]$choix -ge 1 -and [int]$choix -le ($count*2)) {
            if ([int]$choix -le $count) {
                $Session = $List[[int]$choix - 1]
                ssh -t $User@$Server "bash -lc 'tmux attach -t $Session'"
            } else {
                $Session = $List[[int]$choix - $count - 1]
                $confirm = Read-Host "Tuer la session $Session ? (y/n)"
                if ($confirm -match '^[yYoO]$') {
                    ssh $User@$Server "bash -lc 'tmux kill-session -t $Session'"
                    Write-Host "Session $Session supprimée." -ForegroundColor Green
                    Start-Sleep 1
                }
            }
        } else {
            Write-Host "Choix invalide." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}

function Start-JobInTmux([string]$session, [string]$scriptPath, [bool]$recursive){
    if ($recursive) { $scriptPath += " -sf" }
    $RemoteCommand = "if ! tmux has-session -t $session 2>/dev/null; then tmux new-session -d -s $session 'python3 $scriptPath'; fi; tmux attach -t $session"
    ssh -t $User@$Server "bash -lc \"$RemoteCommand\""
    ssh $User@$Server "bash -lc 'while tmux has-session -t $session 2>/dev/null; do sleep 2; done'"
    Write-Host "`n✅ Encodage terminé. Fermeture automatique..." -ForegroundColor Green
    Start-Sleep 2
    exit
}

# ===================== BOUCLE MENU PRINCIPAL =====================

$ExitProgram = $false

while (-not $ExitProgram) {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1) 720p Nvidia"
    Write-Host "2) 1080p Nvidia"
    Write-Host ""
    Write-Host "3) Audio FR"
    Write-Host "4) Audio 192"
    Write-Host "5) Audio 224"
    Write-Host "6) Audio 384"
    Write-Host "7) Audio 448"
    Write-Host "8) Audio 640"
    Write-Host ""
    Write-Host "9) Gérer les sessions actives"
    Write-Host "11) Renommage des Films"
    Write-Host "0) Quitter"
    Write-Host "=============================================="
    $choice = Read-Host "Ton choix"

    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "=== 720p ===" -ForegroundColor Cyan
            Write-Host "1) Dossier uniquement"
            Write-Host "2) Sous-dossiers (récursif)"
            $rec = ((Read-Host "Ton choix") -eq "2")
            Start-JobInTmux -session "720p" -scriptPath "$RemotePath/720p.py" -recursive:$rec
        }
        "2" {
            Clear-Host
            Write-Host "=== 1080p ===" -ForegroundColor Cyan
            Write-Host "1) Dossier uniquement"
            Write-Host "2) Sous-dossiers (récursif)"
            $rec = ((Read-Host "Ton choix") -eq "2")
            Start-JobInTmux -session "1080p" -scriptPath "$RemotePath/1080p.py" -recursive:$rec
        }
        "3" {
            Clear-Host
            Write-Host "=== Audio FR ===" -ForegroundColor Cyan
            Write-Host "1) Dossier uniquement"
            Write-Host "2) Sous-dossiers (récursif)"
            $rec = ((Read-Host "Ton choix") -eq "2")
            Start-JobInTmux -session "encode_fr" -scriptPath "$RemotePath/encode_fr.py" -recursive:$rec
        }
        "4" { Start-JobInTmux -session "encode_192" -scriptPath "$RemotePath/audio_192.py" -recursive:$false }
        "5" { Start-JobInTmux -session "encode_224" -scriptPath "$RemotePath/audio_224.py" -recursive:$false }
        "6" { Start-JobInTmux -session "encode_384" -scriptPath "$RemotePath/audio_384.py" -recursive:$false }
        "7" { Start-JobInTmux -session "encode_448" -scriptPath "$RemotePath/audio_448.py" -recursive:$false }
        "8" { Start-JobInTmux -session "encode_640" -scriptPath "$RemotePath/audio_640.py" -recursive:$false }
        "9" { Show-SessionsMenu; continue }
        "11" {
            Clear-Host
            Write-Host "=== Renommage des Films ===" -ForegroundColor Cyan
            Write-Host "1) Dossier uniquement"
            Write-Host "2) Sous-dossiers (récursif)"
            $rec = ((Read-Host "Ton choix") -eq "2")
            Start-JobInTmux -session "ren1" -scriptPath "$RemotePath/ren.py" -recursive:$rec
        }
        "0" { $ExitProgram = $true }
        default {
            Write-Host "Choix invalide." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}

# ==================================================
#  Fin du PowerShell
# ==================================================
exit
