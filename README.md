# Murmure

Murmure est une application macOS de dictée vocale destinée à vivre dans la barre des menus. Elle sera basée sur des endpoints STT et TTT compatibles avec le format OpenAI.

## État du projet

Le jalon J1 fournit une fondation Swift 6 ciblant macOS 26 :

- cible exécutable `Murmure` ;
- bibliothèque de domaine `MurmureCore` ;
- interface `MenuBarExtra` et `Settings` ;
- coordination injectable ;
- capture audio et livraison presse-papiers héritées du spike J0 ;
- raccourcis globaux push-to-talk et toggle.

Le projet est encore en phase de fondation. Les appels STT/TTT ne sont pas implémentés.

## Développement local

Avec Swift 6.3 et un SDK macOS 26 :

```shell
swift build
swift run Murmure
```

L'exécution graphique et les permissions microphone/Accessibilité doivent être validées dans une session macOS avec Xcode ou un bundle `.app` correctement configuré.

## Licence

Murmure est distribué sous licence MIT. Voir [LICENSE](LICENSE).
