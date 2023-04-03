OCPVER=$1
OCPURL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/$OCPVER"
[ "$OCPVER" = "" ] && echo "usage:  $0 <ocp_tag=4.5.8|candidate-4.5|fast-4.5|latest-4.5|stable-4.5|candidate|fast|latest|stable>" >&2 && exit 1
pushd $PWD
wget $OCPURL/openshift-client-linux.tar.gz
wget $OCPURL/openshift-install-linux.tar.gz
tar xvfz openshift-client-linux.tar.gz
tar xvfz openshift-install-linux.tar.gz
rm -f README.md
rm -f openshift-client-linux.tar.gz*
rm -f openshift-install-linux.tar.gz*
popd

