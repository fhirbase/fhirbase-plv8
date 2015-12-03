utils = require('../core/utils')
outcome = require('./outcome')

exports.fhir_expand_valueset = (plv8, query)->
  cond = ['$and', ['$eq',':valueset_id',query.id]]

  existance = utils.exec plv8,
    select: [':valueset_id']
    from: ':_valueset_expansion'
    where: cond
    limit: 1

  unless existance.length == 1
    return outcome.valueset_not_found(query.id)

  if query.filter
    cond.push ['$or', ['$ilike', ':display', "%#{query.filter}%"]
                      ['$ilike', ':code', "%#{query.filter}%"]]


  rows = utils.exec plv8,
    select: [':code', ':display', ':system']
    from: ':_valueset_expansion'
    where: cond
    order: [':system', ':parent_code', ':code']

  id: query.id
  resourceType: 'ValueSet'
  expansion:
    contains: rows

exports.fhir_expand_valueset.plv8_signature = ['json', 'json']


EXPAND_CODE_SYSTEMS_SQL = """
  WITH RECURSIVE concepts(vid, system, parent_code, concept, children) AS (
      SELECT  vid, system, parent_code, concept, concept->'concept'
      FROM (
        SELECT
          id as vid,
          resource#>>'{codeSystem,system}' as system,
          null::text as parent_code,
          jsonb_array_elements(resource#>'{codeSystem,concept}') as concept
        FROM valueset
        WHERE jsonb_typeof(resource#>'{codeSystem}') IS NOT NULL
        AND id = $1
      ) _

      UNION ALL
      SELECT
        vid, system, parent_code, next, next->'concept' as children from (
          select vid, system, concept->>'code' as parent_code, jsonb_array_elements(children) as next
          from concepts c
          where jsonb_typeof(children) is not null
      )  _
  )
  INSERT INTO _valueset_expansion (valueset_id, system, parent_code, code, display)
  SELECT
  vid, system, parent_code, concept->>'code' as code, concept->>'display' as display
  FROM concepts
"""

EXPAND_INCLUDES_SQL = """
  WITH concepts(vid, system, parent_code, concept) AS (
    SELECT vid, system as system, null::text as parent_code, concept as concept
    FROM (
        SELECT
          vid,
          include->>'system' as system,
          jsonb_array_elements(include#>'{concept}') as concept
          FROM (
            SELECT
              id as vid,
              resource#>>'{codeSystem,system}' as system,
              null::text as parent_code,
              jsonb_array_elements(resource#>'{compose,include}') as include
            FROM valueset
            WHERE jsonb_typeof(resource#>'{compose,include}') IS NOT NULL
            AND id = $1
          ) _
      ) _
  )
  INSERT INTO _valueset_expansion (valueset_id, system, parent_code, code, display)
  SELECT
    vid, system, parent_code, concept->>'code' as code, concept->>'display' as display
  FROM concepts
"""

exports.fhir_valueset_after_changed = (plv8, resource)->
  return unless resource.id
  res = plv8.execute "DELETE FROM _valueset_expansion WHERE valueset_id = $1", [resource.id]
  res = plv8.execute EXPAND_CODE_SYSTEMS_SQL, [resource.id]
  res = plv8.execute EXPAND_INCLUDES_SQL, [resource.id]

exports.fhir_valueset_after_changed.plv8_signature = ['json', 'json']
