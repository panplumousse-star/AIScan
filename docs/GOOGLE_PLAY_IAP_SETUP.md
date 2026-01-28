# Guide de Configuration Google Play In-App Purchase pour Scanaï

Ce guide détaille les étapes pour configurer l'achat in-app "Premium Lifetime" sur Google Play Console.

## Table des matières

1. [Prérequis](#prérequis)
2. [Étape 1 : Préparer l'application](#étape-1--préparer-lapplication)
3. [Étape 2 : Configurer le profil de paiement](#étape-2--configurer-le-profil-de-paiement)
4. [Étape 3 : Créer le produit in-app](#étape-3--créer-le-produit-in-app)
5. [Étape 4 : Configurer les testeurs](#étape-4--configurer-les-testeurs)
6. [Étape 5 : Publier en test interne](#étape-5--publier-en-test-interne)
7. [Étape 6 : Tester les achats](#étape-6--tester-les-achats)
8. [Dépannage](#dépannage)

---

## Prérequis

Avant de commencer, assurez-vous d'avoir :

- [ ] Un compte Google Play Console actif (frais d'inscription : 25$ une fois)
- [ ] L'application Scanaï créée dans la console
- [ ] Un AAB (Android App Bundle) signé uploadé (même en test interne)
- [ ] Un profil de paiement marchand configuré

> ⚠️ **Important** : L'API Google Play Billing ne fonctionne PAS tant que vous n'avez pas au moins une release sur un track de test (interne, fermé, ou ouvert).

---

## Étape 1 : Préparer l'application

### 1.1 Créer l'application (si pas déjà fait)

1. Aller sur [Google Play Console](https://play.google.com/console)
2. Cliquer sur **"Créer une application"**
3. Remplir les informations :
   - **Nom** : Scanaï
   - **Langue par défaut** : Français
   - **Application ou jeu** : Application
   - **Gratuite ou payante** : Gratuite
4. Accepter les déclarations et cliquer **"Créer l'application"**

### 1.2 Générer un AAB signé

```bash
# Générer une clé de signature (une seule fois)
keytool -genkey -v -keystore ~/scanai-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias scanai

# Build l'AAB signé
flutter build appbundle --release
```

Le fichier sera dans : `build/app/outputs/bundle/release/app-release.aab`

### 1.3 Uploader l'AAB sur le track de test interne

1. Aller dans **Publication** > **Test interne**
2. Cliquer sur **"Créer une release"**
3. Uploader le fichier `app-release.aab`
4. Ajouter des notes de version
5. Cliquer sur **"Enregistrer"** puis **"Examiner la release"**
6. Cliquer sur **"Démarrer le déploiement vers Test interne"**

---

## Étape 2 : Configurer le profil de paiement

### 2.1 Créer un profil de paiement marchand

1. Aller dans **Paramètres** (icône engrenage) > **Profil de paiement**
2. Si pas de profil, cliquer sur **"Créer un profil de paiement"**
3. Remplir les informations légales :
   - Type d'entreprise (particulier ou entreprise)
   - Nom et adresse
   - Informations fiscales
   - Coordonnées bancaires pour les versements

> 📝 **Note** : La vérification du profil peut prendre 24-48h.

---

## Étape 3 : Créer le produit in-app

### 3.1 Accéder à la section produits

1. Dans Play Console, sélectionner **Scanaï**
2. Aller dans **Monétiser** > **Produits** > **Produits intégrés à l'application**

### 3.2 Créer le produit Premium Lifetime

1. Cliquer sur **"Créer un produit"**

2. Remplir les informations :

| Champ | Valeur |
|-------|--------|
| **ID produit** | `scanai_premium_lifetime` |
| **Nom** | Premium à vie |
| **Description** | Débloque toutes les fonctionnalités : scans illimités, multi-pages, export PDF, partage, OCR |

> ⚠️ **IMPORTANT** : L'ID produit `scanai_premium_lifetime` doit correspondre EXACTEMENT à celui dans le code (`iap_service.dart`). Il ne peut PAS être modifié après création.

3. Configurer le prix :
   - Cliquer sur **"Définir le prix"**
   - Sélectionner **France** comme pays de base
   - Entrer **2,99 €**
   - Cliquer sur **"Appliquer aux taux de change"** pour les autres pays
   - Vérifier et ajuster les prix si nécessaire
   - Cliquer sur **"Mettre à jour"**

4. **NE PAS cocher** "Autoriser l'achat en plusieurs quantités" (c'est un achat unique)

5. Cliquer sur **"Enregistrer"**

### 3.3 Activer le produit

1. Après l'enregistrement, cliquer sur **"Activer"**
2. Le statut doit passer à **"Actif"**

> ⏳ **Note** : Les produits peuvent mettre jusqu'à quelques heures pour être disponibles dans l'application après activation (cache Google).

---

## Étape 4 : Configurer les testeurs

### 4.1 Ajouter des testeurs de licence

Les testeurs de licence peuvent effectuer des achats test SANS être facturés.

1. Aller dans **Paramètres** > **Gestion des licences**
2. Sous **"Testeurs de licence"**, ajouter les adresses Gmail des testeurs
3. Cliquer sur **"Enregistrer les modifications"**

### 4.2 Configurer la liste d'adresses e-mail pour le test interne

1. Aller dans **Publication** > **Test interne**
2. Dans l'onglet **"Testeurs"**, cliquer sur **"Créer une liste d'adresses e-mail"**
3. Nommer la liste (ex: "Testeurs Scanaï")
4. Ajouter les adresses e-mail des testeurs
5. Cocher la liste créée
6. Cliquer sur **"Enregistrer les modifications"**

### 4.3 Obtenir le lien de test

1. Dans **Test interne** > **Testeurs**
2. Copier le **"Lien de participation"** (format : `https://play.google.com/apps/internaltest/...`)
3. Envoyer ce lien aux testeurs

---

## Étape 5 : Publier en test interne

### 5.1 Vérifier le statut de publication

1. Aller dans **Publication** > **Test interne**
2. Vérifier que le statut est **"Disponible pour les testeurs"**

### 5.2 Attendre la propagation

- **Release** : Quelques heures pour être disponible
- **Produits in-app** : Jusqu'à 24h pour être actifs

---

## Étape 6 : Tester les achats

### 6.1 Installer l'application de test

Les testeurs doivent :

1. Ouvrir le lien de participation reçu
2. Accepter l'invitation à devenir testeur
3. Installer l'application depuis le Play Store (version test)

> ⚠️ **Important** : Les achats in-app ne fonctionnent PAS sur :
> - Les APK installés manuellement (sideload)
> - Les émulateurs
> - Les builds debug
>
> Il FAUT installer depuis le Play Store via le track de test.

### 6.2 Effectuer un achat test

1. Ouvrir Scanaï
2. Déclencher le dialog Premium (ex: essayer de scanner au-delà de la limite)
3. Cliquer sur **"Débloquer pour X €"**
4. Google Play affiche le dialog de paiement
5. Si le compte est un testeur de licence : le paiement sera simulé (pas de facturation réelle)
6. Si le compte n'est PAS testeur de licence : le paiement sera RÉEL

### 6.3 Tester la restauration

1. Désinstaller l'application
2. Réinstaller depuis le Play Store
3. Ouvrir le dialog Premium
4. Cliquer sur **"Restaurer les achats"**
5. L'achat précédent doit être restauré

---

## Dépannage

### Le produit n'apparaît pas dans l'application

| Problème | Solution |
|----------|----------|
| Produit pas encore propagé | Attendre 24h après activation |
| ID produit incorrect | Vérifier que `scanai_premium_lifetime` est exact |
| App pas signée | Utiliser l'app du Play Store, pas un APK debug |
| Pas de release active | Publier au moins en test interne |

### L'achat échoue

| Problème | Solution |
|----------|----------|
| "Item not available" | Le produit n'est pas actif ou pas propagé |
| "Authentication required" | Vérifier le compte Google sur l'appareil |
| Erreur de facturation | Vérifier le profil de paiement |

### L'achat est facturé alors que c'est un testeur

- Vérifier que l'adresse Gmail est dans **Paramètres** > **Gestion des licences**
- Le compte doit être connecté sur l'appareil Android

### Les achats fonctionnent en test mais pas en production

1. Vérifier que le produit est actif
2. Vérifier que l'app de production utilise le même `applicationId`
3. Vérifier la signature de l'app

---

## Récapitulatif des IDs

| Élément | Valeur |
|---------|--------|
| **Product ID** | `scanai_premium_lifetime` |
| **Prix** | 2,99 € |
| **Type** | Non-consommable (achat unique à vie) |

---

## Checklist finale avant mise en production

- [ ] Produit `scanai_premium_lifetime` créé et actif
- [ ] Prix défini pour tous les pays cibles
- [ ] Testeurs de licence configurés
- [ ] Tests d'achat réussis (achat + restauration)
- [ ] Tests sur plusieurs appareils
- [ ] AAB de production signé et uploadé
- [ ] Fiche Play Store complète (screenshots, description, etc.)

---

## Ressources utiles

- [Documentation officielle Google Play Billing](https://developer.android.com/google/play/billing)
- [Google Codelabs - Flutter IAP](https://codelabs.developers.google.com/codelabs/flutter-in-app-purchases)
- [Support Google Play Console](https://support.google.com/googleplay/android-developer)
- [Play Billing Lab (app de test)](https://play.google.com/store/apps/details?id=com.google.android.apps.playbillinglab)

---

*Document créé le 28 janvier 2026 pour Scanaï v1.0*
