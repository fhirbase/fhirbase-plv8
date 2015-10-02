assert = (x, msg)->
  unless x
    throw new Error(msg)

exports.outcome = (issues)->
  outcome =
    resourceType: "OperationOutcome"
    text: {status: "TODO", div: '<div>TODO</div>'}
    issue: issues
  # TODO validate
  outcome

exports.error = (issue)->
  issue.severity = "error"
  assert(issue.code, 'Issue.code expected')
  assert(issue.diagnostics, 'Issue.diagnostics expected')
  exports.outcome([issue])

# console.log(exports.error(code: 'invalid', diagnostics: 'Ups'))
