--db:ups
--{{{
create table sch( id text);
insert into sch (id) VALUES ('ups');
--}}}
--{{{
DO $$
BEGIN
  IF EXISTS (SELECT * FROM sch) THEN
    RAISE NOTICE 'Hello';
  END IF;
END$$;
--}}}

--{{{
CREATE OR REPLACE
FUNCTION add_migration(_version_ text, _up_ text) RETURNS text AS $$
   INSERT INTO schema (version, up)
   VALUES (_version_, _up_)
   RETURNING  version
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION migrate(_version_ text) RETURNS text[] AS $$
DECLARE
mig RECORD;
_done text[] := ARRAY[]::text[];
BEGIN
  FOR mig IN SELECT * FROM schema where done = false OR done is NULL AND version <= _version_ ORDER BY version LOOP
    RAISE NOTICE '-> migrate: %s', mig.up;
    EXECUTE mig.up;
    UPDATE schema set done=true WHERE version = mig.version;
    _done = _done || mig.version;
  END LOOP;
  RETURN _done;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION migrate() RETURNS text[] AS $$
  SELECT migrate((SELECT max(version) FROM schema));
$$ LANGUAGE sql;
--}}}
--{{{
select * from schema;
--}}}

--{{{
select migrate();
--}}}
