#- # Ping Identity DevOps Docker Image - `pingfederate`
#-
#- This docker image includes the Ping Identity PingFederate product binaries
#- and associated hook scripts to create and run both PingFederate Admin and
#- Engine nodes.
#-
#- ## Related Docker Images
#- - `pingidentity/pingbase` - Parent Image
#- > This image inherits, and can use, Environment Variables from [pingidentity/pingbase](https://devops.pingidentity.com/docker-images/pingbase/)
#- - `pingidentity/pingcommon` - Common Ping files (i.e. hook scripts)
#- - `pingidentity/pingdownloader` - Used to download product bits

#
# Staging product to a seperate image saves us the download + staging
# for each shim a product version is built for
#
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
FROM ${REGISTRY}/pingcommon:${GIT_TAG}-${ARCH} as common
FROM ${REGISTRY}/pingjvm:${JVM}-${SHIM_TAG}-${GIT_TAG}-${ARCH} as jvm

FROM ${DEPS}${SHIM} as final-staging
ARG RHEL_USER
ARG RHEL_PASSWORD

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


#
# The final image
#
FROM ${REGISTRY}/pingbase:${GIT_TAG}-${ARCH}
# Image version and git revision, set by build process of the docker build
ARG IMAGE_VERSION="undefined"
ARG IMAGE_GIT_REV=""
ARG LICENSE_VERSION

ENV SHIM=${SHIM} \
    IMAGE_VERSION=${IMAGE_VERSION} \
    IMAGE_GIT_REV=${IMAGE_GIT_REV} \
#-- Ping product name
    PING_PRODUCT="PingFederate" \
#-- License directory
    LICENSE_DIR="${SERVER_ROOT_DIR}/server/default/conf" \
#-- Name of license file
    LICENSE_FILE_NAME="pingfederate.lic" \
#-- Short name used when retrieving license from License Server
    LICENSE_SHORT_NAME="PF" \
#-- Version used when retrieving license from License Server
    LICENSE_VERSION=${LICENSE_VERSION} \
#-- The command that the entrypoint will execute in the foreground to
#-- instantiate the container
    STARTUP_COMMAND="${SERVER_ROOT_DIR}/bin/run.sh" \
#-- Files tailed once container has started
    TAIL_LOG_FILES=${SERVER_ROOT_DIR}/log/server.log \

#-- Defines the log file size max for ALL appenders
    PF_LOG_SIZE_MAX="10000 KB" \

#-- Defines the maximum of log files to retain upon rotation
    PF_LOG_NUMBER=2 \

#-- General log level -- provide custom log4j2.xml in profile for more detailed control
#-- valid values are OFF, ERROR, WARN, INFO, DEBUG
    PF_LOG_LEVEL="INFO" \

#-- Defines the port on which the PingFederate administrative
#-- console and API runs.
    PF_ADMIN_PORT=9999 \

#-- Defines the port on which PingFederate listens for
#-- encrypted HTTPS (SSL/TLS) traffic.
    PF_ENGINE_PORT=9031 \

#-- Flag to turn on PingFederate Engine debugging
#-- Used in run.sh
    PF_ENGINE_DEBUG=false \

#-- Flag to turn on PingFederate Admin debugging
#-- Used in run.sh
    PF_ADMIN_DEBUG=false \

#-- Defines the port on which PingFederate opens up a java debugging port.
#-- Used in run.sh
    PF_DEBUG_PORT=9030 \

#-- Operational Mode
#-- Indicates the operational mode of the runtime server in run.properties
#-- Options include STANDALONE, CLUSTERED_CONSOLE, CLUSTERED_ENGINE.
    OPERATIONAL_MODE="STANDALONE" \

#-- Defines mechanism for console authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
    PF_CONSOLE_AUTHENTICATION= \

#-- Defines mechanism for admin api authentication in run.properties.
#-- Options include none, native, LDAP, cert, RADIUS, OIDC.
#-- If not set, default is native.
    PF_ADMIN_API_AUTHENTICATION= \

#-- Hardware Security Module Mode in run.properties
#-- Options include OFF, AWSCLOUDHSM, NCIPHER, LUNA, BCFIPS.
    HSM_MODE="OFF" \

#-- Defines a variable that allows instantiating non-FIPS crypto/random
    PF_BC_FIPS_APPROVED_ONLY=false \

#-- Hardware Security Module Hybrid Mode
#--   When PF is in Hybrid mode, certs/keys can be created either on the local trust store or on the HSM.
#--   This can used as a migration strategy towards an HSM setup.
    PF_HSM_HYBRID=false \

#-- This is the username for an account within the LDAP Directory Server
#-- that can be used to perform user lookups for authentication and other
#-- user level search operations.  Set if PF_CONSOLE_AUTHENTICATION or
#-- PF_ADMIN_API_AUTHENTICATION=LDAP
    PF_LDAP_USERNAME="cn=pingfederate" \

#-- This is the password for the Username specified above.
#-- This property should be obfuscated using the 'obfuscate.sh' utility.
#-- Set if PF_CONSOLE_AUTHENTICATION or PF_ADMIN_API_AUTHENTICATION=LDAP
    PF_LDAP_PASSWORD="OBF:JWE:eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2Iiwia2lkIjoiRW1JY1UxOVdueSIsInZlcnNpb24iOiI5LjIuMS4xIn0..euBO0bawJz3XC_plAjxECg.yF7BpnCTPZlpZUo21WQ5IQ.YlLtlJTxXhrp3LsxyQDo5g" \

#-- IP address for cluster communication.  Set to NON_LOOPBACK to
#-- allow the system to choose an available non-loopback IP address.
    CLUSTER_BIND_ADDRESS="NON_LOOPBACK" \

#-- Provisioner Mode in run.properties
#-- Options include OFF, STANDALONE, FAILOVER.
    PF_PROVISIONER_MODE=OFF \

#-- Provisioner Node ID in run.properties
#-- Initial active provisioning server node ID is 1
    PF_PROVISIONER_NODE_ID=1 \

#-- Provisioner Failover Grace Period in run.properties
#-- Grace period, in seconds. Default 600 seconds
    PF_PROVISIONER_GRACE_PERIOD=600 \

#-- Percentage of the container memory to allocate to PingFederate JVM
#-- DO NOT set to 100% or your JVM will exit with OutOfMemory errors and the container will terminate
    JAVA_RAM_PERCENTAGE=75.0 \
    

    BULK_CONFIG_DIR="${OUT_DIR}/instance/bulk-config" \
    BULK_CONFIG_FILE=data.json

# the method by which the framework can assess whether the container is viable or not
HEALTHCHECK --interval=31s --timeout=29s --start-period=241s --retries=7 CMD [ "liveness.sh" ]

LABEL image-version="${IMAGE_VERSION}" \
      image-git-rev="${IMAGE_GIT_REV}"

EXPOSE 9031 9999

# get the staged bits
COPY --from=final-staging ["/","/"]

#- ## Running a PingFederate container
#- To run a PingFederate container:
#-
#- ```shell
#-   docker run \
#-            --name pingfederate \
#-            --publish 9999:9999 \
#-            --detach \
#-            --env SERVER_PROFILE_URL=https://github.com/pingidentity/pingidentity-server-profiles.git \
#-            --env SERVER_PROFILE_PATH=getting-started/pingfederate \
#-            --env PING_IDENTITY_ACCEPT_EULA=YES \
#-            --env PING_IDENTITY_DEVOPS_USER \
#-            --env PING_IDENTITY_DEVOPS_KEY \
#-            --tmpfs /run/secrets \
#-            pingidentity/pingfederate:edge
#- ```
#-
#- Follow Docker logs with:
#-
#- ```
#- docker logs -f pingfederate
#- ```
#-
#- If using the command above with the embedded [server profile](https://devops.pingidentity.com/reference/config/), log in with:
#- * https://localhost:9999/pingfederate/app
#-   * Username: Administrator
#-   * Password: 2FederateM0re
