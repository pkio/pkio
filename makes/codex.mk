ifndef PKIO-CODEX-LOADED
PKIO-CODEX-LOADED := true
PKIO-PROGRAM-LOADED := true

include $(MAKES)/rg.mk

PKIO-NONO-OPTS += --read $(LOCAL-BIN)
PKIO-EXPORT-ENV += PATH=$(PATH)

pkio-setup: $(NONO) $(RG)

endif
