## Installation

- Clone this git repo to your host.

- Copy the files to a directory, which should be included in your `$PATH`.

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

- Include the contents of the `oc_rc` environment script by source it directly from your existing `$HOME/.bashrc`

- Ensure that you copy the `auth` sub-directory containing the admin `KUBECONFIG` file for each OCP cluster to your workstation under a separate `$HOME/cluster-<mycluster>` directory.

- Also, use the `ocp4download.sh` to download the `oc`, `kubectl`, and `openshift-install` binaries for the version of the cluster found in the `$HOME/cluster-<mycluster>` directory. Make sure to run `ocp4download.sh` script from within the `$HOME/cluster-<mycluster>` directory to ensure that the binaries downloaded are specific to the cluster version found there.

- Modify the `oc_rc` script to include an alias for every cluster you wish to switch to ensuring that `CLUSTERNAME` variable represents the unique OCP clustername. In my example, the `CLUSTERNAME` is `mycluster`.

- The prompt will automatically be changed to include the current `CLUSTERNAME` that you are switched to.

- The original admin `KUBECONFIG` authentication file found in `$HOME/cluster-mycluster` is copied under a temporary `KUBECONFIG` file in `/tmp` for your current `SESSIONID`. Therefore, the default `$HOME/.kube/config` file is never modified.

- You can optionally choose to login using kubeadmin or any other user relying on Oauth service and the temporary `KUBECONFIG` in `/tmp` will contain additional contexts reflecting each user login.

