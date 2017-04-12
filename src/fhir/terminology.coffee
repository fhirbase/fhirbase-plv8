utils = require('../core/utils')
compat = require('../compat')
outcome = require('./outcome')

exports.fhir_expand_valueset = (plv8, query)->
  cond = ['$and', ['$eq',':valueset_id',query.id.toString()]]

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


  valueset = utils.exec plv8,
    select: [":resource->'status' as status", ':expanded_at', ":resource->'url' as url", ":expanded_id"]
    from: [':valueset'],
    where: ['$eq', ':id', "#{query.id}"],
    limit: 1

  rows = utils.exec plv8,
    select: [':code', ':display', ':system']
    from: ':_valueset_expansion'
    where: cond
    order: [':system', ':parent_code', ':code']

  id: query.id
  resourceType: 'ValueSet'
  status: valueset[0].status,
  expansion:
    identifier: valueset[0].url + '/' + valueset[0].expanded_id
    timestamp: valueset[0].expanded_at
    total: rows.length
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

# this impl raise out of memory 
# exports.fhir_valueset_after_changed = (plv8, resource)->
#   return unless resource.id
#   res = plv8.execute "DELETE FROM _valueset_expansion WHERE valueset_id = $1", [resource.id]
#   res = plv8.execute EXPAND_CODE_SYSTEMS_SQL, [resource.id]
#   res = plv8.execute EXPAND_INCLUDES_SQL, [resource.id]

# exports.fhir_valueset_after_changed.plv8_signature = ['json', 'json']

_create_concept = (plv8, acc, props, parent, concept)->
  acc.push
    valueset_id: props.valueset_id
    system: props.system
    parent_code: parent.code
    code: concept.code
    display: concept.display
    abstract: concept.abstract
    definition: concept.definition
    designation: JSON.stringify(concept.designation)
    extension: JSON.stringify(concept.extension)

  for ch in (concept.concept || [])
    _create_concept(plv8, acc, props, concept, ch)

_remove_concept = (plv8, acc, system, code)->
    acc.forEach (item, idx)->
        if system && item.system == system && item.code == code
           acc.splice(idx, 1)

_expand_resource = (plv8, acc, vid, resource)->
  codeSystem = resource.codeSystem
  for concept in ((codeSystem && codeSystem.concept) || [])
    _create_concept(plv8, acc, {valueset_id: vid, system: codeSystem.system}, {}, concept)

  for inc in  ((resource.compose && resource.compose.include) || [])
    for concept in (inc.concept || [])
      _create_concept(plv8, acc, {valueset_id: vid, system: inc.system}, {}, concept)
    if inc.system
      syst = utils.exec plv8,
        select: [':*']
        from: ':codesystem'
        where: ['$eq', ":resource->>'url'", inc.system]
        limit: 1
      syst_res = (syst[0] && syst[0].resource)
      for concept in ((syst_res && syst_res.concept) || [])
        _create_concept(plv8, acc, {valueset_id: vid, system: inc.system}, {}, concept)

  if resource.compose && resource.compose.import
      imports = resource.compose.import
      if typeof imports == 'string'
          imports = [imports]
      for imp in imports
        syst = utils.exec plv8,
          select: [':*']
          from: ':valueset'
          where: ['$eq', ":resource->>'url'", imp]
          limit: 1
        syst_res = (syst[0] && syst[0].resource)
        if syst_res
            _expand_resource(plv8, acc, vid, syst_res)
        else
            plv8.elog(NOTICE, "import not found", imp);


  for exc in ((resource.compose && resource.compose.exclude) || [])
      for concept in (exc.concept || [])
        _remove_concept(plv8, acc, exc.system, concept.code)

_expand_valueset = (plv8, resource)->
  acc = []

  plv8.execute "UPDATE valueset SET expanded_at=now(), expanded_id=gen_random_uuid() WHERE id=$1", [resource.id]
  _expand_resource(plv8, acc, resource.id, resource)

  res = plv8.execute """
    INSERT INTO _valueset_expansion
      (valueset_id, system, parent_code, code, display, abstract, definition, designation, extension)
    SELECT
      x->>'valueset_id',
      x->>'system',
      x->>'parent_code',
      x->>'code',
      x->>'display',
      (x->>'abstract')::boolean,
      x->>'definition',
      (x->'designation')::jsonb,
      (x->'extension')::jsonb
    FROM json_array_elements($1::json) x
  """, [JSON.stringify(acc)]

exports.fhir_valueset_after_changed = (plv8, resource)->
  return unless resource.id
  utils.exec plv8,
    delete: ':_valueset_expansion'
    where: {valueset_id: resource.id}

  _expand_valueset(plv8, resource)

exports.fhir_valueset_after_changed.plv8_signature = ['json', 'json']

exports.fhir_valueset_after_deleted = (plv8, resource)->
  return unless resource.id
  utils.exec plv8,
    delete: ':_valueset_expansion'
    where: {valueset_id: resource.id}

exports.fhir_valueset_after_deleted.plv8_signature = ['json', 'json']

exports.fhir_expand_all_valuesets = (plv8)->
    utils.exec plv8,
        delete: ':_valueset_expansion'
    vals = utils.exec plv8,
          select: [':*']
          from: ':valueset'
    for valueset in (vals)
        _expand_valueset(plv8, valueset.resource)

exports.fhir_expand_all_valuesets.plv8_signature =
    returns: 'void'
    arguments: ''
    immutable: false
    runnable: true
