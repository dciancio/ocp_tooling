[ ! -f openshift-install ] && { echo "Download binaries to current directory using ocp4download.sh" >&2; exit 1; }

[ ! -f metadata.json ] && { echo "Missing terraform metadata.json in the current directory" >&2; exit 1; }

openshift-install destroy cluster --dir . --log-level info

