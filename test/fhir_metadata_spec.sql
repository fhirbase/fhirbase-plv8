-- #import ../src/tests.sql
-- #import ../src/fhir/metadata.sql


select count(*) from metadata.profile => 137::bigint
select count(*) from metadata.profile_elements => 4702::bigint
select count(*) from metadata.searchparameter => 661::bigint

