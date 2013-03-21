gamEvolve
=========

Create and modify games using simple concepts. 

Covered under the MIT open source license. All included libraries (see _Dependencies_ below) are covered under their own open source licenses


Development Philosophy
----------------------

Following [Beck's Directive]:

1. Make it work
2. Make it right
3. Make it fast


Our GIT Workflow
----------------

We follow a continuous-deployment process, based on the [GitHub Flow]. All development, new features as well as bug fixes, are done in separate branches (called "feature branches" below), and merged into the master branch via pull request on GitHub.

There are at least 2 parties involved in the process, the one who proposes changes and the one who reviews them.

To propose changes:

1. Clone the repository (requires you to fork it first, if you do not have direct push access)
  * `git clone https://github.com/CyberCRI/gamEvolve.git`
2. Create a (local) feature branch 
  * `git checkout -b MY_BRANCH_NAME`
3. Work on that feature and commit to it
  * `git commit -am "my commit message"`
4. Push that branch to GitHub
  * `git push -u origin MY_BRANCH_NAME`
5. Go to GitHub and create a pull request
6. If further commits are necessary, you can continue to commit and push that branch
7. Once the pull request is accepted, delete the local branch, as well as the reference to the remote one.
  * `git checkout master`
  * `git branch -d MY_BRANCH_NAME`
8. Drink a beer

To review changes:

1. Switch to the remote branch
  * `git fetch origin`
  * `git checkout MY_BRANCH_NAME`
2. Perform a code review (see below). Any comments should be put into the pull request. Changes can be pushed to the feature branch. 
3. Compile
4. Test the feature.
5. Run regression tests (below)
6. If all is well, accept the pull request and delete the remote branch. 
  - Depending on the changes, GitHub may be able to merge automatically. If not, you need to do it yourself:
      * `get checkout master`
      * `git merge MY_BRANCH_NAME`
      * `git push origin master`
7. Deploy! (see below)
8. Drink 2 beers

Some other common commands:

- To return your branch to the version online (possibly losing local commits)
  * `git reset --hard origin/master`
- To list remote branches:
  * `git branch -r`


Compiling
----------

To compile the code, run `cake build` in the platform folder. To have the code continuously compile as files are saved, try `cake watch`.


Documentation
-------------

Documentation is generated using [Docco]. To create it, simply type `cake doc` in the `platform` directory.


Code Review
-----------

The goal of the code review is to:

- Insure the quality of the submission
- Inform others of changes to the project

Code reviewers should check the following things:

- All current regression tests pass
- Regression tests have been updated:
  - New features require new tests
  - Changed features require changed tests
  - Bug fixes should have tests that will find the bug if it sneaks back
- Syntax is harmonious with the rest of the file, if not the rest of the project
  - Syntax should roughly match standard style guides for the language in question, such as the [Coffeescript Style Guide] and the [Javascript Style Guide]
  - Consistency is more important then strict adhesion to the rules


Regression Tests
----------------

Currently only the library portion of the project has automatic tests. GUI tests should be added soon.

To run the automatic tests, make sure the code is compiled, and navigate to `platform/site/tests/` in a web browser. The Jasmine test suite will run and show any failing tests.


Deployment
----------

As part of the continuous deployment process, the master branch should be deployed each time it is pushed to.

Currently, there is not automatic process to deploy. This should be fixed soon.

In the meantime, follow these steps:

1. In a separate directory, checkout the `gh-pages` branch
  * `cd DEPLOY_DIR`
  * `git clone -b gh-pages`
2. Copy everything in the `platform/site` folder to the `gh-pages` branch
3. Commit all changes to the `gh-pages` branch 
  * `commit -am "COMMIT MESSAGE"`
4. Deploy to GitHub
  * `git push origin`


Dependencies
------------

Compiling the project requires the following dependencies:

1. [Node.js] and [NPM]
2. NPM modules:
  - [Coffeescript]
  - [win-spawn]
  - [Docco]


[GitHub Flow]: http://scottchacon.com/2011/08/31/github-flow.html
[Node.js]: http://nodejs.org/
[NPM]: https://npmjs.org/
[Coffeescript]: http://coffeescript.org/
[win-spawn]: https://npmjs.org/package/win-spawn
[Docco]: http://jashkenas.github.com/docco/
[Coffeescript Style Guide]: https://github.com/polarmobile/coffeescript-style-guide
[Javascript Style Guide]: http://google-styleguide.googlecode.com/svn/trunk/javascriptguide.xml#Naming
[Beck's Directive]: http://c2.com/cgi/wiki?MakeItWorkMakeItRightMakeItFast