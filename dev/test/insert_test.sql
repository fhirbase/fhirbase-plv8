--db:fhirb -e
--{{{
\set obs `cat test/fixtures/observation-example-f001-glucose.json`
\set uuid '550e8400-e29b-41d4-a716-446655440000'
\set tags '[{"scheme": "fhir.com", "term": "term", "label": "label"},{"scheme": "fhir.com1", "term": "term1", "label": "label1"}]'
\set new_tags '[{"scheme": "fhir.com", "term": "term", "label": "label"}, {"scheme": "fhir.com2", "term": "term2", "label": "label2"}]'

BEGIN;

SELECT assert(count(*) = 0, 'empty observation') FROM observation where logical_id = :'uuid';
SELECT assert(count(*) = 0, 'empty observation_history') FROM observation_history where logical_id = :'uuid';
SELECT assert(count(*) = 0, 'empty observation_tag') FROM observation_tag where resource_id = :'uuid';
SELECT assert(count(*) = 0, 'empty observation_tag_history') FROM observation_tag_history where resource_id = :'uuid';

SELECT insert_resource(:'uuid'::uuid, :'obs'::jsonb, :'tags'::jsonb);

SELECT assert(count(*) = 1, 'insert: not empty observation') FROM observation where logical_id = :'uuid';
SELECT assert(count(*) = 0, 'insert: empty history') FROM observation_history where logical_id = :'uuid';
SELECT assert(count(*) = 2, 'insert: not empty tags') FROM observation_tag where resource_id = :'uuid';
SELECT assert(count(*) = 0, 'insert: empty tags history') FROM observation_tag_history where resource_id = :'uuid';

SELECT update_resource(:'uuid'::uuid, :'obs'::jsonb, :'new_tags'::jsonb);

SELECT assert(count(*)=1,'update: not empty observation') FROM observation where logical_id = :'uuid';
SELECT assert(count(*)=1,'update: not empty history') FROM observation_history where logical_id = :'uuid';
SELECT assert(count(*)=3,'update: 3 merged tags') FROM observation_tag where resource_id = :'uuid';
SELECT assert(count(*)=2,'update: 2 tags in history') FROM observation_tag_history where resource_id = :'uuid';

SELECT delete_resource(:'uuid'::uuid, 'observation');

SELECT assert(count(*)=0,'delete: empty res') FROM observation where logical_id = :'uuid';
SELECT assert(count(*)=2,'delete: 2 in history') FROM observation_history where logical_id = :'uuid';
SELECT assert(count(*)=0,'delete: 0 in tags') FROM observation_tag where resource_id = :'uuid';
SELECT assert(count(*)=5,'delete: 5 in history tags') FROM observation_tag_history where resource_id = :'uuid';

ROLLBACK;
--}}}
