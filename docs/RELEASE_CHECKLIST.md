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
- [ ] Définir les six variables de signature et de notarisation ci-dessous,
      puis lancer `MURMURE_VERSION=0.1.0 ./Scripts/release.sh`.
- [ ] Vérifier le DMG final avec `spctl --assess --type open --verbose`.
- [ ] Publier le DMG, son fichier SHA-256, les notes de version et la licence
      MIT sur GitHub Releases.

## Workflow GitHub Release

Le workflow **Release** se lance manuellement depuis l’onglet *Actions*. Il
demande une version, puis crée le tag `v<version>`, construit un DMG signé et
notarisé, joint le DMG et son SHA-256 à la release, et publie les notes générées
par GitHub.

La signature et la notarisation sont obligatoires pour une release GitHub : le
workflow échoue explicitement si l’un des secrets requis manque.

Renseigner ces secrets du dépôt :

- `DEVELOPER_ID_CERTIFICATE_BASE64` : certificat Developer ID Application au
  format `.p12`, encodé en Base64 ;
- `DEVELOPER_ID_CERTIFICATE_PASSWORD` : mot de passe de ce `.p12` ;
- `BUILD_KEYCHAIN_PASSWORD` : mot de passe temporaire du Trousseau de CI ;
- `APP_STORE_CONNECT_KEY_BASE64` : clé Team API App Store Connect `.p8`,
  encodée en Base64 ;
- `APP_STORE_CONNECT_KEY_ID` et `APP_STORE_CONNECT_ISSUER_ID` : identifiants
  de cette clé.

Le script reconstruit la clé `.p8` dans un répertoire temporaire, appelle
directement `xcrun notarytool submit --key --key-id --issuer`, puis supprime les
fichiers temporaires et le Trousseau de CI. Il n’utilise ni Apple ID, ni mot de
passe spécifique, ni profil `notarytool`, ni `altool`.
