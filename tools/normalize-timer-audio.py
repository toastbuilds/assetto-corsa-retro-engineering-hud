from array import array
from pathlib import Path
import math
import sys
import wave


def main():
    assets = Path(__file__).resolve().parent.parent / 'assets'
    target_peak = int(32767 * 10 ** (-1 / 20))
    for filename in ('notification-qqv87.wav', 'experimental-5btgm.wav', 'notification-d4s3s.wav'):
        path = assets / filename
        with wave.open(str(path), 'rb') as source:
            parameters = source.getparams()
            if parameters.sampwidth != 2 or parameters.comptype != 'NONE':
                raise ValueError(f'{filename} must use 16-bit PCM')
            samples = array('h', source.readframes(parameters.nframes))
        if sys.byteorder != 'little':
            samples.byteswap()
        peak = max(abs(value) for value in samples)
        if peak == 0:
            raise ValueError(f'{filename} has no audible samples')
        gain = target_peak / peak
        normalized = array('h', (round(value * gain) for value in samples))
        if sys.byteorder != 'little':
            normalized.byteswap()
        with wave.open(str(path), 'wb') as destination:
            destination.setparams(parameters)
            destination.writeframes(normalized.tobytes())
        print(f'{filename}: {20 * math.log10(gain):+.2f} dB, peak -1 dBFS')


if __name__ == '__main__':
    main()
