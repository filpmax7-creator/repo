#!/bin/bash
cd /var/jb/var/mobile/myrepo

# 1. إنشاء الفهرس الأساسي
dpkg-scanpackages -m . /dev/null > Packages

# 2. إضافة روابط العرض الأصلية تلقائياً
echo "Depiction: https://filpmax7-creator.github.io/repo/index.html" >> Packages
echo "SileoDepiction: https://filpmax7-creator.github.io/repo/sileo.json" >> Packages

# 3. تحديث ضغط الفهارس لـ Sileo
bzip2 -f -k Packages
gzip -f -k Packages

# 4. الرفع التلقائي
git add .
git commit -m "Auto update repository index"
git push origin main
