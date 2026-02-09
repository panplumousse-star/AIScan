● Toutes les reviews sont terminées. Je vais maintenant arrêter les agents et te fournir le rapport consolidé.                                                                                                       
                                                                                                                                                                                                                     
✻ Crunched for 4m 56s                                                                                                                                                                                                
                                                                                                                                                                                                                     
● ---                                                                                                                                                                                                                  Rapport de Code Review Consolidé -- AIscan                                                                                                                                                                         
                                                                                                                                                                                                                       Application : Scanner de documents Flutter, privacy-first, AES-256
  4 agents ont reviewé ~120 fichiers en parallèle.                                                                                                                                                                                                                                                                                                                                                                                        
  ---                                                                                                                                                                                                                
  Vue d'ensemble                                                                                                                                                                                                       ┌────────────────────────┬──────────┬───────┬───────┬───────┐                                                                                                                                                        │        Domaine         │ CRITICAL │ MAJOR │ MINOR │ Total │                                                                                                                                                        ├────────────────────────┼──────────┼───────┼───────┼───────┤                                                                                                                                                        │ Sécurité               │ 0        │ 2     │ 5     │ 7     │                                                                                                                                                        ├────────────────────────┼──────────┼───────┼───────┼───────┤                                                                                                                                                      
  │ Architecture & Qualité │ 0        │ 9     │ 8     │ 17    │
  ├────────────────────────┼──────────┼───────┼───────┼───────┤
  │ UI/UX & Performance    │ 3        │ 9     │ 6     │ 18    │
  ├────────────────────────┼──────────┼───────┼───────┼───────┤
  │ Data Layer & Services  │ 2        │ 13    │ 14    │ 29    │
  ├────────────────────────┼──────────┼───────┼───────┼───────┤
  │ TOTAL                  │ 5        │ 33    │ 33    │ 71    │
  └────────────────────────┴──────────┴───────┴───────┴───────┘
  ---
  Les 5 CRITIQUES a traiter en priorite

  1. Migration DB sans index ni FTS

  database_migration_helper.dart:724 -- Apres migration, la DB n'a ni index ni tables FTS. Les recherches tombent en fallback LIKE (lent) et les requetes courantes ne sont pas indexees.
  Fix : Extraire la creation du schema (index + FTS) dans des methodes partagees entre _onCreate et les migrations.

  2. BentoBackground : 4 blobs animes + BackdropFilter plein ecran

  bento_background.dart:14-83 -- 4 AnimationController permanents + BackdropFilter(sigmaX: 50, sigmaY: 50) rerasterise chaque frame. Charge GPU constante sur chaque ecran.
  Fix : Image de fond statique pre-rendue, ou desactiver sur appareils low-end via DevicePerformance.

  3. OptimizedListView fuit ScrollController et listeners

  optimized_list_view.dart:97-106 -- Cree un ScrollController + addListener() dans build() d'un ConsumerWidget (stateless). Fuite memoire a chaque rebuild.
  Fix : Convertir en ConsumerStatefulWidget avec init/dispose propres.

  4. Calcul de contraste WCAG mathematiquement faux

  accessibility_config.dart:406-436 -- Implementation maison de exp()/log() via series de Taylor au lieu de dart:math. Les ratios de contraste sont potentiellement incorrects.
  Fix : Remplacer par math.pow(), math.exp(), math.log() (fix d'une ligne).

  ---
  Les MAJEURS les plus impactants (par priorite)

  Securite
  ┌─────┬─────────────────────────────────────────────────────────┬────────────────────────────────────────────────┐
  │  #  │                          Issue                          │                    Fichier                     │
  ├─────┼─────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
  │ S1  │ Meme cle pour DB et fichiers (pas de separation)        │ encryption_service.dart / database_helper.dart │
  ├─────┼─────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
  │ S2  │ Fallback legacy decryption sans HMAC (bypass integrity) │ encryption_service.dart:182-226                │
  └─────┴─────────────────────────────────────────────────────────┴────────────────────────────────────────────────┘
  Performance & Memoire
  ┌─────┬─────────────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────┐
  │  #  │                                Issue                                │                                    Fichier                                    │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P1  │ Pattern repete x3 : toutes les images chargees en memoire d'un coup │ pdf_generator.dart, document_share_service.dart, document_export_service.dart │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P2  │ getAllDocuments() appele juste pour .length (x3 endroits)           │ bento_home_screen.dart, scan_usage_service.dart                               │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P3  │ N+1 queries dans la recherche                                       │ search_service.dart                                                           │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P4  │ Home screen : 10+ AnimationControllers simultanes                   │ bento_home_screen.dart                                                        │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P5  │ ThemeData reconstruit a chaque acces (pas cache)                    │ app_theme.dart:296-297                                                        │
  ├─────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────┤
  │ P6  │ hashCode parcourt TOUS les bytes d'une image (x2)                   │ image_processor.dart, image_exporter.dart                                     │
  └─────┴─────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────┘
  Architecture
  ┌─────┬──────────────────────────────────────────────────┬───────────────────────────────────┐
  │  #  │                      Issue                       │              Fichier              │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A1  │ DocumentRepository monolithique (1683 lignes)    │ document_repository.dart          │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A2  │ StateNotifier deprecated (devrait etre Notifier) │ Tous les notifiers                │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A3  │ Anti-pattern : Ref stocke comme champ de classe  │ scanner_screen_notifier.dart:47   │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A4  │ == omet imageBytes → widgets pas rebuilds        │ document_detail_notifier.dart:111 │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A5  │ Fail-open sur erreur du lock screen              │ app.dart:241-243                  │
  ├─────┼──────────────────────────────────────────────────┼───────────────────────────────────┤
  │ A6  │ aes_encrypt_file: ^0.0.4 pre-release pour crypto │ pubspec.yaml:44                   │
  └─────┴──────────────────────────────────────────────────┴───────────────────────────────────┘
  UI/UX
  ┌─────┬──────────────────────────────────────────────────────────┬──────────────────────────────┐
  │  #  │                          Issue                           │           Fichier            │
  ├─────┼──────────────────────────────────────────────────────────┼──────────────────────────────┤
  │ U1  │ Aucune animation ne respecte reduceMotion                │ Tous les widgets animes      │
  ├─────┼──────────────────────────────────────────────────────────┼──────────────────────────────┤
  │ U2  │ Couleurs hardcodees au lieu du theme (dark mode casse)   │ bento_home_screen.dart, etc. │
  ├─────┼──────────────────────────────────────────────────────────┼──────────────────────────────┤
  │ U3  │ Image reseau externe pour texture de fond                │ bento_background.dart:73-79  │
  ├─────┼──────────────────────────────────────────────────────────┼──────────────────────────────┤
  │ U4  │ deleteFolderRecursive sans transaction DB                │ folder_service.dart          │
  ├─────┼──────────────────────────────────────────────────────────┼──────────────────────────────┤
  │ U5  │ Escaping FTS inconsistant entre Search et DatabaseHelper │ search_service.dart          │
  └─────┴──────────────────────────────────────────────────────────┴──────────────────────────────┘
  ---
  Points positifs

  L'application a de vraies qualites qu'il faut souligner :

  - Chiffrement bien implemente : AES-256-CBC/CTR, IV frais par operation, HMAC-SHA256 (Encrypt-then-MAC), comparaison constante
  - Architecture feature-based claire et coherente
  - Hierarchie d'exceptions personnalisee et consistante
  - Protection path traversal (SEC-10) et injection FTS (SEC-09)
  - Deletion securisee avec zero-overwrite 3 passes
  - Gestion du cache de thumbnails avec lifecycle-aware cleanup
  - Skeleton loading fidele pour la UX percue
  - i18n en 7 langues avec fallbacks
  - allowBackup="false" sur Android
  - Pas de secrets hardcodes dans le code

  ---
  Plan d'action recommande

  Phase 1 -- Critiques (a faire immediatement) :
  1. Fix calcul de contraste (dart:math)
  2. Fix fuite ScrollController
  3. Ajouter index/FTS dans les migrations
  4. Optimiser BentoBackground (ou remplacer par image statique)
  5. Planifier verification IAP serveur

  Phase 2 -- Performance (semaine suivante) :
  1. Ajouter getDocumentCount() SQL au lieu de getAllDocuments().length
  2. Streaming des pages pour PDF/export (1 page a la fois)
  3. Cacher ThemeData en static final
  4. Batch query pour resultats de recherche

  Phase 3 -- Architecture (sprint suivant) :
  1. Migrer StateNotifier → Notifier
  2. Splitter DocumentRepository
  3. Respecter reduceMotion dans les animations
  4. Supprimer le code mort (widgets inutilises, debug premium toggle)