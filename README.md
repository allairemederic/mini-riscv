# Mini-RISC-V — Five-Stage Processor Design

A five-stage RV32I processor written in VHDL, developed as part of
the ELE8304 VLSI Design course at Polytechnique Montréal.

The project covers processor RTL design, functional verification,
and an ongoing ASIC implementation flow targeting Cadence's
educational 45 nm Generic Process Design Kit (GPDK045).

## Processor Architecture

- Five pipeline stages: instruction fetch, decode, execute,
  memory access, and write-back
- Modular datapath and control logic
- Data forwarding and pipeline stalls for hazard handling
- Branch handling and pipeline control

## Verification

VHDL testbenches and Tcl scripts are used to simulate and verify
processor modules in QuestaSim.

Tests cover:
- ALU arithmetic and logical operations
- Register-file reads, writes, and forwarding
- Program-counter updates
- Reset, stall, and control behavior

## ASIC Implementation

Logic synthesis, timing analysis, and performance evaluation
are in progress using Cadence Genus and the GPDK045 technology.

The course's implementation flow also introduces placement
and routing, timing constraints, and physical design.

## Tools and Languages

- **RTL:** VHDL
- **Simulation:** QuestaSim
- **Synthesis:** Cadence Genus
- **Automation:** Tcl
- **Target technology:** Cadence GPDK045, 45 nm

## Course Context

This project is based on Laboratory 2 of
[ELE8304 — VLSI Design](https://www.polymtl.ca/etudes/cours/circuits-integres-tres-grande-echelle).

The laboratory focuses on sequential digital design, processor
architecture, functional simulation, and the ASIC design flow.

The associated
[digital IC design tutorial](https://intranet.grm.polymtl.ca/wiki/doku.php?id=tutoriels:numerique)
requires access to Polytechnique Montréal's internal network.

EDA tools and technology access are provided through
[CMC Microsystems](https://www.cmc.ca/).