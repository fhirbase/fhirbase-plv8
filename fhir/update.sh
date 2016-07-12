#! /bin/bash

set -e

# Bleeding edge FHIR.
# Remember if you're using development FHIR version
# there is a chance this will eat your cat and kill your hamster.
# You have been warned.
# url="http://hl7-fhir.github.io"

# Published FHIR version <http://www.hl7.org/fhir/directory.html>.
# url="http://www.hl7.org/fhir/2015Dec" #1.1.0
url="http://www.hl7.org/fhir/2016May" #1.4.0

rm -f *.json
rm -f *.xml
wget $url/all-valuesets.zip
unzip all-valuesets.zip
rm all-valuesets.zip
rm *.xml
wget $url/2016May/search-parameters.json
wget $url/2016May/profiles-resources.json
wget $url/2016May/profiles-types.json
