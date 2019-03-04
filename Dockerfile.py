FROM debian:wheezy

ADD Makefile /app/
ADD requirements.txt.py /app/requirements.txt
ADD config/perl/ /app/config/perl/
ADD bin/ /app/bin/
ADD lib/ /app/lib/
ADD modules/ /app/modules/
ADD deps/ /app/deps/

RUN cd /app && \
    apt-get update && \
    apt-get install -y make perl curl wget libssl-dev && \
    make deps-docker-py PMBP_OPTIONS="--execute-system-package-installer --dump-info-file-before-die" && \
    pip install -r requirements.txt && \
    rm -rf /var/lib/apt/lists/* deps

CMD cd /app && ./plackup -s Twiggy::Prefork -p $PORT bin/server.psgi
