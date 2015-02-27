import re
import sys
import os
import os.path
import subprocess
import ql.prepr

import glob

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
        raise
    elif err and pr.returncode == 0:
        print '\x1b[33m%s\x1b[0m' % err
    return dict(returncode=returncode, stderr=err, stdout=out)

def slurp(f):
    fl = open(f)
    sql = fl.read()
    fl.close()
    return sql

def migrate(db):
    pgexec(db, 'create table if not exists schema (version text primary key)')
    for f in sorted(glob.glob("schema/*_up.sql")):
        res = pgexec(db, "SELECT 'ok' FROM schema WHERE version = '%s'" % f)
        if res['returncode'] == 0 and res['stdout'].find('ok') < 0:
            print '> migate %s' % f
            mod = os.path.basename(f)
            sql = ql.prepr.process('m' + mod,slurp(f))
            res = pgexec(db, sql)
            if res['returncode'] == 0:
                print res['stdout']
                pgexec(db, "INSERT INTO schema (version) VALUES ('%s')" % f)

def migrate_down(db):
    for f in glob.glob("schema/*_down.sql"):
        res = pgexec(db, "SELECT 'ok' FROM schema WHERE version = '%s'" % f.replace('_down','_up'))
        if res['returncode'] == 0 and res['stdout'].find('ok') > -1:
            print '> migate down %s' % f
            res = pgexec(db, slurp(f))
            if res['returncode'] == 0:
                print res['stdout']
                pgexec(db, "DELETE FROM schema WHERE version = '%s'" % f.replace('_down', '_up'))

