ifndef PKIO-CODEX-LOADED
PKIO-CODEX-LOADED := true
PKIO-PROGRAM-LOADED := true

include $(MAKES)/rg.mk
include $(MAKES)/node.mk

PKIO-NONO-OPTS += --read $(LOCAL-BIN)
PKIO-NONO-OPTS += --read $(NODE-BIN)
PKIO-CMD-ARGS += -c
PKIO-CMD-ARGS += projects.\"$(PKIO_BASE)\".trust_level=\"trusted\"
PKIO-EXPORT-ENV += PATH=$(PATH)

CODEX-CONFIG ?= $(or $(CODEX_HOME),$(HOME)/.codex)/config.toml
CODEX-PROJECT-KEY := [projects."$(PKIO_BASE)"]

include $(PKIO_ROOT)/makes/gh-readonly.mk

_codex-trust-project:
	@mkdir -p "$(dir $(CODEX-CONFIG))"
	@touch "$(CODEX-CONFIG)"
	@if grep -Fqx '$(CODEX-PROJECT-KEY)' "$(CODEX-CONFIG)"; then \
	  perl -0pi -e 'my $$key = quotemeta(q{$(CODEX-PROJECT-KEY)}); if (!s/($$key\n(?:(?!^\[).*\n)*?trust_level\s*=\s*)"[^"]*"/$${1}"trusted"/m) { s/($$key\n)/$${1}trust_level = "trusted"\n/m }' "$(CODEX-CONFIG)"; \
	else \
	  printf '\n%s\ntrust_level = "trusted"\n' '$(CODEX-PROJECT-KEY)' >> "$(CODEX-CONFIG)"; \
	fi

pkio-setup: _codex-trust-project $(NONO) $(RG) $(NODE) $(PKIO-GH-READONLY-DEPS)

endif
