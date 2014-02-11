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
# Arguments:
# Returns:
#   None
get_config() {
  true
}