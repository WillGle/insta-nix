# Repository entrypoints. Validation stays in scripts/validate.sh.
HOST ?= laptop
FLAKE ?= git+file://$(CURDIR)

.PHONY: check build build-plank switch diff update clean

check:
	./scripts/validate.sh

build:
	nix build --no-link --no-write-lock-file \
		$(FLAKE)#nixosConfigurations.$(HOST).config.system.build.toplevel

build-plank:
	nix build --no-link --no-write-lock-file \
		$(FLAKE)#nixosConfigurations.plank.config.system.build.toplevel

switch:
	sudo nixos-rebuild switch --flake $(FLAKE)#$(HOST)

diff:
	nix build --no-write-lock-file \
		$(FLAKE)#nixosConfigurations.$(HOST).config.system.build.toplevel \
		--out-link result-new
	nix store diff-closures /run/current-system ./result-new
	rm -f result-new

update:
	nix flake update

clean:
	rm -f result result-new
	nix-collect-garbage --delete-older-than 14d
