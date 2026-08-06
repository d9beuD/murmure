# ADR 0004 — Tranche verticale STT J3

Statut : implémenté, validation réelle du microphone et du fournisseur en attente

## Décision

La capture reste un WAV PCM mono 16 kHz, 16 bits. Après l'arrêt, `DictationCoordinator` crée une session identifiée, passe à l'état `transcribing`, puis délègue à `OpenAITranscriptionService`. Le service utilise `URLSession` éphémère et construit lui-même la requête `multipart/form-data`, sans SDK tiers.

Le contrat principal est `/audio/transcriptions` : champs `file`, `model`, `prompt` et langue optionnelle. Pour `gpt-transcribe`, la langue est envoyée en `languages[]` ; les modèles compatibles Whisper reçoivent le champ singulier `language`. Les réponses JSON contenant `text` et les corps texte bruts sont acceptés. Les corps de requête, réponses et clés ne sont jamais journalisés.

Chaque session supprime son WAV dans un `defer`, y compris en cas d'annulation, d'erreur HTTP ou d'échec de décodage. Une réponse arrivée après l'annulation est ignorée grâce à l'identifiant de session.

## Validation réalisée

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

La permission microphone, l'envoi vers un endpoint réel et l'insertion dans une application cible nécessitent un `.app` signé, un TCC macOS configuré et une clé de fournisseur de test.
