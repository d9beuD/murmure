# ADR 0007 — Nettoyage TTT J5

Statut : implémenté, validation fournisseur réel en attente

## Décision

Après une transcription STT réussie, le nettoyage est optionnel. Responses API reçoit `instructions` pour le prompt et `input` pour le texte brut ; Chat Completions reçoit un message `system` puis un message `user`. Les requêtes demandent `store: false` et n'utilisent aucun état conversationnel.

`OpenAITextCleanupService` accepte les réponses Responses en agrégeant tous les contenus `output_text`, plutôt que de supposer que le premier élément de `output` est du texte. Pour Chat Completions, il accepte le contenu texte simple et les tableaux de parties texte.

La politique `useRawTranscript` conserve le texte STT si le nettoyage échoue. La politique `stop` expose l'erreur tout en gardant la transcription brute en mémoire pour une copie ultérieure. Dans les deux cas le fichier audio temporaire est supprimé.

Les logs indiquent l'envoi au fournisseur TTT, la taille de la réponse améliorée et les erreurs, sans écrire les prompts, clés ou contenus dans un stockage persistant.

## Validation réalisée

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

Un test avec un endpoint Responses et un endpoint Chat Completions réels reste à effectuer avec des clés de test et un texte de dictée non sensible.
