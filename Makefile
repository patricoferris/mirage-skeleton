-include Makefile.config

BASE_TESTS = \
  src/tutorial/noop \
  src/tutorial/hello \
  src/tutorial/hello-key \
  src/tutorial/lwt/echo_server \
  src/tutorial/lwt/heads1 \
  src/tutorial/lwt/heads2 \
  src/tutorial/lwt/timeout1 \
  src/tutorial/lwt/timeout2 \
  src/tutorial/lwt/echo_server \
  src/tutorial/app_info \
  src/device-usage/clock \
  src/device-usage/conduit_server \
  src/device-usage/http-fetch \
  src/device-usage/kv_ro \
  src/device-usage/network \
  src/device-usage/ping6 \
  src/device-usage/prng \
  src/device-usage/disk-lottery \
  src/applications/docteur \
  src/applications/dhcp \
  src/applications/http \
  src/applications/git \
  src/applications/dns \
  src/applications/crypto \
  src/applications/static_website_tls
# disabled as it is using an old version of conduit:
# device-usage/pgx
# disabled as it is incompatible with dune 3.7
# device-usage/littlefs

ifeq ($(MODE),muen)
	TESTS = $(BASE_TESTS)
else
	TESTS = $(BASE_TESTS)
	TESTS += src/device-usage/block
endif

CONFIGS = $(patsubst %, %-configure, $(TESTS))
CLEANS  = $(patsubst %, %-clean,     $(TESTS))

OPAM_SWITCH = $(patsubst %, %/mirage/*.opam, $(TESTS))

all:
	$(MAKE) configure
	$(MAKE) lock
	$(MAKE) depends
	$(MAKE) pull
	$(MAKE) build

configure: $(CONFIGS)
clean: $(CLEANS)
	rm -f $(LOCK)
	rm -rf duniverse

%-configure:
	$(MIRAGE) configure -f $*/config.ml -t $(MODE) $(MIRAGE_FLAGS)

device-usage/block-configure: device-usage/block/disk.img

OPAMFILES = $(shell for i in $(TESTS); do (cd $$i/mirage; ls *.opam | sed -e 's/\.opam$$//'); done)

lock:
	@$(MAKE) -s repo-add
	env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo lock --recurse-opam $(OPAMFILES) --build-only --ocaml-version $(shell ocamlc --version) -l $(LOCK)
	@$(MAKE) -s repo-rm

depends:
	$(OPAM) install $(OPAM_SWITCH) --deps-only --yes
	env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo depext -y -l $(LOCK)

pull:
	env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo pull

build:
	dune build

%-clean:
	mirage clean -f $*/config.ml

device-usage/block/disk.img:
	dd if=/dev/zero of=disk.img count=100000

comma := ,
comment := \#
repo-add:
	$(foreach OVERLAY,$(subst $(comma), ,$(MIRAGE_EXTRA_REPOS)), \
		$(eval NAME = $(shell echo --no $(OVERLAY) | cut -d: -f1)) \
		$(eval URL  = $(subst $(comment),\\\#,$(shell echo --no $(OVERLAY) | cut -d: -f2-))) \
		$(OPAM) repo add $(NAME) $(URL) || $(OPAM) repo set-url $(NAME) $(URL) ; \
	)

repo-rm:
	$(foreach OVERLAY,$(subst $(comma), ,$(MIRAGE_EXTRA_REPOS)), \
	  $(eval NAME = $(echo -n $(OVERLAY) | cut -d: -f1)) \
	  $(OPAM) repo remove $(NAME) ; \
	)
