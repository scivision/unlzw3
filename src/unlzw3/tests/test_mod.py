import importlib.resources

from unlzw3 import unlzw


def test_simple():

    with importlib.resources.path("unlzw3.tests", "hello.Z") as fn:
        assert unlzw(fn) == b"He110\n"


def test_lipsum():
    """
    courtesy lipsum.com
    """

    with importlib.resources.path("unlzw3.tests", "lipsum.com.Z") as fn:
        data = unlzw(fn)

        assert data == unlzw(fn.read_bytes())
        assert len(data) == 100172
