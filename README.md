# Zythium-1
Micro-computer with a RISC CPU (firmware for Maximator FPGA board)

The ZTH1 is a simple Harvard-architecture 16-bit RISC CPU coded in VHDL.
It can be implemented into an FPGA (like the Altera MAX10) to create micro-computers.
An example is the Zythium-1 micro-computer, previously known as "the ZTH1 computer".
Since the ZTH1 CPU is now used on other machines, this computer had to be renamed to better identify it. 

This repository contains the Intel Quartus Prime project with all the VHDL files to
implement on a Kamami Maximator MAX10 FPGA board the Zythium-1 computer based on the
ZTH1 CPU, with 8 k-words of instruction ROM and 8 k-words of data RAM
(including the video memory). The video-controller of this computer has an HDMI
output to display 128 x 192 pixel images with 16 colors. It also features
the display of eight 8x8-pixel sprites, which makes this computer suitable for
developing and playing simple arcade video games.

This repository includes a manual (ZTH1_CPU.pdf)
describing the ZTH1 CPU and how to program it, and another manual (Zythium1.pdf) describing the Zythium-1 micro-computer
architecture with a focus on the video-controller.

