### Heroku

Register on [Heroku][]

[Heroku]: https://heroku.com

Then login and create app

```sh
heroku login
heroku apps:create your-app-name
```

Then create PostgreSQL 9.4 database

```sh
heroku addons:add heroku-postgresql --app your-app-name --version=9.4
```

Then restore fhirbase dump and generate tables

```sh
curl https://raw.githubusercontent.com/fhirbase/fhirbase-build/master/fhirbase.sql \
  | pg:psql --app your-app-name YOUR_DB_NAME
pg:psql --app your-app-name YOUR_DB_NAME --command 'SELECT fhir.generate_tables()'
```
Then run benchmark

```sh
git clone https://github.com/fhirbase/fhirbase.git
cd fhirbase
PGHOST=your-host \
  DB=YOUR_DB_NAME \
  PGPORT=5432 \
  PGUSER=your-user \
  PGPASSWORD=your-password \
  VERBOSE=1 \
  ./runme perf
```
