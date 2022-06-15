PREFIX=$${HOME}
APPDIR=$(PREFIX)/UpdateUbuntuCalendarIcon
BINDIR=$(APPDIR)/bin
TEMPLATESDIR=$(APPDIR)/templates

install:
	mkdir -p $(APPDIR)
	mkdir -p $(BINDIR)
	mkdir -p $(TEMPLATESDIR)
	test -f /usr/bin/inkscape || (echo "Missing Inkscape. Run 'sudo apt install inkscape' to install. $$?"; exit 1)
	test -f /usr/bin/convert || (echo "Missing ImageMagick. Run 'sudo apt install imagemagick' to install. $$?"; exit 1)
	test -f /usr/bin/perl || (echo "Missing Perl. Run 'sudo apt install perl' to install. $$?"; exit 1)
	cp ./src/update_cal_icon.pl $(BINDIR)/
	sed -i "s#use constant APPDIR => '.';#use constant APPDIR => '$(APPDIR)';#" $(BINDIR)/update_cal_icon.pl
	chmod 0555 $(BINDIR)/update_cal_icon.pl
	chown $(shell id -u):$(shell id -g) $(BINDIR)/update_cal_icon.pl
	cp ./src/templates/calendar.svg $(TEMPLATESDIR)/
	chmod 0444 $(TEMPLATESDIR)/calendar.svg
	chown $(shell id -u):$(shell id -g) $(TEMPLATESDIR)/calendar.svg

uninstall:
	./src/update_cal_icon.pl remove-timer
	./src/update_cal_icon.pl remove
	rm -rf $(APPDIR)
  
