# MacBook Air (1M patients)

## Performance

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
building Encounter.participant index                                                                                              8.256 ms
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

## Raw

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

## Size

```
disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"98 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_111888,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 8,492 ms
```

## Performance
```
disk usage right after generation of seed data                                                                               10,023 ms
fhir.create called just one time                                                                                              8,300 ms
fhir.create called 1000 times in batch                                                                                      642,207 ms
fhir.read called just one time                                                                                                5,912 ms
fhir.read called 1000 times in batch                                                                                        175,103 ms
Updating single patient with fhir.update()                                                                                  110,883 ms
fhir.delete called one time                                                                                                   4,217 ms
fhir.delete called 1000 times in batch                                                                                      337,431 ms
searching for non-existent name without index                                                                             56176,987 ms
building Patient.name index                                                                                               64518,944 ms
building Patient.gender index                                                                                             49518,105 ms
building Patient.address index                                                                                           123283,911 ms
building Patient.telecom index                                                                                            79562,081 ms
building Participant.name index                                                                                               4,561 ms
building Organization.name index                                                                                             39,553 ms
building Encounter.status index                                                                                           66670,859 ms
building Encounter.patient index                                                                                          91143,656 ms
building Encounter.participant index                                                                                          3,424 ms
building Encounter.practitioner index                                                                                         4,015 ms
building Patient.organization index                                                                                       45433,334 ms
running VACUUM ANALYZE on patient table                                                                                   19400,141 ms
running VACUUM ANALYZE on encounter table                                                                                  3662,147 ms
running VACUUM ANALYZE on organization table                                                                                 36,605 ms
running VACUUM ANALYZE on practitioner table                                                                                  4,670 ms
searching for patient with unique name                                                                                       25,476 ms
searching for all Johns in database                                                                                         120,679 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                    65,596 ms
searching Patient with name=John&gender=male&_count=100                                                                      31,992 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                          18,704 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          110,051 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                         91,659 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         12726,057 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         183,248 ms
```

# Amazon RDS - db.t2.micro (1M patients)

## Hardware

* Class: db.t2.micro
* Storage Type: General Purpose (SSD)
* Storage: 5 GB
* Engine: postgres
* Engine Version: 9.4.1
* Encrypted: No
* Endpoint: fhirbase.cpjjbgbfyeng.us-west-1.rds.amazonaws.com:5432

## Raw

```
PGHOST=fhirbase.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme build

PGHOST=fhirbase.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed

Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 403425,397 ms

PGHOST=fhirbase.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme perf
```

## Size

```
disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"98 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_16503,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 225,285 ms
```

## Performance

```
disk usage right after generation of seed data                                                                              225,285 ms
fhir.create called just one time                                                                                            275,062 ms
fhir.create called 1000 times in batch                                                                                     1487,994 ms
fhir.read called just one time                                                                                              205,522 ms
fhir.read called 1000 times in batch                                                                                        794,516 ms
Updating single patient with fhir.update()                                                                                  522,262 ms
fhir.delete called one time                                                                                                 260,549 ms
fhir.delete called 1000 times in batch                                                                                     1691,040 ms
searching for non-existent name without index                                                                             73965,293 ms
building Patient.name index                                                                                               91126,739 ms
building Patient.gender index                                                                                             73233,964 ms
building Patient.address index                                                                                           167526,909 ms
building Patient.telecom index                                                                                           109897,848 ms
building Participant.name index                                                                                             211,297 ms
building Organization.name index                                                                                            249,692 ms
building Encounter.status index                                                                                           99244,819 ms
building Encounter.patient index                                                                                         111530,729 ms
building Encounter.participant index                                                                                            219,066 ms
building Encounter.practitioner index                                                                                       204,985 ms
building Patient.organization index                                                                                       58602,119 ms
running VACUUM ANALYZE on patient table                                                                                   95621,509 ms
running VACUUM ANALYZE on encounter table                                                                                 33805,179 ms
running VACUUM ANALYZE on organization table                                                                                264,316 ms
running VACUUM ANALYZE on practitioner table                                                                                228,069 ms
searching for patient with unique name                                                                                      340,173 ms
searching for all Johns in database                                                                                        1122,438 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   290,577 ms
searching Patient with name=John&gender=male&_count=100                                                                     243,546 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                         228,047 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          338,938 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        332,615 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         15867,754 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         416,509 ms
```

# Amazon RDS - db.t2.small (1M patients)

## Hardware

* Class: db.t2.small
* Storage Type: General Purpose (SSD)
* Storage: 5 GB
* Engine: postgres
* Engine Version: 9.4.1
* Encrypted: No
* Endpoint: fhirbase-2.cpjjbgbfyeng.us-west-1.rds.amazonaws.com:5432

## Raw

```
PGHOST=fhirbase-2.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme build

PGHOST=fhirbase-2.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed

Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 347389,214 ms

PGHOST=fhirbase-2.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme perf
```

## Size

```
disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"98 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_16503,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 214,047 ms
```

## Performance

```
disk usage right after generation of seed data                                                                              214,047 ms
fhir.create called just one time                                                                                            277,006 ms
fhir.create called 1000 times in batch                                                                                     1466,573 ms
fhir.read called just one time                                                                                              209,396 ms
fhir.read called 1000 times in batch                                                                                        730,432 ms
Updating single patient with fhir.update()                                                                                  388,134 ms
fhir.delete called one time                                                                                                 268,168 ms
fhir.delete called 1000 times in batch                                                                                     1635,118 ms
searching for non-existent name without index                                                                             74319,450 ms
building Patient.name index                                                                                               90406,729 ms
building Patient.gender index                                                                                             73328,226 ms
building Patient.address index                                                                                           166842,641 ms
building Patient.telecom index                                                                                           111242,295 ms
building Participant.name index                                                                                             211,554 ms
building Organization.name index                                                                                            247,558 ms
building Encounter.status index                                                                                          102705,758 ms
building Encounter.patient index                                                                                         115113,043 ms
building Encounter.participant index                                                                                            206,293 ms
building Encounter.practitioner index                                                                                       209,628 ms
building Patient.organization index                                                                                       62497,050 ms
running VACUUM ANALYZE on patient table                                                                                   87933,859 ms
running VACUUM ANALYZE on encounter table                                                                                 29777,740 ms
running VACUUM ANALYZE on organization table                                                                                259,394 ms
running VACUUM ANALYZE on practitioner table                                                                                224,543 ms
searching for patient with unique name                                                                                      289,646 ms
searching for all Johns in database                                                                                         369,587 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   290,928 ms
searching Patient with name=John&gender=male&_count=100                                                                     249,562 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                         217,709 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          348,694 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        339,493 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         16624,151 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         425,217 ms
```

# Amazon RDS - db.t2.medium (1M patients)

## Hardware

* Class: db.t2.medium
* Storage Type: General Purpose (SSD)
* Storage: 5 GB
* Engine: postgres
* Engine Version: 9.4.1
* Encrypted: No
* Endpoint: fhirbase-3.cpjjbgbfyeng.us-west-1.rds.amazonaws.com:5432

## Raw

```
PGHOST=fhirbase-3.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme build

PGHOST=fhirbase-3.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed

Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 297499,137 ms

PGHOST=fhirbase-3.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme perf
```

## Size

```
disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"98 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_16503,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 251,638 ms
```

## Performance

```
disk usage right after generation of seed data                                                                              251,638 ms
fhir.create called just one time                                                                                            259,051 ms
fhir.create called 1000 times in batch                                                                                     1154,012 ms
fhir.read called just one time                                                                                              205,077 ms
fhir.read called 1000 times in batch                                                                                        522,362 ms
Updating single patient with fhir.update()                                                                                  441,320 ms
fhir.delete called one time                                                                                                 212,713 ms
fhir.delete called 1000 times in batch                                                                                      817,892 ms
searching for non-existent name without index                                                                             70027,329 ms
building Patient.name index                                                                                               87737,590 ms
building Patient.gender index                                                                                             71807,105 ms
building Patient.address index                                                                                           159742,052 ms
building Patient.telecom index                                                                                           104483,526 ms
building Participant.name index                                                                                             221,909 ms
building Organization.name index                                                                                            251,234 ms
building Encounter.status index                                                                                           98142,402 ms
building Encounter.patient index                                                                                         103020,055 ms
building Encounter.participant index                                                                                            205,692 ms
building Encounter.practitioner index                                                                                       207,741 ms
building Patient.organization index                                                                                       61889,533 ms
running VACUUM ANALYZE on patient table                                                                                   81462,458 ms
running VACUUM ANALYZE on encounter table                                                                                 28862,497 ms
running VACUUM ANALYZE on organization table                                                                                284,253 ms
running VACUUM ANALYZE on practitioner table                                                                                229,989 ms
searching for patient with unique name                                                                                      378,068 ms
searching for all Johns in database                                                                                         327,181 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   304,569 ms
searching Patient with name=John&gender=male&_count=100                                                                     247,662 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                         216,418 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          342,651 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        349,441 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         16156,156 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         421,937 ms
```

# Amazon RDS - db.m3.medium (1M patients)

## Hardware

* Class: db.m3.medium
* Storage Type: General Purpose (SSD)
* Storage: 5 GB
* Engine: postgres
* Engine Version: 9.4.1
* Encrypted: No
* Endpoint: fhirbase-4.cpjjbgbfyeng.us-west-1.rds.amazonaws.com:5432

## Raw

```
PGHOST=fhirbase-4.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme build

PGHOST=fhirbase-4.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed
```

## Size

```
Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 497960,587 ms

PGHOST=fhirbase-4.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme perf

disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"98 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_16503,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 277,946 ms
```

## Performance

```
disk usage right after generation of seed data                                                                              277,946 ms
fhir.create called just one time                                                                                            282,487 ms
fhir.create called 1000 times in batch                                                                                     1746,039 ms
fhir.read called just one time                                                                                              208,766 ms
fhir.read called 1000 times in batch                                                                                        699,437 ms
Updating single patient with fhir.update()                                                                                  611,039 ms
fhir.delete called one time                                                                                                 361,234 ms
fhir.delete called 1000 times in batch                                                                                     3172,697 ms
searching for non-existent name without index                                                                            150543,584 ms
building Patient.name index                                                                                              180524,064 ms
building Patient.gender index                                                                                            148594,928 ms
building Patient.address index                                                                                           331647,773 ms
building Patient.telecom index                                                                                           219243,290 ms
building Participant.name index                                                                                             213,703 ms
building Organization.name index                                                                                            284,381 ms
building Encounter.status index                                                                                          203268,255 ms
building Encounter.patient index                                                                                         206153,998 ms
building Encounter.participant index                                                                                        220,982 ms
building Encounter.practitioner index                                                                                       208,526 ms
building Patient.organization index                                                                                      121744,697 ms
running VACUUM ANALYZE on patient table                                                                                  121436,925 ms
running VACUUM ANALYZE on encounter table                                                                                 34599,967 ms
running VACUUM ANALYZE on organization table                                                                                287,857 ms
running VACUUM ANALYZE on practitioner table                                                                                229,068 ms
searching for patient with unique name                                                                                      301,607 ms
searching for all Johns in database                                                                                         615,540 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   396,715 ms
searching Patient with name=John&gender=male&_count=100                                                                     308,913 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                         238,200 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          512,811 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        486,161 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         36674,545 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         703,125 ms
```

# Amazon RDS - db.r3.8xlarge (1M patients)

## Hardware

* Class: db.r3.8xlarge
* Storage Type: Provisioned IOPS (SSD)
* Storage: 100 GB
* IOPS: 1000
* Engine: postgres
* Engine Version: 9.4.1
* Encrypted: No
* Endpoint: fhirbase-5.cpjjbgbfyeng.us-west-1.rds.amazonaws.com:5432

## Raw

```
PGHOST=fhirbase-5.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme build

PGHOST=fhirbase-5.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase PATIENTS_COUNT=1000000 ./runme seed
```

## Size

```
Timing is on.
 generate 
----------
  1000000
(1 row)

Time: 223382,349 ms

PGHOST=fhirbase-5.cpjjbgbfyeng.us-west-1.rds.amazonaws.com PGPORT=5432 PGDATABASE=fhirbase PGUSER=fhirbase PGPASSWORD=fhirbase DB=fhirbase ./runme perf

disk usage right after generation of seed data
Timing is on.
              admin_disk_usage_top               
-------------------------------------------------
 (public.patient,"1302 MB")
 (public.encounter,"548 MB")
 (public.encounter_pkey,"97 MB")
 (public.patient_pkey,"73 MB")
 (temp.last_names,"3360 kB")
 (temp.first_names,"1936 kB")
 (temp.cities,"1920 kB")
 (pg_toast.pg_toast_16503,"1472 kB")
 (public.structuredefinition_elements,"1048 kB")
 (public.valueset,"968 kB")
(10 rows)

Time: 207,413 ms
```

## Performance

```
disk usage right after generation of seed data                                                                              207,413 ms
fhir.create called just one time                                                                                            213,469 ms
fhir.create called 1000 times in batch                                                                                      879,353 ms
fhir.read called just one time                                                                                              208,156 ms
fhir.read called 1000 times in batch                                                                                        396,348 ms
Updating single patient with fhir.update()                                                                                  340,407 ms
fhir.delete called one time                                                                                                 207,463 ms
fhir.delete called 1000 times in batch                                                                                      704,367 ms
searching for non-existent name without index                                                                             70774,305 ms
building Patient.name index                                                                                               85753,144 ms
building Patient.gender index                                                                                             71467,160 ms
building Patient.address index                                                                                           157911,853 ms
building Patient.telecom index                                                                                           103705,596 ms
building Participant.name index                                                                                             209,533 ms
building Organization.name index                                                                                            237,218 ms
building Encounter.status index                                                                                           95653,414 ms
building Encounter.patient index                                                                                          95312,580 ms
building Encounter.participant index                                                                                        209,598 ms
building Encounter.practitioner index                                                                                       203,901 ms
building Patient.organization index                                                                                       56424,106 ms
running VACUUM ANALYZE on patient table                                                                                   32440,887 ms
running VACUUM ANALYZE on encounter table                                                                                  9052,227 ms
running VACUUM ANALYZE on organization table                                                                                246,270 ms
running VACUUM ANALYZE on practitioner table                                                                                220,885 ms
searching for patient with unique name                                                                                      230,123 ms
searching for all Johns in database                                                                                         321,991 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   287,771 ms
searching Patient with name=John&gender=male&_count=100                                                                     247,900 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                         219,679 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          343,859 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        332,514 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex         15941,140 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis         417,854 ms
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

```
10M Patients (mlapshin workstation)

disk usage right after generation of seed data                                                                               11,830 ms
fhir.create called just one time                                                                                             18,905 ms
fhir.create called 1000 times in batch                                                                                     1861,735 ms
fhir.read called just one time                                                                                                6,360 ms
fhir.read called 1000 times in batch                                                                                        590,863 ms
Updating single patient with fhir.update()                                                                                  165,430 ms
fhir.delete called one time                                                                                                   7,976 ms
fhir.delete called 1000 times in batch                                                                                      842,368 ms
searching for non-existent name without index                                                                            559095,524 ms
building Patient.name index                                                                                              630598,769 ms
building Patient.gender index                                                                                            488680,672 ms
building Patient.address index                                                                                           1221804,100 ms
building Patient.telecom index                                                                                           776166,156 ms
building Participant.name index                                                                                              22,269 ms
building Organization.name index                                                                                             57,735 ms
building Encounter.status index                                                                                          652347,112 ms
building Encounter.patient index                                                                                         1578718,725 ms
building Encounter.participant index                                                                                         23,583 ms
building Encounter.practitioner index                                                                                         4,510 ms
building Patient.organization index                                                                                      456730,511 ms
running VACUUM ANALYZE on patient table                                                                                  117220,769 ms
running VACUUM ANALYZE on encounter table                                                                                 48796,100 ms
running VACUUM ANALYZE on organization table                                                                                 48,803 ms
running VACUUM ANALYZE on practitioner table                                                                                 10,479 ms
searching for patient with unique name                                                                                       54,644 ms
searching for all Johns in database                                                                                        1379,931 ms
searching Patient with name=John&gender=female&_count=100 (should have no matches at all)                                   108,387 ms
searching Patient with name=John&gender=male&_count=100                                                                      63,641 ms
searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100                                          33,443 ms
searching Patient with name=John&gender=male&_count=100&_sort=name                                                          921,170 ms
searching Patient with name=John&gender=male&_count=100&_sort=active                                                        810,976 ms
searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex        35509215,810 ms
searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis      519593,454 ms
```
