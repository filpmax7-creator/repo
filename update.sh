#!/bin/bash

# ضبط مسارات بيئة الجلبريك Rootless
export PATH="/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/local/bin:$PATH"

# زيادة ذاكرة التخزين المؤقت للرفع لتفادي خطأ HTTP 400 مع الملفات الكبيرة
git config http.postBuffer 524288000
git config http.maxRequestBuffer 100M

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}    محدث مستودع الأدوات التلقائي     ${NC}"
echo -e "${BLUE}=====================================${NC}"

DEB_COUNT=$(find . -maxdepth 1 -name "*.deb" | wc -l | tr -d ' ')

if [ "$DEB_COUNT" -eq 0 ]; then
  echo -e "${RED}تنبيه: لم يتم العثور على أي ملفات .deb داخل المجلد!${NC}"
  exit 1
fi

echo -e "${YELLOW}تم العثور على (${DEB_COUNT}) أدوات .deb:${NC}"
find . -maxdepth 1 -name "*.deb" -exec basename {} \; | sed 's/^/  - /'

echo -e "\n${GREEN}[1/3] تحديث الفهرس مع أدوات .deb...${NC}"
dpkg-scanpackages -m . /dev/null > Packages

echo -e "${GREEN}[2/3] إعادة ضغط ملفات الفهرس...${NC}"
bzip2 -f -k Packages
gzip -f -k Packages

echo -e "${GREEN}[3/3] المزامنة والرفع المباشر إلى GitHub...${NC}"
git add .
git commit -m "Auto update repo: ($DEB_COUNT packages)"
git push -f origin main || git push -f origin master

if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}=====================================${NC}"
  echo -e "${GREEN}  تم التحديث والرفع بنجاح 100%!       ${NC}"
  echo -e "${GREEN}  افتح Sileo واعمل Refresh للمصادر.  ${NC}"
  echo -e "${GREEN}=====================================${NC}"
else
  echo -e "\n${RED}خطأ: حدثت مشكلة أثناء الرفع إلى GitHub.${NC}"
fi
