

P1 pulses are ~5us wide

P1 period within a burst is ~ 54us

clocks come in bursts of 4
inter-burst period ~76us
bursts aren't consistent sizes
there are some ranges with tens of tighly-spaced pulses

P2 repeats P1 with an ~8us delay



when SYNC = 1 expect command bits on ISA
when SYNC = 0 expect data bits on IWA

data changes ~13us before a P1 rising edge
P2 pulses look well-centered on 1-bit data pulses

probably read on P2 rising edge




