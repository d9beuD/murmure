# ADR 0008 — Livraison inter-applications J6

Statut : implémenté, validation manuelle des applications cibles en attente

## Décision

La livraison est déclenchée par le coordinateur après le STT et le TTT éventuel. Le mode `clipboard` écrit le texte dans `NSPasteboard`. Le mode `paste` demande l'autorisation Accessibilité, inspecte l'élément focalisé et tente de remplacer le texte sélectionné via `kAXSelectedTextAttribute`.

Les champs `AXSecureTextField` et `AXPasswordField` ne reçoivent jamais de frappe synthétique : le texte est seulement copié. Si l'autorisation manque, si l'élément n'est pas éditable ou si l'insertion AX échoue, Murmure conserve le résultat dans le presse-papiers et utilise `⌘V` uniquement lorsqu'un champ texte non sécurisé est identifié. Chaque résultat est journalisé sans inclure le texte.

La livraison ne persiste rien et ne remplace pas la transcription en mémoire. Une copie manuelle reste possible via le service de livraison pour les écrans futurs.

## Validation réalisée

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

La validation finale doit couvrir Notes, Safari, Terminal et un éditeur de code, avec et sans autorisation Accessibilité, ainsi qu'un champ mot de passe.
