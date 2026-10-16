# Synchronisation hors ligne

## Écritures locales

SQLite est la source de lecture hors ligne. Les changements de statut, notes et pièces jointes sont enregistrés avec une opération UUID stable dans `outbox`. La modification métier et l’ajout de l’opération sont transactionnels. Le fichier photo/signature reste dans le stockage privé avant tout envoi. Aucune opération n’est supprimée avant l’accusé du serveur.

## Déclencheurs et états

La synchronisation démarre à la connexion, au retour au premier plan, lors d’un changement de connectivité et sur demande depuis le tableau de bord. L’application vérifie d’abord le backend, puis dépile les opérations par date. Elle utilise un délai exponentiel plafonné à cinq tentatives, conserve l’erreur, distingue les échecs des conflits et garde une date de dernière réussite. Le tableau de bord expose le serveur, l’activité, les opérations en attente/échec/conflit et une action de reprise.

## Envoi, réception et déduplication

Les opérations sont transmises à `POST /api/sync/{operationId}` ou `POST /api/sync/{operationId}/attachment`. MySQL réserve l’identifiant unique de l’opération et applique statut ou note dans la même transaction JDBC ; un rejeu du même UUID ne répète pas la mutation. Les médias sont enregistrés avec métadonnées SQL et fichier dans `uploads/`. Le serveur expose `GET /api/sync/changes?since=...` avec un curseur basé sur `updated_at`. Les changements reçus sont appliqués localement dans une transaction SQLite.

## Résolution des conflits

Une modification locale en attente prévaut sur un changement téléchargé : le serveur ne peut pas l’écraser avant son accusé. Si le serveur rejette une transition par HTTP 409, l’outbox passe à `conflict`. L’utilisateur peut garder la modification locale en attente de décision, ou confirmer qu’il veut la remplacer par la version serveur. L’acceptation distante récupère d’abord un instantané complet ; si l’API est indisponible, les modifications locales ne sont pas supprimées.

## Limites et preuve

Le compte et les données seed sont des démonstrations. Le serveur crée désormais des jetons aléatoires temporaires et ne conserve que leur hash dans MySQL; les mots de passe du tableau `users` sont dérivés avec PBKDF2. Les scénarios de panne réseau, doublons simultanés, conflits, redémarrage et transfert de fichiers doivent encore réussir leurs tests de bout en bout contre MySQL. Consulter `suivi_exigences.md` pour le statut vérifié.
