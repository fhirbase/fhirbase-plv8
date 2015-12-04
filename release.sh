set -e

export PREV_FBVERSION="fhirbase-0.0.1-betta.3"
export FBVERSION="fhirbase-0.0.1-betta.4"

export DATABASE_URL=postgres://root:root@localhost:5432/build
PGOPTIONS='--client-min-messages=warning'
loadcmd="psql -X -q -a -1 -v ON_ERROR_STOP=1 --pset pager=off"

psql postgres -c 'drop database if exists build' && \
psql postgres -c "create database build" && \
bash build.sh && \
cat tmp/build.sql  | $loadcmd build  > /dev/null && \
npm run test && \

psql postgres -c 'drop database if exists build' && \
psql postgres -c "create database build" && \
bash build.sh && \
cat releases/$PREV_FBVERSION.sql  | $loadcmd build > /dev/null && \
time cat tmp/patch.sql | $loadcmd build > /dev/null && \
npm run test && \


cp tmp/build.sql  releases/$FBVERSION.sql && \
cp tmp/patch.sql  releases/$FBVERSION-patch.sql && \
cd releases && \

zip -r $FBVERSION.sql.zip zip $FBVERSION.sql && \
zip -r $FBVERSION-patch.sql.zip $FBVERSION-patch.sql



