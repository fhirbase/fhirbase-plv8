sql = require('../src/honey')

q1 =
 res: ["SELECT 'Patient', logical_id FROM patient WHERE logical_id = 1"]
 exp:
  select: ['Patient',':logical_id'],
  from: ['patient'],
  where: [':=',':logical_id', 1]

q2 =
  res: ["SELECT * FROM patient p, users u WHERE (logical_id = 'x' AND version_id = 'y')"]
  exp:
   select: [':*']
   from: [['patient', 'p'], ['users', 'u']],
   where: [':and',[':=',':logical_id', 'x'], [':=', ':version_id', 'y']]

qjoin =
   res: ["SELECT * FROM patient p JOIN encounter e ON e.name = p.name JOIN another a ON a.name = e.name WHERE (p.name = 4 AND a.name = 4 AND e.name = 4)"]
   exp:
    select: [':*']
    from: [['patient', 'p']]
    joins: [
      [['encounter', 'e']
       [':=',':e.name',':p.name']]
      [['another', 'a']
       [':=',':a.name',':e.name']]]
    where: [':and'
      [':=',':p.name',4]
      [':=',':a.name',4]
      [':=',':e.name',4]]

ddl =
  res: ["CREATE TABLE \"resource\" ( \"content\" jsonb PK, \"logical_id\" text, \"published\" timestamp with time zone ) INHERITS (\"parent\")"]
  exp: {
     create: "table"
     name: "resource"
     inherits: ["parent"]
     columns:
       content: ["jsonb","PK"]
       logical_id: ["text"]
       published: ["timestamp with time zone"]}

ddl2 =
  res: ['CREATE EXTENSION IF NOT EXISTS plv8']
  exp:
     create: "extension"
     name: "plv8"
     safe: true

insert =
  res: ['INSERT INTO history.users (a, b, c) VALUES ($1, $2, CURRENT_TIMESTAMP)', 1, 'string']
  exp:
     insert: 'history.users'
     values:  {a: 1, b: 'string', c: '^CURRENT_TIMESTAMP'}
     returning: ['id']

insert2 =
  res: ['INSERT INTO users (a, b, c) VALUES ($1, $2, CURRENT_TIMESTAMP)', 1, 'string']
  exp:
     insert: 'users'
     values:  [{a: 1, b: 'string', c: '^CURRENT_TIMESTAMP'}]
     returning: ['id']

tests = [q1, q2, qjoin, ddl, ddl2, insert]

strcmp = (x,y)->
  unless x and y
    return "#{x.length} != #{y.length}"
  x.split('').forEach (l,i)->
    if l != y[i]
      console.log(x.substring(0,i+2))
      console.log(y.substring(0,i+2), '^')
      throw new Error("unmatch")

describe "honey", ()->
  tests.forEach (x)->
    it x.res, ()->
      res = sql(x.exp)
      strcmp(res[0],x.res[0])
      expect(res).toEqual(x.res)
