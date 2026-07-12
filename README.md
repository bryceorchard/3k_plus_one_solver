# 3k + 1 Sequence Generator (VHDL / FPGA)

A hardware implementation of the **"3k + 1" (Collatz) sequence generator**, written in VHDL and
synthesized to a **Digilent Nexys A7 (Xilinx Artix-7)** FPGA. The system finds the smallest positive
integer whose 3k + 1 sequence contains **at least 9 terms**, and displays the result live on the board's
7-segment displays.

> Course project for **COEN 313 – Digital Systems Design II**, Concordia University.
> Two independent implementations of the same algorithm are provided to contrast two RTL design styles.

---

## The problem

The **Collatz conjecture** starts from any positive integer *k* and repeatedly applies:

```text
if k is even:  k = k / 2
if k is odd:   k = 3k + 1
```

...until *k* reaches 1. The number of steps taken is the sequence's **length**. For example:

```text
k = 6:  6 → 3 → 10 → 5 → 16 → 8 → 4 → 2 → 1     (9 terms)
```

This project solves a bounded version of the problem in hardware: **find the smallest integer whose
sequence has ≥ 9 terms.** The design walks the integers in order, generates each one's full sequence,
and halts on the first that qualifies — **the answer is 6** — asserting a `done` signal and holding the
result until reset.

---

## Two implementations

The same algorithm is realized two ways, both matching the identical entity/pin specification:

|            | `part 1` — Single clocked process                  | `part 2` — ASM chart (FSM + datapath)                                     |
| ---------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| **Style**  | One algorithmic clocked process using **variables** | Moore-style **control unit** (FSM) driving separate **datapath** register processes |
| **Focus**  | Compact, algorithmic RTL                           | Textbook control-unit / datapath methodology                              |
| **File**   | `part1_single_process/three_k_plus_one.vhd`        | `part2_asm_fsm/three_k_plus_one_asm.vhd`                                  |

Both compute the same result and share the same time-multiplexed 7-segment display driver. Building the
design twice demonstrates that a high-level algorithmic description and an explicit ASM-chart state machine
can be made behaviorally equivalent — a core lesson in RTL design.

---

## Hardware target & I/O

Board: **Nexys A7**, driven by the on-board **100 MHz** oscillator. Pin assignments live in
[`3k.xdc`](3k.xdc).

| Port        | Board resource         | Purpose                             |
| ----------- | ---------------------- | ----------------------------------- |
| `clk_in`    | E3 (100 MHz clock)     | System clock                        |
| `reset`     | BTNC (center button)   | Asynchronous reset                  |
| `done_out`  | LD15                   | Goes high when the answer is found  |
| `sseg[7:0]` | 7-seg cathodes (CA–DP) | Active-low segment pattern          |
| `an[7:0]`   | 7-seg anodes (AN7–AN0) | Active-low digit select             |

On the board, `number` is shown on one 7-segment digit and `term` on two digits (in hex). Once `done`
is asserted, the registers hold their final values (`number = 6`) until the reset button is pressed.

---

## Design highlights

- **Variables vs. signals.** In the single-process version, `number`, `term`, and `length` are VHDL
  *variables* so that an incremented value can be consumed in the *same* clock cycle — mirroring the
  sequential semantics of the reference C++. Using signals would insert a one-cycle delay, changing the
  behavior. This subtlety is called out in the code and the report.
- **Synthesis-friendly arithmetic.** Division by 2 is implemented as a right shift (`shift_right`), and
  the `3*term` multiply uses `resize(...)` to keep the product within the declared register width — both
  chosen because unrestricted `/` and unsized `*` are not (or not efficiently) synthesizable.
- **Time-multiplexed 7-segment driver.** A 20-bit counter divides the 100 MHz clock to cycle through the
  digits at a ~90 Hz refresh rate (`N = log₂(100 MHz / 90 Hz) ≈ 20`), fast enough to appear continuous to
  the eye. The two most-significant counter bits select which digit is driven.
- **Clean stop condition.** A `done` flip-flop latches once 9 terms are reached and gates all further
  state updates, so the answer stays on-screen until an asynchronous reset.

---

## Repository layout

```text
.
├── 3k.xdc                          # Nexys A7 pin constraints (shared by both parts)
├── part1_single_process/           # Single clocked-process implementation
│   ├── three_k_plus_one.vhd        #   synthesizable design (algorithm + 7-seg driver)
│   ├── three_k_plus_one_sim.vhd    #   simulation variant (display removed, length exposed)
│   ├── part1.do                    #   ModelSim simulation macro
│   └── Figures/                    #   elaborated/implemented schematics, waveforms
├── part2_asm_fsm/                  # ASM chart: FSM control unit + datapath
│   ├── three_k_plus_one_asm.vhd    #   synthesizable design
│   ├── part2.do                    #   ModelSim simulation macro
│   └── Figures/                    #   ASM chart, block diagram, waveforms
├── Project Report.pdf              # Full write-up: code, ASM chart, sim & synthesis results
└── Project Description Summer 2026.pdf   # Original assignment specification
```

---

## Simulating the design (ModelSim)

Each part ships a `.do` macro that sets up the clock, applies reset, and runs the design. From the
ModelSim console:

```tcl
vcom three_k_plus_one_sim.vhd          # compile (use the *_sim variant for Part 1)
vsim -voptargs="+acc" three_k_plus_one # elaborate; +acc preserves the 'length' signal for viewing
do part1.do                            # drive stimulus and add signals to the wave window
```

> **Note:** the `-voptargs="+acc"` flag is required because `length` is never read by the logic, so
> ModelSim would otherwise optimize it away and it wouldn't appear in the waveform.

Signals should be viewed in **unsigned** radix. The simulation shows `number` climbing 1 → 6 while each
sequence is generated, with `done` asserting once a 9-term sequence (at `number = 6`) is found.

---

## Synthesis results

Both designs synthesize and implement on the Nexys A7 with **0 errors and 0 critical warnings.** The only
synthesis warnings are expected and benign:

- `Synth 8-3917` (ports `an[…]` driven by constant 1) — 5 of the 8 displays are intentionally unused and
  tied off.
- `Synth 8-7080` (parallel synthesis criteria not met) — the design is simply too small to trigger
  parallel synthesis; no effect on correctness.

See [`Project Report.pdf`](Project%20Report.pdf) for full simulation waveforms, the ASM chart, the
datapath block diagram, and RTL component (register/adder/mux) statistics.

---

## Skills demonstrated

- RTL design in **VHDL** using the `numeric_std` package (`unsigned`, `resize`, `shift_right`)
- Two design methodologies: **single algorithmic process** and **ASM-chart control-unit/datapath**
- **Finite-state-machine** (Moore) design and register-transfer-level datapath construction
- Writing **synthesizable** hardware (shift-for-divide, sized arithmetic, latch avoidance)
- **Clock division** and **time-multiplexed 7-segment** LED display driving
- FPGA toolflow: simulation in **ModelSim**, synthesis & implementation in **Vivado**, timing constraints via **XDC**
- Reading and reviewing **synthesis/implementation logs** to verify inferred hardware

---

## Author

**Bryce Orchard** — Concordia University, COEN 313 (Summer 2026).
