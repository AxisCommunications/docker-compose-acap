include COMPOSEVERSION
include DOCKERVERSION

PROG1	= dockerdwrapperwithcompose
OBJS1	= $(PROG1).c

PKGS = gio-2.0 glib-2.0 axparameter
DOCKS = docker dockerd docker-compose docker-init docker-proxy
CFLAGS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --cflags $(PKGS))
LDLIBS += $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --libs $(PKGS))

CFLAGS += -W -Wformat=2 -Wpointer-arith -Wbad-function-cast -Wstrict-prototypes -Wmissing-prototypes -Winline -Wdisabled-optimization -Wfloat-equal -Wall -Werror

ifeq ($(ARCH),arm64)
  ACAPARCH = aarch64
  DOCKERARCH = aarch64
  DOCKER_COMPOSE_ARCH = arm64
else ifeq ($(ARCH),arm)
  ACAPARCH = armv7hf
  DOCKERARCH = armhf
  DOCKER_COMPOSE_ARCH = armv7
else
  $(error No Docker download path defined for ARCH "$(ARCH)")
endif

all:	$(PROG1) $(DOCKS)

$(PROG1): $(OBJS1)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ $(LIBS) $(LDLIBS) -o $@

dockerd:
	ARCH=$(ARCH) $(MAKE) -f Makefile.dockerd

docker-compose:
	curl -L https://github.com/docker/compose/releases/download/$(COMPOSEVERSION)/docker-compose-linux-${DOCKER_COMPOSE_ARCH} -o $@
	$(STRIP) $@
	chmod +x $@

download_docker_binaries:
	curl https://download.docker.com/linux/static/stable/$(DOCKERARCH)/docker-$(DOCKERVERSION).tgz -o docker_binaries.tgz

docker: download_docker_binaries
	tar xz -f docker_binaries.tgz --strip-components=1 docker/$@ && $(STRIP) $@

docker-init: download_docker_binaries
	tar xz -f docker_binaries.tgz --strip-components=1 docker/$@ && $(STRIP) $@

docker-proxy: download_docker_binaries
	tar xz -f docker_binaries.tgz --strip-components=1 docker/$@ && $(STRIP) $@

acap: dockerd
	docker buildx build --build-arg ACAPARCH=$(ACAPARCH) . -t axisecp/docker-acap-$(ACAPARCH):latest

clean:
	mv package.conf.orig package.conf || :
	rm -f $(PROG1) docker dockerd docker_binaries.tgz docker-compose docker-init docker-proxy *.o *.eap
