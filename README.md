# 🚀 Satel Shopify Theme Deployment Action
A reusable GitHub Action to deploy Shopify themes across multiple environments and stores using a centralized configuration

📦 Features
- Deploys Shopify themes to multiple stores

- Supports environment-specific deployments (dev, prd, etc.)

- Copies published theme settings when needed

- Works with multiple `config.yml` profiles by temporary modifying `config.yml.example`

- Integrates with CI/CD workflows and Slack

- Works with GitHub-hosted and self-hosted runners



## 🔧 Usage
Here’s an example of how to use this custom action within a workflow:
```YAML

- name: Checkout
  uses: actions/checkout@v4.2.2

- name: Get branch name
  run: echo "BRANCH_NAME=$(echo ${GITHUB_REF#refs/*/})" >> $GITHUB_ENV   

- name: Set branch name
  if: ${{ github.ref != 'refs/heads/main' }}
  run: echo "BRANCH_NAME=$(echo ${GITHUB_HEAD_REF})" >> $GITHUB_ENV

- name: Current tag name
  id: tag-name
  run:  echo "TAG_NAME=$(git describe --tag --abbrev=0)" >> $GITHUB_ENV  

- name: Get repo name
  run: echo "REPO_NAME=${{ github.event.repository.name }}" >> $GITHUB_ENV

- name: Install themekit
  if: ${{ runner.environment == 'github-hosted' }}
  run: curl -s https://shopify.dev/themekit.py | sudo python3     

- name: Set run ID (on PR open)
  if: ${{ github.event_name == 'pull_request' && github.event.action == 'opened' }}
  run: echo "RUN_ID=1" >> $GITHUB_ENV  

- name: Deploy theme
  id: theme-deploy
  uses: SatelCreative/satel-shopify-theme-deployment@2.0.0
  with: 
    store-name: ${{ inputs.store-name }}         # e.g., '<store1> <store2>'
    api-key: "${{ secrets.store-1 }},${{ secrets.store2 }},...."
    theme-env: ${{ inputs.environment }}         # e.g., 'dev'
    main-theme-id: ${{ inputs.main-theme-id }}   # e.g., '<id1> <id2>'
    repo-name: ${{ env.REPO_NAME }} 
    github-token: ${{ secrets.GITHUB_TOKEN }}
    theme-files-location: ${{ inputs.work-dir }}
    current-branch-name: ${{ env.BRANCH_NAME }}
    tag-name: ${{ env.TAG_NAME }} 
    org-name: ${{ inputs.org-name }}
    run-id: ${{ env.RUN_ID }}                    # Used for a new PR
    is-prd: true                                 # Adds 'DON’T PUBLISH' prefix for production themes

```


## 🔁  Reusable Workflow Example
Below is a sample of how to call the above workflow from a reusable one:

```YAML
# .github/workflows/storefront-deploy_dev.yml

name: Deploy to Dev Store

on:
  pull_request:
    paths:
      - 'storefront/**'
      - '.github/workflows/storefront-deploy_dev.yml'
      - '.github/workflows/lib-storefront_deploy.yml'
  push:
    paths:
      - 'storefront/**'
      - '.github/workflows/storefront-deploy_dev.yml'
      - '.github/workflows/lib-storefront_deploy.yml'
    branches:
      - main

concurrency:
  group: '${{ github.workflow }} @ ${{ github.event.pull_request.head.label || github.head_ref || github.ref }}'
  cancel-in-progress: true

jobs:
  deploy-theme:
    uses: ./.github/workflows/lib-storefront_deploy.yml
    with:
      work-dir: storefront
      environment: dev
      store-name: '<STORE1>.myshopify.com,<STORE12>.myshopify.com,....'
      main-theme-id: '<MAIN-THEME_ID1> <MAIN-THEME_ID2> .....' # this needs to exist before deployment
      org-name: 'SatelCreative'
    secrets:
      API_KEY: ${{ secrets.DEV_STOREFRONT_API_KEY }}    # Must have theme read/write permissions
      SELF_HOSTED_RUNNER_TOKEN: ${{ secrets.SELF_HOSTED_RUNNER_TOKEN }}
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

`config.yml.example` would like this:

```YAML
downloadPublishedSettings:
  password: API_KEY
  theme_id: THEME_ID # This is not being used while deployment
  store: STORE
  ignore_files:
    - sections/*.liquid
    - snippets/*
    - assets/*
    - config/settings_schema.json
    - layout/*
    - locales/*

deployTheme:
  password: API_KEY
  theme_id: TARGET_THEME_ID # Theme GitHub is deploying to
  store: STORE
  ```

📘 **Notes**
- API Key should be stored securely (e.g., in LastPass). It must come from a Shopify Custom App with theme read/write access. Name the app as `CI CD` on Shopify

- The `main-theme-id` input is used for deploying changes to the live theme when working in a development environment.

- If no DEV store exists, the `is-prd` flag ensures your production themes are clearly marked with a DON’T PUBLISH prefix.