#!/bin/bash

read -p 'Enter package name: ' package

read -p 'Enter s to install from source or p from dpkg/rpm: ' source

read -p 'Enter the download link: ' downloadLink

echo package: $package, source: $source, downloadLink: $downloadLink

inst_path=/usr/local/src

echo $(ls -ldh $inst_path | cut -d " " -f1) 
gr=$(ls -ldh $inst_path | cut -d " " -f1| cut -c 8-10)

if [[ "$gr" == *"-"* ]]; then
  echo setting others to have +rwx
  sudo chmod o+rwx $inst_path
fi

$(wget -v  $downloadLink -P $inst_path)

if [[ "$source" == *"s"* ]]; then
  echo insalling from source
  echo this is the result: $(echo ${downloadLink##*/})
  echo the path: "$inst_path/${downloadLink##*/}"
  $(tar -C "$inst_path/" -xf ${downloadLink##*/} )

  #$("$inst_path/${downloadLink##*/}/./configure") 

  unzip_path=$(ls -l -d /usr/local/src/*/ | grep $package | head -1) 
  echo first unzip_path $unzip_path
  unzip_path=$(echo $unzip_path | rev | cut -d " " -f1 | rev)
  echo second unzip_path $unzip_path
  
  echo running ./configure
  $(cd $unzip_path; ./configure)
fi

# https://www.cyberciti.biz/faq/linux-list-just-directories-or-directory-names/
# https://how-to.fandom.com/wiki/How_to_untar_a_tar_file_or_gzip-bz2_tar_file
# https://stackoverflow.com/questions/3162385/how-to-split-a-string-in-shell-and-get-the-last-field
# https://www.pluralsight.com/blog/it-ops/linux-file-permissions
# https://linuxize.com/post/how-to-check-if-string-contains-substring-in-bash/
# https://stackoverflow.com/questions/428109/extract-substring-in-bash

