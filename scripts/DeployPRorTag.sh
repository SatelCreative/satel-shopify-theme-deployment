#!/bin/bash

# Initialize arrays for preview links and theme IDs
PREVIEW_LINKS=()
THEME_IDS=()
THEME_ID=""

# Extract THEMEKIT password from configuration file
THEMEKIT_PASSWORD=$(grep -E 'password:\s*.*' storefront/config.yml | head -n 1 | sed 's/.*password:\s*//')

# Set THEME_NAME based on TAG_NAME or fallback to BRANCH_NAME
if [[ -n "${TAG_NAME}" ]]; then
    THEME_NAME="==== ${TAG_NAME} ===="
else 
    THEME_NAME="${BRANCH_NAME}"
    echo "==== THEME_NAME: ${BRANCH_NAME} ===="
fi

deploy_pr_branch_or_tag() {
    local STORE_NAME="$1"

    # Get existing THEME_ID
    THEME_ID=$(theme get --list --password="${THEMEKIT_PASSWORD}" --store="${STORE_NAME}" | grep -i "${THEME_NAME}" | cut -d "[" -f 2 | cut -d "]" -f 1)
    echo "==== Existing THEME_ID=${THEME_ID} ===="
    
    # Create the theme if it doesn't exist
    if [[ -z "${THEME_ID}" ]]; then
        echo "===== Creating theme ====="
        THEME_ID=$(curl -s -d "{\"theme\":{\"name\": \"PR: ${THEME_NAME}\", \"env\": \"${THEME_ENV}\"}}" \
            -X POST "https://${STORE_NAME}/admin/api/${SHOPIFY_API_VERSION}/themes.json" \
            -H "X-Shopify-Access-Token: ${THEMEKIT_PASSWORD}" \
            -H "Content-Type: application/json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
        echo "Created theme ID=${THEME_ID}"
    fi

    if [[ -n $WORK_DIR ]]; then  # Only change directory if theme files are in a different folder than root
        echo "==== WORK_DIR: ${WORK_DIR} ===="
        cd "$WORK_DIR" || exit
    fi

    echo "===== Downloading theme settings from live theme ====="
    theme -e downloadPublishedSettings download --live
    STATUS1=$?
    if [[ $STATUS1 -ne 0 ]]; then
        echo "==== Failing deployment due to error in downloading live theme settings"
        exit $STATUS1
    fi

    # Update TARGET_THEME_ID in config.yml with the new THEME_ID
    sed -i "s/theme_id: TARGET_THEME_ID/theme_id: ${THEME_ID}/" config.yml

    echo "===== Deploying theme for the first time ====="
    theme -e deployTheme deploy 
    STATUS2=$?

    # Retry deployment if the first attempt fails
    if [[ $STATUS2 -ne 0 ]]; then
        echo "===== Re-deploying theme ====="
        theme -e deployTheme deploy 
        STATUS3=$?
        if [[ $STATUS3 -ne 0 ]]; then
            echo "THEME_ID=${THEME_IDS[@]}"
            echo "preview_link=${PREVIEW_LINKS[@]}" >> "$GITHUB_OUTPUT"
            echo "theme_id=${THEME_IDS[@]}" >> "$GITHUB_OUTPUT"
            echo "===== Failing deployment due to error in theme deployment ====="
            exit $STATUS3
        fi
    fi

    # Generate PR preview link
    echo "===== Generating preview link ====="
    PREVIEW_LINK=$(theme -e deployTheme --themeid="${THEME_ID}" --password="${THEMEKIT_PASSWORD}" --store="${STORE_NAME}" open -b /bin/echo | grep -i "${STORE_NAME}" | awk 'END {print $3}')
    PREVIEW_LINKS+=("Preview this PR on [${STORE_NAME}](${PREVIEW_LINK})<br>")
    THEME_IDS+=("${THEME_ID}")

    cd .. || exit 1  # Navigate back for the next store
}

# Iterate over stores and deploy the theme
stores=("${STORE_NAME}")
for store in "${stores[@]}"; do
    echo "====== Running deploy PR or Tag on store ${store} ====="
    deploy_pr_branch_or_tag "${store}"
done

# Output theme IDs and preview links for use in other steps/jobs
echo "THEME_IDs=${THEME_IDS[@]}"
echo "preview_link=${PREVIEW_LINKS[@]}" >> "$GITHUB_OUTPUT"
echo "theme_id=${THEME_IDS[@]}" >> "$GITHUB_OUTPUT"
