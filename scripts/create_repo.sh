#!/bin/bash

#DATA_CATALOG=../../../vwt-digital-config/dat-deployment-config/config/vwt-d-gew1-dat-deployment/data_catalog.json
DATA_CATALOG=data_catalog.json
GITHUB_ACCESS_TOKEN=../../../vwt-digital-config/dat-deployment-config/config/vwt-d-gew1-dat-deployment/github_access_token.key

OLDIFS="$IFS"
IFS=$'\n'

for pr in $(python3 listrepos.py ${DATA_CATALOG})
do
  # (re)Create the repo
  cp template_newRepo.json newRepo.json

  REPO_TITLE=$(echo $pr | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)['distribution']))" | \
	     python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)[0]))" | \
	     python3 -c "import sys, json; print(json.load(sys.stdin)['title'])")
  ORGANISATION=$(echo $REPO_TITLE | cut -d / -f1)

  REPO_NAME=$(echo $REPO_TITLE | cut -d / -f2)

  REPO_DESCRIPTION=$(echo $pr | python3 -c "import sys, json; print(json.load(sys.stdin)['title'])")

  REPO_INTERNAL=$(echo $pr | python3 -c "import sys, json; print(json.load(sys.stdin)['accessLevel'])")

  echo $ORGANISATION
  echo $REPO_NAME
  echo $REPO_DESCRIPTION
  echo $REPO_INTERNAL

  sed -i "s/REPO_NAME/${REPO_NAME}/g" newRepo.json
  sed -i "s/REPO_DESCRIPTION/${REPO_DESCRIPTION}/g" newRepo.json

  if [ $REPO_INTERNAL == public ]
  then
    sed -i "s/REPO_INTERNAL/false/g" newRepo.json
  else
    sed -i "s/REPO_INTERNAL/true/g" newRepo.json
  fi

  curl -d @newRepo.json -X POST -H "Authorization:token $(cat ${GITHUB_ACCESS_TOKEN})" "https://api.github.com/orgs/$(echo ${ORGANISATION})/repos"

  # Add "develop" branch
  export SHA=$(curl -X GET -H "Authorization:token $(cat ${GITHUB_ACCESS_TOKEN})" "https://api.github.com/repos/$(echo ${ORGANISATION})/$(echo ${REPO_NAME})/git/refs/heads" | \
	python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)[0]))" | \
       	python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)['object']))" | \
	python3 -c "import sys, json; print(json.load(sys.stdin)['sha'])")

  sed "s/SHA/${SHA}/g" template_addBranch.json > addBranch.json

  curl -d @addBranch.json -X POST -H "Authorization:token $(cat ${GITHUB_ACCESS_TOKEN})" "https://api.github.com/repos/$(echo ${ORGANISATION})/$(echo ${REPO_NAME})/git/refs"

  # Set default branch to "develop"
  curl -d @patchRepo.json -X PATCH -H "Authorization:token $(cat ${GITHUB_ACCESS_TOKEN})" "https://api.github.com/repos/$(echo ${ORGANISATION})/$(echo ${REPO_NAME})"

  # Set repo restrictions
  curl -d @set_github_restrictions.json -X PUT -L -H "Authorization:token $(cat ${GITHUB_ACCESS_TOKEN})"  -H "Accept: application/vnd.github.luke-cage-preview+json" "https://api.github.com/repos/$(echo ${ORGANISATION})/$(echo ${REPO_NAME})/branches/master/protection"
done

IFS="$OLDIFS"

exit