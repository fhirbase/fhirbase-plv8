import re
import sys
import os
import os.path
import subprocess
import glob

import ql.prepr
from ql.pg import psql

def slurp(f):
    fl = open(f)
    sql = fl.read()
    fl.close()
    return sql

def migrate(db):
    psql(db, 'create table if not exists schema (version text primary key)')
    for f in sorted(glob.glob("schema/*_up.sql")):
        res = psql(db, "SELECT 'ok' FROM schema WHERE version = '%s'" % f)
        if res['returncode'] == 0 and res['stdout'].find('ok') < 0:
            print '> migate %s' % f
            mod = os.path.basename(f)
            sql = ql.prepr.process('fhirbase_migration_' + mod,slurp(f))
            res = psql(db, sql)
            if res['returncode'] == 0:
                print res['stdout']
                psql(db, "INSERT INTO schema (version) VALUES ('%s')" % f)

def migrate_down(db):
    for f in glob.glob("schema/*_down.sql"):
        res = psql(db, "SELECT 'ok' FROM schema WHERE version = '%s'" % f.replace('_down','_up'))
        if res['returncode'] == 0 and res['stdout'].find('ok') > -1:
            print '> migate down %s' % f
            res = psql(db, slurp(f))
            if res['returncode'] == 0:
                print res['stdout']
                psql(db, "DELETE FROM schema WHERE version = '%s'" % f.replace('_down', '_up'))

