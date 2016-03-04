

FF_PROF_DIR = $(W5_FFPROFDIR)
FF_EXT_DIR = $(FF_PROF_DIR)/extensions

EXTENSION_ID = w5@pdos.lcs.mit.edu
EXTENSION_DIR = $(FF_EXT_DIR)/$(EXTENSION_ID)
EXTENSION_FILE = w5toolbar.xpi


FILES = chrome/chromeFiles/locale/en-US/w5toolbar/w5toolbar.dtd \
	chrome/chromeFiles/content/w5toolbar-overlay.js \
	chrome/chromeFiles/content/util.js \
	chrome/chromeFiles/content/test.js \
	chrome/chromeFiles/content/w5toolbar-overlay.xul \
	chrome/chromeFiles/content/preferences.js \
	chrome/chromeFiles/content/preferences.xul \
	chrome/chromeFiles/content/images/webmac32.png \
	chrome/chromeFiles/content/images/w5toolbar32.png \
	chrome/chromeFiles/content/images/w5toolbar18.png \
	chrome.manifest \
	defaults/preferences/w5toolbar.js \
	install.rdf

$(EXTENSION_FILE): $(FILES)
	zip -q $@ $(FILES)

all: $(EXTENSION_FILE)

install: $(EXTENSION_FILE)
	mkdir -p $(EXTENSION_DIR)
	unzip -q -o $(EXTENSION_FILE) -d $(EXTENSION_DIR)
	rm -f $(FF_PROF_DIR)/extensions.ini
	rm -f $(FF_PROF_DIR)/compreg.dat
	rm -f $(FF_PROF_DIR)/xpti.dat

clean:
	rm -f $(EXTENSION_FILE)