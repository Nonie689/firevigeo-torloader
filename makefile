##
## Makefile
##
## Licensed under GNU GPL v3

# PREFIX is environment variable, but if it is not set, then set default value
ifeq ($(PREFIX),)
    PREFIX := /usr/bin/
endif

all:
	\shc -S -f firevigeo.sh -o firevigeo

clean :
	\rm *.x.c

cleanall :
	\rm firevigeo
	\rm *.x.c

install: firevigeo
	\install -d $(DESTDIR)$(PREFIX)
	\install -Dm755 firevigeo $(DESTDIR)$(PREFIX)/firevigeo
	\chown root:root $(DESTDIR)$(PREFIX)/firevigeo
	\chmod u+s $(DESTDIR)$(PREFIX)/firevigeo
	\chmod u+x $(DESTDIR)$(PREFIX)/firevigeo
	\install -Dm755 firevigeo-simple_test.sh $(DESTDIR)$(PREFIX)/firevigeo-simple_test
	\install -Dm755 exclude-slow-tor-relays-ng $(DESTDIR)$(PREFIX)/exclude-slow-tor-relays-ng
	\cp -RT data/ /usr/share/firevigeo/data
	\install -Dm644 icon.png /usr/share/firevigeo/icon.png
	\install -Dm644 LICENSE /usr/share/licenses/firevigeo/LICENSE
	\install -Dm644 README.md /usr/share/doc/firevigeo/README.md
	\install -Dm644 country_codes.lst /usr/share/doc/firevigeo/country_codes.lst
	\install -Dm755 firevigeo-tray.py $(DESTDIR)$(PREFIX)/firevigeo-tray.py
	\install -Dm644 firevigeo-tray.desktop /etc/xdg/autostart/firevigeo-tray.desktop
	\install -Dm644 firevigeo-tray-manager.desktop /usr/share/applications/firevigeo-tray.desktop
	\install -Dm644 icon.png /usr/share/icons/hicolor/32x32/apps/firevigeo-tray.png
	\install -Dm644 icon.png /usr/share/icons/hicolor/64x64/apps/firevigeo-tray.png
	\install -Dm644 icon.png /usr/share/icons/hicolor/128x118/apps/firevigeo-tray.png
	\install -Dm644 icon.png /usr/share/icons/hicolor/256x1024/apps/firevigeo-tray.png
	\install -Dm644 icon.png /usr/share/icons/hicolor/512x1024/apps/firevigeo-tray.png
	\install -Dm644 icon.png /usr/share/icons/hicolor/1024x1024/apps/firevigeo-tray.png

uninstall:
	\rm $(DESTDIR)$(PREFIX)/firevideo
	\rm $(DESTDIR)$(PREFIX)firevigeo-simple_test
	\rm $(DESTDIR)$(PREFIX)firevigeo-simple_test
	\rm /usr/share/firevigeo/
	\rm /usr/share/licenses/firevigeo/
	\rm /usr/share/doc/firevigeo/
	\rm $(DESTDIR)$(PREFIX)/firevigeo-tray.py
	\rm /etc/xdg/autostart/firevigeo-tray.desktop
	\rm /usr/share/applications/firevigeo-tray.desktop
	\rm /usr/share/firevigeo/icon.png
	\rm $(DESTDIR)$(PREFIX)/exclude-slow-tor-relays-ng
	\rm /usr/share/icons/hicolor/32x32/apps/firevigeo-tray.png
	\rm /usr/share/icons/hicolor/64x64/apps/firevigeo-tray.png
	\rm /usr/share/icons/hicolor/128x118/apps/firevigeo-tray.png
	\rm /usr/share/icons/hicolor/256x1024/apps/firevigeo-tray.png
	\rm /usr/share/icons/hicolor/512x1024/apps/firevigeo-tray.png
	\rm /usr/share/icons/hicolor/1024x1024/apps/firevigeo-tray.png
