#!/bin/bash
# Script pour retirer les fichiers de build du suivi Git

echo "Nettoyage des fichiers de build du suivi Git..."

# Retirer le dossier build/ complet
git rm -r --cached build/ 2>/dev/null || true

# Retirer .dart_tool/ (contient les fichiers de build Flutter)
git rm -r --cached .dart_tool/ 2>/dev/null || true

# Retirer les fichiers Android build spécifiques
git rm -r --cached android/app/build/ 2>/dev/null || true
git rm -r --cached android/build/ 2>/dev/null || true

# Retirer les fichiers temporaires Windows
git rm --cached assets/icons/*~RF* 2>/dev/null || true
git rm --cached assets/icons/*Zone.Identifier 2>/dev/null || true

# Retirer les fichiers temporaires
git rm --cached tmpclaude-* 2>/dev/null || true
git rm --cached update_icon.bat 2>/dev/null || true
git rm --cached INSTRUCTIONS_ICONE.md 2>/dev/null || true

echo "Fichiers retirés du suivi Git. Vérifiez avec 'git status'"
echo "Puis commitez avec: git commit -m 'chore: remove build files from git tracking'"
