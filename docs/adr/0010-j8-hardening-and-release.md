# ADR 0010 — Durcissement et release J8

Statut : implémenté, validation Apple de la première release en attente

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
produit un DMG et un SHA-256, et peut soumettre l’archive à `notarytool` via une
Team API Key App Store Connect reconstruite temporairement.

## Validation finale restante

La compilation stricte et les tests sont validés avec Xcode. La première
signature et notarisation réelles restent à effectuer avec le certificat
Developer ID et la Team API Key App Store Connect du mainteneur ; elles sont
décrites dans la checklist de release.
