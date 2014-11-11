Vagrant.configure('2') do |config|
  config.vm.provider 'docker' do |docker|
    docker.image = 'fhirbase/fhirbase'
    docker.ports = ['5433:5432']
    docker.vagrant_vagrantfile = './Vagrantfile.proxy'
  end
end
