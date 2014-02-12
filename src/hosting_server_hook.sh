#!/bin/sh

MY_REALPATH=$(readlink --canonicalize --quiet --no-newline --silent $0)
MY_DIR=$(dirname ${MY_REALPATH})
INVOKED_NAME=$(basename $0)

. $MY_DIR/functions.sh

case "${INVOKED_NAME}" in
  post-receive)
    on_hosting_server_on_post_receive
    ;;
  *)
    echo "Nothing to do for ${INVOKED_NAME}"
esac
