#!/usr/bin/env python
import pytest
from pathlib import Path
from unlzw3 import unlzw


R = Path(__file__).parent


def test_simple():
    fn = R / 'hello.Z'
    assert unlzw(fn) == b'He110\n'


if __name__ == '__main__':
    pytest.main([__file__])
