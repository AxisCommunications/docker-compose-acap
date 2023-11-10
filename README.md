<!-- omit in toc -->
# The Docker Compose ACAP

The Docker Compose ACAP application provides the means to run rootless Docker on a compatible Axis
device. In addition it bundles the docker CLI and the docker Compose CLI.

> **Note**
>
> This is a preview of the rootless Docker Compose ACAP. Even though it uses a non-root user at runtime,
> it requires root privileges during installation and uninstallation. This can be accomplished by
> setting the `AllowRoot` toggle to `true` when installing and uninstalling the application.
> See the [VAPIX documentation][vapix-allow-root] for details.
>
> **Known Issues**
>
> * Only uid and gid are properly mapped between device and containers, not the other groups that
> the user is a member of. This means that resources on the device, even if they are volume or device
> mounted can be inaccessible inside the container. This can also affect usage of unsupported dbus
>  methods from the container.
> * iptables use is disabled.
> * The docker.socket group ownership is set to `addon`.

<!-- omit in toc -->
## Table of contents

* [Overview](#overview)
* [Requirements](#requirements)
* [Installation and Usage](#installation-and-usage)
  * [Installation](#installation)
  * [Securing the Docker Compose ACAP using TLS](#securing-the-docker-compose-acap-using-tls)
  * [Using an SD card as storage](#using-an-sd-card-as-storage)
* [Using the Docker Compose ACAP](#using-the-docker-compose-acap)
  * [Using the Docker Compose ACAP on the Axis device](#using-the-docker-compose-acap-on-the-axis-device)
  * [Using the Docker Compose ACAP remotely](#using-the-docker-compose-acap-remotely)
* [Building the Docker Compose ACAP](#building-the-docker-compose-acap)
* [Installing a locally built Docker Compose ACAP](#installing-a-locally-built-docker-compose-acap)
* [Contributing](#contributing)
* [License](#license)

## Overview

The Docker Compose ACAP provides the means to run a Docker daemon on an Axis device, thereby
making it possible to deploy and run Docker containers on it. When started the daemon
will run in rootless mode, i.e. the user owning the daemon process will not be root,
and in extension, the containers will not have root access to the host system.
See [Rootless Mode][docker-rootless-mode] on Docker.com for details. That page also
contains known limitations when running rootless Docker.
In addition the [docker CLI[dockerCLI]] and [docker compose CLI][dockerComposeCLI]
are included in the application, thereby providing the means to access these e.g.
from a separate ACAP application running on the device.

> **Note**
>
> The Docker Compose ACAP application can be run with TLS authentication or without.
> Be aware that running without TLS authentication is extremely insecure and we
strongly recommend against this.
> See [Securing the Docker Compose ACAP using TLS](#securing-the-docker-compose-acap-using-tls)
for information on how to generate certificates for TLS authentication when using
the Docker Compose ACAP application.

## Requirements

The following requirements need to be met.

* Axis device:
  * Axis OS version 11.7 or higher.
  * The device needs to have ACAP Native SDK support. See [Axis devices & compatibility][devices]
  for more information.
  * Additionally, the device must be container capable. To check the compatibility
  of your device run:

```sh
DEVICE_IP=<device ip>
DEVICE_PASSWORD='<password>'

curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.Network.SSH.Enabled=yes"

ssh root@$DEVICE_IP 'command -v containerd >/dev/null 2>&1 && echo Compatible with Docker Compose ACAP || echo Not compatible with Docker Compose ACAP'
```

where `<device ip>` is the IP address of the Axis device and `<password>` is the root password. Please
note that you need to enclose your password with quotes (`'`) if it contains special characters.

* Computer:
  * Either [Docker Desktop][dockerDesktop] version 4.11.1 or higher, or
  [Docker Engine][dockerEngine] version 20.10.17 or higher.
  * To build Docker Compose ACAP locally it is required to have [Buildx][buildx] installed.

## Installation and Usage

> [!IMPORTANT]
> From AXIS OS 11.8 `root` user is not allowed by default and in 12.0 it will be disallowed completely. Read more on the [Developer Community](https://www.axis.com/developer-community/news/axis-os-root-acap-signing). \
> Docker Compose ACAP 1.3.1 and previous, requires root and work is ongoing to create a version that does not.
> Meanwhile, the solution is to allow root to be able to install the Docker Compose ACAP.
>
> On the web page of the device:
> 1. Go to the Apps page, toggle on `Allow root-privileged apps`.
> 1. Go to System -> Account page, under SSH accounts toggle off `Restrict root access` to be able to send the TLS certificates. Make sure to set the password of the `root` SSH user.

The prebuilt Docker Compose ACAP application is signed, read more about signing [here][signing-documentation].

### Installation

Install and use any signed eap-file from [prereleases or releases][all-releases]
with a tag on the form `<version>_<ARCH>`, where `<version>` is the docker-compose-acap release version
and `<ARCH>` is either `armv7hf` or `aarch64` depending on device architecture.
E.g. `Docker_Daemon_with_Compose_1_3_0_aarch64_signed.eap`.
The eap-file can be installed as an ACAP application on the device,
where it can be controlled in the device GUI **Apps** tab.

```sh
# Get download url for a signed ACAP with curl
# Where <ARCH> is the architecture
curl -s https://api.github.com/repos/AxisCommunications/docker-compose-acap/releases/latest | grep "browser_download_url.*Docker_Daemon_with_Compose_.*_<ARCH>\_signed.eap"
```

### Securing the Docker Compose ACAP using TLS

The Docker Compose ACAP can be run either unsecured or in TLS mode. The Docker Compose ACAP uses
TLS as default. Use the "Use TLS" dropdown in the web interface to switch
between the two different modes. It's also possible to toggle this option by
calling the parameter management API in [VAPIX][vapix] and setting the
`root.dockerdwrapperwithcompose.UseTLS` parameter to `yes` or `no`. The following command would
enable TLS:

```sh
DEVICE_IP=<device ip>

curl -s --anyauth -u "root:<device root password>" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.dockerdwrapperwithcompose.UseTLS=yes"
```

Note that the dockerd service will be restarted every time TLS is activated or
deactivated. Running the ACAP using TLS requires some additional setup, see next chapter.
Running the ACAP without TLS requires no further setup.

#### TLS Setup

TLS requires a keys and certificates to work, which are listed in the
subsections below. For more information on how to generate these files, please
consult the official [Docker documentation][docker-tls].
Most of these keys and certificates need to be moved to the Axis device. There are multiple ways to
achieve this, for example by using `scp` to copy the files from a remote machine onto the device.
This can be done by running the following command on the remote machine:

```sh
scp ca.pem server-cert.pem server-key.pem root@<device ip>:/usr/local/packages/dockerdwrapperwithcompose/
```

Once copied to the Axis device the correct permissions need to be set for the certificates:

```sh
ssh root@<device IP> 'chown acap-dockerdwrapperwithcompose /usr/local/packages/dockerdwrapperwithcompose/*.pem'

```

##### The Certificate Authority (CA) certificate

This certificate needs to be present in the dockerdwrapperwithcompose package folder on the
Axis device and be named `ca.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/ca.pem`.

##### The server certificate

This certificate needs to be present in the dockerdwrapperwithcompose package folder on the
Axis device and be named `server-cert.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/server-cert.pem`.

##### The private server key

This key needs to be present in the dockerdwrapperwithcompose package folder on the Axis device
and be named `server-key.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/server-key.pem`.

##### Client key and certificate

A client will need to have its own private key, together with a certificate authorized by the CA.
Key, certificate and CA shall be used when running Docker against the dockerd daemon on
the Axis device. See below for an example:

```sh
DOCKER_PORT=2376
docker --tlsverify \
       --tlscacert=ca.pem \
       --tlscert=client-cert.pem \
       --tlskey=client-key.pem \
       --host tcp://$DEVICE_IP:$DOCKER_PORT \
       version
```

Specifying the files on each Docker command will soon become tedious. To configure Docker to
automatically use your key and certificate, please export the `DOCKER_CERT_PATH` environment variable:

```sh
export DOCKER_CERT_PATH=<client certificate directory>
DOCKER_PORT=2376
docker --tlsverify \
       --host tcp://$DEVICE_IP:$DOCKER_PORT \
       version
```

where `<client certificate directory>` is the directory on your computer where the files `ca.pem`,
`client-cert.pem` and `client-key.pem` are stored.

### Using an SD card as storage

An SD card might be necessary to run the Docker Compose ACAP correctly. Docker
containers and docker images can be quite large, and putting them on an SD card
gives more freedom in how many and how large images can be stored. Switching
between storage on the SD card or internal storage is done by toggling the "SD
card support" dropdown in the web interface. It's also possible to toggle this
option by calling the parameter management API in
[VAPIX][vapix] (accessing this documentation
requires creating a free account) and setting the
`root.dockerdwrapperwithcompose.SDCardSupport` parameter to `yes` or `no`.

Toggling this setting will automatically restart the docker daemon using the
specified storage. The default setting is to use the internal storage on the
Axis device.

Note that dockerdwrapperwithcompose requires that Unix permissions are supported by the
file system. Examples of file systems which support this are ext4, ext3 and xfs.
It might be necessary to reformat the SD card to one of these file systems, for
example if the original file system of the SD card is vfat.

Make sure to use an SD card that has enough capacity to hold your applications.
Other properties of the SD card, like the speed, might also affect the performance of your
applications. For example, the Computer Vision SDK example
[object-detector-python][object-detector-python]
has a significantly higher inference time when using a small and slow SD card.
To get more informed about specifications, check the
[SD Card Standards][sd-card-standards].

>**Note**
>
>If Docker Compose ACAP v1.3 or previous has been used on the device with SD card as storage
>the storage directory might already be created with root permissions.
>Since v2.0 the Docker Compose ACAP is run in rootless mode and it will then not be able
>to access that directory. To solve this, either reformat the SD card or manually
>remove the directory that is used by the Docker Compose ACAP.

## Using the Docker Compose ACAP

The Docker Compose ACAP contains the Docker Daemon, the docker client binary and the docker
compose plugin. This means that all Docker management can be done running a terminal on
the Axis device.

### Using the Docker Compose ACAP on the Axis device

The first step is to open a terminal on the Axis device. This can be done using SSH:

```sh
ssh root@<device ip>
```

The docker client binary will be reachable in the terminal without any additional setup:

```sh
docker version
```

The [docker compose][dockerCLI] functionality is also available:

```sh
docker compose version
```

Note that the ACAP is shipped with [Compose V2][dockerComposeCLI].

### Using the Docker Compose ACAP remotely

It's also possible to call the Docker Compose ACAP from a separate machine.
This can be achieved by using the -H flag when running the docker command on the remote machine.

The port used will change depending on if the Docker Compose ACAP runs using TLS or not.
The Docker Compose ACAP will be reachable on port 2375 when running unsecured, and on
port 2376 when running secured using TLS. Please read section
[Securing the Docker Compose ACAP using TLS](#securing-the-docker-compose-acap-using-tls) for
more information.
Below is an example of how to remotely run a docker command on an Axis device running
the Docker Compose ACAP in unsecured mode:

```sh
DOCKER_INSECURE_PORT=2375
docker -H=<device ip>:$DOCKER_INSECURE_PORT version
```

See [Client key and certificate](#client-key-and-certificate) for an example
of how to remotely run docker commands on a device running a secured Docker Compose ACAP
using TLS.

#### Test that the Docker ACAP can run a container

Make sure the Docker Compose ACAP, using TLS, is running, then pull and run the
[hello-world][docker-hello-world] image from Docker Hub:

```sh
>docker --tlsverify --host tcp://$DEVICE_IP:$DOCKER_PORT pull hello-world
Using default tag: latest
latest: Pulling from library/hello-world
70f5ac315c5a: Pull complete 
Digest: sha256:88ec0acaa3ec199d3b7eaf73588f4518c25f9d34f58ce9a0df68429c5af48e8d
Status: Downloaded newer image for hello-world:latest
docker.io/library/hello-world:latest
>docker --tlsverify --host tcp://$DEVICE_IP:$DOCKER_PORT run hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

```

#### Loading images onto a device

If you have images in a local repository that you want to transfer to a device, or
if you have problems getting the `pull` command to work in your environment, `save`
and `load` can be used.

```sh
docker save <image on host local repository> | docker --tlsverify --host tcp://$DEVICE_IP:$DOCKER_PORT load
```

## Building the Docker Compose ACAP

To build the Docker Compose ACAP use docker buildx with the provided Dockerfile:

```sh
# Build Docker Compose ACAP image
docker buildx build --file Dockerfile --tag docker-acap-with-compose:<ARCH> --build-arg ACAPARCH=<ARCH> .
```

where `<ARCH>` is either `armv7hf` or `aarch64`.

To extract the Docker Compose ACAP eap-file use docker cp to copy it to a `build` folder:

```sh
docker cp "$(docker create "docker-acap-with-compose:<ARCH>")":/opt/app/ ./build
```

## Installing a locally built Docker Compose ACAP

Installation can be done either by running the locally built docker image:

```sh
docker run --rm docker-acap-with-compose:1.0 <device ip> <rootpasswd> install
```

Or by manually installing the .eap file from the `build` folder by using the Web GUI in the device:

```sh
http://<device ip>/#settings/apps
```

Go to your device web page above > Click on the tab **App** in the device GUI >
Add **(+)** sign and browse to the newly built .eap-file > Click **Install** > Run the application by
enabling the **Start** switch.

## Contributing

Take a look at the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## License

[Apache 2.0](LICENSE)

<!-- Links to external references -->
<!-- markdownlint-disable MD034 -->
[all-releases]: https://github.com/AxisCommunications/docker-compose-acap/releases
[buildx]: https://docs.docker.com/build/install-buildx/
[devices]: https://axiscommunications.github.io/acap-documentation/docs/axis-devices-and-compatibility#sdk-and-device-compatibility
[dockerDesktop]: https://docs.docker.com/desktop/
[dockerEngine]: https://docs.docker.com/engine/
[dockerCLI]: https://docs.docker.com/engine/reference/commandline/cli/
[dockerComposeCLI]: https://docs.docker.com/compose/reference/
[docker-hello-world]: https://hub.docker.com/_/hello-world
[docker-tls]: https://docs.docker.com/engine/security/protect-access/
[docker-rootless-mode]: https://docs.docker.com/engine/security/rootless/
[latest-releases]: https://github.com/AxisCommunications/docker-compose-acap/releases/latest
[object-detector-python]: https://github.com/AxisCommunications/acap-computer-vision-sdk-examples/tree/main/object-detector-python
[sd-card-standards]: https://www.sdcard.org/developers/sd-standard-overview/
[signing-documentation]: https://axiscommunications.github.io/acap-documentation/docs/faq/security.html#sign-acap-applications
[vapix]: https://www.axis.com/vapix-library/
[vapix-allow-root]: https://www.axis.com/vapix-library/subjects/t10102231/section/t10036126/display?section=t10036126-t10185050
<!-- markdownlint-enable MD034 -->
