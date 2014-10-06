#!/bin/bash

if [ $UID -ne 0 ]; then
  gksu -l "$0"
  exit
fi

#config
hostDir="/vagrant/sites"
autoDisable=1  #auto disable all other sites that enabled in /etc/apache2/sites-enabled

#disable list
cd /etc/apache2/sites-enabled

disable=$(ls)
disable=${disable//"000-default"}
#add exclusion here, e.g: disable=${disable//site.com}

sitelist="";

echo "sites available:";

cd $hostDir

#get current dirs
dirlist=$(find . -maxdepth 1 -type d)

for direc in $dirlist ; do

  if [ $direc == "." ]; then continue; fi

  sitename=${direc#./}
  sitelist="$sitelist"' '"$sitename"' '"www.$sitename"
  subdmnVH=""
  
  echo "$sitename with subdomains:"

  #find subdomains
  sdlist=$(find "$hostDir"/"$sitename" -maxdepth 1 -mindepth 1 -type d)

  #create main virtual host
  out="<VirtualHost *:80>
    ServerName $sitename
    ServerAlias www.$sitename
    DocumentRoot $hostDir/$sitename
    CustomLog $hostDir/$sitename/access.log combined
    ErrorLog $hostDir/$sitename/error.log
    <Directory \"$hostDir/$sitename\">
      Options FollowSymLinks Includes MultiViews
      AllowOverride All
      Order allow,deny
      Allow from all
      Require all granted
    </Directory>
</VirtualHost>""$subdmnVH"

  #tell apache about it
  echo "$out" > /etc/apache2/sites-available/$sitename.conf;

  #enable if needed
  if [ "${disable//$sitename}" == "$disable" ]
    then a2ensite $sitename.conf
  fi
  disable=${disable//$sitename}

#fi

done


#edit hosts
sed -n '1h;1!H;${;g;s/\n#AVHBEGIN.*#AVHEND//g;p;}' /etc/hosts > hst.tmp
mv -f hst.tmp /etc/hosts
echo '#AVHBEGIN' >> /etc/hosts
echo "127.0.0.1""$sitelist" >> /etc/hosts
echo '#AVHEND' >> /etc/hosts


#disable other
if [ $autoDisable == 1 ]; then
  for dis in $disable ; do
    a2dissite $dis
  done
fi

echo "---------------------------------";
#reload apache
/etc/init.d/apache2 reload

