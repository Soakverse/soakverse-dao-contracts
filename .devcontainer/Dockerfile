FROM debian:bullseye

# disable interactive ui
ENV DEBIAN_FRONTEND=noninteractive

# install dependencies from package manager
RUN apt update && apt install -y \
    sudo \
    git \
    curl wget

# install nodejs, npm & yarn
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && apt-get install -y nodejs
RUN npm install -g yarn

# install solt (https://github.com/hjubb/solt)
# RUN wget https://github.com/hjubb/solt/releases/download/v0.5.2/solt-linux-x64 -O /usr/local/bin/solt && chmod +x /usr/local/bin/solt

# create 'dev' user, add it to sudo group and set password
RUN mkdir /home/dev
RUN useradd dev && chown -R dev /home/dev
RUN adduser dev sudo
RUN echo "dev:dev"|chpasswd 
