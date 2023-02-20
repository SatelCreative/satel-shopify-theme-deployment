#!/bin/bash

echo "Running deloy main branch script"

STORE_NAME=$1
THEME_NAME=$2 
THEME_ID=$3
THEME_ENV=$4
SHOPIFY_API_VERSION=$5
WORK_DIR=$6

THEMEKIT_PASSWORD=`grep -o '"'${STORE_NAME}'": "[^"]*' theme.json | grep -o '[^"]*$'`

#only change dir if theme files are in a different folder
if [[ -n $WORK_DIR ]] 
then
    echo "WORK_DIR ${WORK_DIR}"
    cd $WORK_DIR
fi   

function deploy_main_branch(){
  theme configure --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com" --themeid=${THEME_ID} --env ${THEME_ENV}

  NAME=`TZ='US/Pacific' date`
  NEW_THEME_NAME="${THEME_NAME^^}"
  #This will rename the theme
  curl -d "{\"theme\":{\"name\": \"${NEW_THEME_NAME} ${NAME}\", \"id\": \"${THEME_ID}\"}}" \
        -X PUT "https://${STORE_NAME}.myshopify.com/admin/api/${SHOPIFY_API_VERSION}/themes/${THEME_ID}.json" \
        -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
        -H "Content-Type: application/json" 
  #Deploy to live
  theme -e developtheme deploy --allow-live --ignored-file=config/settings_data.json    
}

deploy_main_branch