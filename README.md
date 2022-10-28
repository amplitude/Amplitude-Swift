<p align="center">
  <a href="https://amplitude.com" target="_blank" align="center">
    <img src="https://static.amplitude.com/lightning/46c85bfd91905de8047f1ee65c7c93d6fa9ee6ea/static/media/amplitude-logo-with-text.4fb9e463.svg" width="280">
  </a>
  <br />
</p>

# Amplitude-{LanguageName}

This is Amplitude's latest version of the {LanguageName} SDK.

## Need Help?
If you have any issues using our SDK, feel free to [create a GitHub issue](https://github.com/amplitude/Amplitude-SDK-Template/issues/new) or submit a request on [Amplitude Help](https://help.amplitude.com/hc/en-us/requests/new).


# Template Usage

## Creating a new repository 
- Go to [create a new repo page](https://github.com/organizations/amplitude/repositories/new)
- Name your repository as Amplitude-{language} (example: Amplitude-TypeScript)
- Provide a description like “{Language} Amplitude Analytics SDK”
- Specify Internal as the type of repository. We will make it Public later
- Add a README.md file
- Use the suggested .gitignore template for the language you are using

## Securing the repository 
- Go to the Settings page in your repository
- Go to Branches
- Add a branch protection rule called “main” for the main branch
  - Check “Require a pull request before merging”
  - Check “Require approvals”
  - Check “Dismiss stale pull request approvals when new commits are pushed”
  - If there are any status checks, check “Require status checks to pass before merging”

## Adding team members 
- Go to Settings page in your repository
- Go to Collaborators and teams
- In Manage Access section, click on Add teams
- Search by the name of the team, and click Add teams  

## Applying templates
- Clone the new repository
- Create a branch (You do not have to preface the branch name with the JIRA ticket number)
- Create .github/pull_request_template.md using this template
- Create a .github/ISSUE_TEMPLATE folder with the following files
- Add a LICENSE file
- Edit the README.md as necessary
- Create a PR with these files and have someone review (This makes sure we have the proper branch protection rules)