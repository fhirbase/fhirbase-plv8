-- #import ../src/tests.sql
-- #import ../src/fhir/resources.sql
-- TODO: verify

SELECT count(*) > 0 from resources.resource_indexables => true

/* TODO: enable*/
/* expect 'invariant' */

/*     SELECT count(*) */
/*       FROM resources.resource_search_params p */
/*       LEFT JOIN resources.resource_elements e */
/*       ON e.path = p.path */
/*       LEFT JOIN resources.hardcoded_complex_params hp */
/*       ON hp.path = p.path */
/*       WHERE (e.path IS NULL AND hp.path IS NULL) */

/* => 0::bigint */
