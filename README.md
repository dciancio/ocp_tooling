## Pre-requisites

- Files in this repository should be installed in `$HOME/bin` directory, which should be included in your `$PATH`.

## Installation

- Clone this git repo to your host.

- Copy the files to `$HOME/bin` directory, which should be included in your `$PATH`.

- Ensure the scripts are executable as follows:
  `chmod +x *.sh`

## Executing shell scripts

- The following scripts will execute against the current working directory. Ensure that you change to the correct directory prior to executing them.
```
ocp4download.sh
ocp4install.sh
ocp4uninstall.sh
omcdownload.sh
```

- Each script will have a usage explaining the options to use when executing them.


## Quickly switching between oc environments

- Include the contents of this script or source it from your existing `$HOME/.bashrc`

- Ensure that you copy the `auth` sub-directory containing the admin `KUBECONFIG` file for each cluster to your workstation under `$HOME/cluster-<mycluster>`.

- Also, use the `ocp4download.sh` to download the `oc`, `kubectl`, and `openshift-install` binaries for the version of the cluster found in the `$HOME/cluster-<mycluster>` directory. Make sure to run `ocp4download.sh` script from within the `$HOME/cluster-<mycluster>` directory to ensure that the binaries downloaded are specific to a cluster version.

- Modify the `oc_rc` script to include an alias for every cluster you wish to switch to ensuring that `CLUSTERNAME` variable represents the unique OCP clustername.

- The prompt will automatically include the current `CLUSTERNAME` that you are switched to.

- This script relies on `KUBECONFIG` authentication method and never touches the `$HOME/.kube/config` file.

- It only modifies a copy of the original admin `KUBECONFIG` file used at cluster installation time.

- You can optionally choose to login using kubeadmin or any other user relying on Oauth service and the `KUBECONFIG` will contain additional contexts reflecting this.

