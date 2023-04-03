OPTION=$1
if [ "$OPTION" != "ic" ] && [ "$OPTION" != "man" ] && [ "$OPTION" != "ign" ] && [ "$OPTION" != "cl" ]; then
  echo "usage:  $0 <option=ic|man|ign|cl" >&2
  exit 1
fi

[ ! -f openshift-install ] && { echo "Download binaries to current directory using ocp4download.sh" >&2; exit 1; }

[ "$OPTION" = "ic" ] && openshift-install create install-config --dir . --log-level info
[ "$OPTION" = "man" ] && openshift-install create manifests --dir . --log-level info
[ "$OPTION" = "ign" ] && openshift-install create ignition-configs --dir . --log-level info
[ "$OPTION" = "cl" ] && openshift-install create cluster --dir . --log-level info

