#!/bin/bash
PREVIEW_LINKS=()
THEME_IDS=()

deploy_pr_branch_or_tag() {

    STORE_NAME=$1 
    
    mkdir temp
    cp storefront/config.yml temp/config.yml
    cd temp

    # create theme
    THEMEKIT_PASSWORD=`grep -E 'password:\s*.*' config.yml | sed 's/.*password:\s*//'`
    
    if [[ -n "${TAG_NAME}" ]]  
    then  
        THEME_NAME=$TAG_NAME
    else
        THEME_NAME=$BRANCH_NAME
        echo "THEME_NAME $BRANCH_NAME"
    fi

    THEME_ID=`theme get --list --password=${THEMEKIT_PASSWORD}  --store="${STORE_NAME}" | grep -i ${THEME_NAME} | cut -d "[" -f 2 | cut -d "]" -f 1`       
    echo "Existing THEME_ID=${THEME_ID}"
    
    if [[ ! "${THEME_ID}" ]] 
    then
        # Theme doesnt exist, create it
        # Use api call instead of theme new as the latter creates a V1 theme
        echo "Creating theme"
        THEME_ID=$(curl -s -d "{\"theme\":{\"name\": \"PR: ${THEME_NAME}\", \"env\": \"${THEME_ENV}\"}}" \
            -X POST "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes.json" \
            -H "X-Shopify-Access-Token:${THEMEKIT_PASSWORD}" \
            -H "Content-Type: application/json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
    
        echo "Created theme id=${THEME_ID}"
    fi

  # theme download
    theme download --password=${THEMEKIT_PASSWORD}  --store="${STORE_NAME}"  --live; STATUS1=$?


    # Return the status code of theme commands
    TOTAL=$((STATUS1))

    if [[ $TOTAL != 0 ]]
    then 
       echo "Failing deployment 1"
       exit $TOTAL
    fi

    # theme deploy
    theme deploy

    cd ..

#     if [[ -n $WORK_DIR ]] #only change dir if theme files are in a different folder than root
#     then
#         echo "WORK_DIR ${WORK_DIR}"
#         cd $WORK_DIR
#     fi  
    

#     sed -i "s/theme_id: THEME_ID/theme_id: ${THEME_ID}/" config.yml
    
#     # echo "Generate PR preview links"
#     PREVIEW_LINK=`theme -e uat open -b /bin/echo | grep -i "${STORE_NAME}" | awk 'END {print \$3}'`
#     PREVIEW_LINKS+=( "Preview this PR on [${STORE_NAME}](${PREVIEW_LINK})<br>" )

#     echo "Running deploy command"
#     theme -e uat deploy; STATUS3=$?   
    
#     THEME_IDS+=("${THEME_ID}")
    
#     # To overcome first theme deploy's limitation for V2 of uploading files in a bad order, so deploy once again
#     if [[ $STATUS3 != 0 ]]
#     then 
#         echo "Re-deploying theme"
#         theme -e uat deploy; STATUS4=$?
#         if [[ $STATUS4 != 0 ]]
#         then 
#             # generate preview link even if it fails as the theme may have  gotten created, eg: Bondiboost
#             # These outputs are used in other steps/jobs via action.yml
#             echo "THEME_ID=${THEME_IDS[@]}"
#             echo "preview_link=${PREVIEW_LINKS[@]}" >> $GITHUB_OUTPUT
#             echo "theme_id=${THEME_IDS[@]}" >> $GITHUB_OUTPUT

#             echo "Failing deployment 2"
#             exit $STATUS4 
#         fi  
#     fi   
#     cd .. # need to do this for next store
 }   


stores=( ${STORE_NAME} )
for store in "${stores[@]}"
do
echo "====== Running deploy PR or Tag on store ${store} ====="  
deploy_pr_branch_or_tag "${store}"
done 

echo "THEME_IDs=${THEME_IDS[@]}"
# These outputs are used in other steps/jobs via action.yml
echo "preview_link=${PREVIEW_LINKS[@]}" >> $GITHUB_OUTPUT
echo "theme_id=${THEME_IDS[@]}" >> $GITHUB_OUTPUT
