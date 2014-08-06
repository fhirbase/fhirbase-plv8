--db:fhirb -e
SET escape_string_warning=off;

--{{{

SELECT assert_eq(8::bigint,
(
SELECT count(*)
  FROM _expand_search_params('Patient'::text,
    _parse_param(
      'provider._id=1,2&provider.name=ups&_id=1,2&birthdate:missing=true&identifier=MRN|7777777&_count=100&name=pups&_sort:desc=name&_sort:asc=address&_page=10&_tag=category&_security=ups'))
), 'should split into 8 params and filter _page _sort and _tags');

SELECT *
  FROM build_search_query('Patient'::text,
    _parse_param(
      'provider._id=1,2&provider.name=ups&_id=1,2&_page=10&birthdate:missing=true&identifier=MRN|7777777&_count=100&_sort:desc=name&_sort:asc=address&name=pups&_tag=category&_security=ups'));

/* SELECT * */
/*   FROM build_search_query('Patient'::text, _parse_param('name=ups&name=dups')); */
/* SELECT * */
/*   FROM build_search_query('Patient'::text, _parse_param('identifier=MRN|7777777')); */

/* SELECT * */
/*   FROM build_search_query('Patient'::text, _parse_param('birthdate=>2011')); */

/* SELECT * */
/*   FROM _expand_search_params('Patient'::text, _parse_param('provider._id=1,2&name=ups&name=pups')); */
/* SELECT * */
/*   FROM _build_references_joins('Patient'::text, _parse_param('provider._id=1,2&name=ups&name=pups')); */
/* SELECT * */
/*   FROM build_search_joins('Patient'::text, _parse_param('provider._id=1,2&name=ups&name=pups')); */

/* SELECT * FROM search('Patient'::text, 'provider._id=1,2&name=ups&name=pups'); */

--}}}
