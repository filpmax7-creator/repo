#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}    محدث مستودع الأدوات (myrepo)     ${NC}"
echo -e "${BLUE}=====================================${NC}"

DEB_COUNT=$(find . -maxdepth 1 -name "*.deb" | wc -l | tr -d ' ')

if [ "$DEB_COUNT" -eq 0 ]; then
  echo -e "${RED}تنبيه: لم يتم العثور على أي ملفات .deb!${NC}"
  exit 1
fi

echo -e "${YELLOW}تم العثور على (${DEB_COUNT}) أداة/أدوات .deb:${NC}"
find . -maxdepth 1 -name "*.deb" -exec basename {} \; | sed 's/^/  - /'

echo ""
read -p "هل تريد الاستمرار وتحديث الريبو والرفع إلى GitHub؟ (y/n): " CONFIRM
case "$CONFIRM" in
  [yY][eE][sS]|[yY])
    echo -e "${GREEN}جاري البدء في التحديث...${NC}"
    ;;
  *)
    echo -e "${RED}تم إلغاء العملية.${NC}"
    exit 0
    ;;
esac

echo -e "${BLUE}[1/3] تحديث ملف Packages...${NC}"
dpkg-scanpackages -m . /dev/null > Packages

echo -e "${BLUE}[2/3] إعادة ضغط الفهرس...${NC}"
bzip2 -f -k Packages
gzip -f -k Packages

echo -e "${BLUE}[3/3] رفع التغييرات إلى GitHub...${NC}"
git add .
git commit -m "Update repo ($DEB_COUNT packages)"
git push origin main || git push origin master

if [ $? -eq 0 ]; then
  echo -e "${GREEN}==> تم التحديث والرفع بنجاح! قم بعمل Refresh داخل Sileo الآن.${NC}"
else
  echo -e "${RED}خطأ: فشلت عملية الرفع إلى GitHub.${NC}"
fi
