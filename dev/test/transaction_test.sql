SET escape_string_warning=off;

\set cfg '{"base":"https://test.me"}'
\set alert `cat test/fixtures/alert.json`
\set bundle `cat test/fixtures/bundle.json`

BEGIN;

  WITH previous AS (
    SELECT
      fhir_create(:'cfg', 'Alert', :'alert'::jsonb, '[]'::jsonb)#>>'{entry,0,id}' AS update_id,
      fhir_create(:'cfg', 'Alert', :'alert'::jsonb, '[]'::jsonb)#>>'{entry,0,id}' AS delete_id
  ), bundle AS (
    SELECT
      p.*,
      replace(replace(:'bundle', '@previous-note', p.update_id), '@delete-note', p.delete_id) as bundle
    FROM previous p
  ), trans AS (
    SELECT
      b.update_id,
      b.delete_id,
      fhir_transaction(:'cfg', b.bundle::jsonb) as bundle
    FROM bundle b
  ), expanded AS (
    SELECT
      t.update_id,
      t.delete_id,
      t.bundle,
      t.bundle#>>'{entry,0,id}' as created_id,
      t.bundle#>>'{entry,1,id}' as updated_id,
      t.bundle#>>'{entry,2,id}' as deleted_id
    FROM trans t
  ), testing AS (
    SELECT
      e.*,
      fhir_read(:'cfg', 'Alert', e.created_id::uuid) as created,
      fhir_read(:'cfg', 'Alert', e.updated_id::uuid) as updated,
      fhir_read(:'cfg', 'Alert', e.deleted_id::uuid) as deleted
    FROM expanded e
  )

  SELECT
    assert_eq(
      t.update_id,
      t.updated_id,
      'update_id == updated_id'),
    assert_eq(
      t.delete_id,
      t.deleted_id,
      'delete_id & deleted_id'),
    assert_eq(
     t.bundle->>'totalResults',
      '3',
      'totalResults'),
    assert_eq(
      t.created#>>'{entry,0,content,note}',
      'create-note',
      'created note'),
    assert_eq(
      t.updated#>>'{entry,0,content,note}',
      'current-note',
      'updated note'),
    assert_eq(
      t.updated#>>'{entry,0,content,note}',
      'current-note',
      'updated note')
  FROM testing t;

ROLLBACK;
