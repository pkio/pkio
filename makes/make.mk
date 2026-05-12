ifndef PKIO-MAKE-LOADED
PKIO-MAKE-LOADED := true
PKIO-PROGRAM-LOADED := true

# `make` targets typically write build artifacts to cwd, so promote
# the default `--allow-cwd` (read-only) to a real r+w grant. $(CURDIR)
# here resolves to the user's working dir, since pkio invokes make
# via `make -f $PKIO_ROOT/Makefile` without changing directory.
PKIO-NONO-OPTS += --allow $(CURDIR)

pkio-setup: $(NONO)

endif
