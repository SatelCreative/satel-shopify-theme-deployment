#!/bin/bash

function deploy_main_branch(){
    local STORE_NAME="$1"
    local THEMEKIT_PASSWORD="$2"
    MAIN_THEME_ID="$3"
    PUBLISH_TEXT=""

    # Only change dir if theme files are in a different folder than root
    if [[ -n $WORK_DIR ]] 
    then
        echo "==== WORK_DIR ${WORK_DIR} ===="
        cd $WORK_DIR
    fi  

    # Copy and update config
    echo "==== Creating config.yml ===="
    cp config.yml.example config.yml
    sed -i "s/password: API_KEY/password: ${THEMEKIT_PASSWORD}/g" config.yml
    sed -i "s/store: STORE/store: ${STORE_NAME}/g" config.yml
    
    LIST=`theme get --list --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}"`
    echo "THEME LIST = ${LIST}"

    echo "===== Downloading theme settings from live theme on ${store} and MAIN THEME ID: ${id} ====="
    theme -e downloadPublishedSettings download --live
    STATUS1=$?
    if [[ $STATUS1 -ne 0 ]]; then
        echo "==== Failing deployment due to error in downloading live theme settings on ${store} ===="
        exit $STATUS1
    fi

    sed -i "s/theme_id: TARGET_THEME_ID/theme_id: ${MAIN_THEME_ID}/" config.yml
    cat config.yml
    if [[ -n $PRD_PARAMETER ]]; then
        PUBLISH_TEXT="DON'T PUBLISH "
    fi

    TIME=$(TZ='US/Pacific' date '+%b %d %H:%M %Z %Y')  # Shortened date format
    NEW_THEME_NAME="GITHUB-${BRANCH_NAME^^}"  # Add GitHub- prefix

    # This will rename the theme
    echo "==== Rename theme on ${store} ==== "
    curl -d "{\"theme\":{\"name\": \"${PUBLISH_TEXT}${NEW_THEME_NAME} ${TIME} \", \"id\": \"${MAIN_THEME_ID}\"}}" \
        -X PUT "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes/${MAIN_THEME_ID}.json" \
        -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
        -H "Content-Type: application/json"

    # Deploy to main theme on Shopify
    echo "==== Deploying to main theme on Shopify on ${store}==== "
    theme -e deployTheme deploy --allow-live; STATUS1=$?    

    # Return the status code of theme commands
    TOTAL=$((STATUS1 + STATUS2))
    if [[ $TOTAL != 0 ]]
        then 
            echo "==== Failing deployment on ${store} ===="
            exit $TOTAL
        fi 

    cd .. || exit 1
}


STORES=($(echo "$STORE_NAME" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
API_KEYS=($(echo "$API_KEY" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
IDS=( ${MAIN_THEME_IDS} )
echo "==== STORES: ${STORES[@]} ===="
echo "==== IDS: ${IDS[@]} ===="

# Iterate over each store and corresponding API key
for i in "${!STORES[@]}"; do
    store="${STORES[$i]}"
    api_key="${API_KEYS[$i]}"
    id="${IDS[$i]}"
    echo "====== Running deploy PR or Tag on store ${store} with API key: ${api_key} and MAIN THEME ID: ${id} ====="

    deploy_main_branch "${store}" "${api_key}" "${id}" 
    
done