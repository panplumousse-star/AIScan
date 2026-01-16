#!/bin/bash
# Script pour nettoyer l'historique Git des fichiers volumineux

set -e

echo "⚠️  ATTENTION : Ce script va réécrire l'historique Git"
echo "Assurez-vous d'avoir fait une sauvegarde ou que vous êtes seul sur ce dépôt"
echo ""
read -p "Continuer ? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Annulé."
    exit 1
fi

echo ""
echo "Étape 0 : Vérifier l'état du dépôt..."
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Des changements non commités détectés !"
    echo ""
    echo "Options :"
    echo "1. Commiter les changements"
    echo "2. Stasher les changements (les mettre de côté)"
    echo "3. Annuler"
    read -p "Votre choix (1/2/3): " choice
    
    case $choice in
        1)
            echo "Ajout de tous les changements..."
            git add -A
            read -p "Message de commit: " commit_msg
            git commit -m "${commit_msg:-chore: save changes before history cleanup}"
            ;;
        2)
            echo "Stash des changements..."
            git stash push -m "Stash before history cleanup"
            echo "✅ Changements mis de côté. Vous pourrez les récupérer avec 'git stash pop' après."
            ;;
        3)
            echo "Annulé."
            exit 1
            ;;
        *)
            echo "Choix invalide. Annulé."
            exit 1
            ;;
    esac
fi

echo ""
echo "Étape 1 : Retirer les fichiers du suivi actuel..."
git rm -r --cached build/ 2>/dev/null || true
git rm -r --cached .dart_tool/ 2>/dev/null || true
git rm -r --cached android/app/build/ 2>/dev/null || true
git rm -r --cached android/build/ 2>/dev/null || true

echo "Étape 2 : Nettoyer l'historique avec git filter-branch..."
# Supprimer build/ de tout l'historique
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch build/" \
  --prune-empty --tag-name-filter cat -- --all

# Supprimer .dart_tool/ de tout l'historique
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch .dart_tool/" \
  --prune-empty --tag-name-filter cat -- --all

echo "Étape 3 : Nettoyer les références..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "✅ Nettoyage terminé !"
echo ""
echo "Vérifiez avec : git log --all --oneline"
echo "Puis force push avec : git push origin master --force"
echo ""
echo "⚠️  ATTENTION : Le force push va réécrire l'historique sur GitHub"
echo "Si d'autres personnes travaillent sur ce dépôt, coordonnez-vous avec elles"
