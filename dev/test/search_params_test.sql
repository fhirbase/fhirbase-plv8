--db:fhirb
SET escape_string_warning=off;
--{{{

SELECT assert_eq(
  'text',
  _get_modifier('subject:Patient.organization:Organization.identifier:text'::text),
  '_get_modifier text');

SELECT assert_eq(
  NULL,
  _get_modifier('subject:Patient.organization:Organization.identifier'::text),
  '_get_modifier null');

SELECT assert_eq(
  'subject:Patient.organization:Organization.identifier',
  _get_key('subject:Patient.organization:Organization.identifier:text'::text),
  '_get_key text');

SELECT assert_eq(
  'subject:Patient.organization:Organization.identifier',
  _get_key('subject:Patient.organization:Organization.identifier'::text),
  '_get_key null');
--}}}

--{{{
-- number
SELECT * FROM _parse_param('param=num');
SELECT * FROM _parse_param('param=num&param=num2');
SELECT * FROM _parse_param('param=<num');

SELECT * FROM _parse_param('param=<%3Dnum');
SELECT * FROM _parse_param('param=>num');
SELECT * FROM _parse_param('param=>%3Dnum');
SELECT * FROM _parse_param('param:missing=true');
SELECT * FROM _parse_param('param:missing=false');

-- date

SELECT * FROM _parse_param('param=date');
SELECT * FROM _parse_param('param=<date');
SELECT * FROM _parse_param('param=<%3Ddate');
SELECT * FROM _parse_param('param=>date');
SELECT * FROM _parse_param('param=>%3Ddate');
SELECT * FROM _parse_param('param:missing=true');
SELECT * FROM _parse_param('param:missing=false');

SELECT * FROM _parse_param('param=str');

SELECT * FROM _parse_param('param:exact=str');

SELECT * FROM _parse_param('subject:Patient.name=ups');

-- token

-- quantity

SELECT * FROM _parse_param('param=~quantity');
--}}}

-- reference

/* ### Chained params ### */

/* [param].[rest]=[val] {"param":"param", "op": "chain" ,"value": "#{rest}=#{val}"} */
/* [param]:[type].[rest]=[val] {"param":"param", "op": "chain" ,"value": [type "#{rest}=#{val}"]} */
/* [param]:[type].[rest]:modifier=[val] {"param":"param", "op": "modifier" ,"value": [type "#{rest}=#{val}"]} */

/* ### Composite Search params ### */

/* [first]&[rest] {:key "op": "and" ,"value":ue [first, rest]} */
/* [param]=[val,rest] {:key "op": "ORDER BY" ,"value":ue []} */
/* [param]=key1$val1,key2$val2 {:kep param "op": "composite" ,"value": [key1 val1 key2 val2]} */
