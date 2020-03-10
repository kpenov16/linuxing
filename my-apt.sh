#!/bin/bash

read -p 'Enter package name: ' package

read -p 'Enter s to install from source or p from dpkg/rpm: ' source

read -p 'Enter the download link: ' downloadLink

echo package: $package, source: $source, downloadLink: $downloadLink

## nmap .deb link
# http://ftp.dk.debian.org/debian/pool/main/n/nmap/nmap_7.70+dfsg1-6_i386.deb 

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
  # $(tar -C "$inst_path/" -xjf ${downloadLink##*/} ) #-xzf for .gz
  $(cd $inst_path ; tar -xjf ${downloadLink##*/} ) 
  # https://www.howtogeek.com/409742/how-to-extract-files-from-a-.tar.gz-or-.tar.bz2-file-on-linux/

  #$("$inst_path/${downloadLink##*/}/./configure") 

  # unzip_path=$(ls -l -d /usr/local/src/*/ | grep $package | head -1) 
  unzip_path=$(ls -l -d /usr/local/src/*/ | grep $package | head -1) 
  echo first unzip_path $unzip_path
  unzip_path=$(echo $unzip_path | rev | cut -d " " -f1 | rev)
  echo second unzip_path $unzip_path
  

  handle_errors(){
    echo running handle_errors 
    if (( $1 <= 1 )); then
       echo done
    else
       echo cónfiguring..     
       er=""
       er=$(cd $unzip_path; echo "" > er_tmp; echo "" > er_fin; ./configure >/dev/null 2> er_tmp; cat er_tmp | awk -F'error:' '{print $2}' > er_fin; cat er_fin  )
       if [[ $er ]]; then 
         ##
	 echo missing libraries are installing..
	 sudo apt-get -y update 2> /dev/null
         for X in $er 
	  do 
	    sudo apt-get -y install $X 2> /dev/null
         # $(cd $unzip_path;
	 #     echo "" > o ; 
	 #     apt-file list $X > o ;
         #     if [[ -s o ]] ; then sudo apt-get update ; sudo apt-get -y install $X ; else echo "$X is not a package" ; fi )	      
         done  
	 #echo calling handle_errors with 2
	 handle_errors 2  
         ##     
       else 
	 #echo calling handle_errors with 1      
         handle_errors 1 
       fi                
    fi
  }
 
  handle_errors 2
	
  ##do make
  echo executing make in: $unzip_path
  cd $unzip_path && sudo make 
 
  ##do checkinstall
  echo executing checkinstall in: $unzip_path
  cd $unzip_path && sudo checkinstall -y 


#we have a .deb file to install  
else
  pack_name=$(cd $inst_path && ls | grep '\.deb$' | grep $package | head -n1)
  cd $inst_path && mkdir $pack_name
  #pack_name_path="$inst_path/$pack_name"   
  pd=$(cd $inst_path; echo "" > pd_tmp && dpkg-deb -I nmap_7.70+dfsg1-6_i386.deb > pd_tmp && awk -F'Depends:' '{print $2}' pd_tmp)
  
  echo missing libraries are installing..
  sudo apt-get -y update 2> /dev/null
  for X in $pd 
    do 
      sudo apt-get -y install $X 2> /dev/null ; 
  done
  
  echo installing.. $pack_name
  cd $inst_path && sudo dpkg -i $pack_name; #sudo apt-get -y install $pack_name

fi

#Done. The new package has been installed and saved to
# /usr/local/src/nmap-7.80/nmap_7.80-1_amd64.deb
#
# You can remove it from your system anytime using: 
#
#      dpkg -r nmap



# awk -F'error:' '{print $2}' er.txt
# install: sudo apt-get install apt-file
# create local database: sudo apt-file update
# search for file: apt-file search <filename>
# sudo apt-get --purge remove flex
# apt-cache depends package-name 

# https://unix.stackexchange.com/questions/124462/detecting-pattern-at-the-end-of-a-line-with-grep
# https://stackoverflow.com/questions/12137431/test-if-a-command-outputs-an-empty-string
# https://unix.stackexchange.com/questions/3514/how-to-grep-standard-error-stream-stderr
# https://www.cyberciti.biz/faq/linux-list-just-directories-or-directory-names/
# https://how-to.fandom.com/wiki/How_to_untar_a_tar_file_or_gzip-bz2_tar_file
# https://stackoverflow.com/questions/3162385/how-to-split-a-string-in-shell-and-get-the-last-field
# https://www.pluralsight.com/blog/it-ops/linux-file-permissions
# https://linuxize.com/post/how-to-check-if-string-contains-substring-in-bash/
# https://stackoverflow.com/questions/428109/extract-substring-in-bash


#old version
  handle_errors2(){
    echo running handle_errors2 
    if (( $1 <= 1 )); then
       echo called with 1
    else
       echo called with 2     
       er=""
       er=$(cd $unzip_path; echo "" > er_tmp; echo "" > er_fin; ./configure >/dev/null 2> er_tmp; cat er_tmp | awk -F'error:' '{print $2}' > er_fin; cat er_fin  )
       if [[ $er ]]; then 
         ##
	 dep=$(cd $unzip_path; echo "" > d; echo "" > d_fin; sudo apt-cache depends $package > d; cat d | awk -F'Depends:' '{print $2}' > d_fin; cat d_fin )
         echo depend on: $dep
	 for X in $dep 
	  do 
	    sudo apt-get -y install $X	  
	    #$(cd $unzip_path;
	     # echo "" > d_o ; 
	     # apt-file list $X > d_o ;
	     # if [[ -s d_o ]] ; then sudo apt-get -y install $X ; else echo "$X is not a package" ; fi )	      
         done  
	 echo calling handle_errors2 with 2
	 handle_errors2 2  
         ##     
       else 
	 echo calling handle_errors2 with 1      
         handle_errors2 1 
       fi                
    fi
  }

#old stuff

#  er=$(cd $unzip_path; echo "" > er_tmp; echo "" > er_fin; ./configure >/dev/null 2> er_tmp; cat er_tmp | awk -F'error:' '{print $2}' > er_fin; cat er_fin  )
#  if [[ $er ]]; then 
#     # there are errors
#     # we run: auto-apt run ./configure
#     # auto-run should be installed beforehand
#     #
#     for X in $er 
#	do 
#	  $( cd $unzip_path;
#	     echo "" > o ; 
#	     apt-file list $X > o ;
#             if [[ -s o ]] ; then sudo apt-get update ; sudo apt-get -y install $X ; else echo "$X is not a package" ; fi 
#	   ) 
#        done 
#     #
#     #
#     
#  else 
#      echo "no errors" 
#  fi




