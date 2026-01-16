@echo off
echo Mise à jour de l'icône de lancement Android...
copy /Y "assets\icons\icone_app_scanai.png" "android\app\src\main\res\drawable\app_icon.png"
echo Image copiée avec succès!
echo.
echo Le fichier XML a déjà été configuré pour utiliser app_icon.png
pause
