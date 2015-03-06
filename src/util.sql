func column_name(name varchar, type varchar) RETURNS varchar
  --- just eat [x] from name
  SELECT replace(name, '[x]', '' || type);

func _fhir_unescape_param(_str text) RETURNS text
  SELECT regexp_replace(_str, $RE$\\([,$|])$RE$, E'\\1', 'g')

func _fhir_spilt_to_table(_str text) RETURNS table (value text)
  SELECT this._fhir_unescape_param(x)
   FROM regexp_split_to_table(regexp_replace(_str, $RE$([^\\]),$RE$, E'\\1,,,,,'), ',,,,,') x


func _merge_tags(_old_tags jsonb, _new_tags jsonb) RETURNS jsonb
 SELECT json_agg(x.x)::jsonb FROM (
   SELECT jsonb_array_elements(_new_tags) x
   UNION
   SELECT jsonb_array_elements(_old_tags) x
 ) x
