# ADR 0005 — Coordinateur et raccourcis J4

Statut : implémenté, validation interactive des raccourcis en attente

## Décision

Une session reçoit un UUID dès la demande de permission microphone. Toutes les tâches — permission, enregistrement et transcription — vérifient cet identifiant avant de modifier l'état. Une annulation invalide donc immédiatement les résultats tardifs.

Le mode push-to-talk arrête la capture au relâchement et annule une demande de permission si la touche est relâchée trop tôt. Le mode bascule ne réagit qu'au `keyDown` : le premier appui démarre, le second arrête. Les événements répétés et les appuis rapprochés sont filtrés par un debounce de 150 ms.

Un enregistrement de moins de 250 ms est supprimé sans requête réseau. Un watchdog de dix minutes déclenche l'arrêt normal si le système ne fournit jamais `keyUp`. Le mode ne peut être modifié que lorsque le coordinateur est au repos et il est maintenant persisté dans le schéma de préférences 3.

## Validation réalisée

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

La matrice de scénarios clavier (appui court, maintien, bascule, répétition, annulation et perte de `keyUp`) doit être exécutée dans une session macOS graphique avec le bundle `Murmure.app`.
