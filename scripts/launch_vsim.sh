#!/usr/bin/env bash
set -eu

# Lancer QuestaSim
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../simulation"

if ! command -v vsim >/dev/null 2>&1; then
    echo "vsim introuvable. Charge d'abord l'environnement du labo." >&2
    exit 1
fi

if (( $# > 2 )); then
    echo "Usage : $0 [basic|fibo|nom_du_module|timing basic|timing fibo|pnr basic|pnr fibo]" >&2
    exit 1
fi

# Seules les simulations temporelles demandent un 2e argument
if (( $# == 2 )) && [[ "$1" != "timing" && "$1" != "pnr" ]]; then
    echo "Seules les commandes timing et pnr acceptent un deuxieme argument." >&2
    exit 1
fi

case "${1:-}" in
    "")
        exec vsim
        ;;

    # Simulation comportementale du core
    basic|fibo)
        exec vsim -do "do ../scripts/run_core.do $1"
        ;;

    # Simulation comportementale individuelle d'un module
    adder|alu|pc|rf|fetch|decode|execute|memory_access|write_back)
        exec vsim -do "do ../scripts/run_standalone_module.do $1"
        ;;

    # Simulation temporelle post-synthese ou post-routage
    timing|pnr)
        case "${2:-}" in
            basic|fibo)
                if [[ "$1" == "timing" ]]; then
                    stage="syn"
                else
                    stage="pnr"
                fi

                exec vsim -do "do ../scripts/run_timing.do $stage $2"
                ;;
            *)
                echo "Usage : $0 $1 basic|fibo" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Test inconnu : $1" >&2
        echo "Choisis basic, fibo, un nom de module, timing ou pnr." >&2
        exit 1
        ;;
esac