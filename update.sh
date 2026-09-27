#!/bin/bash
cd /var/jb/var/mobile/myrepo
dpkg-scanpackages -m . /dev/null > Packages
echo "Depiction: https://filpmax7-creator.github.io/repo/index.html" >> Packages
echo "SileoDepiction: https://filpmax7-creator.github.io/repo/sileo.json" >> Packages
bzip2 -f -k Packages
gzip -f -k Packages
git add .
git commit -m "Fix URL paths for GitHub Pages subfolder"
git push origin main
