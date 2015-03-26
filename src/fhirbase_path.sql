func _is_descedant(_parent_ anyarray, _child_ anyarray) RETURNS boolean
  --- test _parent_ is prefix of _child_
  SELECT _child_[array_lower(_parent_,1) : array_upper(_parent_,1)] = _parent_;

func _subpath(_parent_ anyarray, _child_ anyarray) RETURNS varchar[]
  --- remove _parent_ elements from begining of _child_
  SELECT _child_[array_upper(_parent_,1) + 1 : array_upper(_child_,1)];
