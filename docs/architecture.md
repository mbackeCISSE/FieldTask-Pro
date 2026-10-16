# Architecture FieldTask Pro

## Règle non négociable

Chaque feature Flutter est organisée en trois couches :

- **Presentation** : pages, widgets et Cubit/BLoC. Elle consomme les contrats du domaine, jamais les adaptateurs concrets.
- **Domain** : entités, règles métier, contrats des repositories et ports de services. Il ne dépend ni de Flutter, ni de SQLite, de Dio ou d’un plugin.
- **Data** : implémentations concrètes SQLite/REST, stockage sécurisé, caméra, géolocalisation et notifications. Les dépendances externes restent ici.

`lib/main.dart` lance l’application et le conteneur de dépendances. `lib/app/injection_container.dart` est le seul endroit qui assemble les implémentations concrètes. Les pages ne doivent importer ni `data/`, ni `sqflite`, `dio`, `GetIt`, `path_provider` ou les plugins d’accès aux données.

## Organisation

```text
lib/
  app/                         Composition et routes
  features/
    auth/{data,domain,presentation}
    interventions/{data,domain,presentation}
    map/{data,domain,presentation}
    notifications/{data,domain,presentation}
    synchronization/{data,domain}
```

## Flux

1. Une page demande une action à son Cubit.
2. Le Cubit applique un cas d’usage ou appelle un contrat Domain.
3. L’adaptateur Data exécute l’opération locale ou distante et renvoie des entités Domain.
4. Le Cubit publie un état que la page affiche.

SQLite est la source de vérité hors ligne. Une modification métier écrit l’intervention et son UUID d’outbox dans une transaction. Les pièces jointes sont stockées dans le répertoire privé de l’application. La session serveur et le profil sont conservés via `flutter_secure_storage`. Le mode démo local est explicite et ne tente aucune synchronisation serveur.

## Backend

Le backend est une application Spring Boot 3 avec Spring JDBC et MySQL. Les tables d’interventions, opérations de synchronisation et pièces jointes sont créées par `schema.sql`, avec quatre interventions de démonstration. L’URL est configurable par `DB_URL`, `DB_USER` et `DB_PASSWORD`. Le jeton fixe est réservé à la démonstration scolaire ; il ne constitue pas une authentification de production.

## Vérification

Les tests cubit/domaine sont présents. Le succès de l’analyse Dart, des tests, du build Android et des scénarios d’intégration ne sera affirmé que si leurs commandes se terminent avec un code de sortie nul. L’état courant est tenu dans `suivi_exigences.md`.
