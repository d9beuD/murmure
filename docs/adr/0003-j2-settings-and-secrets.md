# ADR 0003 — Réglages et secrets J2

Statut : implémenté, validation interactive Xcode en attente

## Décision

Les configurations STT et TTT sont des valeurs `Codable` dans `MurmureCore`. `AppPreferences` porte un numéro de schéma (actuellement 3, depuis l'ajout du mode de déclenchement) et est encodé en une seule valeur JSON dans `UserDefaults`. Une version inconnue est ignorée et revient aux valeurs par défaut ; les migrations futures auront un point d'entrée unique.

Les clés API ne font pas partie de `AppPreferences`. `KeychainStore` les stocke comme un mot de passe générique unique sous le service `com.d9beuD.Murmure`; son contenu JSON associe le UUID de chaque connexion à sa clé. Une clé vide est retirée de ce contenu. Les erreurs du Trousseau sont réduites à un statut système et ne révèlent jamais la valeur.

Au démarrage, les secrets des profils STT et TTT sont lus dans une entrée
Trousseau unique, encodée en JSON, afin de ne solliciter le Trousseau qu'une
seule fois. Les profils absents sont traités comme des clés vides. Les entrées
des versions précédentes, qui stockaient une clé par UUID de profil, sont
relues une dernière fois puis migrées automatiquement vers cette entrée unique.

La vue Settings expose les paramètres STT et TTT, le format Responses ou Chat Completions, le prompt de nettoyage, la politique de repli vers le texte brut, le mode de livraison et les informations d'authentification. Les modifications sont sauvegardées automatiquement ; aucun appel réseau n'est effectué à ce stade.

## Validation réalisée

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

La vérification réelle du Trousseau, de la fenêtre Settings et de l'absence de secret dans le bundle doit être faite avec une cible Xcode signée sur macOS 26.
