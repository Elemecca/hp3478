

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


everything is sent little-endian
every span starts with two 0 bits which are irrelevant
every packet starts with 44 irrelevant 0 data bits
some data spans get extra irrelevant bits
irrelevant bits copy the last real bit

command 0A (0101 0000)
sets low nybble of each digit
from right to left

command 1A (0101 1000)
sets high nybble of each digit
from right to left

dot segments are encoded in high 2 bits
  0  off
  1  decimal
  2  colon
  3  comma

command BC (0011 1101)
controls annunciators
12 packed bits _left to right_



also sends
command FC (0011 1111)
command B8 (0001 1101)
command C8 (0001 0011)
command 2A (0101 0100)


