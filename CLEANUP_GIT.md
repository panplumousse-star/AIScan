# Instructions pour nettoyer Git et retirer les fichiers de build

## Problème
Des fichiers de build volumineux (>100MB) sont dans l'historique Git et bloquent le push vers GitHub.

## Solution

### Étape 1 : Retirer les fichiers du suivi Git (sans les supprimer localement)

Exécutez ces commandes dans l'ordre :

```bash
# Retirer le dossier build/ complet
git rm -r --cached build/

# Retirer .dart_tool/ (contient les fichiers de build Flutter volumineux)
git rm -r --cached .dart_tool/

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
```

### Étape 2 : Vérifier les changements

```bash
git status
```

Vous devriez voir les fichiers listés comme "deleted" mais ils resteront sur votre disque local.

### Étape 3 : Commiter les changements

```bash
git add .gitignore
git commit -m "chore: remove build files and artifacts from git tracking"
```

### Étape 4 : Nettoyer l'historique Git (optionnel mais recommandé)

Si les fichiers volumineux sont dans l'historique, vous devrez nettoyer l'historique avec git filter-branch ou BFG Repo-Cleaner :

**Option A : Utiliser git filter-branch (intégré à Git)**
```bash
# ATTENTION : Cela réécrit l'historique Git
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch build/ .dart_tool/" \
  --prune-empty --tag-name-filter cat -- --all
```

**Option B : Utiliser BFG Repo-Cleaner (plus rapide, recommandé)**
```bash
# Télécharger BFG depuis https://rtyley.github.io/bfg-repo-cleaner/
# Puis :
java -jar bfg.jar --delete-folders build
java -jar bfg.jar --delete-folders .dart_tool
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### Étape 5 : Force push (seulement si vous avez nettoyé l'historique)

⚠️ **ATTENTION** : Ne faites cela que si vous êtes sûr et que vous travaillez seul ou avez coordonné avec votre équipe.

```bash
git push origin master --force
```

## Alternative : Créer une nouvelle branche propre

Si vous ne voulez pas modifier l'historique :

```bash
# Créer une nouvelle branche depuis le commit actuel
git checkout --orphan clean-master

# Ajouter tous les fichiers sauf ceux ignorés
git add .

# Commiter
git commit -m "Initial commit - clean version without build files"

# Pousser la nouvelle branche
git push origin clean-master

# Puis sur GitHub, changer la branche par défaut vers clean-master
```

## Vérification

Après le nettoyage, vérifiez que les gros fichiers ne sont plus suivis :

```bash
git ls-files | xargs ls -lh | sort -k5 -hr | head -20
```

Aucun fichier ne devrait dépasser quelques MB.
