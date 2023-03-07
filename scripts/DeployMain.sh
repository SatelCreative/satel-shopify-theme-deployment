#!/bin/bash

function deploy_main_branch(){
  STORE_NAME=$1
  THEME_ID=$2 

  THEMEKIT_PASSWORD=`grep -o '"'${STORE_NAME}'": "[^"]*' theme.json | grep -o '[^"]*$'`

  #only change dir if theme files are in a different folder
  if [[ -n $WORK_DIR ]] 
  then
      echo "WORK_DIR ${WORK_DIR}"
      cd $WORK_DIR
  fi 

  theme configure --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com" --themeid=${THEME_ID} --env ${THEME_ENV}

  NAME=`TZ='US/Pacific' date`
  NEW_THEME_NAME="${BRANCH_NAME^^}"
  #This will rename the theme
  curl -d "{\"theme\":{\"name\": \"${NEW_THEME_NAME} ${NAME}\", \"id\": \"${THEME_ID}\"}}" \
        -X PUT "https://${STORE_NAME}.myshopify.com/admin/api/${SHOPIFY_API_VERSION}/themes/${THEME_ID}.json" \
        -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
        -H "Content-Type: application/json" 
  #Deploy to live
  theme -e developtheme deploy --allow-live --ignored-file=config/settings_data.json    
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