# TODO: outdated

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

## Types

SQL has strict type checking, so SP's arguments and return values are
typed. When describing SP, we will put type of every argument in
parens. For example, if argument `cfg` has `jsonb` type, we'll write:

<dl>
<dt>cfg (jsonb)</dt>
<dd>Confguration data</dd>
</dl>

You can take a look at
[overview of standard PostgreSQL types](http://www.postgresql.org/docs/9.4/static/datatype.html#DATATYPE-TABLE).

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
several advantages of such decision:

* PostgreSQL has native support for JSON data type which means fast
  queries and efficient storage;
* JSON is native and preferred format for Web Services/APIs nowadays;
* If you need an XML representation of a resource, you can always get
  it from JSON in your application's code.

## Passing JSON to a SP

When SP's argument has type `jsonb`, that means you have to pass some
JSON as a value. To do this, you need to represent JSON as
single-line PostgreSQL string. You can do this in many ways, for
example, using a
[online JSON formatter](http://jsonviewer.stack.hu/). Copy-paste your
JSON into this tool, cick "Remove white space" button and copy-paste
result back to editor.

Another thing we need to do before using JSON in SQL query is quote
escaping. Strings in PostgreSQL are enclosed in single quotes. Example:

```sql
SELECT 'this is a string';

     ?column?
------------------
 this is a string
(1 row)
```

If you have single quote in your string, you have to **double** it:

```sql
SELECT 'I''m a string with single quote!';

            ?column?
---------------------------------
 I'm a string with single quote!
(1 row)
```

So if your JSON contains single quotes, Find and Replace them with two
single quotes in any text editor.

Finally, get your JSON, surround it with single quotes, and append
`::jsonb` after closing quote. That's how you pass JSON to PostgreSQL.

```sql
SELECT '{"foo": "i''m a string from JSON"}'::jsonb;
               jsonb
-----------------------------------
 {"foo": "i'm a string from JSON"}
(1 row)
```

## Creating resources

Right after installation FHIRBase is "empty", it doesn't have any data
we can operate with. So let's create some resources first.

Resources are created with **fhir_create** SP which takes four
arguments:

<dl>
<dt>resource_content (jsonb)</dt>
<dd>Content of resource being created</dd>
</dl>

**Returns (jsonb):**
[Bundle](http://www.hl7.org/implement/standards/fhir/extras.html#bundle)
containing newly created Resource.

Following query will create a
[Patient resource](http://www.hl7.org/implement/standards/fhir/patient.html)
from standard
[FHIR example](http://www.hl7.org/implement/standards/fhir/patient-example.json.html)
without any tags:

```sql
SELECT fhir.create(
  '{"resourceType":"Patient","identifier":[{"use":"usual","label":"MRN","system":"urn:oid:1.2.36.146.595.217.0.1","value":"12345","period":{"start":"2001-05-06"},"assigner":{"display":"Acme Healthcare"}}],"name":[{"use":"official","family":["Chalmers"],"given":["Peter","James"]},{"use":"usual","given":["Jim"]}],"telecom":[{"use":"home"},{"system":"phone","value":"(03) 5555 6473","use":"work"}],"gender":{"coding":[{"system":"http://hl7.org/fhir/v3/AdministrativeGender","code":"M","display":"Male"}]},"birthDate":"1974-12-25","deceasedBoolean":false,"address":[{"use":"home","line":["534 Erewhon St"],"city":"PleasantVille","state":"Vic","zip":"3999"}],"contact":[{"relationship":[{"coding":[{"system":"http://hl7.org/fhir/patient-contact-relationship","code":"partner"}]}],"name":{"family":["du","Marché"],"_family":[{"extension":[{"url":"http://hl7.org/fhir/Profile/iso-21090#qualifier","valueCode":"VV"}]},null],"given":["Bénédicte"]},"telecom":[{"system":"phone","value":"+33 (237) 998327"}]}],"managingOrganization":{"reference":"Organization/1"},"active":true}'::jsonb,
  );

          fhir.create
---------------------------------------------------------------------------------
{"id": "8d33a19b-af36-4e70-ae64-e705507eb074", "name": ....}
```

When resource is created, FHIRBase assigns unique identifier to it. We
need to "remember" (copy-paste) this identifier for later use.
Copy-paste this ID somewhere, because we'll need it in the
next step.

## Reading resources

To read latest version of Resource use **fhir.read** SP:

<dl>
<dt>resource_type (varchar)</dt>
<dd>Type of resource being created, e.g. 'Organization' or 'Patient'</dd>

<dt>url (jsonb)</dt>
<dd>Uniform Locator of Resource being read.</dd>

<dt>RETURNS (jsonb)</dt>
<dd>Bundle containing found Resource or empty Bundle if no such resource was found.</dd>
</dl>

Use following code to invoke `fhir.read`, just replace `[URL]` with
Patient's identifier from previous step:

```sql
SELECT fhir.read('Patient', '[URL]');

          fhir.read
---------------------------------------------------------------------------------
{"id": "b1f2890a..",...}
```

## Reading resource data in relational way

Instead of invoking **fhir.read** SP, you can `SELECT` resource data
from `resource` table.
Replace `[logical ID]` in following query with logical ID of
previously inserted Patient resource and execute it.


```sql
SELECT content FROM resource
 WHERE logical_id = '[logical ID]'
   AND resource_type = 'Patient';

          content
---------------------------------------------------------------------------------
{"name": [{"use": "official", "given": ["Peter", "James"], "family": ["Chalmers"]},
{"use": "usual", "given": ["Jim"]}],
[... skipped ...]
```

`resource` table contains latest versions of all resources stored in
FHIRBase. It must be said that no data is stored in it. Each type of
resource has it's own table: `patient`, `adversereaction`,
`encounter`, etc (48 total) where all resource data is actually
stored. Each of them inherits `resource` table using
[PostgreSQL Table Inheritance](http://www.postgresql.org/docs/9.4/static/ddl-inherit.html)
feature. So when you `SELECT ... FROM resource`, PostgreSQL executes
your query on every inherited table and then union results. Such
approach might be inefficient, especially on complex queries, and
that's why it's important to use `WHERE resource_type = '...'`
predicate. When you specify `resource_type`, PostgreSQL knows exactly
which inherited table to touch. Alternatively, you can select directly
from inherited table:

```sql
SELECT content FROM patient
 WHERE logical_id = '[logical ID]';

          content
---------------------------------------------------------------------------------
{"name": [{"use": "official", "given": ["Peter", "James"], "family": ["Chalmers"]},
{"use": "usual", "given": ["Jim"]}],
[... skipped ...]
```

Generally, `SELECT`ing data from `resource` table by logical ID and
resource type is as fast as `SELECT`ing from inherited table by
logical ID only.

## Updating resource

To update resource data use **fhir_update** SP:

<dl>
<dt>new_resource (jsonb)</dt>
<dd>New resource content.</dd>
<dt>RETURNS (jsonb)</dt>
<dd>updated resource</dd>
</dl>


To read latest version of resource use already discussed **fhir.read** SP:

```sql
SELECT fhir.read('Patient', '[logical id]');

               fhir.read
----------------------------------------------------------------------------
{"id": "b1f2890a-0536-4742-9d39-90be5d4637ee",...}
```

TODO: write about meta.versionId

Now let's invoke `fhir_update` with version URL we just received and
change Patient.text value:

```sql
SELECT fhir_update(updated_resource) ;

                 fhir_update
-------------------------------------------------------------------------
{"id": "b1f2890a-0536-4742-9d39-90be5d4637ee", ....}
```

If meta.versionId in resource you passed to `fhir.update` isn't latest (optimistic locking has failed), you'll receive error message:

```
ERROR:  Wrong version_id 43d7c2cf-a1b5-4602-b9a2-ec55d1a2dda8. Current is abb33ccc-bb5a-4875-af43-9b3bba62a95c
```

## Reading previous versions of resource

To receive all versions of specific resource use **fhir.history** SP:

<dl>
<dt>resource_type (varchar)</dt>
<dd>Type of resource.</dd>

<dt>id (varchar)</dt>
<dd>URL of resource.</dd>

<dt>options (jsonb)</dt>
<dd>Additional options as described in <a href="http://www.hl7.org/implement/standards/fhir/http.html#history">FHIR Standard for <em>history</em> RESTful action</a>. Not implemented for now.</dd>

<dt>RETURNS (jsonb)</dt>
<dd>Bundle containing all versions of resource.</dd>
</dl>

Invoking **fhir_history** is quite straightforward:

```sql
SELECT fhir_history(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  '[URL]',
  '{}'::jsonb);

                fhir_history
---------------------------------------------------------------------------
[... skipped ...]
```

Also there is a **fhir_vread** SP to read single version of some resource:

<dl>
<dt>cfg (jsonb)</dt>
<dd>Confguration data</dd>

<dt>resource_type (varchar)</dt>
<dd>Type of resource.</dd>

<dt>version_url (varchar)</dt>
<dd>URL of resource version being read.</dd>

<dt>RETURNS (jsonb)</dt>
<dd>Bundle containing single version of resource.</dd>
</dl>

```sql
SELECT fhir_vread(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  '[version URL]');

                fhir_vread
----------------------------------------------------------------------------
{"id": "34d2ec09-9211-4c95-a591-905279cc8212", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee", "link": [{"rel": "self", "href": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee/_history/43d7c2cf-a1b5-4602-b9a2-ec55d1a2dda8"}],
[... skipped ...]
```

## Searching Resources

[Search](http://www.hl7.org/implement/standards/fhir/search.html) is
the most tricky part of FHIR Standard. FHIRBase implements most of
Search features:

* simple search
* full-text search
* search by chainged parameters
* search by tag
* pagination and sorting
* including other resources in search results

We'll demonstrate how to perform simple search and will leave other
cases for separate article.

Search is performed with **fhir_search** SP:

<dl>
<dt>cfg (jsonb)</dt>
<dd>Confguration data</dd>

<dt>resource_type (varchar)</dt>
<dd>Type of resources you search for.</dd>

<dt>search_parameters (text)</dt>
<dd>Search parameters in query-string format, as described in <a href="http://www.hl7.org/implement/standards/fhir/search.html#standard">FHIR Standard</a>.</dd>

<dt>RETURNS (jsonb)</dt>
<dd>Bundle containing found resources.</dd>
</dl>

Let's start with searching for all patients with name containing "Jim":

```sql
SELECT fhir_search(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  'name=Jim');

                fhir_search
----------------------------------------------------------------------------
{"id": "3367b97e-4cc3-4afa-8d55-958ed686dd10", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee",
[ ... skipped ... ]
"resourceType": "Bundle", "totalResults": 1}
```

Search by MRN identifier:

```sql
SELECT fhir_search(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  'identifier=urn:oid:1.2.36.146.595.217.0.1|12345');

                fhir_search
----------------------------------------------------------------------------
{"id": "3367b97e-4cc3-4afa-8d55-958ed686dd10", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee",
[ ... skipped ... ]
"resourceType": "Bundle", "totalResults": 1}
```

Search by gender:

```sql
SELECT fhir_search(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  'gender=http://hl7.org/fhir/v3/AdministrativeGender|M');

                fhir_search
----------------------------------------------------------------------------
{"id": "3367b97e-4cc3-4afa-8d55-958ed686dd10", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee",
[ ... skipped ... ]
"resourceType": "Bundle", "totalResults": 1}
```

Combining several conditions:

```sql
SELECT fhir_search(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  'gender=http://hl7.org/fhir/v3/AdministrativeGender|M&name=Jim&identifier=urn:oid:1.2.36.146.595.217.0.1|12345');

                fhir_search
----------------------------------------------------------------------------
{"id": "3367b97e-4cc3-4afa-8d55-958ed686dd10", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee",
[ ... skipped ... ]
"resourceType": "Bundle", "totalResults": 1}
```

## Deleting resource

To delete resource, use **fhir_delete** SP:

<dl>
<dt>cfg (jsonb)</dt>
<dd>Confguration data</dd>

<dt>resource_type (varchar)</dt>
<dd>Type of resources you search for.</dd>

<dt>url (varchar)</dt>
<dd>URL of resource being deleted.</dd>

<dt>RETURNS (jsonb)</dt>
<dd>Bundle containing deleted resource.</dd>
</dl>

```sql
SELECT fhir_delete(
  '{"base": "http://localhost.local"}'::jsonb,
  'Patient',
  '[URL]'
);

                fhir_delete
----------------------------------------------------------------------------
{"id": "3367b97e-4cc3-4afa-8d55-958ed686dd10", "entry": [{"id": "http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee",
[ ... skipped ... ]
"resourceType": "Bundle", "totalResults": 1}
```

NB: History of resource is also deleted:

```sql
SELECT fhir_history(
  '{"base": "http://localhost.local"}'::jsonb,
  'http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee',
  '{}'::jsonb
);

                fhir_history
----------------------------------------------------------------------------
 {"id": "6d31ea93-49b3-47d2-9249-1f47d1e72c39", "entry": [], "title": "History of resource with type=http://localhost.local/Patient/b1f2890a-0536-4742-9d39-90be5d4637ee", "updated": "2014-11-25T12:42:47.634399+00:00", "resourceType": "Bundle", "totalResults": 0}
```
