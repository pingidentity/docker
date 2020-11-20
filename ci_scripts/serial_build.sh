#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This build a set of images running through the steps of:
#
#     cleanup_docker.sh   - Cleaning up a docker environment
#     build_downloader.sh - Build the Ping Downloader Image
#     build_foundation.sh - Build the foundation images (pingbase, pingcommon, ...)
#     build_product.sh    - Build the product image itself
#
test -n "${VERBOSE}" && set -x
#
# Usage printing function
#
usage ()
{
        test -n "${*}" && echo "${*}"
    cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:
    -p, --product
        The name of the product for which to build a docker image
    --with-tests
        Execute smoke tests
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --use-proxy
        If the http_proxy or HTTP_PROXY variables are set, pass them on to docker build
    --verbose-build
        verbose docker build not using docker buildkit
    --dry-run
        does everything except actually call the docker command and prints it instead
    --help
        Display general usage information
END_USAGE
    exit 99
}

PING_IDENTITY_SNAPSHOT=""
export PING_IDENTITY_SNAPSHOT
while ! test -z "${1}"
do
    case "${1}" in
        --dry-run)
            buildOptions="${buildOptions:+${buildOptions} }--dry-run"
            ;;
        --fail-fast)
            buildOptions="${buildOptions:+${buildOptions} }--fail-fast"
            ;;
        -j|--jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            buildOptions="${buildOptions:+${buildOptions} }--jvm ${1}"
            ;;
        --no-build-kit)
            buildOptions="${buildOptions:+${buildOptions} }--no-build-kit"
            ;;
        --no-cache)
            buildOptions="${buildOptions:+${buildOptions} }--no-cache"
            ;;
        -p|--product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            _products="${_products:+${_products} }${1}"
            ;;
        -s|--shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            buildOptions="${buildOptions:+${buildOptions} }--shim ${1}"
            ;;
        --snapshot)
            export PING_IDENTITY_SNAPSHOT="--snapshot"
            ;;
        --verbose-build)
            buildOptions="${buildOptions:+${buildOptions} }--verbose-build"
            ;;
        --use-proxy)
            for v in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY; do
              if test -n "${!v}"
              then
                buildOptions="${buildOptions} --use-proxy"
                useProxy="${useProxy} --build-arg $v=${!v}"
              fi
            done
            ;;
        -v|--version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            buildOptions="${buildOptions:+${buildOptions} }--version ${1}"
            smokeOptions="${smokeOptions:+${smokeOptions} }--version ${1}"
            ;;
        --with-tests)
            _smokeTests=true
            ;;
        --help)
            usage
            ;;
        *)
            usage "Unrecognized option"
            ;;
    esac
    shift
done

if test -z "${CI_COMMIT_REF_NAME}"
then
    CI_PROJECT_DIR="$( cd "$(dirname "${0}")/.." || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

"${CI_SCRIPTS_DIR}/cleanup_docker.sh" full
if test -n "${useProxy}"
then
  "${CI_SCRIPTS_DIR}/build_downloader.sh" --use-proxy
  "${CI_SCRIPTS_DIR}/build_foundation.sh" --use-proxy
else
  "${CI_SCRIPTS_DIR}/build_downloader.sh"
  "${CI_SCRIPTS_DIR}/build_foundation.sh"
fi


test -z "${_products}" && _products="apache-jmeter ldap-sdk-tools pingaccess pingcentral pingdataconsole pingdatagovernance pingdatagovernancepap pingdatasync pingdirectory pingdirectoryproxy pingdelegator pingfederate pingtoolkit"

for p in ${_products}
do
    # shellcheck disable=SC2086
    "${CI_SCRIPTS_DIR}/build_product.sh" -p "${p}" ${buildOptions}
    test ${?} -ne 0 && failed=true && break

    if test -n "${_smokeTests}"
    then
        # shellcheck disable=SC2086
        "${CI_SCRIPTS_DIR}/run_smoke.sh" -p "${p}" ${smokeOptions}
        test ${?} -ne 0 && failed=true && break
    fi
done
test -z "${failed}" && docker images
