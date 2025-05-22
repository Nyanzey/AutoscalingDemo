#!/bin/bash
sudo yum update -y
sudo yum install -y httpd stress
echo "<h1>Hola desde $(hostname)</h1>" > /var/www/html/index.html
sudo systemctl start httpd
sudo systemctl enable httpd

# Para simular carga CPU
# stress --cpu 1 --timeout 600 &