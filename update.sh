#!/bin/bash
cd /var/jb/var/mobile/myrepo
dpkg-scanpackages -m . /dev/null > Packages
echo "SileoDepiction: https://filpmax7-creator.github.io/repo/sileo.json" >> Packages
bzip2 -f -k Packages
gzip -f -k Packages
git add .
git commit -m "Auto update repo"
git push origin main
