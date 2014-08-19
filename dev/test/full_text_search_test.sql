SET escape_string_warning=off;

\set cfg '{"base":"https://test.me"}'
\set alert `cat test/fixtures/alert.json`

BEGIN;

  SELECT assert_eq (
    '(bone | liver) & metastases',
    _text_to_query('(boNe OR liveR) and metastases'),
    'convert text to query');

  WITH alert AS (
    SELECT *
    FROM fhir_create(:'cfg', 'Alert', :'alert'::jsonb, '[]'::jsonb) as bundle
  ), searching AS (
    SELECT a.*,
      fhir_search(:'cfg', 'Alert', '_text=%28previous%20and%20active%20and%20note%29%20OR%20absent_text') as present,
      fhir_search(:'cfg', 'Alert', '_text=absent_text') as absent
    FROM alert a
  )
  SELECT
    assert_eq(
      s.bundle#>>'{entry,0,id}',
      s.present#>>'{entry,0,id}',
      'full text search found'),
    assert_eq(
      0,
      jsonb_array_length(s.absent#>'{entry}'),
      'full text search not found')
  FROM searching s;

ROLLBACK;
