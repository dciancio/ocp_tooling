## Installation

- Clone this git repo to your host.

- Copy the files to a directory, which should be included in your `$PATH`.

- Ensure the scripts are executable as follows:
  `chmod +x *.sh`

## Executing shell scripts

- The following scripts will execute against the current working directory. Ensure that you change to the correct directory prior to executing them.
```
ocp4download.sh       -> Download a version of OCP client and installer into current directory
ocp4install.sh        -> Install OCP, optionally performing the installation at different stages, create-manifests, etc.
ocp4uninstall.sh      -> Destroy an OCP cluster
omcdownload.sh        -> Download OMC tool for analyzing must-gathers
```

- Each script will have a usage explaining the options to use when executing them.


## Quickly switching between oc environments

- Include the contents of the `oc_rc` environment script by source it directly from your existing `$HOME/.bashrc`

- Ensure that you copy the `auth` sub-directory containing the admin `KUBECONFIG` file for each OCP cluster to your workstation under a separate directory, for example, `$HOME/cluster-<mycluster>`.

- Also, use the `ocp4download.sh` to download the `oc`, `kubectl`, and `openshift-install` binaries for the version of the cluster found in the `CLUSTERPATH` directory, `$HOME/cluster-<mycluster>`. Make sure to execute `ocp4download.sh` script from within the `$HOME/cluster-<mycluster>` directory to ensure that the binaries get downloaded there as the `CLUSTERPATH` containing the binaries will get included in the environment's `PATH`.

- Modify the `oc_rc` script to include an alias for every cluster you wish to switch to ensuring that the `CLUSTERNAME` variable represents the unique OCP clustername. In my example, the `CLUSTERNAME` is `mycluster`.  The alias should also have the correct `CLUSTERPATH` pointing to the location containing the cluster's OCP client and installation files.

- The prompt will automatically be changed to include the current `CLUSTERNAME` and `PROJECT` that you are switched to.

- The original admin `KUBECONFIG` authentication file found in `$HOME/cluster-mycluster` is copied under a temporary `KUBECONFIG` file in `/tmp` for your current `SESSIONID`. Therefore, the default `$HOME/.kube/config` file is never modified.  This ensures isolation for each terminal session into its own unique `KUBECONFIG` file.

- You can optionally choose to login using kubeadmin or any other user relying on Oauth service and the temporary `KUBECONFIG` in `/tmp` will contain additional contexts reflecting each user login.

