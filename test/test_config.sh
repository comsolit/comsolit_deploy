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
  local tmpfile="$(_comsolit_deploy_cat_blob_to_tmp $git_dir "master:catblob")"

  assertEquals "hello world!!" "$(cat $tmpfile)"
  rm $tmpfile
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
