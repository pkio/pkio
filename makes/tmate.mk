ifndef PKIO-TMATE-LOADED
PKIO-TMATE-LOADED := true
PKIO-PROGRAM-LOADED := true

PKIO-NONO-OPTS += \
  --profile $(PKIO_ROOT)/etc/cmd/tmate/profile.json \

pkio-setup: $(NONO)

endif
