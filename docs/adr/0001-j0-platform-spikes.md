# ADR 0001 — Résultats des spikes J0

Statut : en cours
Date : 5 août 2026

## Contexte

J0 doit valider les capacités système qui peuvent remettre en cause l'architecture de Murmure : application uniquement dans la barre des menus, événements globaux key-down/key-up, capture WAV, presse-papiers et collage automatique.

## Implémentation de spike

Le dépôt contient un Swift Package exécutable nommé `MurmureSpike` avec :

- `MenuBarExtra` et scène `Settings` SwiftUI ;
- deux modes de déclenchement ;
- dépendance MIT `KeyboardShortcuts` ;
- capture WAV PCM 16 kHz mono 16 bits via `AVAudioRecorder` ;
- test presse-papiers ;
- test d'insertion via événement `Commande-V` ;
- suppression explicite de la dernière capture.

Le spike utilise `AVAudioRecorder` pour isoler rapidement la validation du format et des permissions. La version définitive pourra remplacer cette implémentation par `AVAudioEngine` sans modifier le coordinateur.

Le manifeste J0 épingle provisoirement `KeyboardShortcuts` 1.10.0 : les versions 2.x/3.x utilisent des macros SwiftUI dont les plugins ne sont pas fournis par les Command Line Tools seuls. J1 devra repasser à la version moderne validée par Xcode, avec `Package.resolved` mis à jour.

## Pré-requis de validation manuelle

L'environnement actuel fournit Swift 6.3.3 et le SDK macOS 26, mais pas Xcode.app. La compilation Swift Package peut donc être exécutée avec `swift build`; la validation interactive doit être faite avec une application macOS lancée depuis Xcode ou depuis un bundle `.app`.

À valider sur macOS 26 :

1. L'icône reste uniquement dans la barre des menus.
2. Le raccourci reçoit bien `keyDown` et `keyUp` hors focus de Murmure.
3. Le microphone demande et conserve la permission attendue.
4. Le fichier produit est bien WAV PCM 16 kHz mono 16 bits.
5. Le presse-papiers conserve le texte UTF-8.
6. Le collage fonctionne dans Notes, TextEdit, Terminal et un éditeur de code.
7. L'absence d'autorisation Accessibilité n'empêche pas le mode presse-papiers.
8. L'App Sandbox est testée avec les deux modes de livraison.

## Décision provisoire

La décision App Sandbox reste ouverte jusqu'à la validation du point 8. La livraison directe, Hardened Runtime et repli presse-papiers restent la stratégie de secours si l'insertion inter-applications complète n'est pas compatible avec le sandbox.

## Commandes

```shell
swift build
swift run MurmureSpike
```

Les commandes `swift run` nécessitent un contexte macOS graphique pour afficher la barre des menus ; elles ne sont pas adaptées à un runner CI sans session utilisateur.
