--db:fhirb -e
SET escape_string_warning=off;
--{{{
\set cfg '{"base":"https://test.me"}'
\set pt `cat test/fixtures/pt.json`
\set pt2 `cat test/fixtures/pt2.json`
\set pt_tags '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'
\set alert `cat test/fixtures/alert.json`

BEGIN;

 WITH reading AS (
   SELECT
     created.created#>>'{entry,0,id}' as id,
     fhir_read(:'cfg', 'Patient', created.created#>>'{entry,0,id}') as bundle
   FROM fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) created
 )

 SELECT
   assert_eq(
     r.bundle#>>'{entry,0,content,name,0,text}',
     'Roel',
     'fhir_create & fhir_read'),
   assert_eq(
     r.bundle#>>'{entry,0,id}',
     r.id,
     'fhir_read entry id'),
   assert_eq(
     _build_id(:'cfg', 'Patient', _extract_id(r.id)::uuid),
     r.id::varchar,
     'id format')
 FROM reading r;

 SELECT assert_eq(
  fhir_vread(:'cfg', 'Patient', x#>>'{entry,0,link,0,href}')#>>'{entry,0,content,name,0,text}',
    'Roel',
    'fhir_create & fhir_vread')
  FROM fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) x;

 WITH created AS (
    SELECT fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
 ), updated AS (
    SELECT fhir_update(:'cfg', 'Patient',
            (x.entry#>>'{entry,0,id}'),
            x.entry#>>'{entry,0,link,0,href}',
            :'pt'::jsonb,
            :'pt_tags'::jsonb) AS entry
    FROM created x
 ), vread AS (
  SELECT fhir_vread(:'cfg', 'Patient', x.entry#>>'{entry,0,link,0,href}') as v
  FROM updated x
 )
 select assert_eq((x.v)#>>'{entry,0,content,name,0,text}',
    'Roel',
    'fhir_update & fhir_vread')
  FROM vread x;

-- test delete
WITH created AS (
  SELECT fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), deleted AS (
SELECT fhir_delete(:'cfg', 'Patient', x.entry#>>'{entry,0,id}') as entry
 FROM created x
)
SELECT assert_eq(fhir_read(:'cfg', 'Patient', c.entry#>>'{entry,0,id}')#>>'{entry,0}',
  NULL, 'deleted')
from created c, deleted x
;


-- test history
WITH created AS (
  SELECT fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), updated AS (
  SELECT fhir_update(:'cfg', 'Patient',
           x.entry#>>'{entry,0,id}',
           x.entry#>>'{entry,0,link,0,href}',
           :'pt'::jsonb,
           :'pt_tags'::jsonb) AS entry
   FROM created x
), history AS (
  SELECT fhir_history(:'cfg', 'Patient', x.entry#>>'{entry,0,id}', '{}'::jsonb) as hx
  FROM updated x
)
SELECT assert_eq(
  jsonb_array_length(h.hx->'entry'),
  2, 'history')
  from history h;


-- test history
WITH roel AS (
  SELECT fhir_create(:'cfg', 'Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), not_roel AS (
  SELECT fhir_create(:'cfg', 'Patient', :'pt2', :'pt_tags'::jsonb) AS entry
), searched AS (
  SELECT fhir_search(:'cfg', 'Patient', 'name=roel') as bundle
)
SELECT assert(jsonb_array_length(s.bundle#>'{entry}') > 0, 'search')
FROM roel, not_roel, searched s;

-- test update version_id
WITH previous AS (
  SELECT
    alert.alert#>>'{entry,0,id}' AS id,
    alert.alert#>>'{entry,0,link,0,href}' AS vid
  FROM fhir_create(:'cfg', 'Alert', :'alert'::jsonb, '[]'::jsonb) alert
), updated AS (
  SELECT
    p.id,
    p.vid,
    _get_vid_from_url(
      fhir_update(:'cfg', 'Alert', p.id, p.vid, :'alert'::jsonb, '[]'::jsonb)
    #>>'{entry,0,link,0,href}') AS new_vid
  FROM previous p
)

SELECT assert_raise(
  'Wrong version_id ' || _get_vid_from_url(u.vid) || '.Current is ' || _get_vid_from_url(u.new_vid),
  'SELECT fhir_update(''' || :'cfg' || ''', ''Alert'', ''' || u.id || ''', ''' || u.vid || ''', ''' || :'alert' || ''', ''[]''::jsonb)',
  'update with no current version_id')
FROM updated u;

ROLLBACK;
--}}}
