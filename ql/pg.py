import subprocess

def psql(db, sql):
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
        raise Exception('sql error')
    elif err and pr.returncode == 0:
        print '\x1b[33m%s\x1b[0m' % err
    return dict(returncode=returncode, stderr=err, stdout=out)

def silent_psql(db, sql):
    return subprocess.Popen("psql -d %s -c \"%s\" &2> /dev/null" % (db,sql),shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout.read()
