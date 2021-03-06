#- # Ping Identity DevOps Docker Image - `pingauthorize`
#-
#- This docker image includes the Ping Identity PingAuthorize product binaries
#- and associated hook scripts to create and run a PingAuthorize instance or
#- instances.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingdatacommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits
#-
ARG PRODUCT
ARG SHIM
ARG SHIM_TAG
ARG VERSION
ARG JVM
ARG REGISTRY
ARG DEPS
ARG GIT_TAG
ARG ARCH

FROM ${REGISTRY}/${PRODUCT}:staging-${VERSION}-${GIT_TAG} as product-staging
FROM ${REGISTRY}/pingdatacommon:${GIT_TAG}-${ARCH} as common
FROM ${REGISTRY}/pingjvm:${JVM}-${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

FROM ${DEPS}${SHIM} as final-staging

# get the product bits FIRST
COPY --from=product-staging ["/opt/","/opt/"]

# get Ping-wide common scripts
#   this needs to happen after the bits have been laid down
#   so they can be patched
COPY --from=common ["/opt/","/opt/"]

# get the jvm
COPY --from=jvm ["/opt/java","/opt/java"]

# apply product-specific hooks and patches
COPY ["/opt","/opt"]

# Run build
RUN ["/opt/build.sh"]

FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
# PingIdentity license version
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
#-- Ping product name
    PING_PRODUCT=PingAuthorize \
#-- Name of license file
    LICENSE_FILE_NAME=PingAuthorize.lic \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME=PingAuthorize \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- Minimal Heap size required for PingAuthorize
    MAX_HEAP_SIZE=1g \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/start-server" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the foreground. This is the
#-- normal start flow for the container
    STARTUP_FOREGROUND_OPTS="--nodetach" \
#-- The command-line options to provide to the the startup command when
#-- the container starts with the server in the background. This is the
#-- debug start flow for the container
    STARTUP_BACKGROUND_OPTS="" \
#-- Location of file with the root user password (i.e. cn=directory manager).
#-- Defaults to /SECRETS_DIR/root-user-password
    ROOT_USER_PASSWORD_FILE= \
#-- Location of file with the passphrase for setting up encryption
#-- Defaults to /SECRETS_DIR/encryption-password
    ENCRYPTION_PASSWORD_FILE= \
#-- Files tailed once container has started
    TAIL_LOG_FILES="${SERVER_ROOT_DIR}/logs/trace ${SERVER_ROOT_DIR}/logs/policy-decision ${SERVER_ROOT_DIR}/logs/ldap-access" \
#-- Directory for the profile used by the PingData manage-profile tool
    PD_PROFILE="${STAGING_DIR}/pd.profile"

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

EXPOSE ${LDAP_PORT} ${LDAPS_PORT} ${HTTPS_PORT} ${JMX_PORT}

COPY --from=final-staging ["/","/"]


#- ## Running a PingAuthorize container
#-
#- The easiest way to test a simple standalone image of PingAuthorize is to cut/paste the following command into a terminal on a machine with docker.
#-
#- ```sh
#-   docker run \
#-            --name pingauthorize \
#-            --publish 1389:1389 \
#-            --publish 8443:1443 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingauthorize \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-           pingidentity/pingauthorize:edge
#- ```
#-
#- You can view the Docker logs with the command:
#-
#- ```sh
#-   docker logs -f pingauthorize
#- ```
#-
#- You should see the ouptut from a PingAuthorize install and configuration, ending with a message the the PingAuthorize has
#- started.  After it starts, you will see some typical access logs.  Simply ``Ctrl-C`` after to stop tailing the logs.
#-
#-
#- ## Stopping/Removing the container
#- To stop the container:
#-
#- ```
#-   docker container stop pingauthorize
#- ```
#-
#- To remove the container:
#-
#- ```
#-   docker container rm -f pingauthorize
#- ```
