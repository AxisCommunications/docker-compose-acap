# The Docker Compose ACAP

This ACAP contains both the Docker Engine and the binaries necessary to interact with it.
Installing this ACAP will make it possible to run Docker containers and Docker commands directly
on the Axis device.

## Compatibility

The Docker Compose ACAP requires a container capable device. You may check the compatibility of your
device by running:

```sh
DEVICE_IP=<device ip>
DEVICE_PASSWORD='<password>'

curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.Network.SSH.Enabled=yes"

ssh root@$DEVICE_IP 'command -v containerd >/dev/null 2>&1 && echo Compatible with Docker ACAP || echo Not compatible with Docker ACAP'
```

where `<device ip>` is the IP address of the Axis device and `<password>` is the root password. Please
note that you need to enclose your password with quotes (`'`) if it contains special characters.

## Installing

The recommended way to install this ACAP is to use the pre-built
[docker hub](https://hub.docker.com/r/axisecp/docker-compose-acap) image:

```sh
docker run --rm axisecp/docker-compose-acap:latest-<ARCH> <device ip> <rootpasswd> install
```

Where `<ARCH>` is either `armv7hf` or `aarch64` depending on device architecture.

It's also possible to build and use a locally built image. See the
[Building the Docker Compose ACAP](#building-the-docker-compose-acap) section for more information.

## Securing the Docker Compose ACAP using TLS

The Docker Compose ACAP can be run either unsecured or in TLS mode. The Docker Compose ACAP uses
TLS as default. Use the "Use TLS" dropdown in the web interface to switch
between the two different modes. It's also possible to toggle this option by
calling the parameter management API in [VAPIX](https://www.axis.com/vapix-library/) and setting the
`root.dockerdwrapperwithcompose.UseTLS` parameter to `yes` or `no`. The following commands would
enable TLS:

```sh
DEVICE_IP=<device ip>
DEVICE_PASSWORD='<password>'

curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.dockerdwrapperwithcompose.UseTLS=yes"
```

Note that the dockerd service will be restarted every time TLS is activated or
deactivated. Running the ACAP using TLS requires some additional setup, see next chapter.
Running the ACAP without TLS requires no further setup.

### TLS Setup

TLS requires a few keys and certificates to work, which are listed in the
subsections below. For more information on how to generate these files, please
consult the official [Docker documentation](https://docs.docker.com/engine/security/protect-access/).
Most of these keys and certificates need to be moved to the Axis device. There are multiple ways to
achieve this, for example by using `scp` to copy the files from a remote machine onto the device.
This can be done by running the following command on the remote machine:

```sh
scp ca.pem server-cert.pem server-key.pem root@<device ip>:/usr/local/packages/dockerdwrapperwithcompose/
```

#### The Certificate Authority (CA) certificate

This certificate needs to be present in the dockerdwrapperwithcompose package folder on the
Axis device and be named `ca.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/ca.pem`.

#### The server certificate

This certificate needs to be present in the dockerdwrapperwithcompose package folder on the
Axis device and be named `server-cert.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/server-cert.pem`.

#### The private server key

This key needs to be present in the dockerdwrapperwithcompose package folder on the Axis device
and be named `server-key.pem`. The full path of the file should be
`/usr/local/packages/dockerdwrapperwithcompose/server-key.pem`.

#### Client key and certificate

A client will need to have its own private key, together with a certificate authorized by the CA.
Key, certificate and CA shall be used when running Docker against the dockerd daemon on
the Axis device. See below for an example:

```sh
docker --tlsverify \
       --tlscacert=ca.pem \
       --tlscert=client-cert.pem \
       --tlskey=client-key.pem \
       -H=<device ip>:2376 \
       version
```

Specifying the files on each Docker command will soon become tedious. To configure Docker to
automatically use your key and certificate, please export the `DOCKER_CERT_PATH` environment variable:

```sh
export DOCKER_CERT_PATH=<client certificate directory>
docker --tlsverify \
       -H=<device ip>:2376 \
       version
```

where `<client certificate directory>` is the directory on your computer where the files `ca.pem`,
`cert.pem` and `key.pem` are stored.

## Using an SD card as storage

An SD card might be necessary to run the Docker Compose ACAP correctly. Docker
containers and docker images can be quite large, and putting them on an SD card
gives more freedom in how many and how large images can be stored. Switching
between storage on the SD card or internal storage is done by toggling the "SD
card support" dropdown in the web interface. It's also possible to toggle this
option by calling the parameter management API in
[VAPIX](https://www.axis.com/vapix-library/) (accessing this documentation
requires creating a free account) and setting the
`root.dockerdwrapperwithcompose.SDCardSupport` parameter to `yes` or `no`.

Toggling this setting will automatically restart the docker daemon using the
specified storage. The default setting is to use the internal storage on the
device.

Note that dockerdwrapperwithcompose requires that Unix permissions are supported by the
file system. Examples of file systems which support this are ext4, ext3 and xfs.
It might be necessary to reformat the SD card to one of these file systems, for
example if the original file system of the SD card is vfat.

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

The [docker compose](https://docs.docker.com/compose/cli-command) functionality is also available:

```sh
docker compose version
```

Note that the ACAP is shipped with [Compose V2](https://docs.docker.com/compose/cli-command).

### Using the Docker Compose ACAP remotely

It's also possible to call the Docker Compose ACAP from a separate machine.
This can be achieved by using the -H flag when running the docker command on the remote machine.

The port used will change depending on if the Docker Compose ACAP runs using TLS or not.
The Docker Compose ACAP will be reachable on port 2375 when running unsecured, and on
port 2376 when running secured using TLS. Please read section
[Securing the Docker Compose ACAP using TLS](#securing-the-docker-acap-using-tls) for
more information.
Below is an example of how to remotely run a docker command on an Axis device running
the Docker Compose ACAP in unsecured mode:

```sh
docker -H=<device ip>:2375 version
```

See [Client keys and certificates](#client-keys-and-certificates) for an example
of how to remotely run docker commands on a device running a secured Docker Compose ACAP
using TLS.

## Building the Docker Compose ACAP

### armv7hf

```sh
./build.sh armv7hf
```

### aarch64

```sh
./build.sh aarch64
```

## Installing a locally built Docker Compose ACAP

Installation can be done in two ways. Either by using the built docker image:

```sh
docker run --rm docker-acap-with-compose:1.0 <device ip> <rootpasswd> install
```

Or by manually navigating to device GUI by browsing to the following page
(replace `<device ip>` with the IP number of your Axis video device)

```sh
http://<device ip>/#settings/apps
```

Go to your device web page above > Click on the tab **App** in the device GUI >
Add **(+)** sign and browse to the newly built
**Docker_Daemon_with_Compose_1_1_0_<arch>.eap** > Click **Install** > Run the application by
enabling the **Start** switch.
