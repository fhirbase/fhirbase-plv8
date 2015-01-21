import re
import os
import sha
import subprocess
from . import prepr

def getin(d, ks):
    for p in ks:
        if p not in d:
            return None
        d = d[p]
    return d

def resolve(t):
    acc = dict(idx=dict(), guard=dict(), deps=[])
    for k in t:
        if k not in acc['idx']:
            resolve_recur(k, t, acc)
    return acc['deps']

def resolve_recur(k, t, acc):
    if getin(acc, ['guard',k]): raise Exception('Cycle dep %s guard %s' % (k,acc['guard'].keys()))
    if getin(acc, ['idx',k]): return acc

    acc['guard'][k] = True
    for d in (t[k] or []):
        resolve_recur(d, t, acc)
    acc['guard'][k] = False

    acc['deps'].append(k)
    acc['idx'][k] = True
    return acc

def resolve_import(fl, pth):
    flpath = os.path.split(fl)
    return '/'.join(flpath[:-1]) + '/' + pth

# TODO: support relative paths
def extract_import(fl, l):
    if not re.search("^\s?--\s?#import",l): return None
    pth = l.split('#import')[1].strip()
    return resolve_import(fl, pth)

def read_imports(fl, idx):
    if fl in idx['files']: return idx
    if not os.path.isfile(fl):
        raise Exception('Could not find file: %s' % fl)
    f = open(fl, 'r')
    idx['files'][fl] = f.read()
    idx['deps'][fl] = []
    f.seek(0)
    for l in f:
        dep = extract_import(fl, l)
        if dep:
            idx['deps'][fl].append(dep)
            if dep not in idx['files']: read_imports(dep, idx)
    f.close()
    return idx

def silent_pgexec(db, sql):
    return subprocess.Popen("psql -d %s -c \"%s\" &2> /dev/null" % (db,sql),shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout.read()

def pgexec(db, sql):
    pr = subprocess.Popen('psql -v ON_ERROR_STOP=1 -d %s' % db, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pr.stdin.write(sql)
    pr.stdin.write("\\q\r")
    pr.stdin.close()
    pr.wait()
    returncode = pr.returncode
    err = pr.stderr and  pr.stderr.read()
    out = pr.stdout and pr.stdout.read()
    if err and pr.returncode != 0:
        print '\x1b[31m%s\x1b[0m' % err
    elif err and pr.returncode == 0:
        print '\x1b[33m%s\x1b[0m' % err
    return dict(returncode=returncode, stderr=err, stdout=out)

def shell(cmd):
    pr = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
    pr.communicate()
    return pr

def is_changed(fl, content):
    print 'Digest ' + s.hexdigest()
    pgexec('SELECT digest FROM modules WHERE file=\'%s\'' % fl)

def is_test_file(fl):
    return fl.find('_spec.sql') > 0

def should_reload(db, fl, digest):
    res = pgexec(db, 'SELECT digest FROM modules WHERE file=\'%s\'' % fl)
    if is_test_file(fl): return True
    return not res['stdout'] or res['stdout'].find(digest) == -1
    return True

def hl(cl, txt):
    colors = dict(red=31,green=32,yellow=33)
    code = colors[cl]
    return '\x1b[%sm%s\x1b[0m' % (code,txt)

def load_to_pg(db, fl, content, force=False):
    s = sha.new(content).hexdigest()
    if force or should_reload(db, fl, s):
        print '\t<- %s' % fl
        sql = prepr.process(fl, content)
        res = pgexec(db, sql)
        if res['returncode'] == 0:
            pgexec(db, 'DELETE FROM modules WHERE file=\'%s\'' % fl)
            pgexec(db, 'INSERT INTO modules (file,digest) VALUES (\'%s\',\'%s\')' % (fl, s))
        if res['stderr'] and res['returncode'] != 0:
            raise Exception(res['stderr'])

def reload(db, fl, force=False):
    idx = dict(files=dict(),deps=dict())
    read_imports(fl, idx)
    deps = resolve(idx['deps'])
    silent_pgexec(db, 'CREATE table IF NOT EXISTS modules (file text primary key, digest text);')
    print 'Load %s' % fl
    for f in deps:
        load_to_pg(db, f, idx['files'][f], force)

def test():
    deps = dict(a=['b','c','z'], c=['d','z'], b=['d','e'], x=['y','z'])
    print resolve(deps)
