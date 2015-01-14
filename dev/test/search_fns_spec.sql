-- TODO: more tests
build_sorting('Patient', '_sort=given') =>  E'\n ORDER BY (json_get_in(patient.content, \'{name,given}\'))[1]::text ASC'
