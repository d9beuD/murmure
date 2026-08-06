# Murmure

Murmure est une application macOS de dictée vocale destinée à vivre dans la barre des menus. Elle sera basée sur des endpoints STT et TTT compatibles avec le format OpenAI.

## État du projet

Le jalon J5 fournit une fondation Swift 6 ciblant macOS 26, avec :

- cible exécutable `Murmure` ;
- bibliothèque de domaine `MurmureCore` ;
- interface `MenuBarExtra` et `Settings` ;
- coordination injectable ;
- capture audio et livraison presse-papiers héritées du spike J0 ;
- raccourcis globaux push-to-talk et toggle.
- réglages STT et TTT éditables depuis la fenêtre SwiftUI Settings ;
- persistance JSON versionnée dans `UserDefaults` pour les réglages non sensibles ;
- clés API conservées uniquement dans le Trousseau macOS ;
- validation locale des endpoints et modèles ;
- demande d’autorisation microphone ;
- enregistrement WAV puis envoi multipart vers `/audio/transcriptions` ;
- parsing des réponses JSON et texte brut, avec erreurs HTTP explicites ;
- suppression du fichier temporaire après chaque transcription.
- machine à états protégée contre les sessions obsolètes ;
- modes push-to-talk et bascule avec debounce ;
- durée minimale de 250 ms et watchdog de 10 minutes ;
- annulation sûre pendant l’autorisation microphone ou la transcription ;
- fenêtre de logs en direct, uniquement en mémoire ;
- nettoyage optionnel par Responses API ou Chat Completions ;
- fallback vers la transcription brute en cas d’échec TTT.

La livraison automatique vers le presse-papiers ou l’application active reste prévue pour J6.

## Développement local

Avec Swift 6.3 et un SDK macOS 26 :

```shell
swift build
./Scripts/run-app.sh
```

Le script construit un vrai bundle `Murmure.app`, applique `Info.plist`, le signe localement puis le lance avec LaunchServices. Il faut utiliser ce script pour tester l'interface, les fenêtres, les raccourcis et les permissions. `swift run Murmure` ne produit qu'un exécutable brut sans métadonnées d'application macOS et n'est adapté qu'aux diagnostics élémentaires.

Le handler du raccourci global est installé après le démarrage de la boucle d'événements macOS, afin que les raccourcis mémorisés restent actifs après une relance.

## Licence

Murmure est distribué sous licence MIT. Voir [LICENSE](LICENSE).
