# Github to Jira

This is a simple script that will migrate our backlog and icebox issues over to Jira.

It will go through each Github issue found by searching the repo using the filters you define and
create a corresponding ticket on JIRA.  After creating the new JIRA ticket from the Github ticket,
the Github ticket will be close with a comment linking to the new JIRA ticket.  Additionally, the
contents of the Github ticket will be carried over to the JIRA ticket and converted to Confluence
syntax automatically.

This script is safe to run multiple times so long as the name of the tickets in JIRA hasn't changed since the migration.

## Settings

Right now the settings are jankily in the ``app.rb`` file.  You can update
those variables to your liking and do `docker build -t gh .` to build the container.

### Github Config

* ``GITHUB_USER`` - Your github username
* ``GITHUB_TOKEN`` - Your Github personal access token
* ``GITHUB_REPO`` - The Github repo to pull issues from (e.g "DramaFever/www")
* ``GITHUB_ISSUE_LIST`` - A list of ticket numbers.  If populated search will not occur and only the GH tickets listed will be migrated
* ``GITHUB_SEARCH_FILTERS`` - - A hash of filters to apply when searching the repo.  Supported filters: https://developer.github.com/v3/issues/#list-issues-for-a-repository

#### Generating Github Personal Token

To generate a Github personal token head over to https://github.com/settings/tokens

This is preferred over using your password since you can limit the scope of what the token
has access to, and it doesn't require you to constantly interact with your 2FA provider.

1. Click the "Generate New Token" button, and give it a descriptive name.

2. Select the top level "repo" and "user" scope checkboxes.

3. Click the "Generate Token" button at the bottom of the page

4. You new access token will be generate.  Make sure you copy down the 40 character string because you *cannot* recover it after it's been generated

5. Now, with the new token in hand, add the token to the ``app.rb`` file as your ``GITHUB_PASSWORD``.


### ZenHub Config

* ``ZENHUB_USE_API`` - Boolean.  If true we'll try to pull story points from ZH
* ``ZENHUB_API_TOKEN`` - The ZenHub API token

#### Generating a Personal Token

1. Navigate to here: https://dashboard.zenhub.io/#/settings

2. Click the ``Generate a new token`` button.  Make sure you copy down the 40 character string because you *cannot* recover it after it's been generated.

3. Past the token into the ``app.rb`` file as the ``ZENHUB_API_TOKEN``.


### JIRA Config

* ``JIRA_USER`` - Your JIRA username (e.g. dant@example.com)
* ``JIRA_PASSWORD`` -  Your JIRA password (e.g "itsNahtATumor")
* ``JIRA_PROJECT_NAME`` -  The JIRA project name (e.g. PLAT or DC)
* ``JIRA_COMPNENTS_NAMES`` -  The list of compnents to add to the newly minted tickets (e.g. ["Backend", "Platform"])
* ``JIRA_STORY_NAME`` -  The name of the issue type to create, e.g "Story" or "Epic"
* ``JIRA_ESTIMATE_FIELD_NAME`` -  The name of the story point custom field, defaults to "Story_Point".  YMMV in changing this
* ``JIRA_SITE`` -  The JIRA backend side

## Running the Script

Running ``make run`` in your terminal will build and launch the script.
