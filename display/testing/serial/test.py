from sys import stdout

from pyftdi.gpio import GpioAsyncController

#  Signal  Probe   FTDI
#  PWO     violet  ADBUS5
#  P1      orange  ADBUS0
#  P2      gray    ADBUS4
#  SYNC    blue    ADBUS7
#  ISA     green   ADBUS2
#  IWA     yellow  ADBUS1


gpio = GpioAsyncController()
gpio.configure(
    'ftdi://ftdi:232h:FTVBQ6H1/1',
    direction=0, # everything is input
    frequency=500000,
)

period = 1.0 / gpio.frequency
stdout.write('sampling every {:.6f}s\n'.format(period))


def gpio_samples():
    while True:
        for sample in gpio.read(512, noflush=True):
            yield sample


def main():
    since_last = 0
    bits_written = 0
    last_p2 = None
    last_sync = None
    in_command = False
    bits = ''

    def flush_span():
        nonlocal bits, last_sync
        if bits:
            out = 'C' if last_sync else 'D'

            if len(bits) % 8 == 2:
                out = out + ' ' + bits[:2]
                bits = bits[2:]

            while bits:
                out = out + ' ' + bits[:8]
                bits = bits[8:]

            print(out)

        bits = ''

    for sample in gpio_samples():
        pwo = sample & 0x20 != 0
        p2 = sample & 0x10 != 0
        sync = sample & 0x80 != 0
        isa = sample & 0x04 != 0
        iwa = sample & 0x02 != 0

        if not pwo:
            if in_command:
                flush_span()

            in_command = False

        elif p2 != last_p2 and p2:
            if not in_command:
                print('\nS +{:.6f}s'.format(since_last * period))
                in_command = True
                last_sync = None

            if sync != last_sync:
                flush_span()
                last_sync = sync

            bit = isa if sync else iwa
            bits = bits + ('1' if bit else '0')
            since_last = 0

        last_p2 = p2
        since_last = since_last + 1

try:
    main()
except KeyboardInterrupt:
    stdout.write('\n')
