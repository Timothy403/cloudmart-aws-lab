#!/bin/bash
set -e

source ../resources.env

AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-*-x86_64" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text)

cat > user-data.sh <<EOF
#!/bin/bash
dnf update -y
dnf install -y nginx mariadb105
systemctl start nginx
systemctl enable nginx

cat > /usr/share/nginx/html/index.html <<HTML
<html>
  <body>
    <h1>Welcome to CloudMart</h1>
    <p>Server: \$(hostname -f)</p>
    <p>S3 bucket: ${BUCKET_NAME}</p>
    <p>DB endpoint: ${RDS_ENDPOINT}</p>
  </body>
</html>
HTML

mysql -h ${RDS_ENDPOINT} -u admin -p${DB_PASSWORD} -e "SHOW DATABASES;" > /tmp/db-test.log 2>&1 || true
EOF

cat > launch-template.json <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.micro",
  "IamInstanceProfile": { "Name": "$INSTANCE_PROFILE" },
  "SecurityGroupIds": ["$WEB_SG"],
  "UserData": "$(base64 -w 0 user-data.sh)",
  "TagSpecifications": [
    { "ResourceType": "instance", "Tags": [{ "Key": "Name", "Value": "cloudmart-web" }] }
  ]
}
EOF

aws ec2 create-launch-template --launch-template-name cloudmart-web-template-$SUFFIX --launch-template-data file://launch-template.json

cat >> ../resources.env <<EOF
AMI_ID=$AMI_ID
EOF
