expect
 json_array_length(
   fhirbase_terminology.expand(
    'diagnostic-report-status', ''
   )#>'{expansion, contains}'
 ) > 0
=> true

expect
 json_array_length(
   fhirbase_terminology.expand(
    'diagnostic-report-status', 'unexist'
   )#>'{expansion, contains}'
 ) > 0
=> false

expect
 json_array_length(
   fhirbase_terminology.expand('v3-Race','india')#>'{expansion, contains}'
 ) > 0
=> true

expect
  json_array_length(
    fhirbase_terminology.expand('valueset-systems','')#>'{expansion, contains}'
  ) > 60
=> true

expect
  json_array_length(
    fhirbase_terminology.expand('modality','CR')#>'{expansion, contains}'
  ) = 1
=> true

select count(*) from (
  select fhirbase_terminology.expand(logical_id, '')
    from valueset
) _;
