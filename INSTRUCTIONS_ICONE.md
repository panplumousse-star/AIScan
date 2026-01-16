# Instructions pour mettre à jour l'icône Android

L'icône de l'application Android a été configurée pour utiliser votre nouvelle image.

## Étape finale requise

Pour terminer la configuration, vous devez copier l'image dans le bon dossier :

**Option 1 : Utiliser le script batch (Windows)**
```bash
update_icon.bat
```

**Option 2 : Copie manuelle**
Copiez le fichier `assets/icons/icone_app_scanai.png` vers :
```
android/app/src/main/res/drawable/app_icon.png
```

**Option 3 : Utiliser PowerShell**
```powershell
Copy-Item -Path "assets\icons\icone_app_scanai.png" -Destination "android\app\src\main\res\drawable\app_icon.png" -Force
```

Une fois l'image copiée, reconstruisez l'application Android pour voir le nouveau logo.
