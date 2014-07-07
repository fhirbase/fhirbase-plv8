--db:fhirb -e
SET escape_string_warning=off;
--{{{
\set pt `cat test/fixtures/pt.json`
\set pt2 `cat test/fixtures/pt2.json`
\set pt_tags  '[{"scheme": "http://pt.com", "term": "http://pt/vip", "label":"pt"}]'


BEGIN;

 select assert_eq(
  fhir_read('Patient',
    (fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb)#>>'{entry,0,id}')::uuid)#>>'{entry,0,content,name,0,text}',
    'Roel',
    'fhir_create & fhir_read');


 select assert_eq(
  fhir_vread('Patient',
             (x#>>'{entry,0,id}')::uuid,
             _get_vid_from_url(x#>>'{entry,0,link,0,href}')::uuid
     )#>>'{entry,0,content,name,0,text}',
    'Roel',
    'fhir_create & fhir_vread')
  FROM fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb) x;


 WITH created AS (
    SELECT fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
 ), updated AS (
    SELECT fhir_update('Patient',
            (x.entry#>>'{entry,0,id}')::uuid,
            _get_vid_from_url(x.entry#>>'{entry,0,link,0,href}')::uuid,
            :'pt'::jsonb,
            :'pt_tags'::jsonb) AS entry
    FROM created x
 ), vread AS (
  SELECT fhir_vread('Patient',
             (x.entry#>>'{entry,0,id}')::uuid,
             _get_vid_from_url(x.entry#>>'{entry,0,link,0,href}')::uuid
     ) as v
  FROM updated x
)
 select assert_eq((x.v)#>>'{entry,0,content,name,0,text}',
    'Roel',
    'fhir_update & fhir_vread')
  FROM vread x;


-- test delete
WITH created AS (
  SELECT fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), deleted AS (
SELECT fhir_delete('Patient', (x.entry#>>'{entry,0,id}')::uuid) as entry
 FROM created x
)
SELECT assert_eq(fhir_read('Patient', (c.entry#>>'{entry,0,id}')::uuid)#>>'{entry,0}',
  NULL, 'deleted')
from created c, deleted x
;


-- test history
WITH created AS (
  SELECT fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), updated AS (
  SELECT fhir_update('Patient',
           (x.entry#>>'{entry,0,id}')::uuid,
           _get_vid_from_url(x.entry#>>'{entry,0,link,0,href}')::uuid,
           :'pt'::jsonb,
           :'pt_tags'::jsonb) AS entry
   FROM created x
), history AS (
  SELECT fhir_history('Patient', (x.entry#>>'{entry,0,id}')::uuid, '{}'::jsonb) as hx
  FROM updated x
)
SELECT assert_eq(
  jsonb_array_length(h.hx->'entry'),
  2, 'history')
  from history h;


-- test history
WITH roel AS (
  SELECT fhir_create('Patient', :'pt'::jsonb, :'pt_tags'::jsonb) AS entry
), not_roel AS (
  SELECT fhir_create('Patient', :'pt2', :'pt_tags'::jsonb) AS entry
), searched AS (
  SELECT fhir_search('Patient', '{"name":"roel"}'::jsonb) as bundle
)
SELECT assert(jsonb_array_length(s.bundle#>'{entry}') > 0, 'search')
FROM roel, not_roel, searched s;

ROLLBACK;
--}}}
