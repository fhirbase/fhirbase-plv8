DROP TABLE IF EXISTS __vars;
create table this.__vars ( name varchar primary key, value jsonb);

func! setv(_name_ text, _val_ jsonb) RETURNS text
  INSERT INTO this.__vars (name, value) VALUES (_name_, _val_)
    RETURNING name

func! getv(_name_ text) RETURNS jsonb
  SELECT value FROM this.__vars WHERE name = _name_

func! delv(_name_ text) RETURNS jsonb
  DELETE FROM this.__vars WHERE name = _name_ RETURNING value
