all:

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl
	$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl

## ------ Setup ------

deps: always
	true # dummy for make -q
ifdef PMBP_HEROKU_BUILDPACK
else
	$(MAKE) git-submodules
endif
	$(MAKE) pmbp-install
ifdef PMBP_HEROKU_BUILDPACK
	$(MAKE) deps-harusame-deps deps-webhacc-deps
else
	$(MAKE) deps-harusame-install deps-webhacc-install
endif

deps-docker-py: pmbp-install
	pip install --upgrade pip

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove \
            --create-perl-command-shortcut @plackup=perl\ modules/twiggy-packed/script/plackup

deps-harusame-install:
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --install-perl-app git://github.com/wakaba/harusame
deps-harusame-deps:
	cd local/harusame && $(MAKE) pmbp-install

deps-webhacc-install:
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --install-perl-app git://github.com/manakai/webhacc-cli
deps-webhacc-deps:
	cd local/webhacc-cli && $(MAKE) pmbp-install

deps-heroku-py: pmbp-install

create-commit-for-heroku:
	git remote rm origin
	rm -fr deps/pmtar/.git deps/pmpp/.git modules/*/.git
	git add -f deps/pmtar/* #deps/pmpp/*
	#rm -fr ./t_deps/modules
	#git rm -r t_deps/modules
	git rm .gitmodules
	git rm modules/* --cached
	rm -fr local/harusame/.git local/harusame/deps/pmtar/.git
	rm -fr local/harusame/deps/pmpp
	rm -fr local/harusame/t local/harusame/t_deps
	rm -fr local/harusame/modules/*/.git
	rm -fr local/webhacc-cli/.git local/webhacc-cli/deps/pmtar/.git
	rm -fr local/webhacc-cli/deps/pmpp
	rm -fr local/webhacc-cli/t local/webhacc-cli/t_deps
	rm -fr local/webhacc-cli/modules/*/.git
	git add -f modules/*/* local/harusame local/webhacc-cli
	git commit -m "for heroku"

create-commit-for-heroku-py:
	wget -O anolis.zip https://bitbucket.org/ms2ger/anolis/get/bb7e0d4b8463.zip
	unzip anolis.zip
	cat config/python/requirements.*.txt > requirements.txt.py
	echo "/app/ms2ger-anolis-bb7e0d4b8463" >> requirements.txt.py
	cp heroku.yml.py heroku.yml
	git add requirements.txt.py heroku.yml
	git rm -fr Procfile local
	git commit -m "for heroku2"

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	#$(PROVE) t/*.t

always:

## License: Public Domain.
