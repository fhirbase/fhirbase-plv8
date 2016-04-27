# OperationOutcome.issue[].code <https://hl7-fhir.github.io/valueset-issue-type.html#expansion>.
# OperationOutcome.issue[].details.coding[].code <https://hl7-fhir.github.io/valueset-operation-outcome.html#expansion>.

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
      extension: [{url: 'http-status-code', valueString: '404'}]
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
      extension: [{url: 'http-status-code', valueString: '404'}]
    }
  ]

exports.version_deleted = (id, versionId)->
  resourceType: 'OperationOutcome'
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      details: {
        coding: [
          {
            code: 'MSG_DELETED_ID',
            display: "The resource \"#{id}\" has been deleted"
          }
        ]
      }
      diagnostics: "Resource Id \"#{id}\" with versionId \"#{versionId}\" has been deleted"
      extension: [{url: 'http-status-code', valueString: '410'}]
    }
  ]

exports.non_selective = (msg)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: '412'
      diagnostics: "Precondition Failed error indicating the client's criteria were not selective enough. #{msg}"
      extension: [{url: 'http-status-code', valueString: '412'}]
    }
  ]

exports.conflict = (msg)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: '409'
      diagnostics: msg
      extension: [{url: 'http-status-code', valueString: '409'}]
    }
  ]

exports.valueset_not_found = (id)->
  resourceType: "OperationOutcome"
  issue: [
    {
      severity: 'error'
      code: 'not-found'
      diagnostics: "ValueSet with id \"#{id}\" does not exist or not supported"
      extension: [{url: 'http-status-code', valueString: '404'}]
    }
  ]

exports.bad_request = (diagnostics)->
  resourceType: 'OperationOutcome'
  issue: [
    {
      severity: 'error'
      code: 'invalid'
      diagnostics: (diagnostics || 'Bad Request')
      extension: [{url: 'http-status-code', valueString: '400'}]
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
      extension: [{url: 'http-status-code', valueString: '404'}]
    }
  ]

exports.truncate_storage_done = (resourceType)->
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
      diagnostics: "Resource type \"#{resourceType}\" has been truncated"
      extension: [{url: 'http-status-code', valueString: '200'}]
    }
  ]
