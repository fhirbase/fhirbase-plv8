expect
 jsonb_array_length(
   fhirbase_terminology.expand(
    'diagnostic-report-status',
    ''
   )#>'{expansion, contains}'
 ) > 0
=> true

expect
 jsonb_array_length(
   fhirbase_terminology.expand(
    'diagnostic-report-status',
    'unexist'
   )#>'{expansion, contains}'
 ) > 0
=> false

expect
 jsonb_array_length(
   fhirbase_terminology.expand('v3-Race','india')#>'{expansion, contains}'
 ) > 0
=> true
