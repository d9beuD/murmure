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

## Workflow GitHub Release

Le workflow **Release** se lance manuellement depuis l’onglet *Actions*. Il
demande une version, puis crée le tag `v<version>`, joint un DMG et son SHA-256
à la release, et publie les notes générées par GitHub.

Sans notarisation, le DMG est signé ad hoc et convient seulement aux essais :
Gatekeeper ne le considérera pas comme une distribution publique vérifiée.

Pour cocher **Notariser**, renseigner ces secrets du dépôt :

- `DEVELOPER_ID_CERTIFICATE_BASE64` : certificat Developer ID Application au
  format `.p12`, encodé en Base64 ;
- `DEVELOPER_ID_CERTIFICATE_PASSWORD` : mot de passe de ce `.p12` ;
- `BUILD_KEYCHAIN_PASSWORD` : mot de passe temporaire du Trousseau de CI ;
- `APPLE_API_KEY_BASE64` : clé App Store Connect `.p8`, encodée en Base64 ;
- `APPLE_API_KEY_ID` et `APPLE_ISSUER_ID` : identifiants de cette clé.
