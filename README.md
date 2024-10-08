This is a shell script that does the following:
  - creates tags with an incrementing number. It does not follow the x.x.x pattern because this was unnecessary for the usecase it was created for. It simply creates a new tag named 'deployed-x'
  - early exits with error code 1 if there are unstaged/uncommitted/unpushed changes in the repo. This prevents one from deploying code that only exists locally.
