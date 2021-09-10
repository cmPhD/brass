import os
import tempfile
import pandas
from pandas import Series
from pathlib import Path
from pprint import pformat

def update_conf_paths(config, dir):
    rep = {}
    for f in Path(dir).glob('**/*'):
        if not f.is_file():
            continue

        for k, v in config._asdict().items():
            try:
                if Path(v).name == f.name:
                    rep[k] = str(f)
            except TypeError:
                pass

    return config._replace(**rep)

def hdf_get(fname, key):
    s = pandas.HDFStore(fname, 'r')
    v = s[key]
    s.close()
    return v

def mktemp(prefix=None, suffix=None):
    tfile = None
    with tempfile.NamedTemporaryFile(
        delete=False, prefix=prefix, suffix=suffix
        ) as f:
        tfile = f.name

    return tfile

def remove(fname):
    os.remove(fname)

def filter(problems, selection):
    assert selection.format == '?' and selection.shape[1] == 1 and len(selection.shape) == 2
    assert len(problems) == selection.shape[0]

    def _flatten(t):
        return [t[(i, 0)] for i in range(t.shape[0])]

    selection = _flatten(selection)
    return problems[selection]

def test_matlab_py(*args, **kwargs):
    print(*args)
    return args, kwargs
