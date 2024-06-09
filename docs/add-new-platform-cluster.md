# How to add a new platform cluster

Assuming you have forked the kuberise repository into your github account and then cloned that repository in your local computer, follow these instructions to add a new platform to your environment:

- Choose a name for your platform like `PlatformName`
- Clone the forked repository and create a value file in app-of-apps folder with the name of `values-PlatformName.yaml` (In this file you can define which tools you want to install in your platform. This file will override default values.yaml file in that folder. You can copy current values-local.yaml file `cp ./app-of-apps/values-local.yaml ./app-of-apps/values-PlatformName.yaml`)
- In values folder create a new folder (or copy local sample folder) and call it `PlatformName`. This is the folder for values for each tool that you install in your platform. For each tool that you install there should be a folder with the same name and values.yaml inside that folder. (`cp -r ./values/local ./values/PlatformName`)
- Commit and push changes to your repository.
- Choose admin password and also postgresql super admin password

```sh
export repoURL=https://github.com/[yourUserName]/kuberise.git
export PLATFORM=platformName
export REVISION=main

git clone $repoURL
cd kuberise

export CONTEXT=$(kubectl config current-context)
export ADMIN_PASSWORD=admin
export PG_SUPERUSER_PASSWORD=superpassword
export PG_APP_PASSWORD=apppassword
./scripts/install.sh $CONTEXT $PLATFORM $repoURL $REVISION
```

## Private Repository

You can clone the kuberise repository and push it to your private repository. In that case you need to add a token to your Github account at the end of the installation command:

```sh
export repoURL=https://github.com/[yourUserName]/kuberise.git
export PLATFORM=platformName
export TOKEN=[your git repo token]
export REVISION=main
git clone $repoURL
cd kuberise

export CONTEXT=$(kubectl config current-context)
export ADMIN_PASSWORD=admin
export PG_SUPERUSER_PASSWORD=superpassword
export PG_APP_PASSWORD=apppassword
./scripts/install.sh $CONTEXT $PLATFORM $repoURL $REVISION $TOKEN
```

REVISION can be branch name, or tag, or commit SHA
