#!/bin/sh
#
# Copyright 2014 comsolit AG
# Released under the LGPL (GNU Lesser General Public License)

. ../lib/test_helpers
. ../src/functions.sh

testGitConfigGet() {
  local file=test_functions/general

  assertEquals "true" $(_comsolit_deploy_get_git_config $file a.bool.truish get bool)
  assertEquals "true" $(_comsolit_deploy_get_git_config $file a.bool.truish get)
  assertEquals "true" $(_comsolit_deploy_get_git_config $file a.bool.truish)

  assertEquals $(_comsolit_deploy_get_git_config $file a.bool.falsy) "false"
  assertEquals 0 $(_comsolit_deploy_get_git_config $file an.int.zero get int)
  assertEquals "0" $(_comsolit_deploy_get_git_config $file an.int.zero get int)
  assertEquals 1 $(_comsolit_deploy_get_git_config $file an.int.one get int)
  assertEquals -1 $(_comsolit_deploy_get_git_config $file an.int.minusone get int)
  assertEquals 10 $(_comsolit_deploy_get_git_config $file an.int.ten get int)

  assertEquals 0 $(_comsolit_deploy_get_git_config $file an.int.zero)
}

testGitConfigGetAll() {
  local file=test_functions/general

  assertEquals "hello world
hello git" \
    "$(_comsolit_deploy_get_git_config $file multiple.values get-all)"
}

testGitCatBlobToTmp() {
  local git_dir=test_functions/cat_blob.git
  local tmpfile
  tmpfile="$(_comsolit_deploy_cat_blob_to_tmp $git_dir "master:catblob")"

  assertEquals "hello world!!" "$(cat $tmpfile)"
  rm $tmpfile
}

testGetConfig() {
  # override global GIT_DIR
  export GIT_DIR=test_functions/cat_blob.git
  _COMSOLIT_DEPLOY_CONFIG_BLOB="master:config"

  assertEquals "foo" "$(get_config sec.tion)"
}

testGetOldCheckouts() {
  local tmpdir
  tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})

  touch $tmpdir/1
  touch $tmpdir/2
  touch $tmpdir/3
  touch $tmpdir/4

  assertEquals "1
2
3" \
    "$(get_old_checkouts "$tmpdir" 1)"

  assertEquals "1
2" \
    "$(get_old_checkouts "$tmpdir" 2)"

  assertEquals "1" "$(get_old_checkouts "$tmpdir" 3)"
  assertEquals "" "$(get_old_checkouts "$tmpdir" 4)"
  assertEquals "" "$(get_old_checkouts "$tmpdir" 5)"
  assertEquals "" "$(get_old_checkouts "$tmpdir" 6)"
}

testRemoveCheckouts() {
  local tmpdir
  tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})

  touch $tmpdir/1
  touch $tmpdir/2
  touch $tmpdir/3
  touch $tmpdir/4

  remove_old_checkouts "$tmpdir" 2

  assertEquals "3
4" \
    "$(ls -1 $tmpdir)"
}

testSwitchSymlink() {
  local tmpdir
  local checkouts_dir
  local a
  local b
  tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  checkouts_dir=$tmpdir/checkouts
  a=$checkouts_dir/2012-12-02
  b=$checkouts_dir/2013-01-12

  DEPLOY_ROOT=$tmpdir
  mkdir -p $a
  echo "a" > $a/sample
  assertEquals "a" $(cat $a/sample)
  mkdir -p $b
  echo "b" > $b/sample
  assertEquals "b" $(cat $b/sample)

  switch_symlink $a
  assertEquals "a" $(cat $DEPLOY_ROOT/current/sample)

  switch_symlink $b
  assertEquals "b" $(cat $DEPLOY_ROOT/current/sample)
}

testRunHook() {
  local tmpdir
  local out
  local hooksdir
  local hook
  tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  hooksdir=$tmpdir/.deploy/hooks
  hook=what-ever

  CHECKOUT_DIR=$tmpdir
  _COMSOLIT_LOG_INFO=true

  out=$(run_hook $hook)
  assertEquals "" "$out"

  mkdir -p $hooksdir
  out=$(run_hook $hook)
  assertEquals "" "$out"

  touch $hooksdir/$hook
  out=$(run_hook $hook)
  assertEquals "" "$out"

  chmod a+x $hooksdir/$hook
  out=$(run_hook $hook)
  assertEquals "1" "$(echo $out|wc -l)"

  echo "#!/bin/sh" >$hooksdir/$hook
  out=$(run_hook $hook)
  assertEquals "1" "$(echo $out|wc -l)"

  _COMSOLIT_LOG_INFO=""
  echo "echo washere" >>$hooksdir/$hook
  out=$(run_hook $hook)
  assertEquals "washere" "$out"
}

testDeploy() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  local checkout_dir="2014-02-12_14-30-25-c5b140057695c3989c7ab310b61d5e54ae4901b7-"
  local i

  unset GIT_DIR
  cp -r test_functions/cat_blob.git $tmpdir
  cd $tmpdir/cat_blob.git

  COMSOLIT_TIMESTAMP="1392211825"
  deploy master "${tmpdir}/s"

  assertEquals "file under current" "hello world!!" "$(cat ${tmpdir}/s/current/catblob)"
  assertEquals "file under checkouts" "hello world!!" "$(cat ${tmpdir}/s/checkouts/${checkout_dir}/catblob)"
  assertEquals "exactly one checkout dir" "${checkout_dir}" "$(ls -1 ${tmpdir}/s/checkouts)"

  # test removal of old checkouts
  for i in $(seq 1392211826 1392211841); do
    COMSOLIT_TIMESTAMP="${i}"
    deploy master "${tmpdir}/s"

    [ "$(ls -1 ${tmpdir}/s/checkouts|wc -l)" -lt 11 ]
    assertTrue "less than 5 checkouts created" $?

    [ "$(ls -1 ${tmpdir}/s/checkouts|wc -l)" -gt 1 ]
    assertTrue "more than 1 checkout created" $?
  done
}

__feedback_testDeployWithHooks_post_checkout() {
  echo "post-checkout"
  echo $@
}

__feedback_testDeployWithHooks_post_switch() {
  echo "post-switch"
  echo $@
}

testDeployWithHooks() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  local out

  unset GIT_DIR
  cp -r test_functions/deployable.git $tmpdir
  cd $tmpdir/deployable.git

  _COMSOLIT_LOG_INFO=""
  _TEST_RUN_POST_CHECKOUT=__feedback_testDeployWithHooks_post_checkout
  _TEST_RUN_POST_SWITCH=__feedback_testDeployWithHooks_post_switch
  COMSOLIT_TIMESTAMP="1392211825"
  out=$(deploy master "${tmpdir}")
  assertEquals \
    "post-checkout master 475de32a28e0b3e8ee2316386e6c32ceee664c17 nopoint nopoint
post-switch master 475de32a28e0b3e8ee2316386e6c32ceee664c17 nopoint nopoint" \
    "${out}"
}

testOnHostingServerOnPostReceive() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  local sourcegit=$tmpdir/deployable.git
  local targetgit=$tmpdir/target.git
  local out

  mkdir -p $targetgit
  git --git-dir=$targetgit init --bare --quiet
  ln -s $(readlink -f ../src/hosting_server_hook.sh) $targetgit/hooks/post-receive

  cp -r test_functions/deployable.git $tmpdir
  git --git-dir=$sourcegit remote add origin $targetgit

  out=$(git --git-dir=$sourcegit push --quiet origin master 2>&1)
  assertEquals 4 "$(echo "$out"|wc -l)"

  out=$(ls -1 $tmpdir/master/current/.deploy)
  assertEquals "config
hooks" "${out}"
}

testShouldDeploy() {
  export GIT_DIR=test_functions/deployable.git
  _COMSOLIT_DEPLOY_CONFIG_BLOB=master:.deploy/config

  should_deploy production
  assertTrue "production failed" $?

  should_deploy "/my/private/branch"
  assertTrue "/my/private/branch failed" $?

  should_deploy "/my/private/branch/even/deeper"
  assertTrue "/my/private/branch failed" $?

  should_deploy master
  assertFalse "master failed" $?

  should_deploy undefined
  assertFalse "undefined failed" $?
}

testOnGitServerOnPostReceive() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  local devgit=$tmpdir/deployable.git
  local sourcegit=$tmpdir/source.git
  local targetgit=$tmpdir/target.git
  local out

  mkdir -p $targetgit
  git --git-dir=$targetgit init --bare --quiet
  ln -s $(readlink -f ../src/hosting_server_hook.sh) $targetgit/hooks/post-receive

  mkdir -p $sourcegit
  git --git-dir=$sourcegit init --bare --quiet
  ln -s $(readlink -f ../src/git_server_hook.sh) $sourcegit/hooks/post-receive

  cp -r test_functions/deployable.git $tmpdir
  git --git-dir=$devgit remote add origin $sourcegit
  git --git-dir=$sourcegit remote add origin $targetgit

  git --git-dir=$devgit push --quiet origin master:master
  assertEquals "" "$(ls -1 $tmpdir|grep master)"

  git --git-dir=$devgit push --tags --quiet
  git --git-dir=$devgit push --quiet origin master:doesnotexist
  assertEquals "" "$(ls -1 $tmpdir|grep doesnotexist)"

  git --git-dir=$devgit push --quiet origin master:production 2>/dev/null
  assertEquals "production" "$(ls -1 $tmpdir|grep production)"

  out=$(ls -1 $tmpdir/production/current/.deploy)
  assertEquals "config
hooks" "${out}"

  git --git-dir=$devgit push --quiet origin master:my/private/branch 2>/dev/null
  assertEquals "branch" "$(ls -1 $tmpdir/my/private|grep branch)"

  out=$(ls -1 $tmpdir/my/private/branch/current/.deploy)
  assertEquals "config
hooks" "${out}"
}

setupGitRepos() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  local devgit=$tmpdir/devgit
  local sourcegit=$tmpdir/source.git
  local targetgit=$tmpdir/target.git

  unset GIT_DIR

  mkdir -p "${devgit}" "${sourcegit}" "${targetgit}"

  git --git-dir=$sourcegit init --quiet --bare "${sourcegit}"
  git --git-dir=$targetgit init --quiet --bare "${targetgit}"

  ln -s $(readlink -f ../src/hosting_server_hook.sh) $targetgit/hooks/post-receive
  ln -s $(readlink -f ../src/git_server_hook.sh) $sourcegit/hooks/post-receive

  cd $devgit && git init --quiet && cd - >/dev/null

  git --git-dir=$devgit/.git remote add origin $sourcegit
  git --git-dir=$sourcegit remote add origin $targetgit

  echo "${tmpdir}"
}

copyAndCommit() {
  unset GIT_DIR
  local gitrepo=$1
  local content=$2

  cp -R $content $gitrepo
  cd $gitrepo
  git add -A .
  git commit --quiet -m"COMMITMESSAGE42"
  cd - >/dev/null
}

testTagpatternWithoutMatchingTag() {
  unset GIT_DIR

  local tmpdir="$(setupGitRepos)"
  local out

  copyAndCommit "$tmpdir/devgit" "test_functions/config_with_tagpatterns/.deploy"
  git --git-dir $tmpdir/devgit/.git push --quiet origin master

  out=$(git --git-dir $tmpdir/source.git log --oneline)
  assertTrue "source.git has a commit" $?
  echo $out | grep COMMITMESSAGE42 >/dev/null
  assertTrue "source.git has correct commit" $?

  out=$(git --git-dir $tmpdir/target.git log --oneline 2>&1)
  assertFalse "target.git has no commit" $?
  assertEquals "fatal: bad default revision 'HEAD'" "$out"
}

testTagpatternWithSomeOtherTag() {
  unset GIT_DIR

  local tmpdir="$(setupGitRepos)"
  local out

  copyAndCommit "$tmpdir/devgit" "test_functions/config_with_tagpatterns/.deploy"
  git --git-dir $tmpdir/devgit/.git tag --annotate -m"." doesnotmatchpattern
  git --git-dir $tmpdir/devgit/.git push --quiet --tags origin master

  out=$(git --git-dir $tmpdir/source.git log --oneline)
  assertTrue "source.git has a commit" $?
  echo $out | grep COMMITMESSAGE42 >/dev/null
  assertTrue "source.git has correct commit" $?

  out=$(git --git-dir $tmpdir/source.git tag -l)
  assertEquals "$out" doesnotmatchpattern

  out=$(git --git-dir $tmpdir/target.git log --oneline 2>&1)
  assertFalse "target.git has no commit" $?
  assertEquals "fatal: bad default revision 'HEAD'" "$out"
}

testTagpatternWithMatchingTag() {
  unset GIT_DIR

  local tmpdir="$(setupGitRepos)"
  local out

  copyAndCommit "$tmpdir/devgit" "test_functions/config_with_tagpatterns/.deploy"
  git --git-dir $tmpdir/devgit/.git tag --annotate -m"." 1.2.3
  git --git-dir $tmpdir/devgit/.git push --quiet --tags origin master

  out=$(git --git-dir $tmpdir/source.git log --oneline)
  assertTrue "source.git has a commit" $?
  echo $out | grep COMMITMESSAGE42 >/dev/null
  assertTrue "source.git has correct commit" $?

  out=$(git --git-dir $tmpdir/target.git log --oneline)
  assertTrue "target.git has a commit" $?
  echo $out | grep COMMITMESSAGE42 >/dev/null
  assertTrue "target.git has correct commit" $?
}

testBranchWithoutTagpattern() {
  unset GIT_DIR

  local tmpdir="$(setupGitRepos)"
  local out

  copyAndCommit "$tmpdir/devgit" "test_functions/config_with_tagpatterns/.deploy"
  git --git-dir $tmpdir/devgit/.git push --quiet --tags origin master:development

  out=$(git --git-dir $tmpdir/source.git log --oneline development)
  assertTrue "source.git has a commit" $?
  echo $out | grep COMMITMESSAGE42 >/dev/null
  assertTrue "source.git has correct commit" $?

  out=$(git --git-dir $tmpdir/target.git branch -a | grep development)
  assertTrue "target.git has development branch" $?
  assertEquals "* development" "$out"
}

testWriteCacheDirTag() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})
  write_cachedir_tag "${tmpdir}"

  assertEquals "CACHEDIR.TAG" "$(ls -1 --almost-all ${tmpdir})"
  assertEquals "Signature: 8a477f597d28d172789f06886806bc55" "$(head -n 1 ${tmpdir}/CACHEDIR.TAG)"
  rm "${tmpdir}/CACHEDIR.TAG"
  rmdir "${tmpdir}"
}

testDeployWritesCacheDirTag() {
  local tmpdir=$(mktemp --directory --tmpdir=${SHUNIT_TMPDIR})

  unset GIT_DIR
  cp -r test_functions/cat_blob.git $tmpdir
  cd $tmpdir/cat_blob.git

  COMSOLIT_TIMESTAMP="1392211825"
  deploy master "${tmpdir}/s"
  local old_checkout=$(readlink --canonicalize-missing ${tmpdir}/s/current)
  COMSOLIT_TIMESTAMP="1392211826"
  deploy master "${tmpdir}/s"

  assertTrue "CACHEDIR.TAG exists in old checkout: $(ls -1l ${old_checkout})" 'test -r "${old_checkout}/CACHEDIR.TAG"'
  assertFalse "No CACHEDIR.TAG in current" 'test -r "${tmpdir}/s/current/CACHEDIR.TAG"'
  assertEquals "CACHEDIR.TAG contains correct signature" "Signature: 8a477f597d28d172789f06886806bc55" "$(head -n 1 ${old_checkout}/CACHEDIR.TAG)"
}


# suite functions
oneTimeSetUp()
{
  th_oneTimeSetUp
}

setUp() {
  cd "${TH_INITIAL_CURRENT_DIRECTORY}"
}

tearDown()
{
  true
}

# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. ${TH_SHUNIT}
