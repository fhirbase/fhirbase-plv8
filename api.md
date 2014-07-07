## API

#### FUNCTION fhir_read(_type_ varchar, _id_ uuid)
Read the current state of the resource
return bundle with one entry;

#### FUNCTION fhir_create(_type_ varchar, _resource_ jsonb, _tags_ jsonb)
Create a new resource with a server assigned id
return bundle with one entry;

#### FUNCTION fhir_vread(_type_ varchar, _id_ uuid, _vid_ uuid)
Read specific version of resource with _type_
Returns bundle with one entry;

#### FUNCTION fhir_update(_type_ varchar, _id_ uuid, _vid_ uuid, _resource_ jsonb, _tags_ jsonb)
Update resource, creating new version
Returns bundle with one entry;

#### FUNCTION fhir_delete(_type_ varchar, _id_ uuid)
DELETE resource by its id AND return deleted version
Return bundle with one deleted version entry ;

#### FUNCTION fhir_history(_type_ varchar, _id_ uuid, _params_ jsonb)
Retrieve the changes history for a particular resource with logical id (_id_)
Return bundle with entries representing versions;

#### FUNCTION fhir_search(_type_ varchar, _params_ jsonb)
Search in resources with _type_ by _params_
Returns bundle with entries;

#### FUNCTION fhir_tags()
Return all tags in system;

#### FUNCTION fhir_tags(_res_type varchar)
Return tags for resources with type = _type_;
