--db:fhirb
--{{{
\set ucum `cat ucum-essence.xml`
\set ns '{{u,http://unitsofmeasure.org/ucum-essence}}'

DROP table ucum_prefixes;
CREATE TABLE ucum_prefixes AS (
SELECT
  (xpath('./@Code', st, :'ns'))[1]::varchar as code,
  (xpath('./@CODE', st, :'ns'))[1]::varchar as big_code,
  (xpath('./name/text()', st, :'ns'))[1]::varchar as name,
  (xpath('./printSymbol/text()', st, :'ns'))[1]::varchar as symbol,
  (xpath('./value/@value', st, :'ns'))[1]::varchar::decimal as value,
  (xpath('./value/text()', st, :'ns'))[1]::varchar as value_text

  FROM (SELECT unnest(xpath('/u:root/prefix', :'ucum', :'ns')) st ) u
);

DROP table ucum_units;
CREATE TABLE ucum_units AS (
SELECT
  (xpath('./@Code', st, :'ns'))[1]::varchar as code,
  (xpath('./@isMetric', st, :'ns'))[1]::varchar as is_metric,
  (xpath('./@class', st, :'ns'))[1]::varchar as class,
  (xpath('./name/text()', st, :'ns'))[1]::varchar as name,
  (xpath('./printSymbol/text()', st, :'ns'))[1]::varchar as symbol,
  (xpath('./property/text()', st, :'ns'))[1]::varchar as property,
  (xpath('./value/@Unit', st, :'ns'))[1]::varchar as unit,
  (xpath('./value/@value', st, :'ns'))[1]::varchar as value,
  (xpath('./value/text()', st, :'ns'))[1]::varchar as value_text,
  (xpath('./value/function/@name', st, :'ns'))[1]::varchar as func_name,
  (xpath('./value/function/@value', st, :'ns'))[1]::varchar::decimal as func_value,
  (xpath('./value/function/@Unit', st, :'ns'))[1]::varchar as func_unit

  FROM (SELECT unnest(xpath('/u:root/unit', :'ucum', :'ns')) st ) u
);
--}}}
--{{{
--select * from ucum_prefixes;

select
name,
--code,
value,
unit,
func_name,
*
from ucum_units
;
--}}}
