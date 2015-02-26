-- #import ../src/tests.sql
-- #import ../src/index_date.sql

set timezone='UTC';
SET search_path TO index_date;

index_as_date('{}', '{birthDate}','dateTime') => null

expect
  index_as_date('{"birthDate": "1980"}', '{birthDate}','dateTime')
=> '["1980-01-01 00:00:00+00","1980-12-31 23:59:59+00"]'

expect
  index_as_date('{"birthDate": "1980-03"}', '{birthDate}','dateTime')
=> '["1980-03-01 00:00:00+00","1980-03-31 23:59:59+00"]'

expect
 index_as_date('{"birthDate": "1980-03-05"}', '{birthDate}','dateTime')
=> '["1980-03-05 00:00:00+00","1980-03-05 23:59:59+00"]'

expect
 index_as_date('{"birthDate": "1980-03-05 12"}', '{birthDate}','dateTime')
=> '["1980-03-05 12:00:00+00","1980-03-05 12:59:59+00"]'

expect
 index_as_date('{"birthDate": "1980-03-05 12:30"}', '{birthDate}','dateTime')
=> '["1980-03-05 12:30:00+00","1980-03-05 12:30:59+00"]'

expect
 index_as_date('{"issued": {"start": "2014-01-05 12:30"}}', '{issued}', 'Period')
=> '["2014-01-05 12:30:00+00",)'

expect
 index_as_date('{"issued": {"start": "2014-01-05 12:30", "end":"2014-12-05"}}', '{issued}', 'Period')
=> '["2014-01-05 12:30:00+00","2014-12-05 23:59:59+00"]'

expect
 index_as_date('{"issued": {"start": "2014-01-05 12:30", "end":"2014-12-05"}}', '{issued}', 'Period')
=> '["2014-01-05 12:30:00+00","2014-12-05 23:59:59+00"]'

expect
 index_as_date('{"issued": [{"start": "2014-01-05 12:30", "end":"2014-02-05"},{"start":"2014-03", "end":"2014-07"}]}', '{issued}', 'Period')
=> '["2014-01-05 12:30:00+00","2014-07-31 23:59:59+00"]'

expect
 index_as_date('{"issued": [{"start": "2014-01-05 12:30", "end":"2014-02-05"},{"start":"2014-03", "end":"2014-07"}]}', '{issued}', 'Period')
=> '["2014-01-05 12:30:00+00","2014-07-31 23:59:59+00"]'

expect
 index_as_date( E'{"activity":[{"simple":{"timingSchedule":{"event":[{"start": "2014-03-05"}]}}}]}', '{activity,simple,timingSchedule}','Schedule')
=> '["2014-03-05 00:00:00+00",)'
