ifndef PKIO-GH-READONLY-LOADED
PKIO-GH-READONLY-LOADED := true

include $(MAKES)/gh.mk

PKIO_GH_TOKEN_FILE ?= $(or $(PKIO_CONFIG),$(HOME)/.config/pkio)/gh-token

PKIO-NONO-OPTS += --read $(GH-BIN)
ifneq (,$(wildcard $(PKIO_GH_TOKEN_FILE)))
PKIO-NONO-OPTS += --read-file $(PKIO_GH_TOKEN_FILE)
endif

PKIO-EXPORT-ENV += PKIO_GH_TOKEN_FILE=$(PKIO_GH_TOKEN_FILE)
PKIO-GH-READONLY-DEPS := _pkio-gh-readonly-check $(GH)

.PHONY: _pkio-gh-readonly-check
_pkio-gh-readonly-check:
	@if [[ ! -s "$(PKIO_GH_TOKEN_FILE)" ]]; then \
	  echo "Warning: GitHub token file not found or empty: $(PKIO_GH_TOKEN_FILE)" >&2; \
	fi

endif
