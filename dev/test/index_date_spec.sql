set timezone='UTC';

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
 index_as_date( E'{"resourceType":"CarePlan","text":{"status":"additional","div":"<div>\\n           <p> A simple care plan to indicate a patient taking their weight once a day because of obesity.\\n            Some Notes: </p>\\n            <ul>\\n            <li>It would be good to have some way of specifying/coding a goal. e.g. what the target weight is</li>\\n            <li>In the codeable concepts I''ve been lazy and just put the text. There should, of course, be a code behind these</li>\\n        </ul>\\n        </div>"},"contained":[{"resourceType":"Condition","id":"p1","subject":{"reference":"Patient/example","display":"Peter James Chalmers"},"code":{"text":"Obesity"},"status":"confirmed"},{"resourceType":"Practitioner","id":"pr1","name":{"family":["Dietician"],"given":["Dorothy"]},"specialty":[{"text":"Dietician"}]}],"patient":{"reference":"Patient/example","display":"Peter James Chalmers"},"status":"active","period":{"end":"2013-01-01"},"concern":[{"reference":"#p1","display":"obesity"}],"participant":[{"role":{"text":"responsiblePerson"},"member":{"reference":"Patient/example","display":"Peter James Chalmers"}},{"role":{"text":"adviser"},"member":{"reference":"#pr1","display":"Dorothy Dietition"}}],"goal":[{"description":"Target weight is 80 kg. Note: be nice if this could be coded"}],"activity":[{"prohibited":false,"simple":{"category":"observation","code":{"text":"a code for weight measurement"},
  "timingSchedule":{"event":[{"start": "2014-03-05"}]},"performer":[{"reference":"Patient/example","display":"Peter James Chalmers"}]}}]}', '{activity,simple,timingSchedule}','Schedule')
=> '["2014-03-05 00:00:00+00",)'
