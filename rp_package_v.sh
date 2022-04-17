#!/bin/bash

clear # to clear the screen
trap ' ' INT TSTP
# Starting notes
echo "###################################################"
echo "******Script for Installing the Desired Stack******"
echo "###################################################"

echo "Please enter the required credentials"

#Taking Input from User
read -p "Enter SSH Username: " username_ssh
read -p "Enter Public IP of the server: " public_ip
read -p "Enter SSH Password: " password_ssh
# read -p "Enter the name of database: " dbname
# read -p "Enter the domain (e.g abc.com): " domainname

# #echo "\n The database username is auto generated i.e. db_name_user e.g your db name is abc then user would be abc_user"

# export ABCXYZ="hello, brother"
# echo $dbname 


nohup sshpass -p $password_ssh ssh $username_ssh@$public_ip < rp_all_commands.sh
