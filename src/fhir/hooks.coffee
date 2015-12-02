utils = require('../core/utils')

SYSTEM_HOOKS = {

}

HOOK_CACHE = null

load_hooks = (plv8)->
  return HOOK_CACHE if HOOK_CACHE
  rows = utils.exec plv8,
    select: ':*'
    from: ':_fhirbase_hook'
    order: [':function_name', ':phase', ':weight']
  res = {}
  for row in rows
    res[row.function_name] = res[row.function_name] || {}
    res[row.function_name][row.phase] = res[row.function_name][[row.phase]] || []
    res[row.function_name][row.phase].push(row)
  HOOK_CACHE = res

exports.load_hooks = load_hooks

exports.fhir_clear_hooks = (plv8, hook)->
  utils.exec plv8,
    delete: ':_fhirbase_hook'
    where: ['$ne', ':system', true]

exports.fhir_register_hook = (plv8, hook)->
  utils.exec plv8,
    insert: ':_fhirbase_hook'
    values: hook
    returning: ':*'

exports.fhir_clear_hook = (plv8, q)->
  utils.exec plv8,
    delete: ':_fhirbase_hook'
    where: {id: q.id}
    returning: ':*'

fhir_resolve_hook = (plv8, hook)->
  utils.exec plv8,
    select: ':*'
    from: ':_fhirbase_hook'
    where: {function_name: hook.function_name, phase: hook.phase}
    order: [':weight']


exports.fhir_resolve_hook = fhir_resolve_hook

exports.wrap_hook = (plv8, hook, data)->
  hook = fhir_resolve_hook(plv8, hook)
  return unless hook
  current = data
  for h in (hook || [])
    rows = plv8.execute("SELECT #{h.hook_function_name}($1::json) res", [JSON.stringify(current)])
    current = rows[0] && rows[0].res
  JSON.parse(current) if current
