DESTDIR?=/opt/www/htdocs/os

all:
	- mkdir -p $(DESTDIR)
	cp router.lua mimes.json $(DESTDIR)
	cp -rf controllers $(DESTDIR)
	cp -rf libs $(DESTDIR)
clean:
	rm -rf $(DESTDIR)/router.lua $(DESTDIR)/mimes.json \
		$(DESTDIR)/controllers  $(DESTDIR)/libs