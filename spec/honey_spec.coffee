sql = require('../src/honey')

q1 =
 res: ['SELECT $1 , logical_id FROM "patient" WHERE logical_id = $2', 'Patient', 1]
 exp:
  select: ['Patient',':logical_id'],
  from: ['patient']
  where: [':=',':logical_id', 1]

q2 =
  res: ['SELECT * FROM "patient" p , "users" u WHERE ( logical_id = $1 AND version_id = $2 )','x','y']
  exp:
   select: [':*']
   from: [['patient', 'p'], ['users', 'u']],
   where: [':and',[':=',':logical_id', 'x'], [':=', ':version_id', 'y']]

qjoin =
   res: ['SELECT * FROM "patient" p JOIN "encounter" e ON e.name = p.name JOIN "another" a ON a.name = e.name WHERE ( p.name = $1 AND a.name = $2 AND e.name = $3 )', 4 ,4 ,4]
   exp:
    select: [':*']
    from: [['patient', 'p']]
    join: [
      [['encounter', 'e']
       [':=',':e.name',':p.name']]
      [['another', 'a']
       [':=',':a.name',':e.name']]]
    where: [':and'
      [':=',':p.name',4]
      [':=',':a.name',4]
      [':=',':e.name',4]]

ddl =
  res: ["CREATE TABLE \"resource\" ( \"content\" jsonb PK , \"logical_id\" text , \"published\" timestamp with time zone ) INHERITS ( \"parent\" )"]
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

ddl3 =
  res: ["CREATE TABLE \"resource\" ( ) INHERITS ( \"parent\" )"]
  exp:
    create: "table"
    name: "resource"
    inherits: ["parent"]

ddl4 =
  res: ["CREATE TABLE \"history\".\"resource\" ( ) INHERITS ( \"parent\" )"]
  exp:
    create: "table"
    name: ["history","resource"]
    inherits: ["parent"]

insert =
  res: ['INSERT INTO "history"."users" ( a , b , c ) VALUES ( $1 , $2 , CURRENT_TIMESTAMP )', 1, 'string']
  exp:
     insert: 'history.users'
     values:  {a: 1, b: 'string', c: '^CURRENT_TIMESTAMP'}
     returning: ['id']

insert_ns =
  res: ['INSERT INTO "history"."users" ( a , b , c ) VALUES ( $1 , $2 , CURRENT_TIMESTAMP )', 1, 'string']
  exp:
     insert: ['history','users']
     values:  {a: 1, b: 'string', c: '^CURRENT_TIMESTAMP'}
     returning: ['id']

insert_obj =
  res: ['INSERT INTO "history"."users" ( obj ) VALUES ( $1 )', '{"a":1}']
  exp:
     insert: 'history.users'
     values:  {obj: {a: 1}}
     returning: ['id']

insert2 =
  res: ['INSERT INTO users ( a , b , c) VALUES ( $1 , $2 , CURRENT_TIMESTAMP )', 1, 'string']
  exp:
     insert: 'users'
     values:  [{a: 1, b: 'string', c: '^CURRENT_TIMESTAMP'}]
     returning: ['id']

update =
  res: ['UPDATE "users" SET a = $1 , b = CURRENT_TIMESTAMP WHERE id = $2', 1, 2]
  exp:
    update: 'users'
    values:  {a: 1, b: '^CURRENT_TIMESTAMP'}
    where: [':=', ':id', 2]

update_simple_where =
  res: ['UPDATE "users" SET a = $1 , b = CURRENT_TIMESTAMP WHERE ( id = $2 AND version_id = $3 )', 1, 2, 3]
  exp:
    update: 'users'
    values:  {a: 1, b: '^CURRENT_TIMESTAMP'}
    where: {id: 2, version_id: 3}

delete_from =
  res: ['DELETE FROM "users" WHERE ( id = $1 )', 1]
  exp:
    delete: 'users'
    where: {id: 1}

select_fn_call =
 res: ['SELECT * FROM "patient" WHERE ( extract_as_string_array ( resource , $1 , $2 ) )::text[] && ARRAY[ $3 , $4 ]::text[]', '["name"]', 'HumanName', 'nicola','ivan']
 exp:
  select: [':*']
  from: ['patient']
  where: ['^&&'
      {call: 'extract_as_string_array', args: [':resource', '["name"]', 'HumanName'], cast: 'text[]' }
      {value: ['nicola','ivan'], array:true, cast: 'text[]'}
  ]

tests = [q1, q2, qjoin, ddl, ddl2, ddl3, ddl4, insert, insert_ns, insert_obj, update, update_simple_where, delete_from, select_fn_call]

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
