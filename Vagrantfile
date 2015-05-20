Vagrant.configure('2') do |config|
  config.vm.provider 'docker' do |docker|
    docker.image = 'fhirbase/fhirbase-build:0.0.10'
    docker.ports = ['5432:5432']
  end
end

