#!/bin/bash
PREVIEW_LINKS=()
THEME_IDS=()

deploy_pr_branch_or_tag() { 

    STORE_NAME=$1
    THEMEKIT_PASSWORD=`grep -o '"'${STORE_NAME}'": "[^"]*' theme.json | grep -o '[^"]*$'`

    if [[ -n $WORK_DIR ]] #only change dir if theme files are in a different folder than root
    then
        echo "WORK_DIR ${WORK_DIR}"
        cd $WORK_DIR
    fi    
    
    if [[ -n "${TAG_NAME}" ]]  
    then  
        THEME_NAME=$TAG_NAME
    else
        THEME_NAME=$BRANCH_NAME
    fi

    THEME_ID=`theme get --list --password=${THEMEKIT_PASSWORD}  --store="${STORE_NAME}.myshopify.com" | grep -i ${THEME_NAME} | cut -d "[" -f 2 | cut -d "]" -f 1`       
    echo "THEME_ID=${THEME_ID}"
    if [[ ! "${THEME_ID}" ]] 
    then
        # Theme doesnt exist, create it
        # Use api call instead of theme new as the latter creates a V1 theme
        echo "Creating theme"
        create_theme
        THEME_ID=`theme get --list --password=${THEMEKIT_PASSWORD}  --store="${STORE_NAME}.myshopify.com" | grep -i ${THEME_NAME} | cut -d "[" -f 2 | cut -d "]" -f 1`
        configure_theme # configure once again before deployment to genearate config.yml as it's needed for theme deploy

    else
        # Theme exist, just configure it
        echo "Configuring theme"
        configure_theme
    fi

    if [[ $COPY_SETTINGS == true ]] && [[ -n $RUN_ID]]
    then   
        echo "Copy settings"
        theme download --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com"  --env ${THEME_ENV} config/settings_data.json --live; STATUS1=$?
    fi 
   
    # Return the status code of theme commands
    TOTAL=$((STATUS1 + STATUS2))

    if [[ $TOTAL != 0 ]]
    then 
       echo "Failing deployment"
       exit $TOTAL
    fi 
    
    echo "Generate PR preview links"
    PREVIEW_LINK=`theme open --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com"  --env ${THEME_ENV} -b /bin/echo | grep -i "${STORE_NAME}.myshopify.com" | awk 'END {print \$3}'`
    PREVIEW_LINKS+=( "Preview this PR on [${STORE_NAME}](${PREVIEW_LINK})<br>" )

    echo "Running deploy command"
    theme deploy --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com" --themeid=${THEME_ID}  --env ${THEME_ENV}; STATUS3=$?   
    
    THEME_IDS+=("${THEME_ID}")
    
    # To overcome first theme deploy's limitation for V2 of uploading files in a bad order, so deploy once again
    if [[ $STATUS3 != 0 ]]
    then 
        echo "Redeploying theme"
        theme deploy --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com" --themeid=${THEME_ID}  --env ${THEME_ENV}; STATUS4=$?
        if [[ $STATUS4 != 0 ]]
        then 
            echo "Failing deployment"
            exit $STATUS4 
        fi  
    fi   
    cd .. # need to do this for next store
}   

function configure_theme(){
    theme configure --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}.myshopify.com" --themeid=${THEME_ID} --env ${THEME_ENV}; STATUS2=$?
}

function create_theme(){
    curl -d "{\"theme\":{\"name\": \"PR: ${THEME_NAME}\", \"env\": \"${THEME_ENV}\"}}" \
        -X POST "https://${STORE_NAME}.myshopify.com/admin/api/${SHOPIFY_API_VERSION}/themes.json" \
        -H "X-Shopify-Access-Token:${THEMEKIT_PASSWORD}" \
        -H "Content-Type: application/json" 
}

stores=( ${STORE_NAME} )
for store in "${stores[@]}"
do
echo "====== Running deploy PR or Tag on store ${store} ====="  
deploy_pr_branch_or_tag "${store}"
done 

echo "THEME_ID=${THEME_IDS[@]}"
# These outputs are used in other steps/jobs via action.yml
echo "::set-output name=preview_link::${PREVIEW_LINKS[@]}" 
echo "::set-output name=theme_id::${THEME_IDS[@]}" 
