# Recreated GAL equations for 16-23 pair

Tested successfully on the actual interface, compiled using 'galasm' tool on Linux

GAL 16 is responsible for:

- managing paged in/out state
- disabling ZX Rom
- enabling interface rom and ram

GAL 23 is responsible for:

- write strobe for Interface out
- read strobe for Interface in

Both GAL chips are interconnected for further address decoding

All Z80 Address lines are connected, including /MREQ /RD /WR /IORQ /M1 signals
