#!/bin/bash

function deploy_main_branch(){
  STORE_NAME=$1
  PUBLISH_TEXT=""

  # Only change dir if theme files are in a different folder than root
  if [[ -n $WORK_DIR ]] 
  then
      echo "WORK_DIR ${WORK_DIR}"
      cd $WORK_DIR
  fi  

  THEMEKIT_PASSWORD=$(grep -E 'password:\s*.*' config.yml | head -n 1 | sed 's/.*password:\s*//')
  
  LIST=`theme get --list --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}"`
  echo "THEME LIST = ${LIST}"

  echo "===== Downloading theme settings from live theme ====="
  theme -e downloadPublishedSettings download --live
  STATUS1=$?
  if [[ $STATUS1 -ne 0 ]]; then
      echo "Failing deployment due to error in downloading live theme settings"
      exit $STATUS1
  fi

  sed -i "s/theme_id: TARGET_THEME_ID/theme_id: ${MAIN_THEME_IDS}/" config.yml

  if [[ -n $PRD_PARAMETER ]]; then
      PUBLISH_TEXT="DON'T PUBLISH "
  fi

  TIME=$(TZ='US/Pacific' date '+%b %d %H:%M %Z %Y')  # Shortened date format
  NEW_THEME_NAME="GITHUB-${BRANCH_NAME^^}"  # Add GitHub- prefix

  # This will rename the theme
  echo "Rename theme"
  curl -d "{\"theme\":{\"name\": \"${PUBLISH_TEXT}${NEW_THEME_NAME} ${TIME} \", \"id\": \"${MAIN_THEME_IDS}\"}}" \
      -X PUT "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes/${MAIN_THEME_IDS}.json" \
      -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
      -H "Content-Type: application/json"

  # Deploy to main theme on Shopify
  echo "Deploying to main theme on Shopify"
  theme -e deployTheme deploy --allow-live; STATUS1=$?    

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
