#!/bin/bash

function deploy_main_branch(){
  STORE_NAME=$1
  THEME_ID=$2 
  PUBLISH_TEXT=""

  # only change dir if theme files are in a different folder than root
  if [[ -n $WORK_DIR ]] 
  then
      echo "WORK_DIR ${WORK_DIR}"
      cd $WORK_DIR
  fi  

  THEMEKIT_PASSWORD=`grep -E 'password:\s*.*' config.yml | sed 's/.*password:\s*//'`
  
  LIST=`"theme get --list"`
  echo "THEME LIST = ${LIST}"

  if [[ -n $PRD_PARAMETER ]]; then
      PUBLISH_TEXT="DO NOT PUBLISH"
  fi
  
  NAME=`TZ='US/Pacific' date`
  NEW_THEME_NAME="${BRANCH_NAME^^}"
  #This will rename the theme
  curl -d "{\"theme\":{\"name\": \"${PUBLISH_TEXT}-${NEW_THEME_NAME} ${NAME} \", \"id\": \"${THEME_ID}\"}}" \
        -X PUT "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes/${THEME_ID}.json" \
        -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
        -H "Content-Type: application/json" 

  # Deploy to live
    theme -e uat deploy --allow-live; STATUS1=$?    

  # Return the status code of theme commands
  TOTAL=$((STATUS1 + STATUS2))
  if [[ $TOTAL != 0 ]]
    then 
        echo "Failing deployment"
        exit $TOTAL
    fi 
    
  cd ..
}

stores=( ${STORE_NAME} )
i=0
for store in "${stores[@]}"
do
  echo "====== Running deploy main on store ${store} ======" 
  ids=( ${MAIN_THEME_IDS} )
  deploy_main_branch "${store}" "${ids[i]}" 
  i=$((i+1))
done 
