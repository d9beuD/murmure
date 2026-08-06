# ADR 0010 — Durcissement et release J8

Statut : implémenté partiellement, signature et validation système bloquées par Xcode

## Décision

Les transports réseau utilisent une session éphémère et bloquent toute
redirection qui change de schéma, hôte ou port. L’exception ATS se limite au
réseau local afin de conserver les endpoints HTTP de boucle locale, sans
autoriser HTTP pour Internet.

Les logs n’écrivent plus `localizedDescription` pour une erreur inconnue. Les
services STT et TTT fournissent un message de diagnostic expurgé, éventuellement
avec un code HTTP, tandis que le détail renvoyé par le fournisseur reste visible
uniquement dans l’interface d’erreur active.

Une cible de tests couvre les migrations de préférences, la normalisation des
endpoints, la protection des logs et un pipeline de dictée injecté. La CI
construit avec les avertissements en erreurs, exécute ces tests et refuse les
formats de secrets, signatures et enregistrements audio connus.

Le script `Scripts/release.sh` construit un bundle Release, applique Hardened
Runtime, signe avec une identité Developer ID fournie par l’environnement,
produit un ZIP et un SHA-256, et peut soumettre l’archive à `notarytool` via un
profil Keychain existant.

## Limite actuelle

Cette machine n’a que les Command Line Tools : `xcodebuild`, `XCTest` et la
signature Developer ID ne sont pas disponibles. La compilation applicative est
validée localement ; l’exécution des tests, la signature et la notarisation sont
documentées dans la checklist de release et doivent être réalisées sur une
installation Xcode avec les identifiants Apple du mainteneur.
