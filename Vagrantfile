Vagrant.configure('2') do |config|
  config.vm.provider 'docker' do |docker|
    docker.image = 'fhirbase/fhirbase'
    docker.ports = ['5432:5432']
  end

  config.vm.network 'forwarded_port', guest: 5432, host: 5433

  # config.vm.provision('docker', images: ['fhirbase/fhirbase']) do |docker|
  #   docker.run 'fhirbase/fhirbase'
  # end
end
