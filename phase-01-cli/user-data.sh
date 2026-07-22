#!/bin/bash
dnf update -y
dnf install -y nginx mariadb105
systemctl start nginx
systemctl enable nginx

cat > /usr/share/nginx/html/index.html <<HTML
<html>
  <body>
    <h1>Welcome to CloudMart</h1>
    <p>Server: $(hostname -f)</p>
    <p>S3 bucket: cloudmart-static-1784747861</p>
    <p>DB endpoint: cloudmart-db-1784747861.ctyckmuyaw4j.eu-west-2.rds.amazonaws.com</p>
  </body>
</html>
HTML

for i in {1..30}; do
  mysql -h cloudmart-db-1784747861.ctyckmuyaw4j.eu-west-2.rds.amazonaws.com -u admin -pglG2kPlramaWUM7g1FfTgJtlOtfPRt4+ -e "SHOW DATABASES;" > /tmp/db-test.log 2>&1
  if [ $? -eq 0 ]; then
    echo "Database connection successful" >> /tmp/db-test.log
    break
  fi
  echo "Retry $i: waiting for database..." >> /tmp/db-test.log
  sleep 30
done
