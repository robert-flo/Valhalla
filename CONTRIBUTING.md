# Contributing to Community Standards

Thank you for your interest in contributing to Community Standards! We welcome any contributions, including bug fixes, feature enhancements, documentation improvements, and other general improvements.

## Getting Started

1. Fork this repository to your GitHub account. This will create a copy of this repository in your account. You can make changes to this copy without affecting the original repository.

   - For fork this repository, click the **Fork** button in the top right corner of this page or click [here](https://github.com/HyDE-Project/HyDE/fork).

> [!NOTE]
> For first-time contributors:** All new contributors should start by submitting pull requests. After demonstrating consistent high-quality contributions through PRs, you may be considered for a collaborator role as described in [TEAM_ROLES.md](https://github.com/HyDE-Project/HyDE/blob/master/TEAM_ROLES.md). Direct repository access is granted selectively based on contribution history.

2. Clone your forked repository to your local machine.

   - Use the following command to clone your forked repository to your local machine.

     ```bash
     git clone https://github.com/HyDE-Project/HyDE.git
     ```

   - Enable the repository-owned commit hooks once inside the clone. The shell
     quality gate requires `shfmt` and `shellcheck`, which are included in the
     RaVN core package manifest.

     ```bash
     git config core.hooksPath .git-hooks
     ```

   - When using VS Code, open the repository root. The included workspace
     checks new and modified shell scripts automatically. Use the
     `shellcheck: full audit` task only when you intentionally need to inspect
     inherited scripts as well. Extend the changed-file exclusions in the
     workspace helper and the editor exclusions in the workspace settings when
     a legacy path is intentionally out of scope.

3. Create a new branch for your changes.

   - For example, to create a new branch named `your-branch-name`, use the following command.

     ```bash
     git checkout -b your-branch-name
     ```

4. Make your changes and commit them with a descriptive commit message.

   - For example, to commit your changes, use the following command and make sure to follow the [commit message guidelines](https://github.com/HyDE-Project/HyDE/blob/master/COMMIT_MESSAGE_GUIDELINES.md).

     ```bash
     git commit -m "feat: add a new feature"
     ```

5. Code should be documented where appropriate.

- For internal pull requests, generate the changelog entry locally with
  `.github/scripts/update-pr-changelog.sh`. Provide `PR_NUMBER`, `PR_URL`,
  `PR_TITLE`, and `PR_LABELS`; a leading `<number> - ` title prefix is removed.
- Apply exactly one of
  `changelog:added`, `changelog:changed`, `changelog:fixed`,
  `changelog:removed`, `changelog:security`, or `changelog:deprecated` to
  select the category.
- Apply `changelog:skip` only when the pull request should have no user-facing
  changelog entry, such as documentation-only or test-only work.
- Review the generated entry, run the generator again to verify idempotence,
  run `tests/changelog-automation.sh`, and commit `CHANGELOG.md` before review.
  CI validates this commit but never writes to the pull-request branch.

5.1. **Optional But Recommended: Test with RavnVM** - You can test a RaVN branch or commit in an isolated VM using [RavnVM](Scripts/ravnvm/README.md) before submitting.

6. Push your changes to your forked repository.

   - For example, to push your changes to your forked repository, use the following command.

     ```bash
     git push origin your-branch-name
     ```

7. Submit a **pull request** targeting `master`. Direct commits and pushes to
   `master` are not allowed; every change must be reviewed and validated through
   a pull request as described in [RELEASE_POLICY.md](RELEASE_POLICY.md).
   - For example, to create a pull request, use the following steps.
     1. Go to your forked repository.
     2. Click the **Compare & pull request** button next to your `your-branch-name` branch.
     3. Make sure the base repository branch is set to `master`.
     4. Confirm the repository pre-commit hook passed for every commit. Do not
        run `pre-commit run --all-files` as the normal validation flow: this
        hardfork intentionally validates only the applicable staged files.
     5. Add a title and description for your pull request.
     6. Click **Create pull request** and remember to add the relevant labels with using the [pull request template](https://github.com/HyDE-Project/HyDE/blob/master/.github/PULL_REQUEST_TEMPLATE.md).

## Guidelines

- Follow the code style of the project.
- Update the **documentation** if necessary.
- Add tests if applicable.
- Make sure all tests pass before submitting your changes.
- Keep your pull request focused and avoid including unrelated changes.
- Remember to follow the given files before submitting your changes.
  - [bug_report.md](https://github.com/HyDE-Project/HyDE/blob/master/.github/ISSUE_TEMPLATE/bug_report.md) - Use this template to create a report to help us improve.
  - [feature_request.md](https://github.com/HyDE-Project/HyDE/blob/master/.github/ISSUE_TEMPLATE/feature_request.md) - Use this template to suggest a feature for this project.
  - [documentation_update.md](https://github.com/HyDE-Project/HyDE/blob/master/.github/ISSUE_TEMPLATE/documentation_update.md) - Use this template to propose a change to the documentation.
  - [custom.md](https://github.com/HyDE-Project/HyDE/blob/master/.github/ISSUE_TEMPLATE/custom.md) - Use this template to submit a custom issue.
  - [PULL_REQUEST_TEMPLATE.md](https://github.com/HyDE-Project/HyDE/blob/master/.github/PULL_REQUEST_TEMPLATE.md) - Use this template to submit a pull request.
  - [COMMIT_MESSAGE_GUIDELINES.md](https://github.com/HyDE-Project/HyDE/blob/master/COMMIT_MESSAGE_GUIDELINES.md) - Read this file to learn about the commit message guidelines.
  - [CONTRIBUTING.md](https://github.com/HyDE-Project/HyDE/blob/master/CONTRIBUTING.md) - Read this file to learn about the contributing guidelines.
  - [RELEASE_POLICY.md](https://github.com/HyDE-Project/HyDE/blob/master/RELEASE_POLICY.md) - Read this file to understand the release cycle, branch management, and deployment schedule.
  - [TEAM_ROLES.md](https://github.com/HyDE-Project/HyDE/blob/master/TEAM_ROLES.md) - Learn about the different roles in our project (Collaborators, Triagers, and Testers) and how to join.
  - [LICENSE](https://github.com/HyDE-Project/HyDE/blob/master/LICENSE) - Read this file to learn about the license.
  - [README.md](https://github.com/HyDE-Project/HyDE/blob/master/README.md) - Read this file to learn about the project.

## Contact

If you have any questions, feel free to contact via [GitHub Discussions](https://github.com/HyDE-Project/HyDE/discussions).
