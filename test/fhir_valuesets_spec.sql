-- #import ../src/fhir/valuesets.sql

select count(*) from valueset => 717::bigint
select count(*) from conceptmap => 18::bigint

select logical_id from valueset;
