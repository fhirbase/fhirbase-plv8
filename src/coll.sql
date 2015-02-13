
func _butlast(_ar_ anyarray) RETURNS anyarray
  --- cut last element of array
  SELECT _ar_[array_lower(_ar_,1) : array_upper(_ar_,1) - 1]

func _rest(_ar_ anyarray) RETURNS anyarray
  --- return rest of array
  SELECT _ar_[2 : array_upper(_ar_,1)];

func _last(_ar_ anyarray) RETURNS anyelement
  --- return last element of collection
  SELECT _ar_[array_length(_ar_,1)];
