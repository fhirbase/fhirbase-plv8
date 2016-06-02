plv8 = require('../../plpl/src/plv8')
outcome = require('../../src/fhir/outcome')
assert = require('assert')
helpers = require('../helpers.coffee')

describe 'OperationOutcome', ->
  it 'should have issues with "diagnostics" property', ->
    outcomeFunctions = Object.keys(outcome)
    for name in ['outcome', 'error', 'is_not_found']
      outcomeFunctions.splice(outcomeFunctions.indexOf(name), 1)

    for name in outcomeFunctions
      for issue in outcome[name].apply(this, ['foo', 'bar', 'baz', 'xyz']).issue
        unless issue.diagnostics
          assert(
            false,
            "Function #{name}(...) should returns OperationOutcome " +
              'with issues and each issue should contains ' +
              '"diagnostics" property but return: ' +
              JSON.stringify(issue, null, 2)
          )
