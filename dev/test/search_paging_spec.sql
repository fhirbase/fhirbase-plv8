BEGIN;
truncate __vars;

setv('cfg','{"base":"https://test.me"}'::jsonb);

setv('pt-tpl', '{"resourceType":"Patient", "gender":"%s", "birthDate":"%s"}');

SELECT fhir_create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1970')::jsonb);
SELECT fhir_create(getv('cfg'), format(getv('pt-tpl')::text, 'mail', '1980')::jsonb);
SELECT fhir_create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1985')::jsonb);
SELECT fhir_create(getv('cfg'), format(getv('pt-tpl')::text, 'femail', '1990')::jsonb);

SELECT build_search_query('Patient', '_count=50&_page=3');

SELECT build_search_query('Patient','_count=50&_page=3&_sort=birthdate');

SELECT build_search_query('Patient', '_count=1');

SELECT count(*) FROM search('Patient', '_count=1') => 1::bigint
SELECT count(*) FROM search('Patient', '_count=2') => 2::bigint
SELECT count(*) FROM search('Patient', '_count=3') => 3::bigint



SELECT content->>'birthDate' FROM search('Patient', '_count=1&_sort=birthdate') => '1970'
SELECT content->>'birthDate' FROM search('Patient', '_count=1&_sort:desc=birthdate') => '1990'
SELECT content->>'birthDate' FROM search('Patient', '_sort:desc=gender&_count=1&_page=1&_sort:desc=birthdate') => '1970'

ROLLBACK;

