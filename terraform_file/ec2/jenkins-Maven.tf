provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "Maven_Hosted_Instance" {
  ami                     = "ami-0601422bf6afa8ac3"
  instance_type           = "t2.micro"
  key_name                = "mykeypair"
  vpc_security_group_ids  = [ aws_security_group.jenkins_sg.id ]
  user_data = <<-EOF
#!/bin/bash

# Userdata script for Ubuntu 24.04 AWS VM
# Attach a role to this Server with IAM policy as --> AmazonEC2ReadOnlyAccess

# ----------------------------------------
# Install Jenkins
# ----------------------------------------
sudo su
sudo apt-get update -y && apt-get upgrade -y
sudo apt-get install -y curl unzip gnupg fontconfig openjdk-17-jre
sudo apt-get install -y openjdk-11-jdk
sudo curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | tee \
/usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian binary/ | \
tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
sudo systemctl enable jenkins
sudo systemctl start jenkins

# ----------------------------------------
# Change The Java Version to JAVA11
# ----------------------------------------
# Find the path of Java 11
#JAVA11_PATH=$(update-alternatives --list java | grep "java-11")
# Set Java 11 as the default
#update-alternatives --set java "$JAVA11_PATH"
#update-alternatives --set javac "$(dirname $JAVA11_PATH)/javac"

# ----------------------------------------
# Installing Apache Maven
# ----------------------------------------
sudo apt-get install maven -y
mvn -v

# ----------------------------------------
# Install and Configure Ansible
# ----------------------------------------
# Create ansible user with sudo privileges
# sudo useradd -m -s /bin/bash ansible
sudo useradd ansible -m 
echo 'ansible:ansible' | sudo chpasswd
sudo usermod -aG sudo ansible

# Give user Authorization | Without Needing Password
sudo EDITOR='tee -a' visudo << 'EOF'
ansible ALL=(ALL) NOPASSWD:ALL
EOF

# Update the sshd_config Authentication file (Password and SSH)
sudo sed -i 's@^#\?PasswordAuthentication .*@PasswordAuthentication yes@' /etc/ssh/sshd_config
sudo sed -i '/^PasswordAuthentication yes/a ChallengeResponseAuthentication yes' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Update system packages
sudo apt update && sudo apt upgrade -y
# Install the necessary software-properties-common package:
sudo apt install -y software-properties-common
# Add the Ansible PPA (Personal Package Archive) to your system:
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible using apt:
sudo apt update -y
sudo apt install -y ansible
# Verify Ansible installation
ansible --version

# Update the ansible config file
sudo tee -a /etc/ansible/ansible.cfg > /dev/null <<EOF
[defaults]
inventory = /etc/ansible/hosts
remote_user = ansible
host_key_checking = False
EOF

## Configure MAVEN_HOME and PATH Environment Variables
rm .bash_profile
wget https://raw.githubusercontent.com/tdolivierth7/jenkins-master-client-config/refs/heads/main/.bash_profile
source .bash_profile
mvn -v

# Create ".m2" and download your "settings.xml" file into it to Authorize Maven
## Make sure to Update the RAW GITHUB Link to your "settings.xml" config
mkdir /var/lib/jenkins/.m2
wget https://raw.githubusercontent.com/AstridFOPA/jenkins-maven-sonarqube-nexus/refs/heads/main/settings.xml -P /var/lib/jenkins/.m2/
chown -R jenkins:jenkins /var/lib/jenkins/.m2/
chown -R jenkins:jenkins /var/lib/jenkins/.m2/settings.xml

# ----------------------------------------
# Installing Git
# ----------------------------------------
sudo apt install git -y 
  tags = {
    Name = "Maven_Hosted_Instance"
    Env = "dev"
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Security group for Jenkins server"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
