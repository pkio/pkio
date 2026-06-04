ifndef PKIO-CLAUDE-LOADED
PKIO-CLAUDE-LOADED := true
PKIO-PROGRAM-LOADED := true

include $(MAKES)/gh.mk
include $(MAKES)/jq.mk

PKIO-NONO-OPTS += \
  --profile claude-code \

PKIO-NONO-CMD := wrap

CLAUDE-NONO-DEPS ?= $(GH)

# Make CLAUDE_CONFIG_DIR visible to the pre-sandbox auth check below.
# The sandbox itself picks the same value up from config.yaml's env:
# block, but that only fires after pkio-setup completes.
export CLAUDE_CONFIG_DIR ?= $(HOME)/.config/pkio/cache/claude

CLAUDE-READY := $(LOCAL-CACHE)/claude-ready

CLAUDE-SYSTEM := $(shell which claude 2>/dev/null)

ifdef CLAUDE-SYSTEM
CLAUDE := $(CLAUDE-SYSTEM)
else
CLAUDE := $(HOME)/.local/bin/claude
override PATH := $(HOME)/.local/bin:$(PATH)
export PATH
endif

SHELL-DEPS += $(CLAUDE)


.SECONDEXPANSION:

ifndef CLAUDE-SYSTEM
$(CLAUDE):
	@$(ECHO) "Installing 'claude' locally"
	$Q curl -fsSL https://claude.ai/install.sh | bash
	$Q touch $@
endif

$(CLAUDE-READY): $(CLAUDE)
	@if [[ -z $$ANTHROPIC_API_KEY ]] && \
	    ! $< auth status &>/dev/null; \
	then \
	  echo 'Claude Code is not authenticated.'; \
	  echo 'Please set: ANTHROPIC_API_KEY'; \
	  echo 'or run: claude auth login'; \
	  exit 1; \
	fi
	$Q touch $@

# Symlink ./CLAUDE.md from config if it exists.
CLAUDE-MD-SOURCE := $(HOME)/.config/pkio$(ROOT)/CLAUDE.md
CLAUDE-MD-LINK := $(ROOT)/CLAUDE.md

_claude-md-link:
ifneq (,$(wildcard $(CLAUDE-MD-SOURCE)))
	@if [[ ! -e $(CLAUDE-MD-LINK) ]]; then \
	  ln -s $(CLAUDE-MD-SOURCE) $(CLAUDE-MD-LINK); \
	fi
endif

PKIO-EXPORT-ENV += CLAUDE_CODE_TMPDIR=/tmp/claude-$(shell id -u)

pkio-setup: _claude-md-link $(CLAUDE-READY) $(NONO) $$(CLAUDE-NONO-DEPS)
ifeq (,$(wildcard $(HOME)/.claude.lock))
	@touch $(HOME)/.claude.lock
	@(sleep 2 && rm -f $(HOME)/.claude.lock) &
endif

endif
