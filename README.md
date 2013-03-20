gamEvolve
=========

Create and modify games using simple concepts. 

Covered under the MIT open source license.


Our GIT Workflow
----------------

We follow a continuous-deployment process, based on the [GitHub Flow][1]. All development, new features as well as bug fixes, are done in separate branches (called "feature branches" below), and merged into the master branch via pull request on GitHub.

There are at least 2 parties involved in the process, the one who proposes changes and the one who reviews them/

To propose changes:

1. Clone the repository (requires you to fork it first, if you do not have direct pull access)
  * `git clone https://github.com/CyberCRI/gamEvolve.git`
2. Create a feature branch 
  * `git checkout --track origin/MY_BRANCH_NAME` _or_ `git checkout -b MY_BRANCH_NAME origin/MY_BRANCH_NAME`
3. Work on that feature and commit to it
  * `git commit -am "my commit message"
4. Push that branch to GitHub
  * `git push origin MY_BRANCH_NAME`
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
3. Test the feature.
4. If all is well, accept the pull request and delete the remote branch. 
  - Depending on the changes, GitHub may be able to merge automatically. If not, you need to do it yourself:
    * `get checkout master`
    * `git merge MY_BRANCH_NAME`
    * `git push origin master`
4. Deploy! (see below)

Some other common commands:

- To return your branch to the version online (possibly losing local commits)
  * `git reset --hard origin/master`
- To list remote branches:
  * `git branch -r`


Code review
-----------

TODO: 


Deployment
----------

Currently, there is not automatic process to deploy. This should be fixed soon.



Dependencies
------------

Compiling 






[1]: http://scottchacon.com/2011/08/31/github-flow.html