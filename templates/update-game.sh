#!/bin/bash

green="\e[32m"
default="\e[0m"
red="\e[31m"

steamuser="{{ steam_user }}"
steampass="{{ steam_password }}"
appid="{{ steam_appid }}"
branchname="{{ steam_branch }}"
steam=~/steam/steamcmd.sh

appmanifestfile=$(find ~/game -type f -name "appmanifest_${appid}.acf")
currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)

set -e

# Remove cache.
rm --force -v ~/steam/appcache/appinfo.vdf

echo -e "Checking Steam Application version..."
availablebuild=$(${steam} +login "${steamuser}" "${steampass}" +app_info_update 1 +app_info_print "${appid}" +quit | sed '1,/branches/d' | sed "1,/${branchname}/d" | grep -m 1 buildid | tr -cd '[:digit:]')


if [ "${currentbuild}" != "${availablebuild}" ]; then
	echo -e "Update available:"
	echo -e "	Current build: ${red}${currentbuild}${default}"
	echo -e "	Available build: ${green}${availablebuild}${default}"
	echo -e "	https://steamdb.info/app/${appid}/"
	echo -e "Updating..."
	${steam} +login "${steamuser}" "${steampass}" +@sSteamCmdForcePlatformType windows +force_install_dir ~/game +app_info_update 1 +app_update "${appid}" -beta "${branchname}" validate +quit
else
	echo -e "No update available:"
	echo -e "	Current version: ${green}${currentbuild}${default}"
	echo -e "	Available version: ${green}${availablebuild}${default}"
	echo -e "	https://steamdb.info/app/${appid}/"
fi

pushd ~/resources

# Clean the resources repo.
git fetch
git reset --hard origin/master
git clean -d -f
git submodule update

echo "Martian start"
martian update --input ~/game/rocketstation_Data/StreamingAssets/
echo "Martian end"

find . -name "english*.xml" -type f -print0 | xargs -0 dos2unix
updateversion=$(grep -Po 'UPDATEVERSION=Update \S+' ~/game/rocketstation_Data/StreamingAssets/version.ini | sed -e "s/^UPDATEVERSION=Update //")
echo "${updateversion}" > version.txt
find . -type f -name "english*.xml" -exec sha256sum "{}" \; > hash.txt

echo -e "Update ${updateversion}"
if [[ `git status --porcelain` ]]; then
  git config user.email "stationeers@gortc.io"
  git config user.name "Stationeers Bot"
  git add version.txt hash.txt
  git ls-files . | grep '\.xml$' | grep english --null | tr '\n' '\0' | xargs -0 -n1 git add
  git ls-files --others . | grep '\.xml$' | grep english --null | tr '\n' '\0' | xargs -0 -n1 git add
  git commit -m "automated update to ${updateversion}"
  git push origin master
else
  echo -e "No changes detected"
fi

popd

echo -e "Done."
