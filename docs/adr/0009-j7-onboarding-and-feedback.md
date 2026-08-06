# ADR 0009 — Onboarding et finition J7

Statut : implémenté, validation interactive macOS en attente

## Décision

Un nouvel utilisateur reçoit un assistant SwiftUI en cinq étapes : explication
des flux de données, configuration STT, test explicite, raccourci global, puis
sortie et préférences générales. Les installations existantes sont considérées
comme déjà configurées lors de la migration du schéma 3 vers 4 afin de ne pas
interrompre leur usage.

Le test de connexion n’est jamais implicite : il ouvre le microphone, demande à
l’utilisateur d’enregistrer une phrase, et réutilise le transport STT normal.
Le fichier temporaire est supprimé à la fin du test et seul le nombre de
caractères est affiché ou journalisé.

Les permissions Microphone et Accessibilité sont exposées dans les réglages.
L’Accessibilité n’est demandée que par action explicite et reste facultative :
le presse-papiers demeure le repli sûr. Le lancement à la connexion emploie
`SMAppService.mainApp`; un échec est montré dans les réglages sans modifier la
préférence persistée.

Les sons de début et de fin sont activables et n’incluent aucune donnée de la
dictée. L’interface et la documentation utilisateur sont en français ; les
événements de logs existants restent en anglais afin de conserver le format
demandé pour le diagnostic.

## Validation réalisée

```text
swift build -Xswiftc -warnings-as-errors
```

La validation manuelle restante couvre l’ouverture automatique du guide sur une
installation propre, l’inscription au lancement à la connexion depuis un bundle
signé, les dialogues système de permission, les sons et un test STT réel.
