# ZTH1
The ZTH1 RISC CPU for micro-computers (firmware for Maximator FPGA board)

The ZTH1 is a simple Harvard-architecture 16-bit RISC CPU coded in VHDL.
It can be implemented into an FPGA (like the Altera MAX10) to create micro-computers.
This repository contains the Intel Quartus Prime project with all the VHDL files to
implement on a Kamami Maximator MAX10 FPGA board such a computer based on the
ZTH1 CPU, with 8 k-words of instruction ROM and 8 k-words of data RAM
(including the video memory). The video controller of this computer has an HDMI
output to display 128 x 192 pixel images with 16 colors. It also features
the display of eight 8x8-pixel sprites, which makes this computer suitable for
developing and playing simple arcade video games. This repository includes manual (ZTH1_CPU.pdf)
describing the ZTH1 CPU and how to program it and a manual (ZTH1_MC.pdf) describing the micro-computer
architecture with a focus on the video-controller.

