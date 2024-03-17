DESTDIR?=/opt/www/htdocs/os
BUILDID:=$(shell git rev-parse  --short HEAD)
all:
	- mkdir -p $(DESTDIR)
	cp router.lua mimes.json $(DESTDIR)
	cp -rf controllers $(DESTDIR)
	cp -rf libs $(DESTDIR)
	sed -i '1s/^/API_REF="$(BUILDID)"\n/' $(DESTDIR)/router.lua
clean:
	rm -rf $(DESTDIR)/router.lua $(DESTDIR)/mimes.json \
		$(DESTDIR)/controllers  $(DESTDIR)/libs