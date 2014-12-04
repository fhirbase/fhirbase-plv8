--db:fhirb -e
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


-- number
SELECT assert_eq(
  '[{"param":"param","op": "=", "value": "num"}]'::jsonb,
  _parse_param('param=num'),
  'numer equal');
SELECT assert_eq(
  '[{"op": "=", "value": "num", "param":"param"}, {"op":"=", "value":"num2", "param":"param"}]'::jsonb,
  _parse_param('param=num&param=num2'),
  'numer equal');
SELECT assert_eq(
  _parse_param('param=<num'),
  '[{"param":"param", "op": "<" ,"value":"num"}]'::jsonb,
  'number less');

SELECT assert_eq(
  '[{"param":"param", "op": "<=" ,"value":"num"}]'::jsonb,
  _parse_param('param=<%3Dnum'),
  'number less or equal');

SELECT assert_eq(
  '[{"param":"param", "op": ">" ,"value":"num"}]'::jsonb,
  _parse_param('param=>num'),
  'number more');

SELECT assert_eq(
  '[{"param":"param", "op": ">=" ,"value":"num"}]'::jsonb,
  _parse_param('param=>%3Dnum'),
  'number more or equal');

SELECT assert_eq(
  '[{"param":"param", "op": "missing", "value": "true"}]'::jsonb,
  _parse_param('param:missing=true'),
  'number missing');

SELECT assert_eq(
  '[{"param":"param", "op": "missing", "value": "false"}]'::jsonb,
  _parse_param('param:missing=false'),
  'number present');

-- date

SELECT assert_eq(
  '[{"param":"param", "op": "=" ,"value": "date"}]'::jsonb,
  _parse_param('param=date'),
  'date equal');
SELECT assert_eq(
  '[{"param":"param", "op": "<" ,"value": "date"}]'::jsonb,
  _parse_param('param=<date'),
  'date less');
SELECT assert_eq(
  '[{"param":"param", "op": "<=" ,"value": "date"}]'::jsonb,
  _parse_param('param=<%3Ddate'),
  'date less or equal');
SELECT assert_eq(
  '[{"param":"param", "op": ">" ,"value": "date"}]'::jsonb,
  _parse_param('param=>date'),
  'date more');
SELECT assert_eq(
  '[{"param": "param", "op": ">=" ,"value": "date"}]'::jsonb,
  _parse_param('param=>%3Ddate'),
  'date more or equal');
SELECT assert_eq(
  '[{"param":"param", "op": "missing", "value":"true"}]'::jsonb,
  _parse_param('param:missing=true'),
  'date missing');
SELECT assert_eq(
  '[{"param":"param", "op": "missing", "value":"false"}]'::jsonb,
  _parse_param('param:missing=false'),
  'date present');

SELECT assert_eq(
  '[{"param":"param", "op": "=" ,"value": "str"}]'::jsonb,
  _parse_param('param=str'),
  'str equal');

SELECT assert_eq(
  '[{"param":"param", "op": "exact" ,"value": "str"}]'::jsonb,
  _parse_param('param:exact=str'),
  'str exact');

SELECT assert_eq(
  '[{"param":"subject:Patient.name", "op": "=", "value":"ups"}]'::jsonb,
  _parse_param('subject:Patient.name=ups'),
  'path');

-- token

-- quantity

SELECT assert_eq(
  '[{"param":"param", "op": "~" ,"value": "quantity"}]'::jsonb,
  _parse_param('param=~quantity'),
  'quantity approximation');
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
