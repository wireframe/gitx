[![Build Status](https://travis-ci.org/wireframe/gitx.png?branch=main)](https://travis-ci.org/wireframe/gitx)
[![Code Coverage](https://coveralls.io/repos/wireframe/gitx/badge.png)](https://coveralls.io/r/wireframe/gitx)
[![Code Climate](https://codeclimate.com/github/wireframe/gitx.png)](https://codeclimate.com/github/wireframe/gitx)

# GitX

> Git eXtensions for improved development workflows

These custom scripts are automatically registered into the git namespace
so they are available without learning any new commands!

## Installation

```bash
$ gem install gitx
```

## git start <new_branch_name (optional)>

update local repository with latest upstream changes and create a new feature branch

options:
* `--issue` or `-i` = reference to github issue id this branch is related to

## git update

update the local feature branch with latest remote changes plus upstream released changes.

## git integrate <aggregate_branch_name (optional, default: staging)>

integrate the current feature branch into an aggregate branch (ex: prototype, staging)

## git review <feature_branch_name (optional, default: current_branch)>

create a pull request on github for peer review of the current branch.  This command is re-runnable
in order to re-assign pull requests.

options:
* `--assign` or `-a` = assign pull request to github user
* `--open` or `-o` = open pull request in default web browser.
* `--bump` or `-b` = bump an existing pull request by posting a comment to re-review new changes
* `--approve` = approve/signoff on pull request (with optional feedback)
* `--reject` = reject pull request (with details)

NOTE: the `--bump` option will also update the pull request commit status to mark the branch as 'pending peer review'.
This setting is cleared when a reviewer approves or rejects the pull request.

## git release <feature_branch_name (optional, default: current_branch)

release the feature branch to the base branch (by default, main).  This operation will perform the following:

* pull latest code from remote feature branch
* pull latest code from the base branch (unless `update_from_base_on_release` config is set to `false`)
* prompt user to confirm they actually want to perform the release
* check if pull request commit status is currently successful
* merge current branch into the base branch (or add release label if configured)
* (optional) cleanup merged branches from remote server

options:
* `--cleanup` = automatically cleanup merged branches after release complete

# Extra Utility Git Extensions

## git cleanup

delete released branches after they have been merged into the base branch.

## git nuke <aggregate_branch_name>

reset an aggregate branch (ex: prototype, staging) back to a known good state.

## git buildtag

create a build tag for the current Travis-CI build and push it back to origin

options:
* `--branch` = configure the branch name related to the build tag
* `--message` = configure the git message associated to the tag

## Configuration
Any of the [default settings defined in the gem](lib/gitx/defaults.yml) can be overridden
by creating a custom `.gitx.yml` file in the root directory of your project.

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md)

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Related Projects
* [socialcast-git-extensions](https://github.com/socialcast/socialcast-git-extensions)
* [thegarage-gitx](https://github.com/thegarage/thegarage-gitx)

## Copyright
See [LICENSE.txt](LICENSE.txt)
