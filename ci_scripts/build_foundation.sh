#!/usr/bin/env bash
#
# Ping Identity DevOps - CI scripts
#
# This script builds the foundation images:
#   - pingbase
#   - pingcommon
#   - pingdatacommon
#   - pingjvm
#
test -n "${VERBOSE}" && set -x

usage ()
{
    test -n "${*}" && echo "${*}"

    cat <<END_USAGE
Usage: ${0} {options}
    where {options} include:
    -d, --default-shim
        The name of the shim that will be tagged as default
    -p, --product
        The name of the product for which to build a docker image
    -s, --shim
        the name of the operating system for which to build a docker image
    -j, --jvm
        the id of the jvm to build
    -v, --version
        the version of the product for which to build a docker image
        this setting overrides the versions in the version file of the target product
    --verbose-build
        verbose docker build using plain progress output
    --no-cache
        no docker cache
    --no-build-kit
        build without using build-kit
    --use-proxy
        If the http_proxy or HTTP_PROXY variables are set, pass them on to docker build
    --help
        Display general usage information
END_USAGE
    exit 99
}

_totalStart=$( date '+%s' )
DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}
noCache=${DOCKER_BUILD_CACHE}
while test -n "${1}"
do
    case "${1}" in
        -p|--product)
            shift
            test -z "${1}" && usage "You must provide a product to build"
            productToBuild="${1}"
            ;;
        -s|--shim)
            shift
            test -z "${1}" && usage "You must provide an OS Shim"
            shimsToBuild="${shimsToBuild}${shimsToBuild:+ }${1}"
            ;;
        -j|--jvm)
            shift
            test -z "${1}" && usage "You must provide a JVM id"
            jvmsToBuild="${jvmsToBuild}${jvmsToBuild:+ }${1}"
            ;;
        -v|--version)
            shift
            test -z "${1}" && usage "You must provide a version to build"
            versionToBuild="${1}"
            ;;
        --use-proxy)
            for v in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY; do
              if test -n "${!v}"
              then
                useProxy="$useProxy --build-arg $v=${!v}"
              fi
            done
            ;;
        --no-build-kit)
            DOCKER_BUILDKIT=0
            ;;
        --no-cache)
            noCache="--no-cache"
            ;;
        --verbose-build)
            progress="--progress plain"
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
    CI_PROJECT_DIR="$( cd "$( dirname "${0}" )/.." || exit 97 ; pwd )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"

if test -z "${isLocalBuild}"
then
    banner "CI FOUNDATION BUILD"
    # get the list of running containers.
    _containersList="$(docker container ls -q | sort | uniq)"

    # stop all running containers
    # shellcheck disable=SC2086
    test -n "${_containersList}" && docker container stop ${_containersList}

    # get list of all stopped containers lingering
    _containersList="$(docker container ls -aq | sort | uniq)"

    # remove all containers
    # shellcheck disable=SC2046
    test -n "${_containersList}" && docker container rm -f $(docker container ls -aq)
    # get the list of all images in the local repo
    _imagesList="$(docker image ls -q | sort | uniq)"

    # shellcheck disable=SC2086
    test -n "${_imagesList}" && docker image rm -f ${_imagesList}

    # wipe everything clean
    docker image prune -f
    docker network prune
else
    banner "LOCAL FOUNDATION BUILD"
fi

# result table header
_resultsFile="/tmp/$$.results"
_headerPattern=' %-53s| %10s| %7s\n'
_reportPattern='%-52s| %10s| %7s'
# shellcheck disable=SC2059
printf "${_headerPattern}" "IMAGE" "DURATION" "RESULT" > ${_resultsFile}

#build foundation and push to gcr for use in subsequent jobs.
banner Building PING COMMON
_start=$( date '+%s' )
_image="${FOUNDATION_REGISTRY}/pingcommon:${ciTag}"

# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} ${useProxy} \
     -t "${_image}" "${CI_PROJECT_DIR}/pingcommon"
_returnCode=${?}
_stop=$( date '+%s' )
_duration=$(( _stop - _start ))
if test ${_returnCode} -ne 0
then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${isLocalBuild}"
    then
        banner "Pushing ${_image}"
        docker push "${_image}"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingcommon" "${_duration}" "${_result}"
fi
imagesToCleanup="${imagesToCleanup} ${_image}"

banner Building PING DATA COMMON
_start=$( date '+%s' )
_image="${FOUNDATION_REGISTRY}/pingdatacommon:${ciTag}"
# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} ${useProxy} \
    --build-arg REGISTRY="${FOUNDATION_REGISTRY}" \
    --build-arg GIT_TAG="${ciTag}" \
    -t "${_image}" "${CI_PROJECT_DIR}/pingdatacommon"
_returnCode=${?}
_stop=$( date '+%s' )
_duration=$(( _stop - _start ))
if test ${_returnCode} -ne 0
then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${isLocalBuild}"
    then
        banner "Pushing ${_image}"
        docker push "${_image}"
    fi
    append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingdatacommon" "${_duration}" "${_result}"
fi
imagesToCleanup="${imagesToCleanup} ${_image}"

if test -n "${shimsToBuild}"
then
    shims=${shimsToBuild}
else
    if test -n "${productToBuild}"
    then
        if test -n "${versionToBuild}"
        then
            shims=$( _getShimsToBuildForProductVersion ${productToBuild} ${versionToBuild} )
        else
            shims=$( _getAllShimsForProduct ${productToBuild} )
        fi
    else
        shims=$( _getAllShims )
    fi
fi


for _shim in ${shims}
do
    _shimTag=$( _getLongTag "${_shim}" )

    if test -z "${jvmsToBuild}"
    then
        # find which JVMs to build for each supported SHIM
        _jvms=$( _getAllJVMsToBuildForShim "${_shim}" )
    else
        _jvms=${jvmsToBuild}
    fi

    for _jvm in ${_jvms}
    do
        if test "${_jvm}" = "nojvm"
        then
            continue
        fi
        banner "Building pingjvm for JDK ${_jvm} for ${_shim}"
        _start=$( date '+%s' )
        _image="${FOUNDATION_REGISTRY}/pingjvm:${_jvm}_${_shimTag}-${ciTag}"
        _jvm_from=$( _getJVMImageForShimID "${_shim}" "${_jvm}" )
        # shellcheck disable=SC2086
        DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
            ${progress} ${noCache} ${useProxy} \
            --build-arg SHIM="${_jvm_from}" \
            -t "${_image}" "${CI_PROJECT_DIR}/pingjvm"
        _returnCode=${?}
        _stop=$( date '+%s' )
        _duration=$(( _stop - _start ))
        if test ${_returnCode} -ne 0
        then
            returnCode=${_returnCode}
            _result="FAIL"
        else
            _result="PASS"
            if test -z "${isLocalBuild}"
            then
                banner "Pushing ${_image}"
                docker push "${_image}"
            fi
        fi
        append_status "${_resultsFile}" "${_result}" "${_reportPattern}" "pingjvm:${_jvm}_${_shimTag}" "${_duration}" "${_result}"
        imagesToCleanup="${imagesToCleanup} ${_image}"
    done
done

banner "Building pingbase"
_start=$( date '+%s' )
_image="${FOUNDATION_REGISTRY}/pingbase:${ciTag}"
# shellcheck disable=SC2086
DOCKER_BUILDKIT=${DOCKER_BUILDKIT} docker image build \
    ${progress} ${noCache} ${useProxy} \
    -t "${_image}" "${CI_PROJECT_DIR}/pingbase"
_returnCode=${?}
_stop=$( date '+%s' )
_duration=$(( _stop - _start ))
if test ${_returnCode} -ne 0
then
    returnCode=${_returnCode}
    _result="FAIL"
else
    _result="PASS"
    if test -z "${isLocalBuild}"
    then
        banner "Pushing ${_image}"
        docker push "${_image}"
    fi
fi
append_status "${_resultsFile}" "${_result}"  "${_reportPattern}" "pingbase" "${_duration}" "${_result}"
imagesToCleanup="${imagesToCleanup} ${_image}"

# leave runner without clutter
# shellcheck disable=SC2086
test -z "${isLocalBuild}" && docker image rm -f ${imagesToCleanup}

cat ${_resultsFile}
rm ${_resultsFile}
_totalStop=$( date '+%s' )
_totalDuration=$(( _totalStop - _totalStart ))
echo "Total duration: ${_totalDuration}s"
exit ${returnCode}
