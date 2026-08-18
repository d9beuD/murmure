#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repository_root"

core_import_violations="$(
    rg -n '^import ' Sources/EntrevoixCore --glob '*.swift' \
        | rg -v ':import (Foundation|_Concurrency)$' \
        || true
)"
if [[ -n "$core_import_violations" ]]; then
    echo "EntrevoixCore may only import Foundation or _Concurrency:" >&2
    printf '%s\n' "$core_import_violations" >&2
    exit 1
fi

if rg -n '(@Observable|ObservableObject|@Published)' Sources/EntrevoixCore; then
    echo "EntrevoixCore application services must publish snapshots, not observable UI state." >&2
    exit 1
fi

adapter_owned_ports='protocol (PermissionProviding|HotkeyHandling|LaunchAtLoginControlling|FeedbackPlaying)'
if rg -n "$adapter_owned_ports" Sources/Entrevoix/Adapters; then
    echo "System-facing ports must live in EntrevoixCore/Application/Ports." >&2
    exit 1
fi

adapter_types="$(
    rg --no-filename -o \
        '^(?:@MainActor )?(?:private )?(?:final )?(?:class|struct|actor) [A-Z][A-Za-z0-9_]*' \
        Sources/Entrevoix/Adapters \
        --glob '*.swift' \
        | awk '{ print $NF }' \
        | sort -u \
        | paste -sd '|' -
)"
composition_owned_types="${adapter_types}|AppLogStore|ListeningIndicatorController|QueuedProviderAlertPresenter"
adapter_construction="\\b(${composition_owned_types})[[:space:]]*\\("
violations="$(
    rg -n "$adapter_construction" Sources/Entrevoix/App Sources/Entrevoix/Presentation \
        --glob '*.swift' \
        --glob '!CompositionRoot.swift' \
        || true
)"
if [[ -n "$violations" ]]; then
    echo "Concrete adapters may only be constructed in App/CompositionRoot.swift:" >&2
    printf '%s\n' "$violations" >&2
    exit 1
fi

echo "Architecture boundaries verified."
