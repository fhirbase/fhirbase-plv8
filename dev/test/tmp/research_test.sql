--db:fhirb -e
SET escape_string_warning=off;
--{{{

SELECT
  assert_eq(12::bigint, count(*), 'split params')
  FROM _query_string_to_params(
   'provider._id=1,2&provider.name=ups&_id=1,2&birthdate:missing=true&identifier=MRN|7777777&_count=100&name=pups&_sort:desc=name&_sort:asc=address&_page=10&_tag=category&_security=ups'
  ) _;
--}}}
