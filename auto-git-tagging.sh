#!/bin/bash

require_clean_work_tree () {
    # Update the index
    git update-index -q --ignore-submodules --refresh
    err=0

    # Disallow unstaged changes in the working tree
    if ! git diff-files --quiet --ignore-submodules --
    then
        echo >&2 "Cannot deploy because you have unstaged changes:"
        git diff-files --name-status -r --ignore-submodules -- >&2
        err=1
    fi

    # Disallow uncommitted changes in the index
    if ! git diff-index --cached --quiet HEAD --ignore-submodules --
    then
        echo >&2 "Cannot deploy because your index contains uncommitted changes:"
        git diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
        err=1
    fi

    if [ $err = 1 ]
    then
        echo >&2 "Please commit and push them before deploying! Aborting deployment..."
        exit 1
    fi
}

require_clean_work_tree

git fetch

# check current branch, has to be main or master
current_branch=$(git rev-parse --abbrev-ref HEAD)

if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ] && [ "$current_branch" != "HEAD" ]
then
  echo "Cannot deploy. Current branch: $current_branch. You can only deploy from master/main branch! Aborting deployment..."
  exit 1
fi

# check if a deployed-* tag exists and if it is pushed to remote
tag_on_current_commit=$(git tag --points-at HEAD)

if [ -n "$tag_on_current_commit" ] && [[ $tag_on_current_commit =~ "deployed-" ]]
then
  remote_tags=$(git ls-remote --tags)

  if [[ ${remote_tags[@]} =~ $tag_on_current_commit ]]
  then
    printf "Commit already has deploy tag '$tag_on_current_commit' and it is pushed to remote. Can start deployment now..."
    exit 0
  else
    printf "\nFound deploy tag '$tag_on_current_commit' on current commit and it is not in remote. Manual intervention is needed, please take a look. If you are sure this tag can be pushed, use this command: \n\n    git push origin tag $tag_on_current_commit \n\nAborting deployment..."
    exit 1
  fi
fi


# check if commit is pushed to remote main or master branch
contains_hash=$(git branch -r --format='%(refname:short)' --contains "$(git rev-parse HEAD)")

if [[ ${contains_hash[@]} =~ "main" ]] || [[ ${contains_hash[@]} =~ "master" ]]
then

  latest_tag=$(git tag -l | grep deployed | sort -V | tail -1)

  echo "Latest tag: $latest_tag"

  current_version=$(echo "$latest_tag" | cut -d'-' -f2) || 0

  new_version=$((current_version+1))

  new_tag=deployed-"$new_version"

  echo "New tag: $new_tag"

  git tag "$new_tag"

  if [ $? -ne 0 ]; then
    echo "Aborting deployment..."
    exit 1
  fi

  git push origin tag "$new_tag"

  if [ $? -ne 0 ]; then
    echo "Aborting deployment..."
    exit 1
  fi

  echo "Deploy tag created successfully! Can start deployment now..."
  exit 0

else
  if [ -n "$contains_hash" ]
  then
    echo "Error: Branches containing changes: $contains_hash"
  fi
  echo "Cannot deploy. Please push to origin/master or origin/main! Aborting deployment..."
  exit 1
fi