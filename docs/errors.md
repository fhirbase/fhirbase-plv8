# read (200, 404, 410)

* GET for a deleted resource returns a 410
* GET for an unknown resource returns 404

# vread (200, 404)

* If the version referred to is actually one where the resource was deleted, the server should return a 410 status code.
* If a request is made for a previous version of a resource, and the server does not support accessing previous versions, it should return a 404 Not Found error, with an operation outcome explaining that history is not supported for the underlying resource type.

# update (200, 201, 400, 404, 405, 409, 412, 422)

* If the interaction is successful, the server SHALL return either a 200 OK HTTP status code if the resource was updated
* or a 201 Created status code if the resource was created
* Conditional updates: Multiple matches: The server returns a 412 Precondition Failed error indicating the the client's criteria were not selective enough
* 400 Bad Request - resource could not be parsed or failed basic FHIR validation rules (or multiple matches were found for
* 404 Not Found - resource type not supported, or not a FHIR end point
* 405 Method Not allowed - the resource did not exist prior to the update, and the serer does not allow client defined ids
* 409/412 - version conflict management - see above
* 422 Unprocessable Entity - the proposed resource violated applicable FHIR profiles or server business rules. This should be accompanied by an OperationOutcome resource providing additional detail

# delete (200, 204, 404, 405, 409, 412)

* Upon successful deletion, or if the resource does not exist at all, the server should return 204 (No Content), or 200 OK status code, with an OperationOutcome resource containing hints and warnings about the deletion; if one is sent it SHALL not include any errors.
* If the server refuses to delete resources of that type as a blanket policy, then it should return the 405 Method not allowed status code.
* If the server refuses to delete a resource because of reasons specific to that resource, such as referential integrity, it should return the 409 Conflict status code
* Performing this interaction on a resource that is already deleted has no effect, and the server should return a 204 or 200 response. Resources that have been deleted may be "brought back to life" by a subsequent update interaction using an HTTP PUT.
* Conditional deletes: No matches: The server returns 404 (Not found)
* Conditional deletes: Multiple matches: The server returns a 412 Precondition Failed error indicating the the client's criteria were not selective enough

# create (201, 400, 404, 405, 422)

* The server returns a 201 Created HTTP status code
* When the resource syntax or data is incorrect or invalid, and cannot be used to create a new resource, the server returns a 400 Bad Request HTTP status code
* When the server rejects the content of the resource because of business rules, the server returns a 422 Unprocessible Entity error HTTP status code
* 400 Bad Request - resource could not be parsed or failed basic FHIR validation rules
* 404 Not Found - resource type not supported, or not a FHIR end point
* 422 Unprocessable Entity - the proposed resource violated applicable FHIR profiles or server business rules. This should be accompanied by an OperationOutcome resource providing additional detail
* Conditional create: Multiple matches: The server returns a 412 Precondition Failed error indicating the the client's criteria were not selective enough

# search (200, 403?)

# conformance (200, 404)

# transaction (200, 400, 404, 405, 409, 412, 422)

# history (200)
