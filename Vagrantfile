Vagrant.configure('2') do |config|
  config.vm.provider 'docker' do |docker|
    docker.image = 'fhirbase/fhirbase'
    docker.ports = ['5432:5432']
    docker.vagrant_vagrantfile = './Vagrantfile.proxy'
  end
end
