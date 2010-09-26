PROVE = prove
POD2HTML = pod2html --css "http://suika.fam.cx/www/style/html/pod.css"

all: lib/constant/exported.html

%.html: %.pod
	$(POD2HTML) $< > $@

test:
	$(PROVE) t/*.t

## License: Public Domain.
