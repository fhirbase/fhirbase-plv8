# MacBook Air (1M patients)

## Results

```
disk usage right after generation of seed data                                                                               21.885 ms
fhir.create called just one time                                                                                             25.243 ms
fhir.create called 1000 times in batch                                                                                     1209.033 ms
fhir.read called just one time                                                                                                6.694 ms
fhir.read called 1000 times in batch                                                                                        356.768 ms
Updating single patient with fhir.update()                                                                                  218.599 ms
fhir.delete called one time                                                                                                  13.135 ms
fhir.delete called 1000 times in batch                                                                                     1182.448 ms
searching for non-existent name without index                                                                             97010.424 ms
building Patient.name index                                                                                              143934.523 ms
building Patient.gender index                                                                                            106689.734 ms
building Patient.address index                                                                                           249214.413 ms
building Patient.telecom index                                                                                           151158.313 ms
building Participant.name index                                                                                               5.616 ms
building Organization.name index                                                                                             64.074 ms
building Organization.address index                                                                                           6.180 ms
building Encounter.status index                                                                                          125611.808 ms
building Encounter.patient index                                                                                         249651.823 ms
building Encounter.patient index                                                                                              8.256 ms
building Encounter.practitioner index                                                                                         7.585 ms
building Patient.organization index                                                                                      105702.273 ms
running VACUUM ANALYZE on patient table                                                                                   41941.426 ms
running VACUUM ANALYZE on encounter table                                                                                 10796.692 ms
running VACUUM ANALYZE on organization table                                                                                 89.839 ms
running VACUUM ANALYZE on practitioner table                                                                                 17.554 ms
searching for patient with unique name                                                                                       51.238 ms
searching for all Johns in database                                                                                         220.397 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   172.586 ms
searching Patient with name=John&gender=male&_count=100                                                                      80.154 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                          31.600 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          234.077 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        209.552 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         34834.579 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         373.777 ms
```

# Desktop (1M patients)

## Hardware

* Processor: 8x Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
* Memory: 16GB
* Disk: ATA INTEL SSDSC2CT12

## Process

```
DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed

NOTICE:  Generating 1000000 patients with rand_seed=0.21

Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 223766,968 ms

sudo du -hs /var/lib/postgresql/9.4/main
2,2G	/var/lib/postgresql/9.4/main
```

## Results
```
disk usage right after generation of seed data                                                                                8,492 ms
fhir.create called just one time                                                                                             12,664 ms
fhir.create called 1000 times in batch                                                                                      555,482 ms
fhir.read called just one time                                                                                                3,853 ms
fhir.read called 1000 times in batch                                                                                        168,861 ms
Updating single patient with fhir.update()                                                                                   94,689 ms
fhir.delete called one time                                                                                                   3,760 ms
fhir.delete called 1000 times in batch                                                                                      351,098 ms
searching for non-existent name without index                                                                             48103,191 ms
building Patient.name index                                                                                               58246,242 ms
building Patient.gender index                                                                                             45438,514 ms
building Patient.address index                                                                                           112563,936 ms
building Patient.telecom index                                                                                            73133,269 ms
building Participant.name index                                                                                               4,355 ms
building Organization.name index                                                                                             36,529 ms
building Encounter.status index                                                                                           61057,663 ms
building Encounter.patient index                                                                                          85315,345 ms
building Encounter.patient index                                                                                              5,581 ms
building Encounter.practitioner index                                                                                         3,898 ms
building Patient.organization index                                                                                       42034,921 ms
running VACUUM ANALYZE on patient table                                                                                   17620,688 ms
running VACUUM ANALYZE on encounter table                                                                                  3463,841 ms
running VACUUM ANALYZE on organization table                                                                                 32,359 ms
running VACUUM ANALYZE on practitioner table                                                                                  4,240 ms
searching for patient with unique name                                                                                       24,509 ms
searching for all Johns in database                                                                                         127,295 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                    59,475 ms
searching Patient with name=John&gender=male&_count=100                                                                      28,686 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                          10,150 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                           90,656 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                         84,282 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         11784,941 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         142,356 ms
```

# TODO

```
1000  - Time: 1365.644 ms

Timing is on.
 count
-------
 10000
(1 row)

Time: 5963.041 ms

Timing is on.
 count
--------
 100000
(1 row)

Time: 58025.182 ms

Timing is on.
 count
--------
 100000
(1 row)

(public.patient,"46 MB")

Time: 30553.204 ms

# with insert

Timing is on.
INSERT 0 100000
Time: 4488.318 ms



Timing is on.
INSERT 0 200000
Time: 8600.216 ms


--------------------------------------------------------

50M patients generation took 3.5 hours

Right after insert public.patient = 64 Gb
After VACUMM FULL size of table on disk remains the same.

Inserting 1000 patients with crud.create() in one SELECT took ~1900 ms
(approx 1.9 ms per patient).
Inserting single patient with crud.create() takes ~9.5 ms.

Reading 1000 patients with crud.read() in one SELECT took 1488 ms
(approx 1.5 ms per patient).
Reading single patient with crud.read() takes ~8 ms.

Updateing single patient with crud.update() takes 319 seconds.

Deleting 1000 patients with crud.delete() in one SELECT took 1665 ms
(approx 1.7 ms per patient).
Deleting single patient with crud.delete() takes ~10 ms.

Searching with 'name=John' without index takes 8098 ms (fast because
of default LIMIT)

Searching for non-existent name without index takes 43 minutes.

Indexing patient name
with indexing.index_search_param('Patient', 'name')
takes 3226 seconds (53 minutes).

Index on patient name (patient_name_name_string_idx)
takes on disk 2250 MB.

Searching for non-existent name with index takes ~200 ms.

Searching by partial match for 'name=John' with fhir.search() using index
and with many search candidates takes 4.7 s

Searching patient by partial match for 'name=John' with fhir.search()
using index and with only one search candidate takes ~198 ms.

Indexing patient identifier
indexing.index_search_param('Patient','identifier')
takes ~5.2 hours.

Indexing patient gender
indexing.index_search_param('Patient','gender')
takes ~42 minutes.

Indexing patient address
indexing.index_search_param('Patient','address')
takes ~103 minutes.

Indexing patient active
indexing.index_search_param('Patient','active')
takes ~41 minutes.

Searching for 'gender=female&_count=50000000'
with fhir.search() using index takes ~9 s

Indexing patient telecom
indexing.index_search_param('Patient','telecom')
takes ~65 minutes.

History by id for non-existent patient takes ~25 ms.

History by id for one patient takes ~25 ms.

History by all patient carsh after 66 minutes
with error (no space left on device).

---------------------------------------------------------

10K patients

Indexing patient birthDate
with indexing.index_search_param('Patient', 'birthdate')
takes 16.7 seconds (50M patients => 23 hours).

---------------------------------------------------------
```
