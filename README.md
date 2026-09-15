# E2Spike: A Tiny End-to-End Neuromorphic Accelerator

E2Spike is a compact neuromorphic accelerator developed during the **HeiChips 2026 Summer School and Hackathon** in Heidelberg, Germany. It is designed to run lightweight spiking neural networks (SNNs) entirely on-chip and support spike-driven synaptic plasticity (SDSP) for on-chip learning. Target applications include EEG-based seizure detection and event-based fall detection.

🏆 **Best Project (Digital) — HeiChips 2026**

## Features

- **End-to-end SNN inference:** supports lightweight networks with up to 12 layers.
- **Multiple operators:** depthwise convolution, pointwise convolution, fully connected layers, pooling, and quantized LIF neuron processing.
- **On-chip learning:** SDSP-based weight updates for local adaptation.
- **Compact implementation:** targets a 500 µm × 415 µm macro slot with access to 4 KiB of shared SRAM.
- **Open-source design flow:** Verilog RTL and LibreLane, targeting IHP 130 nm CMOS technology.

## Repository

The main design is located in [`macros/heichips26_e2spike/`](macros/heichips26_e2spike/). Its [README](macros/heichips26_e2spike/README.md) documents the pins, the SRAM protocol, the memory image and how to run an inference.

- [`rtl/`](macros/heichips26_e2spike/rtl/): accelerator RTL and learning modules.
- [`rtl/tb/`](macros/heichips26_e2spike/rtl/tb/): accelerator testbenches.
- [`rtl/fpga_emu/`](macros/heichips26_e2spike/rtl/fpga_emu/): FPGA emulation on a Basys 3.
- [`interface/`](macros/heichips26_e2spike/interface/): SRAM image with the weights and one input sample.
- [`testbenches/verilog/`](macros/heichips26_e2spike/testbenches/verilog/): self-checking testbench at the macro pins, for RTL and gate-level simulation.
- [`flow/`](macros/heichips26_e2spike/flow/): ASIC implementation configuration.
- [`final/`](macros/heichips26_e2spike/final/): the submitted layout views.
- [`verification/`](macros/heichips26_e2spike/verification/): signoff of the submitted views.

## Team

Yuehai, Frank, Shuzhong, Yike, and Sebastian.

## Acknowledgments

Thanks to the HeiChips organizers, instructors, and IHP for providing the tools, guidance, and tapeout opportunity. This repository builds on the HeiChips project template; see the [HeiChips 2026 tapeout project](https://github.com/HeiChips/heichips26-tapeout) for chip integration details.

## License

Apache-2.0 WITH SHL-2.1, unless otherwise stated.
