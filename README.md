# timex-interface-cpld
ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 

Initial work done by analyzing GAL equations (proven to be working OK)

Claude was a stupid co-worker and it didn't have any "critical thinking" to make the design unstuck itself from GAL equations.

Since all Address bus pins are available to CPDL, it was just a matter of decoding full addresses and ioports into local variables.

Then, instead of trying to replicate precisely the J/K flip-flop from original design, I opted to just go with a simple register to hold activation status. 

GAL logic equations were a mess because they had to deal with inverted logic to activate 74LS109 J/K flip-flop.

Design is now a lot leaner and simple to understand and maintain.

## software requirements: 

Xilinx ISE Legacy 14.7 - webpack edition

I source 'settings64.sh' from where the software was installed and then just run build from ise-project folder.

This will allow compilation using command line only, I have no interest in GUI tools to generate a .JED file...

## replacing two PAL chips and a flipflop
  - GAL23 (I/O port decoding)
  - GAL16 (address decoding, chip selects)
  - LS109 J-K flip-flop (page-in/out state)

## Memory Map (when paged in):
  - 0x0000-0x0FFF: 4KB ROM
  - 0x2000-0x27FF: 2KB RAM

## Interface Paging:
  - Pages IN:  Read from 0x0000 or 0x0008
  - Pages OUT: Access to 0x0604 region
  
## I/O Port: 
  - 0xEF Fully decoded
