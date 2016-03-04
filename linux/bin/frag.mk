
SRCDIR_BIN = bin

install-bin: \
	install-bin-flume-cfg \
	install-bin-flume-initdb \
	install-bin-flume-python \
	install-bin-flume-initrm

install-bin-%: $(SRCDIR_BIN)/%
	@echo "+ inst: $< -> $(FLUMEBIN)"
	@mkdir -p $(FLUMEBIN)
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMEBIN)

root-install-bin: \
	root-install-bin-flume-cfg

root-install-bin-%: $(SRCDIR_BIN)/%
	@echo "+ inst: $< -> $(STD_BIN)"
	$(V)$(INSTALL) $(BINMODE) $< $(STD_BIN)
