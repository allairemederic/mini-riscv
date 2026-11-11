#!/usr/bin/env bash
set -eu

# Lancer QuestaSim
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../simulation"

if ! command -v vsim >/dev/null 2>&1; then
    echo "vsim introuvable. Charge d'abord l'environnement du labo." >&2
    exit 1
fi

if (( $# > 1 )); then
    echo "Usage : $0 [basic|fibo|nom_du_module]" >&2
    exit 1
fi

case "${1:-}" in
    "")
        exec vsim
        ;;
    basic|fibo)
        exec vsim -do "do ../scripts/run_core.do $1"
        ;;
    adder|alu|pc|rf|fetch|decode|execute|memory_access|write_back)
        exec vsim -do "do ../scripts/run_standalone_module.do $1"
        ;;
    *)
        echo "Test inconnu : $1" >&2
        echo "Choisis basic, fibo, adder, alu, pc, rf, fetch, decode, execute, memory_access ou write_back." >&2
        exit 1
        ;;
esac