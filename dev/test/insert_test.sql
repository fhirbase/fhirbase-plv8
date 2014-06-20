--db:fhirb -e
--{{{
\set obs `curl http://www.hl7.org/implement/standards/fhir/observation-example-f001-glucose.json`
\set uuid '550e8400-e29b-41d4-a716-446655440000'
\set tags '[{"scheme": "fhir.com", "term": "term", "label": "label"}]'
\set new_tags '[{"scheme": "fhir.com", "term": "term", "label": "label"}, {"scheme": "fhir.com2", "term": "term2", "label": "label2"}]'

BEGIN;

SELECT count(*) FROM observation where logical_id = :'uuid';

SELECT insert_resource(:'uuid'::uuid, :'obs'::jsonb, :'tags'::jsonb);

SELECT count(*) FROM observation where logical_id = :'uuid';

SELECT update_resource(:'uuid'::uuid, :'obs'::jsonb, :'new_tags'::jsonb);

SELECT count(*) FROM observation_history where logical_id = :'uuid';

SELECT delete_resource(:'uuid'::uuid, 'observation');

SELECT count(*) FROM observation where logical_id = :'uuid';

SELECT count(*) FROM observation_history where logical_id = :'uuid';

ROLLBACK;
--}}}

