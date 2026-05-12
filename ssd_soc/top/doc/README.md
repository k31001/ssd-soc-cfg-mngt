# ssd_soc_top

가상 SSD Controller SoC Top-level wrapper.

## Subsystems
- host_ss: PCIe Gen4/NVMe host interface subsystem
- fcc_ss: Flash Channel Controller subsystem (NAND interface)
- mem_ss: On-die memory and interconnect subsystem
- cpu_ss: Embedded RISC-V CPU subsystem (FW execution)
- sec_ss: Security subsystem (crypto + secure boot)