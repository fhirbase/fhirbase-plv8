hooks = require('../../src/fhir/hooks')
assert = require('assert')
plv8 = require('../../plpl/src/plv8')


describe "hooks", ()->
  before ->
    plv8.execute """
     CREATE OR REPLACE FUNCTION fhir_before_patient_create(data json) returns json
     AS $$
       return {status: 'error', data: data}
     $$ LANGUAGE plv8 IMMUTABLE STRICT;
    """

    hooks.fhir_clear_hooks(plv8)
    hooks.fhir_register_hook plv8,
      function_name: 'fhir_create_resource'
      phase: 'before'
      hook_function_name: 'fhir_before_patient_create'
      weight: 1

  it "hooks", ()->

    i = 0
    while i < 20
      result = hooks.wrap_hook(plv8, {function_name: 'fhir_create_resource', phase: 'before'}, {a: 1})
      assert.deepEqual(result, {status: 'error', data: {a: 1}}) if result
      i++

