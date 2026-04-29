PKIO_ROOT ?= $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

M := $(HOME)/.cache/pkio/makes
export MAKES_LOCAL_DIR := $(HOME)/.cache/pkio/local

$(shell [ -d $M ] || (git clone -q https://github.com/makeplus/makes $M))

include $M/init.mk
include $M/nono.mk
include $M/ys.mk
include $M/md2man.mk

ifdef PKIO_CONFIG_MK
-include $(PKIO_CONFIG_MK)
endif

PKIO-NONO-OPTS += --allow-cwd
PKIO-NONO-OPTS += $(PKIO_NONO_OPTS_EXTRA)

-include $(PKIO_ROOT)/makes/$(PKIO_PROGRAM).mk

# Default pkio-setup target (only if program .mk didn't define one).
ifndef PKIO-PROGRAM-LOADED
pkio-setup: $(NONO)
	@true
endif

include $M/perl.mk
include $M/bpan.mk
include $M/shellcheck.mk
include $M/shell.mk
include $M/clean.mk

MAKES-REALCLEAN += $(HOME)/.cache/pkio/local $(HOME)/.cache/pkio/makes

MANPAGE-SRC := $(PKIO_ROOT)/ReadMe.md
MANPAGE-OUT := $(PKIO_ROOT)/man/man1/pkio.1


pkio-env: $(NONO)
	@echo "PKIO_NONO=$(NONO)"
	@echo "PKIO_NONO_OPTS='$(PKIO-NONO-OPTS)'"
	@echo "PKIO_CMD_ARGS='$(PKIO-CMD-ARGS)'"
	@$(foreach v,$(PKIO-EXPORT-ENV),echo "export $v";)

ys: $(YS)
	@echo $<

man: $(MANPAGE-OUT)

$(MANPAGE-OUT): $(MANPAGE-SRC) $(MD2MAN)
	@mkdir -p $(dir $@)
	$(MD2MAN) -in $< -out $@

test ?= test/*.t
v ?=

unexport PERL5OPT PERL5LIB

test: $(PERL) $(BPAN) $(SHELLCHECK)
	prove$(if $(v), -v,) $(test)

update: man
