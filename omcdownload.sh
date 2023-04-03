VER=$1
pushd $HOME/bin >/dev/null
pushd /tmp >/dev/null
wget -q -e robots=off -r -nH --cut-dirs=3 --no-parent --reject="index.html*,latest" https://github.com/gmeghnag/omc/releases/
[ "$VER" = "" ] && echo "usage:  $0 <tag_version=latest|2.3.1|2.4.0>" >&2 && echo && echo "Tag versions available:" && ls tag | sort | cut -c 2- && exit 1
if [ "$VER" = "latest" ]; then
  VER=$(ls tag | sort | tail -1 | cut -c 2-)
fi
URL="https://github.com/gmeghnag/omc/releases/download/v${VER}/omc_Linux_x86_64"
popd >/dev/null
wget $URL
mv omc_Linux_x86_64 omc
chmod 755 omc
popd >/dev/null

