# Murmure

Murmure est une application macOS de dictée vocale destinée à vivre dans la barre des menus. Elle sera basée sur des endpoints STT et TTT compatibles avec le format OpenAI.

## État du projet

Le jalon J8 fournit une application Swift 6 ciblant macOS 26, avec :

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
- fallback vers la transcription brute en cas d’échec TTT ;
- livraison automatique dans le presse-papiers ou le champ actif ;
- insertion Accessibility sécurisée avec repli contrôlé.
- assistant de premier lancement entièrement en français ;
- test de connexion STT explicite avec un court enregistrement ;
- statut et demandes des permissions Microphone et Accessibilité ;
- lancement optionnel à l’ouverture de session et feedbacks sonores ;
- aide accessible depuis la barre des menus.
- transport éphémère qui refuse les redirections inter-origines ;
- logs d’erreur expurgés des réponses des fournisseurs ;
- tests de domaine et CI avec avertissements traités comme erreurs ;
- script de préparation d’une archive signée, notarisable et accompagnée d’un SHA-256.

## Première configuration

Au premier lancement, Murmure ouvre un guide qui permet de configurer un
fournisseur STT, de choisir un raccourci global, de tester la connexion et de
choisir le mode de sortie. Tous ces réglages restent modifiables depuis
**Réglages** dans la barre des menus.

Le test STT demande le microphone, enregistre une courte phrase, puis envoie
le fichier audio au fournisseur configuré. Il n’est jamais effectué en arrière-plan.

Le mode **Insérer automatiquement** demande l’autorisation Accessibilité. En
son absence — et pour les champs sécurisés — Murmure copie toujours le résultat
dans le presse-papiers à la place.

## Confidentialité

- Les clés API sont conservées dans le Trousseau macOS, jamais dans
  `UserDefaults` ni dans les logs.
- L’audio est créé dans le répertoire temporaire de macOS puis supprimé après
  chaque transcription, réussite, erreur ou annulation.
- Murmure n’exploite aucun compte ni serveur propre : l’audio et, si activé, la
  transcription sont envoyés seulement aux endpoints STT et TTT choisis.
- La fenêtre Logs ne conserve ses événements qu’en mémoire et n’affiche ni
  secret, ni audio, ni transcription, ni prompt.

## Développement local

Avec Swift 6.3 et un SDK macOS 26 :

```shell
swift build
./Scripts/run-app.sh
```

Le script construit un vrai bundle `Murmure.app`, applique `Info.plist`, le signe localement puis le lance avec LaunchServices. Il faut utiliser ce script pour tester l'interface, les fenêtres, les raccourcis et les permissions. `swift run Murmure` ne produit qu'un exécutable brut sans métadonnées d'application macOS et n'est adapté qu'aux diagnostics élémentaires.

Le handler du raccourci global est installé après le démarrage de la boucle d'événements macOS, afin que les raccourcis mémorisés restent actifs après une relance.

Les tests demandent une installation complète de Xcode (les Command Line Tools
ne fournissent pas XCTest) :

```shell
swift test -Xswiftc -warnings-as-errors
```

## Démarrage à la connexion

L’option est disponible dans **Réglages > Général**. macOS peut demander une
autorisation ou exiger que l’application soit installée comme un bundle signé ;
le script de développement n’est pas le mode de distribution final.

## Préparer une release

Sur une machine équipée d’Xcode et d’une identité Developer ID, le script
`Scripts/release.sh` produit un ZIP et son SHA-256. Le workflow GitHub
**Release** peut être lancé manuellement pour produire un DMG, l’attacher à une
nouvelle release et, si les secrets sont configurés, le signer puis le
notariser. La procédure détaillée est dans [la checklist de release](docs/RELEASE_CHECKLIST.md).

## Licence

Murmure est distribué sous licence MIT. Voir [LICENSE](LICENSE).
Les notices des dépendances sont disponibles dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
