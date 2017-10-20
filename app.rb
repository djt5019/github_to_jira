require 'jira-ruby'
require 'octokit'
require 'markdown2confluence'


Octokit.auto_paginate = true

# Get a Zenhub token to carry over story points if you want
# https://github.com/ZenHubIO/API#authentication
ZENHUB_USE_API = true
ZENHUB_API_TOKEN = ""

# JIRA Configuration

# Add your useranme here
JIRA_USER =
# Add your JIRA password here.
JIRA_PASSWORD =
# This is the JIRA project ID (e.g. PLAT or DC)
JIRA_PROJECT_NAME =
# If you want components on your issues list their names here, e.g. "Backend"
JIRA_COMPNENTS_NAMES = [""]
# The issue type to create on JIRA. You can change this to any supported issue type in your project
JIRA_ISSUE_TYPE_NAME = 'Story'
# The name of the story points field in JIRA.  I'd recommend not changing this tbh
JIRA_ESTIMATE_FIELD_NAME = "Story_Points"
JIRA_SITE = "https://dramafever.atlassian.net:443/"

# Your github username
GITHUB_USER =
# Your github personal access token (make sure it has the `repo` rights)
GITHUB_TOKEN =
# The repo to pull issues from
GITHUB_REPO =
# If you know the *exact* issues to carry over you can list them here.  It will _only_ carry over those issues and won't perform a search
GITHUB_ISSUE_LIST = []
# Search filters.  You can find the supported fields here: https://developer.github.com/v3/issues/#list-issues-for-a-repository
# NOTE: Search will only happen if the issue list is empty.
GITHUB_SEARCH_FILTERS = {
    "direction"=>"asc",
    #"labels"=>"premium,bug,review",
    "sort"=>"created",
    "state"=>"open",
    #"milestone"=>123
}

GITHUB_EXCLUDE_LABELS = []

### Nothing modified below here

## Jira logic section

jira_client = JIRA::Client.new(
    :username => JIRA_USER,
    :password => JIRA_PASSWORD,
    :site => JIRA_SITE,
    :auth_type => :basic,
    :context_path => ''
)

jira_project = jira_client.Project.find JIRA_PROJECT_NAME
jira_estimate_field = jira_client.Field.map_fields[JIRA_ESTIMATE_FIELD_NAME]
jira_story = jira_project.issuetypes.detect {|t| t.name == JIRA_ISSUE_TYPE_NAME}
jira_epic = jira_project.issuetypes.detect {|t| t.name == 'Epic'}
jira_compnents = []

puts 'Feching JIRA project components'
jira_project.components.each do |component|
    if JIRA_COMPNENTS_NAMES.include? component.name
        jira_compnents << {"id" => component.id}
    end
end
puts "Fetched '#{jira_compnents.size}' JIRA project components"

offset = 0
existing_jira_tickets = {}
puts 'Feching existing JIRA issues'
loop do
    begin
        issues_results = jira_client.Issue.jql(
            "project = #{JIRA_PROJECT_NAME} AND resolution = Unresolved ORDER BY updated DESC",
            max_results: 200,
            start_at: offset
        )
    rescue Exception => e
        puts exc.response.body
        raise e
    end

    break if issues_results.size == 0

    issues_results.each do |i|
        existing_jira_tickets[i.summary] = i.key
    end

    offset += issues_results.size
end


# Github logic section

github_client = Octokit::Client.new(:login => GITHUB_USER, :password=>GITHUB_TOKEN)
github_repo_id = github_client.repo(GITHUB_REPO).id

if GITHUB_ISSUE_LIST.empty?
    github_issues = []
    all_issues = github_client.list_issues(GITHUB_REPO, GITHUB_SEARCH_FILTERS)
    all_issues.each do |issue|
        labels = issue.labels.map {|l| l.name}
        if (labels & GITHUB_EXCLUDE_LABELS).empty?
            github_issues << issue
        end
    end
else
    github_issues = issue_list.each {|number| github_client.issue(GITHUB_REPO, number.to_s)}
end

puts "Fetched '#{github_issues.size}' Github issues"


def get_estimate(zenhub_api_token, github_repo_id, issue_number)
    uri = URI("https://api.zenhub.io/p1/repositories/#{github_repo_id}/issues/#{issue_number}")

    req = Net::HTTP::Get.new(uri)
    req['X-Authentication-Token'] = zenhub_api_token

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl=>true) {|http| http.request(req)}

    if res.is_a?(Net::HTTPSuccess)
        payload = JSON::load res.body
        return payload.fetch('estimate', {}).fetch('value', 0)
    end
end


puts "Beginning Github to JIRA migration"
github_issues.each do |issue|
    begin
        description = "Github Issue: #{issue.html_url}\n\n#{issue.body}"
        description = Kramdown::Document.new(description).to_confluence

        data = {
            "fields" => {
                "project" => {"id" => jira_project.id},
                "summary" => issue.title,
                "description" => description,
                "issuetype"=> {"id" => jira_story.id},
                "components" => jira_compnents,
            }
        }

        if ZENHUB_USE_API
            data["fields"][jira_estimate_field] = get_estimate(ZENHUB_API_TOKEN, github_repo_id, issue.number)
        end

        if existing_jira_tickets.include? issue.title
            ticket_key = existing_jira_tickets[issue.title]
        else
            ticket = jira_client.Issue.build
            ticket.save!(data)
            ticket_key = ticket.key
        end

        url = "https://dramafever.atlassian.net/browse/#{ticket_key}"
        github_client.add_comment(
            GITHUB_REPO,
            issue.number,
            "This issue was migrated [to JIRA as #{ticket_key}](#{url}): #{url}"
        )
        github_client.close_issue(GITHUB_REPO, issue.number)

        puts "Migrated GH-#{issue.number} to JIRA #{ticket_key}"

    rescue Exception => exc
        puts exc.response.body
    end
end

puts "Completed Github to JIRA migration"
