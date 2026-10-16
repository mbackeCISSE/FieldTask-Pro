# Rapport technique — FieldTask Pro

**Projet Flutter offline-first — état au 13 octobre 2026**

## Objectif et périmètre

FieldTask Pro est une application mobile en français pour les techniciens de terrain de TechFix. Elle permet de consulter et traiter les interventions, y compris sans réseau, puis de synchroniser les changements avec une API REST Spring Boot et une base MySQL. Le périmètre est le sujet de développement mobile et son prompt détaillé; le sujet UGB de BD répartie a été retiré comme demandé.

## Architecture

L’application applique les couches **Presentation** (pages et Cubits), **Domain** (entités, règles, contrats et cas d’usage) et **Data** (SQLite, REST et adaptateurs de plateforme). Le conteneur d’injection assemble les dépendances. La page Notifications a été ajustée pour passer par un Cubit et un cas d’usage.

## Fonctions

- Authentification par API, session sécurisée et compte de démonstration; mode démo locale hors ligne.
- Tableau de bord affecté au technicien connecté, filtres de statut, tri par priorité, recherche dynamique et état de connexion.
- Détail des interventions, progression, notes, photos et signature.
- Stockage SQLite et outbox durable pour l’usage hors ligne; synchronisation REST et gestion des conflits.
- Carte et position du technicien; les tuiles OpenStreetMap nécessitent Internet.
- Rappels locaux d’échéance, écran des rappels programmés et navigation vers l’intervention depuis la notification Android.

## Backend et vérifications

Le backend Spring Boot + MySQL est livré avec Docker Compose; phpMyAdmin est configuré sur le port local 8081. L’utilisateur a confirmé que MySQL et l’API démarrent correctement. Leur compilation/intégration n’a pas pu être reproduite dans cette session : Docker Engine était inaccessible et Maven n’avait pas le parent Spring Boot requis dans son cache hors ligne.

| Vérification | Résultat |
|---|---|
| Analyse Flutter (`dart analyze lib test`) | Réussie, aucune erreur |
| Tests Flutter (`flutter test --no-pub`) | Réussis, 20 tests |
| Run Android après les dernières modifications | À effectuer par l’utilisateur dans Android Studio |
| Notifications Android et intégration réelle API/MySQL | Scénarios manuels à vérifier sur émulateur/appareil et avec Docker |

## Limites et suite

La validation finale nécessite le run Android demandé à l’utilisateur, l’autorisation de notifications et l’essai du rappel depuis la barre Android. Il faut ensuite vérifier les scénarios en ligne/hors ligne avec Docker et la synchronisation. Le projet iOS n’est pas présent; iOS reste à faire seulement si cette plateforme est exigée.

La matrice détaillée figure dans [`suivi_exigences.md`](suivi_exigences.md).
