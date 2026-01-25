# ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 

An experiment on using a Xilinx CPLD to replace both GAL chips and the flipflop in the daughter board.

This is a validation build for further Interface replacement
 
ZX Spectrum side:
  - GAL23 (I/O port decoding)
  - GAL16 (address decoding, chip selects)
  - LS109 J-K flip-flop (page-in/out state)

Memory Map (when paged in):
  - 0x0000-0x0FFF: 4KB ROM
  - 0x1000-0x1FFF: ROM echo (A12 not decoded)
  - 0x2000-0x27FF: 2KB RAM
  -  0x2800-0x3FFF: RAM echoes (A11-A12 not decoded)

Paging:
  - Pages IN:  Read from 0x0000 or 0x0008
  - Pages OUT: Access to 0x0604 region

I/O Port: 
  - 0x3F (A5=1, A4=0, A3=1, A2=1, A1=1, A0=1)# Recreated GAL equations in a CPLD

