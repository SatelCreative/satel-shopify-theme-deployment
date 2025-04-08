#!/bin/bash

function delete_inactive_themes() {
    local STORE_NAME="$1"
    local THEMEKIT_PASSWORD="$2"

    if [[ -n $WORK_DIR ]] # only change dir if theme files are in a different folder than root
    then
        echo "==== WORK_DIR ${WORK_DIR} ===="
        cd $WORK_DIR
    fi  

    # grab all the themes except for main and sandboxes as we dont want to delete theme
    THEME_NAMES=`theme get --list --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}" | grep 'PR: ' | awk '{print $3}'`
    THEME_LIST=( $THEME_NAMES )

    get_branch_list
    BRANCH_NAMES=( $BRANCH_LIST )

    for THEME in "${THEME_LIST[@]}"
    do    
        if [[ ! "${BRANCH_NAMES[*]}" =~ "${THEME}" ]]; then
            echo "==== Themes that will be deleted PR:${THEME} on ${STORE_NAME} ===="
            THEME_ID=`theme get --list --password=${THEMEKIT_PASSWORD} --store="${STORE_NAME}" | grep -i ${THEME} | cut -d "[" -f 2 | cut -d "]" -f 1`
    
            THEME=$(echo -n "${THEME}" | tr -d '[:space:]')
            
            RESPONSE=$(curl -s -w "\n%{http_code}" -d "{\"theme\":{\"id\": \"${THEME_ID}\",\"name\":\"${THEME}\"}}" \
            -X DELETE "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes/${THEME_ID}.json" \
            -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
            -H "Content-Type: application/json")
            
            RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
            HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

            if [[ $HTTP_CODE == "200" ]]; then
                echo "Successfully deleted theme PR:${THEME} with ID:${THEME_ID} from ${STORE_NAME}"
            else
                echo "==== Failed to delete theme PR:${THEME} with ID:${THEME_ID} from ${STORE_NAME}. Response code: ${HTTP_CODE}"
                echo "==== Response body: ${RESPONSE_BODY} ===="
            fi
        else
            echo "==== No GitHub themes to delete on ${STORE_NAME} ==== "    
        fi
        
    done
}

function get_branch_list(){
    PAYLOAD="query { \
        organization(login: \\\"${ORG_NAME}\\\") {\
            repository(name: \\\"${REPO_NAME}\\\") {\
            refs(refPrefix: \\\"refs/heads/\\\", first: 100) {\
                edges {\
                node{\
                    name\
                }\
                }\
            }\
            }\
        }\
    }"

    BRANCH_LIST=`curl -X POST "https://api.github.com/graphql" \
        -H "Authorization: bearer ${GITHUB_TOKEN}" \
        -H "Content-Type: application/json"  \
        -d "{ \"query\": \"${PAYLOAD}\"}" | jq ".data.organization.repository.refs.edges[].node.name"`; STATUS1=$?  

    # Catch exit code so all the PR: themes dont get deleted
    if [[ $STATUS1 != 0 ]]
    then    
        exit 1
    fi         
}


## Start of the script
STORES=($(echo "$STORE_NAME" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
API_KEYS=($(echo "$API_KEY" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
echo "==== STORES: ${STORES[@]} ===="
echo "==== API_KEYS: ${API_KEYS[@]} ===="

# Check if the number of stores matches the number of API keys
if [ ${#STORES[@]} -ne ${#API_KEYS[@]} ]; then
    echo "ERROR: The number of stores and API keys do not match!"
    exit 1
fi

# Iterate over each store and corresponding API key
for i in "${!STORES[@]}"; do
    store="${STORES[$i]}"
    api_key="${API_KEYS[$i]}"
    echo "======  Running delete inactive themes on ${store} with API key: ${api_key} ====="

    delete_inactive_themes "${store}" "${api_key}"
done

