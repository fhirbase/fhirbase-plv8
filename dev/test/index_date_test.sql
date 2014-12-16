--db:fhirb -e

SET escape_string_warning=off;
--{{{

SELECT index_as_date('{}', '{birthDate}','dateTime');
SELECT index_as_date('{"birthDate": "1980"}', '{birthDate}','dateTime');
SELECT index_as_date('{"birthDate": "1980-03"}', '{birthDate}','dateTime');
SELECT index_as_date('{"birthDate": "1980-03-05"}', '{birthDate}','dateTime');
SELECT index_as_date('{"birthDate": "1980-03-05 12"}', '{birthDate}','dateTime');
SELECT index_as_date('{"birthDate": "1980-03-05 12:30"}', '{birthDate}','dateTime');


SELECT index_as_date('{"issued": {"start": "2014-01-05 12:30"}}', '{issued}', 'Period');
SELECT index_as_date('{"issued": {"start": "2014-01-05 12:30", "end":"2014-12-05"}}', '{issued}', 'Period');
SELECT index_as_date('{"issued": {"start": "2014-01-05 12:30", "end":"2014-12-05"}}', '{issued}', 'Period');
SELECT index_as_date('{"issued": [{"start": "2014-01-05 12:30", "end":"2014-02-05"},{"start":"2014-03", "end":"2014-07"}]}', '{issued}', 'Period');

SELECT index_as_date('{"issued": [{"start": "2014-01-05 12:30", "end":"2014-02-05"},{"start":"2014-03", "end":"2014-07"}]}', '{issued}', 'Period');


\set careplan `cat test/fixtures/careplan.json`
SELECT index_as_date(:'careplan', '{activity,simple,timingSchedule}','Schedule');
--}}}

