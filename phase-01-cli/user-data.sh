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
    <p>S3 bucket: cloudmart-static-1784726779</p>
    <p>DB endpoint: None</p>
  </body>
</html>
HTML

mysql -h None -u admin -p5LpBus9E5FKAyS78AcwNLnVEOoZBn6VM -e "SHOW DATABASES;" > /tmp/db-test.log 2>&1 || true
