# This container should as much as possible be like amazone ubuntu container.
FROM ubuntu:14.04.3
MAINTAINER Danil Kutkevich <danil@kutkevich.org>

ENV REFRESHED_AT 2016-03-24

RUN localedef --force --inputfile=en_US --charmap=UTF-8 \
    --alias-file=/usr/share/locale/locale.alias \
    en_US.UTF-8
ENV LANG en_US.UTF-8

RUN apt-get --yes update
RUN apt-get --yes upgrade

RUN apt-get install --yes openssh-server python-apt sudo

USER root

RUN useradd --user-group --create-home --shell /bin/bash ubuntu \
    && echo 'ubuntu:ubuntu' | chpasswd && adduser ubuntu sudo
RUN echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER ubuntu

RUN mkdir ~/.ssh
RUN touch ~/.ssh/authorized_keys

USER root

COPY ../../secure/local_docker.pub /home/ubuntu/.ssh/local_docker.pub
RUN chown ubuntu:ubuntu /home/ubuntu/.ssh/local_docker.pub

USER ubuntu

RUN cat ~/.ssh/local_docker.pub > ~/.ssh/authorized_keys
RUN touch ~/.ssh/known_hosts
RUN chmod 700 ~/.ssh
RUN chmod 600 ~/.ssh/authorized_keys

USER root

RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
