SET escape_string_warning=off;

\set cfg '{"base":"https://test.me"}'
\set alert `cat test/fixtures/alert.json`
\set device `cat test/fixtures/device.json`
\set bundle `cat test/fixtures/bundle.json`
\set tags '[{"scheme": "http://hl7.org/fhir/tag", "term": "sound", "label": "noise"}]'

BEGIN;
  WITH previous AS (
    SELECT
      c.alert#>>'{entry,0,id}' AS update_id,
      _get_vid_from_url(c.alert#>>'{entry,0,link,0,href}') AS update_vid,
      c.device#>>'{entry,0,id}' AS delete_id
    FROM (
      SELECT
        fhir_create(:'cfg', 'Alert', :'alert'::jsonb, :'tags'::jsonb) as alert,
        fhir_create(:'cfg', 'Device', :'device'::jsonb, '[]'::jsonb) as device
    ) c
  ), bundle AS (
    SELECT
      p.*,
      replace(replace(replace(:'bundle', '@update-alert', p.update_id), '@delete-device', p.delete_id), '@update-vid-alert', p.update_vid) as bundle
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
      fhir_read(:'cfg', 'Device', e.created_id::uuid) as created,
      fhir_read(:'cfg', 'Alert', e.updated_id::uuid) as updated,
      fhir_read(:'cfg', 'Device', e.deleted_id::uuid) as deleted
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
      '3',
      t.bundle->>'totalResults',
      'totalResults')
  FROM testing t
  UNION ALL
  SELECT
    assert_eq(
      'ECG',
      t.created#>>'{entry,0,content,type,text}',
      'created device'),
    assert_eq(
      'current-note',
      t.updated#>>'{entry,0,content,note}',
      'updated note'),
    assert_eq(
      NULL,
      t.deleted->>'entry',
      'updated device')
  FROM testing t
  UNION ALL
  SELECT
    assert_eq(
      t.created_id,
      t.updated#>>'{entry,0,content,subject,reference}',
      'update created reference'),
    assert_eq(
      t.deleted_id,
      t.updated#>>'{entry,0,content,author,reference}',
      'update deleted reference'),
    assert_eq(
      'noise',
      t.created#>>'{entry,0,category,0,label}',
      'created tag')
  FROM testing t
  UNION ALL
  SELECT
    assert_eq(
      '{noise,silence}',
      (SELECT array_agg(e.value->>'label' ORDER BY e.value->>'label')
        FROM jsonb_array_elements(t.updated#>'{entry,0,category}') e),
      'original and updated tags'),
    null,
    null
  FROM testing t;

ROLLBACK;
