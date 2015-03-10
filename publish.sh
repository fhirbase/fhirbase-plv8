if [ -z $1 ]; then
  echo "No version supplied"
  exit
else
  echo "Publish version: $1"
fi

git tag $1
echo "Build docker: fhirbase/fhirbase-build:$1"
sudo docker.io build -t fhirbase/fhirbase-build:$1 .
echo 'TODO: Test docker docker'
sudo docker.io tag fhirbase/fhirbase-build:$1 fhirbase/fhirbase-build:dev

git push --follow-tags
sudo docker.io push fhirbase/fhirbase-build
