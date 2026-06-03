ifndef PKIO-CODEX-LOADED
PKIO-CODEX-LOADED := true
PKIO-PROGRAM-LOADED := true

include $(MAKES)/rg.mk
include $(MAKES)/node.mk

PKIO-NONO-OPTS += --read $(LOCAL-BIN)
PKIO-NONO-OPTS += --read $(NODE-BIN)
PKIO-EXPORT-ENV += PATH=$(PATH)

pkio-setup: $(NONO) $(RG) $(NODE)

endif
