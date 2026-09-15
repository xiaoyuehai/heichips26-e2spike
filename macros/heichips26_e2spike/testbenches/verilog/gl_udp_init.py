#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 The E2Spike team
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
"""Copy of the IHP standard cell primitives with every flip-flop starting at 0 or 1.

    gl_udp_init.py <sg13cmos5l_udp.v from the PDK> <output.v> <0|1>

Used by `make sim-gl-verilog`. 650 of the netlist's 753 flip-flops have no reset
(RESET_B tied high), and the PDK primitives have no initial statement, so every
register starts as X. RTL simulation hides that; at gate level the X reaches the
SRAM enables within 25 cycles and the run is meaningless. Silicon powers up
with an arbitrary mix of 0s and 1s, so the netlist is simulated once from all 0
and once from all 1, and both runs must pass.

Two edits to the copy:
  * `initial q = 1'b<value>;` before the table of every sequential primitive
  * in ihp_dff_r, the primitive of sg13cmos5l_dfrbpq_1 (the only flop cell the
    netlist uses), a row that holds the state on a clock step from x to 0. The
    clock net makes that step at time 0 while D is still x; no row of the PDK
    table matches it, so the primitive would fall back to x and lose the initial
    value before the first real clock edge. A falling clock never captures.
"""

import sys
from pathlib import Path


def main():
    if len(sys.argv) != 4 or sys.argv[3] not in ("0", "1"):
        sys.exit(__doc__)
    src, dest, value = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    out, sequential, primitive = [], False, None
    for line in src.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("primitive"):
            sequential = False
            primitive = stripped.split()[1].split("(")[0]
        if stripped.startswith("reg q"):
            sequential = True
        if stripped == "table" and sequential:
            out.append("\tinitial q = 1'b%s;" % value)
        if stripped == "endtable" and primitive == "ihp_dff_r":
            out.append("\t\t?  (x0) ?  ?   ? : ? : -;")
        out.append(line)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
