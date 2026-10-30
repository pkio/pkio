ifndef PKIO-CODEX-LOADED
PKIO-CODEX-LOADED := true
PKIO-PROGRAM-LOADED := true

include $(MAKES)/rg.mk
include $(MAKES)/node.mk

PKIO-NONO-OPTS += --read $(LOCAL-BIN)
PKIO-NONO-OPTS += --read $(NODE-BIN)

# XWayland authentication filenames can change between desktop sessions.
ifneq (,$(strip $(XAUTHORITY)))
PKIO-NONO-OPTS += --read-file $(XAUTHORITY)
endif

# Preserve clipboard access without granting other desktop session sockets.
ifneq (,$(wildcard /tmp/.X11-unix))
PKIO-NONO-OPTS += --allow-unix-socket-dir /tmp/.X11-unix
endif
ifneq (,$(strip $(WAYLAND_DISPLAY)))
CODEX-WAYLAND-SOCKET := $(WAYLAND_DISPLAY)
ifeq (,$(filter /%,$(WAYLAND_DISPLAY)))
CODEX-WAYLAND-SOCKET := $(XDG_RUNTIME_DIR)/$(WAYLAND_DISPLAY)
endif
ifneq (,$(wildcard $(CODEX-WAYLAND-SOCKET)))
PKIO-NONO-OPTS += --allow-unix-socket $(CODEX-WAYLAND-SOCKET)
endif
endif

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

# Symlink ./AGENTS.md from config if it exists.
AGENTS-MD-SOURCE := $(HOME)/.config/pkio$(ROOT)/AGENTS.md
AGENTS-MD-LINK := $(ROOT)/AGENTS.md

_agents-md-link:
ifneq (,$(wildcard $(AGENTS-MD-SOURCE)))
	@if [[ ! -e $(AGENTS-MD-LINK) ]]; then \
	  ln -s $(AGENTS-MD-SOURCE) $(AGENTS-MD-LINK); \
	fi
endif

pkio-setup: _agents-md-link _codex-trust-project $(NONO) $(RG) $(NODE) $(PKIO-GH-READONLY-DEPS)

endif
