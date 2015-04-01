alias d="sudo docker.io"

d build -t test_fhirbase .
d run --name=test_fhirb -d -p 2345:5432 -t test_fhirbase

sleep 10

env PGUSER=fhirbase PGPASSWORD=fhirbase PGHOST=localhost PGPORT=2345 DB=fhirbase ./runme test test/fhirbase_spec.sql

d stop test_fhirb
d rm test_fhirb

