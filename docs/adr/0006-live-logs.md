# ADR 0006 — Logs en direct

Statut : implémenté

## Décision

`AppLogStore` est un objet observable en mémoire, injecté dans `AppEnvironment`. Il ne s'écrit ni dans `UserDefaults`, ni dans un fichier, ni dans le Trousseau. Les lignes ne contiennent jamais de clé API, de corps de requête ou de texte transcrit.

La fenêtre SwiftUI `LogsView` est accessible depuis la menubar. Elle affiche les entrées en police monospace blanche sur fond noir, avec date locale au format milliseconde et défilement automatique vers la dernière entrée. Un bouton permet d'effacer le contenu courant.

Le coordinateur produit actuellement les événements d'enregistrement et de STT : démarrage, fin, taille envoyée, puis nombre de caractères reçus. Les événements d'enrichissement TTT seront ajoutés lorsque `CleanupService` sera implémenté au jalon J5.
