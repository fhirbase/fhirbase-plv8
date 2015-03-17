-- #import ./coll.sql
-- #import ./tests.sql

func _is_array(_json jsonb) RETURNS boolean
  SELECT jsonb_typeof(_json) = 'array';

func _is_object(_json jsonb) RETURNS boolean
  SELECT jsonb_typeof(_json) = 'object';

proc json_get_in(_json_ jsonb, path varchar[]) RETURNS jsonb[]
  item jsonb;
  acc jsonb[] := array[]::jsonb[];
  BEGIN
    --RAISE NOTICE 'in with % and path %', json, path;
    IF _json_ is NULL THEN
      --RAISE NOTICE 'ups';
      RETURN array[]::jsonb[];
    END IF;
    IF array_length(path, 1) IS NULL THEN
      -- expand array
      IF this._is_array(_json_) THEN
        FOR item IN SELECT jsonb_array_elements(_json_)
        LOOP
          acc := acc || item;
        END LOOP;
        RETURN acc;
      ELSE
        RETURN array[_json_];
      END IF;
    END IF;
    IF this._is_array(_json_) THEN
      FOR item IN SELECT jsonb_array_elements(_json_)
      LOOP
        acc := acc || this.json_get_in(item,path);
      END LOOP;
      RETURN acc;
    ELSIF this._is_object(_json_) THEN
      RETURN this.json_get_in(_json_->path[1], coll._rest(path));
    ELSE
      RETURN array[]::jsonb[];
    END IF;


proc json_array_to_str_array(_jsons jsonb[]) RETURNS text[]
  item jsonb;
  acc text[] := array[]::text[];
  BEGIN
    FOR item IN
      SELECT unnest(_jsons)
    LOOP
      acc := acc || (json_build_object('x', item)->>'x')::text;
    END LOOP;
    RETURN acc;

func assoc(_from_ jsonb, _key_ text, _value_ jsonb) RETURNS jsonb
   SELECT json_object_agg(key, value)::jsonb FROM (
     SELECT * FROM (
       SELECT x.*, 'a' as tp FROM jsonb_each(_from_) x
       UNION SELECT _key_ as key, _value_ as value, 'b' as tp
     ) _ ORDER BY tp
   ) _

func merge(_to_ jsonb, _from_ jsonb) RETURNS jsonb
   SELECT json_object_agg(key, value)::jsonb FROM (
     SELECT * FROM (
       SELECT x.*, 'a' as tp FROM jsonb_each(_to_) x
       UNION
       SELECT y.*, 'b' as tp FROM jsonb_each(_from_) y
     ) _ ORDER BY tp
   ) _

func jsonb_primitive_to_text(x jsonb) RETURNS text
  SELECT CASE
   WHEN jsonb_typeof(x) = 'null' THEN
     NULL
   ELSE
     json_build_object('x', x)->>'x'
  END

func jsonb_to_array(_jsonb_ jsonb) RETURNS jsonb[]
  SELECT array_agg(j)
  FROM jsonb_array_elements(_jsonb_) j

func dissoc(_jsonb_ jsonb, VARIADIC _keys_to_delete_ TEXT[]) RETURNS jsonb
  SELECT COALESCE(
    (SELECT ('{' || string_agg(to_json("key") || ':' || "value", ',') || '}')::jsonb
     FROM jsonb_each(_jsonb_)
     WHERE "key" <> ALL (_keys_to_delete_)),
    '{}'
  )::jsonb
