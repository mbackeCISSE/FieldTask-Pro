# Vérification des exigences — FieldTask Pro

Mise à jour : 13 octobre 2026. Le périmètre suivi est le projet mobile FieldTask Pro et le sujet de développement mobile. Le document **UGB 2026** de BD répartie a été explicitement retiré du périmètre.

## Matrice d’état

| Exigence | État vérifié | Preuve / reste à faire |
|---|---|---|
| Architecture en trois couches | Implémentée | Présentation, Domaine et Data sont séparées. La page de notifications utilise maintenant un Cubit et un cas d’usage au lieu d’accéder au conteneur d’injection. `dart analyze lib test` réussit. |
| Authentification | Implémentée | API Spring Boot, compte démo dans MySQL, dérivé PBKDF2 du mot de passe, jetons de session aléatoires hachés et expiration, session conservée côté Flutter dans le stockage sécurisé, déconnexion/révocation. Mode démo locale indiqué séparément. |
| Tableau de bord | Implémenté | Liste limitée au technicien connecté, recherche dynamique, filtres de statut, tri par priorité et état serveur en ligne/hors ligne. |
| Interventions | Implémenté | Détail, transitions de statut, notes, capture et conservation locale des photos, signature et pièces jointes. |
| Carte et géolocalisation | Implémenté | Position via Geolocator et fond cartographique avec attribution. Les tuiles nécessitent Internet. |
| Fonctionnement hors ligne | Implémenté | SQLite sert de cache local; les opérations sont conservées dans une outbox jusqu’à synchronisation. |
| Synchronisation et conflits | Présents dans le code | API REST, affectation par technicien, déduplication des opérations, reprise avec délai progressif et choix de résolution des conflits. L’intégration complète Flutter–API–MySQL doit être rejouée sur l’installation locale. |
| Notifications | Implémentées dans le code | Rappels locaux avant les échéances, permission Android, page in-app des rappels programmés et ouverture du détail quand on touche la notification système. Tests de livraison et d’ouverture à faire sur l’émulateur/téléphone. La page affiche les rappels à venir, pas un historique permanent des notifications déjà livrées. |
| Backend Spring Boot + MySQL | Code présent; exécution signalée par l’utilisateur | L’utilisateur a confirmé que MySQL et l’API démarrent correctement. Dans cette session, Docker Engine est inaccessible et Maven ne peut pas récupérer le parent Spring Boot 3.4.4 : la compilation backend n’a donc pas été certifiée ici. |
| Tests et analyse Flutter | Réussis | `dart analyze lib test` : aucune erreur. `flutter test --no-pub` : 20 tests passent. |
| Build Android et vérification sur appareil | À refaire après les dernières modifications | L’utilisateur avait signalé un run réussi avant les changements récents. Le code actuel n’a pas été lancé sur l’émulateur, conformément à sa demande de faire lui-même le run. |
| iOS | Non livré | Le projet actuel est préparé pour Android; aucun projet iOS n’est fourni. À traiter uniquement si la cible iOS est demandée par le sujet. |
| Rapport PDF | Livré et actualisé | `output/pdf/rapport_technique.pdf`, synthèse technique à jour. |

## Actions manuelles restantes

1. Dans Android Studio, lancer l’application sur l’émulateur et accepter l’autorisation de notifications.
2. Ouvrir un rappel depuis la page Notifications et, après qu’un rappel arrive, depuis la barre Android; vérifier l’ouverture de la bonne fiche, application ouverte et relancée.
3. Avec Docker Desktop démarré, vérifier `docker compose up --build`, puis connexion, modification en ligne, modification hors ligne et synchronisation; vérifier l’affectation à l’utilisateur connecté.
4. Si une livraison iOS est imposée par le sujet, demander/ajouter cette plateforme; elle n’existe pas dans le projet actuel.

Le run de l’application Flutter est laissé à l’utilisateur. Les tests unitaires ne remplacent pas ces validations sur appareil et avec le backend réel.
