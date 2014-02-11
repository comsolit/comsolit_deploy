_COMSOLIT_DEPLOY_GIT=git

# Read config values from a config file with git-config
#
# Globals:
#   _COMSOLIT_DEPLOY_GIT path to git executable
# Arguments:
#   file
#   name
#   get_method (optional): one of get, get-all, get-regexp
#   type (optional): one of int, bool, bool-or-int
# Returns:
#   value of the requested git config name
_comsolit_deploy_get_git_config() {
  local _file="--file=$1"
  local _name="$2"
  local _get_method=--${3:-get}
  local _type=${4:+--}${4:-}
  ${_COMSOLIT_DEPLOY_GIT} config $_file $_type $_get_method $_name
}

# Cat git blob to a temporary file and return file path
#
# Globals:
#   _COMSOLIT_DEPLOY_GIT path to git executable
# Arguments:
#   git_dir
#   blob, e.g. "HEAD:.deploy/config"
# Returns:
#   file path
_comsolit_deploy_cat_blob_to_tmp() {
  local _git_dir=$1
  local _blob=$2
  local _tmpfile="$(mktemp)"
  ${_COMSOLIT_DEPLOY_GIT} --git-dir=${_git_dir} cat-file -p $_blob >${_tmpfile}
  echo ${_tmpfile}
}

# get config value from deploy config file
#
# the deploy config file is located in the git repository
# under .deploy/config
#
# Globals:
#   _COMSOLIT_DEPLOY_CONFIG_BLOB
# Arguments:
#   name
#   get method (optional)
#   type (optional)
# Returns:
#   value of the requested git config name
get_config() {
  local git_dir
  local tmpfile
  local blob
  git_dir="$(git rev-parse --git-dir)"
  blob="${_COMSOLIT_DEPLOY_CONFIG_BLOB}"
  tmpfile=$(_comsolit_deploy_cat_blob_to_tmp $git_dir $blob)
  _comsolit_deploy_get_git_config ${tmpfile} $@
  rm ${tmpfile}
}

# return all but the most recent checkouts
#
# The function just uses standard ordering of the ls command to sort by date.
#
# Globals:
#   _None
# Arguments:
#   checkouts_dir
#   number_to_keep
# Returns:
#   directory names
get_old_checkouts() {
  checkouts_dir=$1
  number_to_keep=$2
  ls -1 ${checkouts_dir} | head --lines=-${number_to_keep}
}

remove_old_checkouts() {
  checkouts_dir=$1
  number_to_keep=$2
  for checkout_dir  in $(get_old_checkouts ${checkouts_dir} ${number_to_keep}); do
    rm -rf ${checkouts_dir}/${checkout_dir}
  done
}
