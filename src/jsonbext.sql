-- #import ./coll.sql

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

func jsonb_primitive_to_text(x jsonb) RETURNS text
  SELECT CASE
   WHEN jsonb_typeof(x) = 'null' THEN
     NULL
   ELSE
     json_build_object('x', x)->>'x'
  END
