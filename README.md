# Satel shopify theme deployment action
This centralized GitHub action deploys a theme to shopify admin

## Usage
```YAML
- name: Deploy theme
  uses: SatelCreative/satel-shopify-theme-deployment@1.0.0
  with: 
    store-name: '<store-name>' # for multiple store '<store_name1 store_name2>'  
    # exclude the .myshopfy.com part. 
    theme-env: '<environment_you_are_deploying_to>'
    copy-settings: true
    main-theme-id: '<theme-id>' # theme that's live on the dev stores, for multiple store '<theme-id-1> <theme-id-2>'
    repo-name: ${{ env.REPO_NAME }} 
    github-token: ${{ secrets.GITHUB_TOKEN }}
    shopify-api-version: '<stable-shopify-api-version>' # format: 2022-10
    theme-files-location: <folder-for-theme-files> #same as work directory 
    current-branch-name: ${{ env.BRANCH_NAME }}
    tag-name: ${{ env.TAG_NAME }} 
    org-name: '<github-organization-name>'
    run-id: <integer>  # To copy setting from main the first time a PR is created, if the settings doesn't exist on github 
```

Theme credentials can be stored as GitHub secrets as: 
```JSON
{
	"<store-name-1>": "<store-name-1-password>",
	"<store-name-2>": "<store-name-2-password>"
}
```

In order to convert the theme secrets to JSON use the following action: 
```YAML
- name: Convert secrets to JSON
  id: create-json
  uses: jsdaniell/create-json@1.1.2
  with:
    name: "theme.json"
    json: ${{ secrets.THEME_CONFIG_JSON }}
```

Combining above two with generating environment variables, the complete workflow would look like: 

```YAML
name: Deploy theme

on:
  pull_request:
    types:
      - opened
      - edited
      - synchronize
  push:
    branches:
      - main 
    tags:
      - "*" 
          
jobs:
  deploy-theme:
    runs-on: ubuntu-latest
    outputs:
      preview-link: ${{ steps.theme-deploy.outputs.preview-link }} # theme preview links, used to append PR description
      theme_id: ${{ steps.theme-deploy.outputs.theme_id }}
    steps:
        - name: Checkout
          uses: actions/checkout@v2

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

        - name: Get run id
          if: ${{ github.event_name == 'pull_request' &&  github.event.action == 'opened'}}
          run: echo "RUN_ID=1" >> $GITHUB_ENV  

        - name: Convert secrets to JSON
          id: create-json
          uses: jsdaniell/create-json@1.1.2
          with:
            name: "theme.json"
            json: ${{ secrets.THEME_CONFIG_JSON }}
            
        - name: Deploy theme
          id: theme-deploy
          uses: SatelCreative/satel-shopify-theme-deployment@1.0.0
          with: 
            store-name: '<store-name(s)>'  
            theme-env: '<environment>'
            copy-settings: true
            main-theme-id: '<theme-id(s)>' 
            repo-name: ${{ env.REPO_NAME }} 
            github-token: ${{ secrets.GITHUB_TOKEN }}
            shopify-api-version: '<stable-shopify-api-version>'
            theme-files-location: <folder-for-theme-files> 
            current-branch-name: ${{ env.BRANCH_NAME }}
            tag-name: ${{ env.TAG_NAME }} 
            org-name: '<github-organization-name>'
            run-id: ${{ env.RUN_ID }} 

  preview-link:
    runs-on: self-hosted
    needs: deploy-theme
    steps:
      - name: Add links in PR description
        if: "${{ github.ref != 'refs/heads/main' && github.ref != 'refs/heads/tags' }}"
        uses: myposter-de/update-pr-description-async-action@1.2.11
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          prDescAppend: "${{ needs.deploy-theme.outputs.preview-link }}"
          isTicketUpdate: false #true, for set jira link on           
```            
