assert = (x, msg)->
  unless x
    throw new Error(msg)

exports.outcome = (issues, message)->
  outcome =
    resourceType: "OperationOutcome"
    issue: issues
  # TODO validate
  outcome

exports.error = (issue)->
  issue.severity = "error"
  assert(issue.code, 'Issue.code expected')
  assert(issue.diagnostics, 'Issue.diagnostics expected')
  exports.outcome([issue])

exports.not_found = (id)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      details: { coding: [{code: 'MSG_NO_EXIST', display: 'Resource Id "%s" does not exist'}]}
      diagnostics: "Resource Id \"#{id}\" does not exist"
    }
  ]
# console.log(exports.error(code: 'invalid', diagnostics: 'Ups'))
