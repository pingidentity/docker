#!/usr/bin/env sh

# shellcheck source=lib.sh
. "${BASE}/lib.sh"

if ! test -z "${SERVER_PROFILE_URL}" ; then
    # deploy configuration if provided
    git clone "${SERVER_PROFILE_URL}" "${SERVER_PROFILE_DIR}"
    die_on_error 78 "Git clone failure" 
    if ! test -z "${SERVER_PROFILE_BRANCH}" ; then
        # https://github.com/koalaman/shellcheck/wiki/SC2103
        (
        cd "${SERVER_PROFILE_DIR}" || return
        git checkout "${SERVER_PROFILE_BRANCH}"
        )
    fi
    # shellcheck disable=SC2086
    cp -af ${SERVER_PROFILE_DIR}/${SERVER_PROFILE_PATH}/* "${STAGING_DIR}"
fi