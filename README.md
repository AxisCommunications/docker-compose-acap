# The Docker Compose ACAP

This ACAP contains both the Docker Engine and the binaries necessary to interact with it.
Installing this ACAP will make it possible to run Docker containers and Docker commands directly
on the Axis device.

## Compatibility

### Device

Minimum Axis OS version 11.9.

The Docker Compose ACAP requires a container capable device. You may check the compatibility of
your device by running:

```sh
DEVICE_IP=<device ip>
DEVICE_PASSWORD='<password>'

curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.Network.SSH.Enabled=yes"

ssh root@$DEVICE_IP 'command -v containerd >/dev/null 2>&1 && echo Compatible with Docker ACAP || echo Not compatible with Docker ACAP'
```

where `<device ip>` is the IP address of the Axis device and `<password>` is the root password. Please
note that you need to enclose your password with quotes (`'`) if it contains special characters.

### Host

The host machine is recommended to have [Docker](https://docs.docker.com/get-docker/) and
[Docker Compose](https://docs.docker.com/compose/install/) installed.
To build Docker Compose ACAP locally it is required to have [Docker Engine](https://docs.docker.com/engine/)
and [Buildx](https://docs.docker.com/build/install-buildx/) installed.

## Installing

The Docker Compose application is available as a **signed** eap-file in [Releases][latest-releases],
this is the recommended way to install this ACAP.

> [!IMPORTANT]
> From AXIS OS 11.8 `root` user is not allowed by default and in 12.0 it will be disallowed completely. Read more on the [Developer Community](https://www.axis.com/developer-community/news/axis-os-root-acap-signing). \
> Docker Compose ACAP 1.3.1 and previous, requires root and work is ongoing to create a version that does not.
> Meanwhile, the solution is to allow root to be able to install the Docker Compose ACAP.
>
> On the web page of the device:
>
>
> 1. Go to the Apps page, toggle on `Allow root-privileged apps`.
> 1. Go to System -> Account page, under SSH accounts toggle off `Restrict root access` to be able to send the TLS certificates. Make sure to set the password of the `root` SSH user.

The prebuilt Docker Compose ACAP application is signed, read more about signing [here][signing-documentation].

Download and install any signed eap-file from [prereleases or releases][all-releases]
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

### Installation of version 1.2.5 and previous

To install this ACAP with version 1.2.5 or previous use the pre-built
[docker hub](https://hub.docker.com/r/axisecp/docker-compose-acap) image:

```sh
docker run --rm axisecp/docker-compose-acap:latest-<ARCH> <device ip> <rootpasswd> install
```

Where `<ARCH>` is either `armv7hf` or `aarch64` depending on device architecture.

It's also possible to build and use a locally built image. See the
[Building the Docker Compose ACAP](#building-the-docker-compose-acap) section for more information.

## Securing the Docker Compose ACAP using TLS

The Docker Compose ACAP application can be run in either TLS mode or unsecured mode. The Docker Compose
ACAP application uses TLS mode by default. It is important to note that Dockerd will fail to start if
TCP socket or IPC socket parameters are not selected, one of these sockets must be set to `yes`.

Use the "Use TLS" and "TCP Socket" dropdowns in the web interface to switch between the
two different modes(yes/no). Whenever these settings change, the Docker daemon will automatically restart.
It's also possible to toggle this option by calling the parameter management API in
[VAPIX](https://www.axis.com/vapix-library/) and setting `root.dockerdwrapperwithcompose.UseTLS` and
`root.dockerdwrapperwithcompose.TCPSocket` parameters to `yes` or `no`.
The following commands would enable those parameters:

```sh
DEVICE_IP=<device ip>
DEVICE_PASSWORD='<password>'
```

Enable TLS:

```sh
curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.dockerdwrapperwithcompose.UseTLS=yes"
```

Enable TCP Socket:

```sh
curl -s --anyauth -u "root:$DEVICE_PASSWORD" \
  "http://$DEVICE_IP/axis-cgi/param.cgi?action=update&root.dockerdwrapperwithcompose.TCPSocket=yes"
```

Note that the dockerd service will be restarted every time TLS is activated or
deactivated. Running the ACAP using TLS requires some additional setup, see next chapter.
Running the ACAP without TLS requires no further setup.

### TLS Setup

TLS requires the following keys and certificates on the device:

* Certificate Authority certificate `ca.pem`
* Server certificate `server-cert.pem`
* Private server key `server-key.pem`

For more information on how to generate these files, please consult the official
[Docker documentation](https://docs.docker.com/engine/security/protect-access/).

The files can be uploaded to the device using HTTP.
The dockerd service will restart, or try to start, after each HTTP POST request.

```sh
curl --anyauth -u "root:$DEVICE_PASSWORD" -F file=@ca.pem -X POST \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/ca.pem
curl --anyauth -u "root:$DEVICE_PASSWORD" -F file=@server-cert.pem -X POST \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/server-cert.pem
curl --anyauth -u "root:$DEVICE_PASSWORD" -F file=@server-key.pem -X POST \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/server-key.pem
```

If desired, they can be deleted from the device using:

```sh
curl --anyauth -u "root:$DEVICE_PASSWORD" -X DELETE \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/ca.pem
curl --anyauth -u "root:$DEVICE_PASSWORD" -X DELETE \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/server-cert.pem
curl --anyauth -u "root:$DEVICE_PASSWORD" -X DELETE \
  http://$DEVICE_IP/local/dockerdwrapperwithcompose/server-key.pem
```

They can also be copied to the `/usr/local/packages/dockerdwrapperwithcompose/localdata`
directory of the device using `scp`,
but this method will not cause the dockerd service to restart.

```sh
scp ca.pem server-cert.pem server-key.pem root@<device ip>:/usr/local/packages/dockerdwrapperwithcompose/localdata/
```

#### Client key and certificate

A client will need to have its own private key, together with a certificate authorized by the CA.
Key, certificate and CA shall be used when running Docker against the dockerd daemon on
the Axis device. See below for an example:

```sh
DOCKER_PORT=2376
docker --tlsverify \
       --tlscacert=ca.pem \
       --tlscert=client-cert.pem \
       --tlskey=client-key.pem \
       -H=<device ip>:$DOCKER_PORT \
       version
```

Specifying the files on each Docker command will soon become tedious. To configure Docker to
automatically use your key and certificate, please export the `DOCKER_CERT_PATH` environment variable:

```sh
export DOCKER_CERT_PATH=<client certificate directory>
DOCKER_PORT=2376
docker --tlsverify \
       -H=<device ip>:$DOCKER_PORT \
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

Make sure to use an SD card that has enough capacity to hold your applications.
Other properties of the SD card, like the speed, might also affect the performance of your
applications. For example, the Computer Vision SDK example
[object-detector-python](https://github.com/AxisCommunications/acap-computer-vision-sdk-examples/tree/main/object-detector-python)
has a significantly higher inference time when using a small and slow SD card.
To get more informed about specifications, check the
[SD Card Standards](https://www.sdcard.org/developers/sd-standard-overview/).

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

The application can provide a TCP socket if the TCP Socket setting is set to `yes` and an IPC socket
if the IPC Socket setting is set to `yes`. Please be aware that at least one of these sockets must be
selected for the application to start.

## Status codes

The application use a parameter called `Status` to inform about what state it is currently in.
The value can be read with a call to the VAPIX param.cgi API, e.g. by using curl:

```sh
curl --anyauth -u <user:user password> \
  'http://<device ip>/axis-cgi/param.cgi?action=list&group=root.Dockerdwrapperwithcompose.Status'
```

Following are the possible values of `Status`:

```text
-1 NOT STARTED                The application is not started.
 0 RUNNING                    The application is started and dockerd is running.
 1 DOCKERD STOPPED            Dockerd was stopped successfully and will soon be restarted.
 2 DOCKERD RUNTIME ERROR      Dockerd has reported an error during runtime that needs to be resolved by the operator.
                              Change at least one parameter or restart the application in order to start dockerd again.
 3 TLS CERT MISSING           Use TLS is selected but there but certificates are missing on the device.
                              The application is running but dockerd is stopped.
                              Upload certificates and restart the application or de-select Use TLS.
 4 NO SOCKET                  Neither TCP Socket or IPC Socket are selected.
                              The application is running but dockerd is stopped.
                              Select one or both sockets.
 5 NO SD CARD                 Use SD Card is selected but no SD Card is mounted in the device.
                              The application is running but dockerd is stopped.
                              Insert and mount an SD Card.
 6 SD CARD WRONG FS           Use SD Card is selected but the mounted SD Card has the wrong file system.
                              The application is running but dockerd is stopped.
                              Format the SD Card with the correct file system.
 7 SD CARD WRONG PERMISSION   Use SD Card is selected but the application user does not have the correct file
                              permissions to use it.
                              The application is running but dockerd is stopped.
                              Make sure no directories with the wrong user permissions are left on the
                              SD Card, then restart the application.
 8 SD CARD MIGRATION FAILED   Use SD Card is selected but migrating data from the old data root location to the
                              new one has failed.
                              The application is running but dockerd is stopped.
                              Manually back up and remove either the old or the new data root folder from the SD card,
                              then restart the application.
```

## Building the Docker Compose ACAP

To build the Docker Compose ACAP use docker buildx with the provided Dockerfile:

```sh
# Build Docker Compose ACAP image
docker buildx build --file Dockerfile --tag docker-acap-with-compose:<ARCH> --build-arg ARCH=<ARCH> --output <build-folder> .
```

where `<ARCH>` is either `armv7hf` or `aarch64`. `<build-folder>` is the path to an output folder
on your machine, eg. `build`. This will be created for you if not already existing.
Once the build has completed the Docker ACAP eap-file can be found in the `<build-folder>`.

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
[latest-releases]: https://github.com/AxisCommunications/docker-compose-acap/releases/latest
[signing-documentation]: https://axiscommunications.github.io/acap-documentation/docs/faq/security.html#sign-acap-applications

<!-- markdownlint-enable MD034 -->
