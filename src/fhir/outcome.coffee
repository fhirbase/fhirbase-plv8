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

exports.is_not_found = (outcome)->
  outcome && outcome.issue && outcome.issue[0] && outcome.issue[0].code == 'not-found'

exports.not_found = (id)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      details: {
        coding: [
          {
            code: 'MSG_NO_EXIST',
            display: "Resource Id \"#{id}\" does not exist"
          }
        ]
      }
      diagnostics: "Resource Id \"#{id}\" does not exist"
    }
  ]

exports.version_not_found = (id, versionId)->
  resourceType: 'OperationOutcome'
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      details: {
        coding: [
          {
            code: 'MSG_NO_EXIST',
            display: "Resource Id \"#{id}\" does not exist"
          }
        ]
      }
      diagnostics: "Resource Id \"#{id}\" with versionId \"#{versionId}\" does not exist"
    }
  ]

exports.non_selective = (msg)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: '412'
      diagnostics: "Precondition Failed error indicating the client's criteria were not selective enough. #{msg}"
    }
  ]

exports.conflict = (msg)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: '409'
      diagnostics: msg
    }
  ]

exports.valueset_not_found = (id)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      diagnostics: "ValueSet with id \"#{id}\" does not exist or not supported"
    }
  ]

exports.bad_request = (msg)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: '400'
      diagnostics: (msg || "Bad Request")
    }
  ]

exports.unknown_type = (resourceType)->
  resourceType: 'OperationOutcome'
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      details: {
        coding: [
          {
            code: 'MSG_UNKNOWN_TYPE',
            display: "Resource Type \"#{resourceType}\" not recognised"
          }
        ]
      }
      diagnostics: "Resource Type \"#{resourceType}\" not recognised." +
        " Try create \"#{resourceType}\" resource:" +
        " `SELECT fhir_create_storage('{\"resourceType\": \"#{resourceType}\"}');`"
    }
  ]

exports.truncate_storage_done = (resourceType, count)->
  resourceType: 'OperationOutcome'
  issue: [
    {
      severity: 'information'
      code: 'informational'
      details: {
        coding: [
          {
            code: 'MSG_DELETED_DONE',
            display: "Resource deleted"
          }
        ]
      }
      diagnostics: "Resource type \"#{resourceType}\" has been truncated." +
        " #{count} rows affected."
    }
  ]
