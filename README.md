# unlzw3

![ci](https://github.com/scivision/unlzw3/workflows/ci/badge.svg)

Pure Python decompression module for .Z files compressed using Unix compress utility.
Unlike the faster but Linux-specific
[unlzw](https://pypi.org/project/unlzw/)
using Python CFFI, `unlzw3` is slower but works on any platform that runs Python including Windows.

This is a purely Python adaptation of Mark Adler's
['unlzw' C function](http://mathematica.stackexchange.com/questions/60531/how-can-i-read-compressed-z-file-automatically-by-mathematica/60879#60879)
on Stackoverflow.
Python can be much slower than using any compiled utility for the same purpose.

## Usage

`unlzw3.unlzw(data)` takes LZW .Z compressed data as any type which can be converted to a bytearray (generally a string).
It returns a UTF-8 decoded string containing the decompressed data.

```python
import unlzw3
from pathlib import Path

uncompressed_data = unlzw3.unlzw(Path('file.Z').read_bytes())

# or

uncompressed_data = unlzw3.unlzw(Path('file.Z'))
```

## Contributions

* reference C code: Mark Adler
* pure Python implemetation: [Brandon Owen](https://github.com/umeat/unlzw)
* modernization, test / CI and PyPi: Michael Hirsch
