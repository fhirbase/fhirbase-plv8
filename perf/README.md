# Requirements

* Ansible 1.9.4

# Environment preparation

`docker_setup.sh` will build docker image and create container
with __Ubuntu 14.04.3__ with `ubuntu` user and `ubuntu`.

```bash
path/to/fhirbase/perf/provisioning/docker_setup.sh
```

Prepare `secure` directory with ssh keys used by container.

```bash
cd path/to/fhirbase && ./secure-decrypt.sh
```

`22` port will proxy to `7022` port.

```bash
ssh -p 7022 \
    -i path/to/fhirbase/secure/local_docker.pem \
    ubuntu@localhost
```

Use `ping.yml` to test ansible and docker:

```bash
ansible-playbook --private-key=path/to/fhirbase/secure/local_docker.pem \
                 --inventory=inventories/local \
                 ping.yml
```

# Playbooks

## bootstrap.yml

Install PostgreSQL and stuff

```bash
ansible-playbook --private-key=path/to/fhirbase/secure/local_docker.pem \
                 --inventory=inventories/local \
                 bootstrap.yml
```

## perf.yml

Run performance test

```bash
ansible-playbook --private-key=path/to/fhirbase/secure/local_docker.pem \
                 --inventory=inventories/local \
                 perf.yml
```

# FAQ

## Для чего нужны Inventories

Чтобы не править файлы плейбуков и не мудрить с параметризацией через
переменные окружения, данные с адресами серверов и авторизационные
данные выносятся в Inventory. Инвентарь — это просто конфиг для
подключения к хосту.

Например, чтобы проиграть плейбук для локального докер-контейнера,
нужно указать инвентарь из `inventories/local`. Для деплоя на devbox
staging нужно использовать инвентарь из
`inventories/devbox.health-samurai.io`:

```bash
ansible-playbook -i inventories/local ping.yml
ansible-playbook -i inventories/example.com bootstrap.yml perf.yml
```

## Для чего нужны host_vars

`host_vars` — это тоже конфиги, только эти конфиги используются для
внутренней настройки хоста.
Большая часть данных из `host_vars` используется при бутстрапе
окружения.
