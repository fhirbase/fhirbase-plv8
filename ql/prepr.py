#!/usr/bin/env python

import re
import sys
import os.path

def close_fn(res,mod):
  res.append('$$ ' + mod + ';')
  res.append('')

def open_fn(res,fn):
  res.append("CREATE OR REPLACE")
  res.append(fn)
  res.append("LANGUAGE sql AS $$")

def open_proc(res,fn):
  res.append("CREATE OR REPLACE")
  res.append(fn)
  res.append("LANGUAGE plpgsql AS $$")
  res.append("DECLARE")

def close_proc(res,mod):
  res.append('  END; $$ ' + mod + ';')
  res.append('')

def macroexpand(fl, ns, ln, line):
    return line.replace('this.',ns + '.').replace('getv(','vars.getv(')

def open_expect_raise(res,fl, ln, line):
  txt = line.replace('expect_raise','').replace('\'','').strip()
  res.append("SELECT tests.expect_raise('%s', '%s:%d'," % (txt, fl, ln + 1))
  res.append('($SQL$')

def close_expect_raise(res,):
  res.append('$SQL$));')

def open_assert(res,fl, ln, line):
  txt = line.replace('expect','').replace('\'','').strip()
  res.append("SELECT tests.expect('%s', '%s:%d',(" % (txt, fl, ln + 1))

def inline_assert(res,fl, ln, line):
  if line.find('--')== 0: return
  if line.find('/*')== 0: return
  (expr, expect) = line.split(' => ')
  res.append("SELECT tests.expect('', '%s:%d',(%s),(%s));" % (fl, ln + 1, expr.strip(), expect.strip()))

def close_assert(res,line):
  res.append('),(%s));' % line.replace('=>','').rstrip())

def close_stmt(res,st, line):
  if st == 'fn':
    close_fn(res,'IMMUTABLE')
  elif st=='fn!':
    close_fn(res,'')
  elif st == 'pr':
    close_proc(res,'IMMUTABLE')
  elif st=='pr!':
    close_proc(res,'')
  elif st=='assert':
    close_assert(res,line)
  elif st=='expect_raise':
    close_expect_raise(res,)

def process(nm, content):
    res = []
    state = 'start'
    ns = os.path.splitext(os.path.basename(nm))[0]

    res.append('drop schema if exists %s cascade;' % ns)
    res.append('create schema %s;' % ns)

    for idx,line in enumerate(content.splitlines()):
      if line.strip() == '': continue
      if (state != 'start' and state != 'assert') and not re.search("^\s",line):
        close_stmt(res,state, line)
        state = 'start'

      if state == 'start' and line.find("proc!") == 0:
        open_proc(res,line.replace('proc! ', 'function %s.' % ns))
        state = 'pr!'
      elif state == 'start' and line.find("proc") == 0:
        open_proc(res,line.replace('proc ', 'function %s.' % ns))
        state = 'pr'
      elif state == 'start' and line.find("func!") == 0:
        open_fn(res,line.replace('func! ', 'function %s.' % ns))
        state = 'fn!'
      elif state == 'start' and line.find("func") == 0:
        open_fn(res,line.replace('func ', 'function %s.' % ns))
        state = 'fn'
      elif state == 'start' and line.find("expect_raise") == 0:
        open_expect_raise(res,nm, idx, line)
        state = 'expect_raise'
      elif state == 'start' and line.find("expect") == 0:
        open_assert(res,nm, idx, line)
        state = 'assert'
      elif state == 'assert' and line.find("=>") == 0:
        close_stmt(res,state, line)
        state = 'start'
      elif state == 'start' and line.find(' => ') > 0:
        inline_assert(res,nm, idx, line)
      elif state == 'start' and line.find('setv') == 0:
        res.append('SELECT %s' % line.replace('setv','vars.setv'))
      elif state == 'start' and line.find('delv') == 0:
        res.append('SELECT %s' % line.replace('delv','vars.delv'))
      elif line != '\n':
        if line.find('\\') == 0 or line.find('$SQL') > -1:
            res.append(macroexpand(nm, ns, idx, line))
        else:
            res.append("%s -- %s:%s" % (macroexpand(nm, ns, idx, line.rstrip()), ns, idx))

    if state != 'start':
      close_stmt(res,state, '')

    return "\n".join(res)
