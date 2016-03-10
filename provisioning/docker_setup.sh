#!/bin/bash
docker stop fhirbase-ansible
docker rm fhirbase-ansible
docker build --tag fhirbase-ansible .
docker create --tty --publish=7022:22 --name fhirbase-ansible fhirbase-ansible
docker start fhirbase-ansible
