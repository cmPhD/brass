from collections import namedtuple

def parse_config_m(filename='Config.m', localfname='ConfigLocal.m'):
    config = {}
    Config = lambda: None
    ConfigLocal = lambda: None
    ConfigLocal.BaseDir = [
        eval(i.split('=')[1].strip())
        for i in open(localfname, 'r').readlines()
        if i.lstrip().startswith('BaseDir')
    ][0]
    def append(i, j):
        return "".join((i, j))

    with open(filename, 'r') as f:
        for l in f:
            if l.lstrip().startswith('%'):
                continue
            
            if '=' in l:
                k, v = l.split('=', 1)
                k = k.strip()
                v = v.strip()
                if v.lower() == 'true':
                    v = 'True'
                elif v.lower() == 'false':
                    v = 'False'
                elif v == 'string(missing)':
                    v = 'None'

                config[k] = eval(v)
                setattr(Config, k, config[k])

    config = namedtuple('Config', config.keys())(*config.values())
    return config
