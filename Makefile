.PHONY: install backup install-extensions dconf packages uninstall

install:
	./scripts/install.sh

backup:
	./scripts/backup.sh

install-extensions:
	./scripts/install-extensions.sh

dconf:
	./scripts/dconf.sh all

packages:
	./scripts/packages.sh

uninstall:
	./scripts/uninstall.sh

