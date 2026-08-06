# ADR 0002 — Fondation J1

Statut : implémenté partiellement, validation Xcode en attente

## Décision

La fondation J1 utilise Swift Package Manager avec deux cibles :

- `MurmureCore` : domaine, états, protocoles de services et `DictationCoordinator` ;
- `Murmure` : application SwiftUI, `MenuBarExtra`, `Settings` et adaptateurs macOS.

Cette organisation permet de compiler avec les Command Line Tools tout en gardant une frontière claire pour le futur projet Xcode. Le bundle identifier, les entitlements et le signing restent des paramètres de la cible Xcode à créer dès que Xcode.app sera disponible.

## Injection

`AppEnvironment` injecte `AudioRecording` et `TextDelivering` dans `DictationCoordinator`. Le modèle SwiftUI ne connaît donc pas les détails AVFoundation ou CoreGraphics.

## Métadonnées

`Configuration/Info.plist` contient les clés nécessaires à la présence menubar et à la demande microphone. Il servira de base à la cible Xcode.

## Dépendance raccourci

Le package reste épinglé à `KeyboardShortcuts` 1.10.0 pour compiler avec les Command Line Tools. Les versions récentes utilisent des plugins de macros SwiftUI indisponibles sans Xcode. Le passage à la version moderne est prévu lors de la création de la cible Xcode.

## Validation réalisée

```text
swift build                         ✅
swift build -Xswiftc -warnings-as-errors ✅
swift run Murmure                  ✅ démarrage graphique, arrêté manuellement
```

La validation des permissions, de l'icône Dock, des événements globaux et de l'insertion inter-applications reste manuelle sur une machine équipée d'Xcode et d'une session macOS graphique.

## Correctif post-J1 — installation différée des raccourcis

`HotkeyService` installe désormais ses handlers au prochain passage de la boucle principale. L'enregistrement Carbon effectué trop tôt pendant l'initialisation SwiftUI peut échouer silencieusement ; ce report garantit que le dispatcher d'événements macOS existe avant la restauration d'un raccourci déjà mémorisé.

## Conséquence

J1 est fonctionnellement prêt pour commencer J2, mais la validation de sortie du jalon reste conditionnée à l'installation d'Xcode.app et à la génération de la cible macOS signée.
