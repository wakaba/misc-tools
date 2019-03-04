FROM quay.io/wakaba/docker-perl-app-base

ADD Makefile /app/
ADD requirements.txt /app/
ADD config/perl/ /app/config/perl/
ADD bin/ /app/bin/
ADD lib/ /app/lib/
ADD modules/ /app/modules/
ADD deps/ /app/deps/

RUN cd /app && \
    apt-get install -y python-pip && \
    make deps-docker-py PMBP_OPTIONS="--execute-system-package-installer --dump-info-file-before-die" && \
    pip install -r requirements.txt && \
    rm -rf /var/lib/apt/lists/* deps

CMD ./plackup -s Twiggy::Prefork -p $PORT bin/server.psgi
