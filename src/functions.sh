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
    log_info "call hook $hook with arguments $*"
    ${hook_path} $@
  fi
}

# enables maintenance page with linking "maintenance" folder outside of project and
# creating a ".maintenance" file which is given for a condition in apache config.
#
# Globals:
#   None
# Arguments:
#   deploy_root: root to be deployed
# Returns:
#   None
enable_maintenance() {
  local deploy_root="$1"
  local maintenance_path=${CHECKOUT_DIR}/.deploy/maintenance
  if [ ! -d ${maintenance_path} ] && [ ! -s ${maintenance_path} ];then
    log_info "maintenance folder is not in your .deploy directory or is empty."
  fi
  if [ -d ${deploy_root}/maintenance ];then
    rm -fr ${deploy_root}/maintenance
  fi

  cp -r ${maintenance_path} ${deploy_root}/maintenance

  if [ -f ${maintenance_path}/.htaccess ];then
    mv ${deploy_root}/maintenance/.htaccess ${deploy_root}/maintenance/.htaccess.disabled
    else
    log_info ".htaccess was not found in ${maintenance_path} or is not a regular file."
  fi
  chown www-data:www-data -R ${deploy_root}/maintenance
  touch ${deploy_root}/.maintenance
}

# disables maintenance page with removing ".maintenance" file and enabling .htaccess for redirecting
#
# Globals:
#  None
# Arguments:
#  deploy_root: root to be deployed
# Returns:
#   None
disable_maintenance() {
  local deploy_root="$1"
  if [ ${deploy_root}/.maintenance ];then
   rm ${deploy_root}/.maintenance
  fi
  if [ -d ${deploy_root}/maintenance ];then
    mv ${deploy_root}/maintenance/.htaccess.disabled ${deploy_root}/maintenance/.htaccess
  fi
}

# returns the exact identifier for the config section that matches for a branch
#
# configuration sections can be grep -E patterns, so it's not possible to directly
# map a pushed branch to a section.
#
# Globals:
#   none
# Arguments:
#   branch: branch to be deployed
# Returns:
#   string, exit 1 if section is not found
get_config_section_for_branch() {
  local branch="$1"
  local branches="$(get_config "branch\..*\.deploy" get-regexp bool)"
  local regexp
  branches=$(echo "$branches"|sed -nr 's/^branch.(.*).deploy true$/\1/p')
  for regexp in $branches; do
    echo "${branch}" | grep -E "${regexp}" >/dev/null
    if [ "$?" -eq 0 ] ; then
      echo "${regexp}"
      return 0
    fi
  done
  return 1
}

# whether a branch is configured to be deployed
#
# Globals:
#   none
# Arguments:
#   branch: branch to be deployed
# Returns:
#   boolean
should_deploy() {
  local branch="$1"
  $(get_config_section_for_branch "${branch}" >/dev/null) || return 1
}

# get tagpattern for branch from config
#
#
# Globals:
#   none
# Arguments:
#   branch: branch to be deployed
# Returns:
#   None
get_tagpattern_for_branch() {
  local branch="$1"
  local section=$(get_config_section_for_branch "${branch}")
  if [ "$?" -ne 0 ] ; then
    return
  fi
  get_config "branch.${section}.tagpattern"
}

write_cachedir_tag() {
  local target="$1"

  cat << 'EOF' > ${target}/CACHEDIR.TAG
Signature: 8a477f597d28d172789f06886806bc55
# This file is a cache directory tag created by comsolit_deploy.
# For information about cache directory tags, see:
#	http://www.brynosaurus.com/cachedir/
EOF
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
  local old_checkout=""

  # ignore error, if no tag is in the history
  describe="$(git describe --always ${branch} 2>/dev/null || true)"
  strict_describe="$(git describe ${branch} 2>/dev/null || true)"
  sha1=$(git rev-parse "${branch}")
  checkout_dir_name="${date}-${sha1}-${strict_describe}"
  checkout_dir_absolute="${deploy_root}/checkouts/${checkout_dir_name}"

  if [ -L "${deploy_root}/current" ];then
    old_checkout=$(readlink --canonicalize-missing ${deploy_root}/current)
  fi

  mkdir -p "${checkout_dir_absolute}"
  git --work-tree="${checkout_dir_absolute}" checkout --force "${branch}" 2>&1 | grep -vE "^(Already on|Switched to branch) '${branch}'$"

  CHECKOUT_DIR=${checkout_dir_absolute}
  cd ${CHECKOUT_DIR}
  enable_maintenance ${deploy_root}
  run_hook post-checkout "${branch}" "${sha1}" "${describe}" "${strict_describe}"

  # TODO db migration

  DEPLOY_ROOT=${deploy_root}
  switch_symlink "./checkouts/${checkout_dir_name}"

  run_hook post-switch "${branch}" "${sha1}" "${describe}" "${strict_describe}"
  disable_maintenance ${deploy_root}

  cd ${current_directory}

  if [ -n "${old_checkout}" ];then
    write_cachedir_tag "${old_checkout}"
  fi

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
      if [ -z "$deploy_root" ]; then
        echo "no deploy.root configured!"
        exit 1
      fi
      if [ ! -d "$deploy_root" ]; then
        echo "deploy.root is not a directory: $deploy_root"
        exit 1
      fi
      if [ ! -w "$deploy_root" ]; then
        echo "deploy.root is not writable: $deploy_root"
        exit 1
      fi

      deploy "${branch}" "${deploy_root}/${branch}"
    fi
  done
}

# push the tag that describes this HEAD
#
# Globals:
#   None
# Arguments:
#   tagpattern - tagpattern that must be matched by the tag
#   branch     - branch that is pushed
# Returns:
#   boolean, whether a tag for the given pattern could describe the pushed HEAD
push_tag() {
  local tagpattern="$1"
  local branch="$2"
  local matching_tags="$(git describe --exact-match ${branch} 2>/dev/null)"
  local tag_to_push="$(echo $matching_tags | grep -E ${tagpattern})"
  if [ ! -z "$tag_to_push" ]; then
    git push --quiet origin "${tag_to_push}"
    return 0
  fi
  # no tag available for the given pattern
  return 1
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
  local tagpattern

  while read oldrev newrev ref; do
    reftype=$(echo $ref | cut -d/ -f2)
    branch=$(echo $ref | cut -d/ -f3-)
    _COMSOLIT_DEPLOY_CONFIG_BLOB="${ref}:.deploy/config"
    if should_deploy "${branch}"; then
      tagpattern=$(get_tagpattern_for_branch "${branch}")
      if [ ! -z "${tagpattern}" ]; then
        if ! push_tag "${tagpattern}" "${branch}" ; then
          # a tag is required but not available. Don't deploy.
          continue;
        fi
      fi

      git push --quiet origin +$ref:$branch
    fi
  done
}
