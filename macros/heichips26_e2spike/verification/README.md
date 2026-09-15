# Signoff of the committed views

Independent checks of what `submission.yaml` points the organisers at, run on
2026-09-15 against commit 97c14ec. Nothing was re-hardened: every check below
reads `final/gds`, `final/lef`, `final/vh`, `final/nl`, `final/pnl` and
`final/spef` as committed. Tool versions are the ones the repository's
`flake.lock` pins (LibreLane 3.1.0.dev2, Yosys 0.66, OpenROAD, Magic 8.3.677,
KLayout 0.30.9, Netgen, Icarus Verilog 13.0).

Unlike the template's `make copy-reports`, these reports do not come from the
LibreLane run that produced the views; that run directory is not in the repo.

## Summary

| Check | Result | Report |
|---|---|---|
| Organisers' precheck (`.github/precheck/heichips_precheck.py`), three PDK checkouts | 0 zero-area polygons, 0 KLayout antenna, 0 Magic DRC, 0 KLayout DRC with every PDK | `precheck_metrics.csv`, `drc.klayout.json`, `drc.magic.rpt`, `antenna.klayout.json`, `zero_area_polygons.klayout.json` |
| LVS, Magic extraction from the GDS + Netgen | Circuits match uniquely, 10249 of 10249 devices, 10244 of 10244 nets | `lvs.netgen.rpt` |
| LVS, IHP KLayout runset, nothing black-boxed | netlists match, 0 errors, strict port mode | `lvs.klayout.summary.txt` |
| Static timing, three corners, 10 ns constraint | hold met everywhere; setup met in typ and fast, -2.21 ns in slow; fmax 82 MHz in the slow corner | `sta_summary.rpt`, `sta_nom_slow_1p08V_125C_violators.rpt` |
| Pin positions against the tapeout repo's `heichips26_template_large.def` | all 83 signal pins match in name, layer (Metal3) and rectangle | |
| Power straps | 10 VPWR and 10 VGND on Metal4 from y = 3.56 to 408.46 um, identical to the organisers' `heichips26_example_large` | |
| RTL simulation against a bit-accurate golden model | 17 of 17 samples with the shipped image, 17 of 17 with the corrected one: every layer's spikes, class label, SRAM protocol and set of written words | |
| Gate-level simulation of `final/nl` | 6 samples per image, flip-flops starting at 0 and at 1: 24 of 24 pass, and every run's SRAM access trace is identical to the RTL's in cycle, address and data | |
| Learning on, RTL and gate level | two inferences of sample 0 with learning on: all 207,196 SRAM accesses of the netlist identical to the RTL's; the weight steps include +7 to -8 wraps (finding 3) | |
| Two inferences back to back, RTL | sample 0, then sample 100: both match the golden model with `rst_n` pulsed in between, the second does not without it (finding 2) | |

## Notes on the method

**PDK checkouts.** The precheck ran against the PDK the repository's Makefile pins
(IHP-Open-PDK db70c13 + ihp-sg13cmos5l 11d3fee, what the CI used), the one
HeiChips/heichips26-tapeout pins (22f2a25 + e8a87d7), and the one
HeiChips/heichips26-template moved to on 2026-09-14 (1ffc783).

**Magic LVS.** LibreLane's own LVS extracts from DEF and LEF abstracts. This run
used `Magic.SpiceExtraction` with `MAGIC_EXT_USE_GDS`, so every standard cell's
transistors and all routing come from the GDS. One cell is black-boxed,
`sg13cmos5l_antennanp` (25 instances, still checked at their pins): Magic's
extraction of that PDK cell puts its n-diode on an internal node, while IHP's
KLayout LVS deck matches the same cell GDS against its CDL. The KLayout run
covers those instances.

**STA.** LibreLane's `OpenROAD.STAPostPNR` with `flow/librelane/signoff.sdc`. The
setup violations are reg-to-reg paths in the slow corner only, which needs 12.21 ns.
The HeiChips chip top (HeiChips/heichips26-tapeout, `librelane/config.yaml`) is
constrained to 15 ns. Max fanout is exceeded by clock tree buffers and three other
drivers; the only drivers without parasitics are unused inputs and CTS dummy loads.

**Simulation.** The testbench is `testbenches/verilog/heichips26_e2spike_tb.v` with
the eFPGA memory controller `efpga_mem_ctrl.v` and the IHP SRAM model from the
PDK around the macro. The golden model is the E2Spike EEG model from
xiaoyuehai/E2Spike (`EEG_SIM`), made bit accurate (arithmetic shifts, int8
write-back clipping) and extended to take the fc layers' bias words from the
memory image, so a word two layers claim shows up in the model the same way it
does in the hardware. Its image builder reproduces `interface/bank_cfg.pat` as
shipped in 97c14ec in all 1024 words, layer table included. `make sim-rtl-verilog`
and `make sim-gl-verilog` rerun sample 0 against the reference snapshots in
`testbenches/verilog/expected/`.

650 of the netlist's 753 flip-flops have no reset and the IHP cell primitives
start as X, which makes a plain gate-level run meaningless after 25 cycles.
`gl_udp_init.py` gives every flop an initial value, and the netlist is simulated
from all 0 and from all 1.

## Findings

The macro README describes these under SRAM interface and known issues:

1. The shipped memory image had fc1 and fc2 both reading word 232 (fixed in this
   commit series, data only). Accuracy over the 200 chb01 samples: 89.0 % with the
   old image, 91.0 % with the corrected one, 92.5 % for the float software model.
2. A second inference started with `gbl_start` alone ends 142 cycles early and gets
   some spikes wrong in every layer (sample 100 after sample 0: 11 of 5120 in ds1,
   8 of 2560 in ds2, 1 of 640 in ds3, 1 of 32 in fc1). `rst_n` has to be pulsed
   before every `gbl_start`.
3. The SDSP learning rule saturates the signed 4-bit weights as unsigned values and
   compares the membrane potential unsigned; 20 of 80 cases of a sweep through the
   rule differ from signed arithmetic, and a weight at +7 wraps to -8.
4. The eFPGA has to implement the 4-beat memory controller (76 LUT4 + 16 FF in a
   Yosys `synth -lut 4` estimate) and load the weights.
