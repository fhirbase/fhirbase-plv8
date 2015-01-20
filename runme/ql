#!/usr/bin/env python

import re
import sys
import os
import sha
import subprocess

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

def pgcall(sql):
    subprocess.call(["psql", "-d", "test", "-c", sql])

def pgexec(sql):
    return subprocess.Popen("psql -d test -c \"%s\"" % sql,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout.read()

def silent_pgexec(sql):
    return subprocess.Popen("psql -d test -c \"%s\" &2> /dev/null" % sql,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout.read()

def shell(cmd):
    pr = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE)
    pr.communicate()
    return pr

def is_changed(fl, content):
    print 'Digest ' + s.hexdigest()
    pgexec('SELECT digest FROM modules WHERE file=\'%s\'' % fl)

def is_test_file(fl):
    return fl.find('_spec.sql') > 0

def should_reload(fl, digest):
    res = pgexec('SELECT digest FROM modules WHERE file=\'%s\'' % fl)
    if is_test_file(fl): return True
    return not res or res.find(digest) == -1
    return True

def load_to_pg(fl, content):
    s = sha.new(content).hexdigest()
    if should_reload(fl, s):
        res = shell("./ssql %s | psql -v ON_ERROR_STOP=1 -d test" % fl)
        if res.returncode == 0:
            pgexec('DELETE FROM modules WHERE file=\'%s\'' % fl)
            pgexec('INSERT INTO modules (file,digest) VALUES (\'%s\',\'%s\')' % (fl, s))
        else:
            print '\x1b[31mERROR: while loading %s\x1b[0m' % fl

def reload(fl):
    idx = dict(files=dict(),deps=dict())
    read_imports(fl, idx)
    deps = resolve(idx['deps'])
    silent_pgexec('CREATE table IF NOT EXISTS modules (file text primary key, digest text);')
    print '<- %s' % fl
    for f in deps:
        load_to_pg(f, idx['files'][f])

def test():
    deps = dict(a=['b','c','z'], c=['d','z'], b=['d','e'], x=['y','z'])
    print resolve(deps)

for fl in sys.argv[1:]:
    reload(fl)
