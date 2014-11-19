# FHIRBase Introduction

FHIRBase is a PostgreSQL extension for storing and retrieving
[FHIR resources](http://www.hl7.org/implement/standards/fhir/resources.html). You
can interact with FHIRBase using any PostgreSQL client. We advise you
to start with [pgAdmin](http://www.pgadmin.org/), because it has
easy-to-use graphical interface. However,
[other options](https://wiki.postgresql.org/wiki/Community_Guide_to_PostgreSQL_GUI_Tools)
are available.

[SQL](https://en.wikipedia.org/wiki/SQL) is the language in which you
"talk" to FHIRBase. If you don't have at least basic knowledge of SQL,
we strongly advise to read some books or tutorials on the Web in the
first place.

We assume that you have successfully
[installed FHIRBase](https://github.com/fhirbase/fhirplace#installation)
using Vagrant and already configured connection parameters in your
PostgreSQL client.

## Stored Procedures as primary API

In SQL world it's conventional to insert data with `INSERT` statement,
delete it with `DELETE`, update with `UPDATE` and so on. FHIRBase uses
less common approach - it forces you to use
[stored procedures](http://en.wikipedia.org/wiki/Stored_procedure) for
data manipulation. Reason for this is that FHIRBase needs to perform
additional actions on data changes in order to keep FHIR-specific
functionality (such as
[search](http://www.hl7.org/implement/standards/fhir/search.html) and
[versioning](http://www.hl7.org/implement/standards/fhir/http.html#vread))
working.

There are some exceptions from this rule in data retrieval cases. For
example you can `SELECT ... FROM resource` to search for specific
resource or set of resources. But when you create, delete or modify
something, you have to use corresponding stored procedures
(hereinafter, we'll refer them as SP).

## JSON and XML

FHIR standard
[allows](http://www.hl7.org/implement/standards/fhir/formats.html) to
use two formats for data exchange: XML and JSON. They are
interchangeable, what means any XML representation of FHIR resource
can be unambiguously transformed into equivalent JSON
representation. FHIRBase team
[has released a XSL 2.0 stylesheet](https://github.com/fhirbase/fhir-xml2json)
for such purpose.

Considering interchangeability of XML and JSON FHIRBase team decided
to discard XML format support and use JSON as only format. There are
many advantages of such decision:

* PostgreSQL has native support for JSON data type which means fast
  queries and efficient storage;
* JSON is native and preferred format for Web Services/APIs nowadays;
* If you need an XML representation of a resource, you can always get
  it from JSON in your application code.

## Creating resources

Right after installation FHIRBase is "empty", it doesn't have any data
we can operate with. So let's create some resources first.

Resources are created with **fhir_create** SP which takes four parameters:

<dl>
<dt>cfg (jsonb)</dt>
<dd>Confguration data</dd>

<dt>resource_type (varchar)</dt>
<dd>Type of resource being created, e.g. 'Organization' or 'Patient'</dd>

<dt>resource_content (jsonb)</dt>
<dd>Content of resource being created</dd>

<dt>tags (jsonb)</dt>
<dd>Array of <a href="http://www.hl7.org/implement/standards/fhir/extras.html#tag">FHIR tags</a> for resource</dd>
</dl>
