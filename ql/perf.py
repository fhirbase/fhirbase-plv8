import ql
import os
import ql.prepr
import ql.perf
import ql.migrate
from ql.pg import psql
import sys
import glob
import re

def perf(db, args):
    perf_files = glob.glob('./perf/*.sql')
    ql.reload_files(db, perf_files)

    benchmarks = [
        ["disk usage right after generation of seed data",
         "SELECT admin.admin_disk_usage_top(10)"],

        ["fhir.create called just one time",
         "SELECT performance.create_patients(1)"],

        ["fhir.create called 1000 times in batch",
         "SELECT performance.create_patients(1000)"],

        ["fhir.read called just one time",
         "SELECT performance.read_patients(1)"],

        ["fhir.read called 1000 times in batch",
         "SELECT performance.read_patients(1000)"],

        ["Updating single patient with fhir.update()",
         "SELECT performance.create_temporary_patients(1000);\nSELECT performance.update_patients(1)"],

        ["fhir.delete called one time",
         "SELECT performance.delete_patients(1)"],

        ["fhir.delete called 1000 times in batch",
         "SELECT performance.delete_patients(1000)"],

        ["searching for non-existent name without index",
         "SELECT count(*) FROM fhir.search('Patient', 'name=nonexistentname')"],

        ["building Patient.name index",
         "SELECT performance.index_search_param('Patient','name')"],

        ["building Patient.gender index",
         "SELECT performance.index_search_param('Patient','gender')"],

        ["building Patient.address index",
         "SELECT performance.index_search_param('Patient','address')"],

        ["building Patient.telecom index",
         "SELECT performance.index_search_param('Patient','telecom')"],

        ["building Participant.name index",
         "SELECT performance.index_search_param('Participant','name')"],

        ["building Organization.name index",
         "SELECT performance.index_search_param('Organization','name')"],

        ["building Encounter.status index",
         "SELECT performance.index_search_param('Encounter','status')"],

        ["building Encounter.patient index",
         "SELECT performance.index_search_param('Encounter','patient')"],

        ["building Encounter.participant index",
         "SELECT performance.index_search_param('Encounter','participant')"],

        ["building Encounter.practitioner index",
         "SELECT performance.index_search_param('Encounter','practitioner')"],

        ["building Patient.organization index",
         "SELECT performance.index_search_param('Patient','organization')"],

        ["running VACUUM ANALYZE on patient table",
         "VACUUM ANALYZE patient"],

        ["running VACUUM ANALYZE on encounter table",
         "VACUUM ANALYZE encounter"],

        ["running VACUUM ANALYZE on organization table",
         "VACUUM ANALYZE organization"],

        ["running VACUUM ANALYZE on practitioner table",
         "VACUUM ANALYZE practitioner"],

        ["searching for patient with unique name",
         "SELECT performance.search_patient_with_only_one_search_candidate()"],

        ["searching for all Johns in database",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&_count=50000000')"],

        ["searching Patient with name=John&gender=female&_count=100 (should have no matches at all)",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=female&_count=100')"],
        ["searching Patient with name=John&gender=male&_count=100",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100')"],
        ["searching Patient with name=John&gender=male&active=true&address=YALUMBA&_count=100",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&active=true&address=YALUMBA&_count=100')"],

        ["searching Patient with name=John&gender=male&_count=100&_sort=name",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100&_sort=name')"],

        ["searching Patient with name=John&gender=male&_count=100&_sort=active",
         "SELECT count(*) FROM fhir.search('Patient', 'name=John&gender=male&_count=100&_sort=active')"],

        ["searching Encounter with patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex",
         "SELECT count(*) FROM fhir.search('Encounter', 'patient:Patient.name=John&_count=100&status=finished&practitioner:Practitioner.name=Alex')"],

        ["searching Encounter with patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis",
         "SELECT count(*) FROM fhir.search('Encounter', 'patient:Patient.name=John&_count=100&patient:Patient.organization:Organization.name=Mollis')"]
    ]

    results = []

    for test in benchmarks:
        desc = test[0]
        sql = test[1]

        print desc
        r = psql(db, "\\timing\n%s;" % sql)
        print r["stdout"]

        m = re.search("Time: ([0-9.,]+) ms", r["stdout"])
        time = m.groups()[0]

        results.append([desc, time])

        print "-" * 50

    maxlength = max([len(x[0]) for x in results]) + 5

    print "\nRESULTS:"
    for r in results:
        print "{0: <{maxlength}} {1: >10} ms".format(r[0], r[1], maxlength=maxlength)
