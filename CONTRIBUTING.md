# Development Workflow

## Resources
* [Git Workflow Presentation](https://docs.google.com/presentation/d/1euOiki_e4OQ4jymGhS-o3xcET8-KZhDONUolDlOVT30/edit?usp=sharing)
* [git extensions gem](https://github.com/wireframe/gitx)

## Step 1:  Create feature branch...

```bash
$ git start my-feature-branch
```

* The `start` command ensures your branch name is valid and your codebase is uptodate.
* Use a descriptive branch name to help other developers (ex: fix-login-screen, api-refactor, payment-reconcile, etc)

## Step 2: Implement the requested change...
Use [Test Driven Development](http://en.wikipedia.org/wiki/Test-driven_development) to ensure that the feature has proper code coverage.

* **RED** - Write tests for the desired behavior...
* **GREEN** - Write just enough code to get the tests to pass...
* **REFACTOR** - Cleanup for clarity and DRY-ness...


### Development Protips&trade;
* Follow [best practices](http://robots.thoughtbot.com/post/48933156625/5-useful-tips-for-a-better-commit-message) for git commit messages to communicate your changes.
* Add [ticket references to commits to automatically trigger product management workflows](http://help.sprint.ly/knowledgebase/articles/108139-available-scm-vcs-commands)
* Only write the **minimal** amount of code necessary to accomplish the given task.
* Ensure branch stays up-to-date with latest changes that are merged into main by using: `$ git update`
* Changes that are not directly related to the current feature should be cherry-picked into their own branch and merged separately.

### Testing Protips&trade;
* Every line of code should have associated unit tests.  If it's not tested, it's probably broken and you just don't know it yet...
* Use [BetterSpecs.org](http://betterspecs.org/) as reference for writing readable and maintainable unit tests.


## Step 3: Peer Review (aka Pull Request)...

```
$ git review
```

* Describe high level overview of the branch in pull request description.  Include links to relevant resources.
* Record **artifacts** created by this feature (ex: screenshots of UI changes, screencasts of UX changes, logs from database migrations, etc)
* Document **follow-up** items/tasks that need to be addressed post-release

### Questions to ask...
* Is there a simpler way to accomplish the task at hand?
* Are we solving the problems of today and not over engineering for the problems of tomorrow?

## Step 4: QA

> With great power comes great responsibility…

* You are responsible to test your changes locally and in production environments as necessary
* Test changes in local development environment using the same process used by Continuous Integration with: `$ rake ci`
* Smoketest all changes locally and in staging environment when appropriate with: `$ git integrate staging`

## Step 5: Sign-off and release

```
$ git release
```

* Ensure that build is green before releasing branch
* Pull requests must be signed off by team leads before release (preferrably via :shipit: emoji)

## Step 5: Profit?
