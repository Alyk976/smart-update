PREFIX ?= /usr
SYSCONFDIR ?= /etc
LOCALSTATEDIR ?= /var
SYSTEMDUNITDIR ?= $(PREFIX)/lib/systemd/system

BINDIR := $(PREFIX)/bin
LIBDIR := $(PREFIX)/lib/smart-update
POLICYDIR := $(LIBDIR)/policies
CONFDIR := $(SYSCONFDIR)/smart-update
STATEDIR := $(LOCALSTATEDIR)/lib/smart-update
LOGDIR := $(LOCALSTATEDIR)/log/smart-update
REPORTDIR := $(LOGDIR)/reports

HELPER_DIR := tools/package-removals-helper
HELPER := $(HELPER_DIR)/package-removals-helper

LIB_MODULES := \
	lib/arch_news.sh \
	lib/arch_news_context.sh \
	lib/arch_news_state.sh \
	lib/config.sh \
	lib/decision.sh \
	lib/engine.sh \
	lib/logger.sh \
	lib/package_removals.sh \
	lib/package_replacements.sh \
	lib/report.sh \
	lib/system_checks.sh

POLICIES := $(wildcard lib/policies/*.sh)
SYSTEMD_UNITS := systemd/smart-update.service systemd/smart-update.timer

.PHONY: all helper install install-bin install-lib install-config install-runtime install-systemd clean

all: helper

helper:
	$(MAKE) -C $(HELPER_DIR)

install: helper install-bin install-lib install-config install-runtime install-systemd

install-bin:
	install -Dm755 bin/smart-update "$(DESTDIR)$(BINDIR)/smart-update"

install-lib:
	install -d -m755 "$(DESTDIR)$(LIBDIR)" "$(DESTDIR)$(POLICYDIR)"
	install -m644 $(LIB_MODULES) "$(DESTDIR)$(LIBDIR)/"
	install -m644 $(POLICIES) "$(DESTDIR)$(POLICYDIR)/"
	install -m755 "$(HELPER)" "$(DESTDIR)$(LIBDIR)/package-removals-helper"

install-config:
	install -d -m750 "$(DESTDIR)$(CONFDIR)"
	@if [ ! -e "$(DESTDIR)$(CONFDIR)/smart-update.conf" ]; then \
		install -m640 config/smart-update.conf "$(DESTDIR)$(CONFDIR)/smart-update.conf"; \
	fi
	@if [ ! -e "$(DESTDIR)$(CONFDIR)/critical-packages.conf" ]; then \
		install -m640 config/critical-packages.conf "$(DESTDIR)$(CONFDIR)/critical-packages.conf"; \
	fi

install-runtime:
	install -d -m750 \
		"$(DESTDIR)$(STATEDIR)" \
		"$(DESTDIR)$(LOGDIR)" \
		"$(DESTDIR)$(REPORTDIR)"

install-systemd:
	install -d -m755 "$(DESTDIR)$(SYSTEMDUNITDIR)"
	install -m644 $(SYSTEMD_UNITS) "$(DESTDIR)$(SYSTEMDUNITDIR)/"

clean:
	$(MAKE) -C $(HELPER_DIR) clean
