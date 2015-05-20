$script = <<SCRIPT
  sudo docker run --name=fhirbase -p 5432:5432 -d -t quay.io/fhirbase/fhirbase:0.0.12
SCRIPT

Vagrant.configure('2') do |config|
  config.vm.box = 'boxcutter/ubuntu1410-docker'
  config.vm.box_url = 'https://atlas.hashicorp.com/boxcutter/boxes/ubuntu1410-docker'
  config.vm.provision "shell", inline: $script
  config.vm.network "forwarded_port", guest: 5432, host: 2345
end

