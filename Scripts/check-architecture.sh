#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repository_root"

forbidden_core_imports='^(import (SwiftUI|Observation|AppKit|AVFoundation|Security|ApplicationServices|CoreGraphics|ServiceManagement|KeyboardShortcuts|Sparkle))$'
if rg -n "$forbidden_core_imports" Sources/MurmureCore; then
    echo "MurmureCore must not import UI, platform, or technical frameworks." >&2
    exit 1
fi

if rg -n '(@Observable|ObservableObject|@Published)' Sources/MurmureCore; then
    echo "MurmureCore application services must publish snapshots, not observable UI state." >&2
    exit 1
fi

adapter_owned_ports='protocol (PermissionProviding|HotkeyHandling|LaunchAtLoginControlling|FeedbackPlaying)'
if rg -n "$adapter_owned_ports" Sources/Murmure/Adapters; then
    echo "System-facing ports must live in MurmureCore/Application/Ports." >&2
    exit 1
fi

adapter_construction='\b(AudioRecorder|SystemPermissionProvider|AppLogStore|SafeNetworkSession|OpenAITranscriptionService|OpenAITextCleanupService|TextDelivery|KeychainStore|HotkeyService|LaunchAtLoginService|SoundFeedback|ListeningIndicatorController)\s*\('
violations="$(rg -l "$adapter_construction" Sources/Murmure --glob '*.swift' | grep -v '^Sources/Murmure/App/CompositionRoot.swift$' || true)"
if [[ -n "$violations" ]]; then
    echo "Concrete adapters may only be constructed in App/CompositionRoot.swift:" >&2
    printf '%s\n' "$violations" >&2
    exit 1
fi

echo "Architecture boundaries verified."
