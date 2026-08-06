# Checklist de release 0.1.0

## Avant la signature

- [ ] `swift build -Xswiftc -warnings-as-errors`
- [ ] `swift test -Xswiftc -warnings-as-errors`
- [ ] Vérifier qu’aucun secret, fichier audio ou log n’est versionné.
- [ ] Vérifier les logs avec un endpoint qui retourne un message d’erreur
      contenant du texte utilisateur : le texte ne doit pas apparaître.
- [ ] Tester Microphone refusé puis autorisé.
- [ ] Tester Accessibilité refusée puis autorisée.
- [ ] Tester Notes, TextEdit, Safari, Mail, Terminal, Xcode et un champ mot de
      passe, en presse-papiers et insertion automatique.
- [ ] Tester un endpoint HTTPS distant, un endpoint HTTP loopback, et une panne
      réseau pendant STT puis TTT.

## Signature et notarisation

- [ ] Installer Xcode stable compatible macOS 26.
- [ ] Configurer une identité `Developer ID Application` dans le Trousseau.
- [ ] Définir `MURMURE_SIGNING_IDENTITY` puis lancer `./Scripts/release.sh`.
- [ ] Configurer un profil Keychain `notarytool`, définir
      `MURMURE_NOTARY_PROFILE`, puis relancer le script.
- [ ] Vérifier l’archive finale avec `spctl --assess --type execute --verbose`.
- [ ] Publier le ZIP, son fichier SHA-256, les notes de version et la licence
      MIT sur GitHub Releases.
