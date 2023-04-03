[ ! -f $PWD/openshift-install ] && { echo "Download binaries to current directory using ocp4download.sh" >&2; exit 1; }

[ ! -f $PWD/metadata.json ] && { echo "Missing terraform metadata.json in the current directory" >&2; exit 1; }

pushd $PWD
./openshift-install destroy cluster --dir . --log-level info
popd

