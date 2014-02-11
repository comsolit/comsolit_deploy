#!/bin/sh
#
# Copyright 2014 comsolit AG
# Released under the LGPL (GNU Lesser General Public License)

. ../lib/test_helpers
. ../src/functions.sh

testGitConfigGet() {
  local file=test_config/general

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
  local file=test_config/general

  assertEquals "hello world
hello git" \
    "$(_comsolit_deploy_get_git_config $file multiple.values get-all)"
}

testGitCatBlobToTmp() {
  local git_dir=test_config/cat_blob.git
  local tmpfile
  tmpfile="$(_comsolit_deploy_cat_blob_to_tmp $git_dir "master:catblob")"

  assertEquals "hello world!!" "$(cat $tmpfile)"
  rm $tmpfile
}

testGetConfig() {
  # override global GIT_DIR
  export GIT_DIR=test_config/cat_blob.git
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

# suite functions
oneTimeSetUp()
{
  th_oneTimeSetUp
}

tearDown()
{
  true
}

# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. ${TH_SHUNIT}
