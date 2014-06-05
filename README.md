# fhirplace

A Clojure library designed to ... well, that part is up to you.


## Search

### String

Search parameter is a simple string, like a name part.
Search is case-insensitive and accent-insensitive.
May match just the start of a string.
String parameters may contain spaces.

The string parameter refer to simple string searches against sequences of characters.
Matches are case- and accent- insensitive.
By default, a match exists if a portion of the parameter
value contains the specified string.
 It is at the discretion of the server whether to do a left-partial search.
The modifier :exact can be used to indicate that
the match needs to be exact (the whole string, including casing and accents).

modifiers: none, :exact, :text

It is at the discretion of the server whether to pre-process names, addresses,
and contact details to remove separator characters
prior to matching in order to ensure more consistent behavior.
For example, a server might remove all spaces and "-"
characters from phone numbers. What is most appropriate varies depending on culture and context.


type => search type


patient example:

* address Address
* family  HumanName.family
* given   HumanName.given
* name    HumanName
* telecom Contact


Solution:

Create index table for (Resource, search param type)

* case & acent insensitive
* search types: exact, like, text

```
create table patient_search_string (
   resource_id references patient (logical_id)
   last_modified_date ? or join resource
   param varchar (address, family, given, telecom)
   value text
   fulltext_value ts_vector
)
```

When we save resource

Options: index in app or in db

app
  PRO: simple implement
  CONS: not scalable, problem with reindex

app implementation
```
each search_param
   case attr_type
     Address => write index
     HumanName => write index
     string[] => write index[]

Protocol ->string_index
implement for?

```

db (RETURN FHIRBASE IDEA!)
  PRO: scalable
  CONS: sophisticated implementation

crazy idea: use indexes (hard to implement)

app implementation
```
generate trigger or insert procudure
which index by profile

INSET INTO patient_string_search
(res_id, param, text)
values
(id, 'name', json->'text')

```

## Usage


## License

Copyright © 2014 FIXME

Distributed under the Eclipse Public License either version 1.0 or (at
your option) any later version.
