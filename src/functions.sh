_COMSOLIT_DEPLOY_GIT=git
_COMSOLIT_LOG_INFO=true
_COMSOLIT_DEPLOY_CONFIG_BLOB=HEAD:.deploy/config

log_info() {
  if [ ! -z "$_COMSOLIT_LOG_INFO" ]; then
    echo $1
  fi
}

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

# return all but the most recent checkouts
#
# The function just uses standard ordering of the ls command to sort by date.
#
# Globals:
#   DEPLOY_ROOT
# Arguments:
#   new_target
# Returns:
#   None
switch_symlink() {
  local new_target
  new_target=$1
  # update current symlink with mv to be atomic
  # ln --force does two syscalls to unlink and to create
  ln --symbolic --force --no-dereference "${new_target}" "${DEPLOY_ROOT}/current.new"
  mv --force --no-target-directory "${DEPLOY_ROOT}/current.new" "${DEPLOY_ROOT}/current"
}

# run a hook script
#
# Globals:
#   CHECKOUT_DIR
# Arguments:
#   hook: name of the hook
# Returns:
#   None
run_hook() {
  hook=$1
  hook_path=${CHECKOUT_DIR}/.deploy/hooks/$hook
  if [ -x "${hook_path}" ];then
    log_info "call hook $hook with arguments $@"
    ${hook_path} $@
  fi
}

# whether a branch is configured to be deployed
#
# Globals:
#   COMSOLIT_TIMESTAMP: the current unix timestamp
# Arguments:
#   branch: branch to be deployed
# Returns:
#   boolean
should_deploy() {
  local branch="$1"
  local branches="$(get_config "branch\..*\.deploy" get-regexp bool)"
  local regexp
  branches=$(echo "$branches"|sed -nr 's/^branch.(.*).deploy true$/\1/p')
  for regexp in "$branches"; do
    echo "$branch"|grep -E "$regexp" >/dev/null && return 0
  done
  return 1
}

# deploy a branch
#
# The function expects to be run by a git update hook so that it
# can use git to work on the repository
#
# Globals:
#   COMSOLIT_TIMESTAMP: the current unix timestamp
# Arguments:
#   branch: branch to be deployed
#   deploy_root: the path where the branch should be deployed
# Returns:
#   None
deploy() {
  local branch="$1"
  local deploy_root=$(readlink --canonicalize-missing "$2")
  local date=$(date --date=@${COMSOLIT_TIMESTAMP} +"%F_%H-%M-%S" )
  local checkout_dir_name
  local checkout_dir_absolute
  local describe
  local sha1
  local current_directory=$(pwd)

  # ignore error, if no tag is in the history
  describe="$(git describe ${branch} 2>/dev/null || true)"
  sha1=$(git rev-parse "${branch}")
  checkout_dir_name="${date}-${sha1}-${describe}"
  checkout_dir_absolute="${deploy_root}/checkouts/${checkout_dir_name}"

  mkdir -p "${checkout_dir_absolute}"
  git --work-tree="${checkout_dir_absolute}" checkout --force "${branch}" 2>&1 | grep -vE "^(Already on|Switched to branch) '${branch}'$"

  CHECKOUT_DIR=${checkout_dir_absolute}
  cd ${CHECKOUT_DIR}
  run_hook post-checkout ${branch} ${sha1} ${describe}

  # TODO db migration

  DEPLOY_ROOT=${deploy_root}
  switch_symlink "./checkouts/${checkout_dir_name}"

  run_hook post-switch ${branch} ${sha1} ${describe}

  cd ${current_directory}
  remove_old_checkouts ${deploy_root}/checkouts 4
}

# to be run on the hosting server by the git post-receive hook
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
on_hosting_server_on_post_receive() {
  local ref
  local reftype
  local branch
  local deploy_root
  local old_object
  local new_object
  COMSOLIT_TIMESTAMP=$(date +%s)

  while read old_object new_object ref; do
    reftype=$(echo $ref | cut -d/ -f2)
    branch=$(echo $ref | cut -d/ -f3-)
    if [ $reftype = "heads" ]; then
      _COMSOLIT_DEPLOY_CONFIG_BLOB="${ref}:.deploy/config"
      local deploy_root=$(get_config deploy.root)
      deploy "${branch}" "${deploy_root}/${branch}"
    fi
  done
}

# TODO
#  git push origin $(git tag -l "*.*" | grep -E "([[:digit:]]+\.)+[[:digit:]]+(\+rc[[:digit:]]+)?$")
push_tags() {
  local tags_with_point="$(git tag -l "*.*")"
  if [ ! -z "$tags_with_point" ]; then
    git push --quiet origin "$tags_with_point"
  fi
}

# to be run on the git server by the git post-receive hook
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
on_git_server_on_post_receive() {
  local ref
  local reftype
  local branch
  local deploy_root
  local old_object
  local new_object

  while read oldrev newrev ref; do
    reftype=$(echo $ref | cut -d/ -f2)
    branch=$(echo $ref | cut -d/ -f3-)
    _COMSOLIT_DEPLOY_CONFIG_BLOB="${ref}:.deploy/config"
    if should_deploy "${branch}"; then
      push_tags
      git push --quiet origin +$ref:$branch
    fi
  done
}
