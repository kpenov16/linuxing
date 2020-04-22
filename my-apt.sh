#!/bin/bash

# new
## add user to sudoers 
MY_USER=$(whoami | sed 's/ *$//')  # https://linuxhint.com/trim_string_bash/
                                   # https://stackoverflow.com/questions/3953645/ternary-operator-in-bash
if [ "$MY_USER" != "root" ]; then
  echo -ne "adding $MY_USER to sudoers"
  echo "$MY_USER  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$MY_USER stdout> /dev/null # https://linuxize.com/post/how-to-add-user-to-sudoers-in-ubuntu/  
  sudo chmod 0440 /etc/sudoers.d/$MY_USER 
  echo "$MY_USER added to sudoers"
fi

## we need the package name
read -p 'Enter package name: ' PACKAGE #promp the user and reads a line with the user input from stdin

## we need to know id we are going to install from source or from .deb package
read -p 'Enter s to install from source or p from dpkg/rpm: ' SOURCE

## we need the link to the source/package
read -p 'Enter the download link: ' DOWNLOAD_LINK

## for the user to see what is was typed and for debugging
echo package: $PACKAGE, source: $SOURCE, download link: $DOWNLOAD_LINK

## the place to keep the source/package files
INST_PATH=/usr/local/src

# new, I just give the rights to others instead of checking if rights are needed, its simple 
sudo chmod o+rwx $INST_PATH   # we assign all rights 
                              # with 'chmod' using temporary root rights via sudo
			      # this will turn the sticky bit on the directory on 
			      # making unlinking and renaming of files a privilage 
			      # to the root and owner as in:
			      # https://en.wikipedia.org/wiki/Sticky_bit
			      # nice history article can be found here:
			      # https://www.thegeekstuff.com/2013/02/sticky-bit/ 


# https://superuser.com/questions/301044/how-to-wget-a-file-with-correct-name-when-redirected
# curl can be used instead here 

$(wget -v  $DOWNLOAD_LINK -P $INST_PATH) # we download the source/pack in the target

if [[ "$SOURCE" == *"s"* ]]; then # if you type more than a 's' you are ..
	                          # just type 's' for source 
  echo insalling from source
  echo this is the result: $(echo ${DOWNLOAD_LINK##*/})        # for debug
  echo the path: "$INST_PATH/${DOWNLOAD_LINK##*/}"             # for debug
  
  #-xzf for .gz, 
  # so yes we support only .biz, this was used for testing..we will fix it in the future
  $(cd $INST_PATH ; tar -xjf ${DOWNLOAD_LINK##*/} ) 
  # https://www.howtogeek.com/409742/how-to-extract-files-from-a-.tar.gz-or-.tar.bz2-file-on-linux/

  UNZIP_PATH=$(ls -l -d /usr/local/src/*/ | grep $PACKAGE | head -1) 
  # we need the directory where we dupmped the files
  # so we list the directories, we filter by package name provided by the user and 
  # we get the first result we get as the true
  # there are many things that can go wrong here 
  # sorting by date of creation and getting the first line might be a better solution 

  #echo first unzip_path $UNZIP_PATH
  UNZIP_PATH=$(echo $UNZIP_PATH | rev | cut -d " " -f1 | rev)
  # this was a funny solution to get the last part by reversing twice and using 'cut' 
  #echo second unzip_path $UNZIP_PATH

  handle_errors(){ 
	  ## this recursive function does more than just handle errors 
	  # so the name need to be changed, but it is basically calling it self 
	  # if there is 'error:' in the ./configure step, 
	  # graps the message after the 'error:' and for each 'word' uses apt to try 
	  # to install a package assuming the 'word' is a package name ...aw 
	  # plase dont kill me for that, trying to check for dependencies 
	  # and installing them before running ./configure didnt worked well because of 
          # the need to be able to handle cyclic and/or transitive dependencies  
          # it didnt worked anyway for nmap	  
    echo running handle_errors 
    if (( $1 <= 1 )); then # this is the base case where there are no more errors 
       echo done
    else                   # and the first call and when there are errors 
       echo cónfiguring..     
       ERROR=""
       ERROR=$(cd $UNZIP_PATH; echo "" > er_tmp; echo "" > er_fin; ./configure >/dev/null 2> er_tmp; cat er_tmp | awk -F'error:' '{print $2}' > er_fin; cat er_fin  )
       ## and yes I am using temporary files, I know it is recomended against it 
       # but to make it work I needed to do it as a start 
       # and I can see now that is still here, and I need to remove the files in the end.
       # I use 'awk' here as it is easyer to use when there is a string of more than 
       # one char as a separtor as for 'error:', I just discard stdout and keep stderr 
       
       if [[ $ERROR ]]; then # if the error string is not empty there are errors  
         ##
	 echo missing libraries are installing..
	 sudo apt-get -y update 2> /dev/null  ## we update using apt-get before installing /sudo was here 
	                                      # and saying yes to all the questions, 
					      # maybe not that smart for some packages 
         for X in $ERROR # for each word separated by space in the error message
	  do 
	    sudo apt-get -y install $X 2> /dev/null # try to install assuming a package /sudo was here
	                                            # and discard error msg   
         done  
	 #echo calling handle_errors with 2
	 handle_errors 2        # call recursively to try to finish ./configure 
         ##     
       else 
	 #echo calling handle_errors with 1      
         handle_errors 1        # no more errors, we are ready to go for the make
       fi                
    fi
  }
 
  handle_errors 2  # call the function to handle the ./configure hell 
	
  ##do make
  echo executing make in: $UNZIP_PATH
  cd $UNZIP_PATH && sudo make  
 
  ##do checkinstall
  echo executing checkinstall in: $UNZIP_PATH
  cd $UNZIP_PATH && sudo checkinstall -y     # you need to have the checkinstall pre-installed 


#we have a .deb or a rmp file to install
else
	install_deb(){
          # PACK_NAME=$(cd $INST_PATH && ls | grep '\.deb$' | grep $PACKAGE | head -n1) # old
    	  PACK_NAME=$(cd $INST_PATH && ls -Art | grep '\.deb$' | grep $PACKAGE | tail -n 1)
    	  DEB_DEPENDS=$(cd $INST_PATH; echo "" > pd_tmp && dpkg-deb -I $PACK_NAME > pd_tmp && awk -F'Depends:' '{print $2}' pd_tmp)
  
    	  echo missing libraries are installing..
    	  sudo apt-get -y update 2> /dev/null   
    	  for X in $DEB_DEPENDS 
      	  do 
            sudo apt-get -y install $X 2> /dev/null ;
    	  done
  
    	  echo installing.. $PACK_NAME
    	  cd $INST_PATH && sudo dpkg -i $PACK_NAME; 
	}

	install_rpm(){
	  PACK_NAME=$(cd $INST_PATH && ls -Art | grep '\.rpm$' | grep $PACKAGE | tail -n 1)
          # https://stackoverflow.com/questions/1015678/get-most-recent-file-in-a-directory-on-linux
    
    	  echo updating apt db..
    	  sudo apt-get -y update 1> /dev/null 
    	  echo installing/updating alien.. 
    	  sudo apt-get -y install alien 1> /dev/null

	  echo "converting $PACK_NAME to .deb ..."
    	  cd $INST_PATH && sudo alien $PACK_NAME;     
		
	  install_deb #call function to install the generated .deb
	}

  EXT=$(echo $DOWNLOAD_LINK | rev | cut -d "." -f1 | rev | awk '{print tolower($0)}') 
  # https://stackoverflow.com/questions/2264428/how-to-convert-a-string-to-lower-case-in-bash
  if [ "$EXT" = "rpm"  ] 
  then
   install_rpm    
  elif [ "$EXT" = "deb" ] 
  then
   install_deb
  else
    echo "Unsupported file format: .$EXT"  	  
  fi
	
fi

## we don't need sudo rights anymore 
sudo rm /etc/sudoers.d/$MY_USER 


### helping stuff during development - skip it ###

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

