#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x

# Install Apache, PHP, stress
yum update -y
sudo amazon-linux-extras install epel
yum install -y httpd php stress

# Create the control web page
cat << 'EOPHP' > /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Load Generator</title>
</head>
<body>
    <h1>Load Generator Control - $(hostname)</h1>
    <form method="post">
        <button name="action" value="start">Start Load</button>
        <button name="action" value="stop">Stop Load</button>
    </form>
    <pre>
<?php
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $action = $_POST["action"];
    if ($action === "start") {
        exec("stress --cpu 1 --timeout 600 &");
        echo "Started load with stress";
    } elseif ($action === "stop") {
        exec("pkill stress");
        echo "Stopped load";
    }
}
?>
    </pre>
</body>
</html>
EOPHP

# Start and enable Apache
systemctl start httpd
systemctl enable httpd