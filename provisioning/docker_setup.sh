#!/bin/bash
docker stop fhirbase-ansible
docker rm fhirbase-ansible
docker build --tag fhirbase-ansible . || exit 1
docker create --tty --publish=7022:22 --name fhirbase-ansible fhirbase-ansible || exit 1
docker start fhirbase-ansible || exit 1
