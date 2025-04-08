#!/bin/bash

# Initialize arrays for preview links and theme IDs
PREVIEW_LINKS=()
THEME_IDS=()
THEME_ID=""

# Set THEME_NAME based on TAG_NAME or fallback to BRANCH_NAME
if [[ -n "${TAG_NAME}" ]]; then
    THEME_NAME="==== ${TAG_NAME} ===="
else 
    THEME_NAME="${BRANCH_NAME}"
    echo "==== THEME_NAME: ${BRANCH_NAME} ===="
fi

deploy_pr_branch_or_tag() {
    local STORE_NAME="$1"
    local THEMEKIT_PASSWORD="$2"

    if [[ -n $WORK_DIR ]]; then
        echo "==== WORK_DIR: ${WORK_DIR} ===="
        cd "$WORK_DIR" || exit
    fi

    echo "==== Deploying for ${STORE_NAME} ===="

    # Copy and update config
    echo "==== Creating config.yml ===="
    cp config.yml.example config.yml
    sed -i "s/password: API_KEY/password: ${THEMEKIT_PASSWORD}/g" config.yml
    sed -i "s/store: STORE/store: ${STORE_NAME}/g" config.yml

    # Get existing THEME_ID
    THEME_ID=$(theme get --list --password="${THEMEKIT_PASSWORD}" --store="${STORE_NAME}" | grep -i "${THEME_NAME}" | cut -d "[" -f 2 | cut -d "]" -f 1)
    echo "==== Existing THEME_ID=${THEME_ID} ===="

    # Create the theme if it doesn't exist
    if [[ -z "${THEME_ID}" ]]; then
        echo "===== Creating theme on ${STORE_NAME}====="
        THEME_ID=$(curl -s -d "{\"theme\":{\"name\": \"PR: ${THEME_NAME}\", \"env\": \"${THEME_ENV}\"}}" \
            -X POST "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes.json" \
            -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
            -H "Content-Type: application/json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
        echo "Created theme ID=${THEME_ID}"
    fi

    echo "===== Downloading theme settings from live theme on ${STORE_NAME} ====="
    theme -e downloadPublishedSettings download --live
    STATUS1=$?
    if [[ $STATUS1 -ne 0 ]]; then
        echo "==== Failing deployment due to error in downloading live theme settings"
        exit $STATUS1
    fi

    # Update TARGET_THEME_ID in config.yml with the new THEME_ID to deploy it
    sed -i "s/theme_id: TARGET_THEME_ID/theme_id: ${THEME_ID}/" config.yml

    echo "===== Deploying theme for the first time on ${STORE_NAME} ====="
    theme -e deployTheme deploy 
    STATUS2=$?

    if [[ $STATUS2 -ne 0 ]]; then
        echo "===== Re-deploying theme on ${STORE_NAME}====="
        theme -e deployTheme deploy 
        STATUS3=$?
        if [[ $STATUS3 -ne 0 ]]; then
            echo "THEME_ID=${THEME_IDS[@]}"
            echo "preview_link=${PREVIEW_LINKS[@]}" >> "$GITHUB_OUTPUT"
            echo "theme_id=${THEME_IDS[@]}" >> "$GITHUB_OUTPUT"
            echo "===== Failing deployment due to error in theme deployment on ${STORE_NAME} ====="
            exit $STATUS3
        fi
    fi

    echo "===== Generating preview link for ${STORE_NAME} ====="
    PREVIEW_LINK=$(theme -e deployTheme --themeid="${THEME_ID}" --password="${THEMEKIT_PASSWORD}" --store="${STORE_NAME}" open -b /bin/echo | grep -i "${STORE_NAME}" | awk 'END {print $3}')
    PREVIEW_LINKS+=("Preview this PR on [${STORE_NAME}](${PREVIEW_LINK})<br>")
    THEME_IDS+=("${THEME_ID}")

    cd .. || exit 1
}

## Start of the script
# IFS=',' read -ra STORES <<< "$STORE_NAME"
# IFS=',' read -ra API_KEYS <<< "$API_KEY"
# Split by comma, then trim leading/trailing whitespace for each item
STORES=($(echo "$STORE_NAME" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
API_KEYS=($(echo "$API_KEY" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
echo "==== STORES: ${STORES[@]} ===="
echo "==== API_KEYS: ${API_KEYS[@]} ===="

#Check if the number of stores matches the number of API keys
if [ ${#STORES[@]} -ne ${#API_KEYS[@]} ]; then
  echo "ERROR: The number of stores and API keys do not match!"
  exit 1
fi

# Iterate over each store and corresponding API key
for i in "${!STORES[@]}"; do
    store="${STORES[$i]}"
    api_key="${API_KEYS[$i]}"
    echo "====== Running deploy PR or Tag on store ${store} with API key: ${api_key} ====="

    deploy_pr_branch_or_tag "${store}" "${api_key}"
done

# Output theme IDs and preview links for GitHub
echo "THEME_IDs=${THEME_IDS[@]}"
echo "preview_link=${PREVIEW_LINKS[@]}" >> "$GITHUB_OUTPUT"
echo "theme_id=${THEME_IDS[@]}" >> "$GITHUB_OUTPUT"
