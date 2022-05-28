#!/bin/sh

read -p 'Git author and commiter name: ' name
read -p 'Git author and commiter email: ' email

git filter-branch -f --env-filter "
	GIT_AUTHOR_NAME=$name
  GIT_AUTHOR_EMAIL=$email
  GIT_COMMITTER_NAME=$name
  GIT_COMMITTER_EMAIL=$email
" HEAD
