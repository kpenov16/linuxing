#!/bin/bash

## we need the package name
read -p 'Enter package name: ' package #promp the user and reads a line with the user input from stdin

## we need to know id we are going to install from source or from .deb package
read -p 'Enter s to install from source or p from dpkg/rpm: ' source

## we need the link to the source/package
read -p 'Enter the download link: ' downloadLink

## for the user to see what is was typed and for debugging
echo package: $package, source: $source, downloadLink: $downloadLink

## the place to keep the source/package files
inst_path=/usr/local/src

##keeping som echos for debug
#echo $(ls -ldh $inst_path | cut -d " " -f1) 

## extract the Others permitions on the inst_path (instalation path)
# this is a bit misleading as this is actually the path to the source
gr=$(ls -ldh $inst_path | cut -d " " -f1| cut -c 8-10) ## we would like to know 
                                                       # if Others need permitions
						       # to write, we first list 
						       # the directory info with 'ls'
						       # and use 'cut' to split 
						       # the output delimited by space
						       # and as the permitions are 
						       # in the first column we get only that
						       # we then extract the last 3 chars
						       # as they show the Others rights                                                        # on the directory  

if [[ "$gr" == *"-"* ]]; then # we check if there is any missing permition for Others
  echo setting others to have +rwx
  sudo chmod o+rwx $inst_path # if there is, we assign all rights 
                              # with 'chmod' using temporary root rights via sudo
			      # this will turn the sticky bit on the directory on 
			      # making unlinking and renaming of files a privilage 
			      # to the root and owner as in:
			      # https://en.wikipedia.org/wiki/Sticky_bit
			      # nice history article can be found here:
			      # https://www.thegeekstuff.com/2013/02/sticky-bit/ 
fi

$(wget -v  $downloadLink -P $inst_path) # we download the source/pack in the target

if [[ "$source" == *"s"* ]]; then # if you type more than a 's' you are ..
	                          # just type 's' for source 
  echo insalling from source
  echo this is the result: $(echo ${downloadLink##*/})        # for debug
  echo the path: "$inst_path/${downloadLink##*/}"             # for debug
  
  #-xzf for .gz, 
  # so yes we support only .biz, this was used for testing..we will fix it in the future
  $(cd $inst_path ; tar -xjf ${downloadLink##*/} ) 
  # https://www.howtogeek.com/409742/how-to-extract-files-from-a-.tar.gz-or-.tar.bz2-file-on-linux/

  unzip_path=$(ls -l -d /usr/local/src/*/ | grep $package | head -1) 
  # we need the directory where we dupmped the files
  # so we list the directories, we filter by package name provided by the user and 
  # we get the first result we get as the true
  # there are many things that can go wrong here 
  # sorting by date of creation and getting the first line might be a better solution 

  #echo first unzip_path $unzip_path
  unzip_path=$(echo $unzip_path | rev | cut -d " " -f1 | rev)
  # this was a funny solution to get the last part by reversing twice and using 'cut' 
  #echo second unzip_path $unzip_path

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
       er=""
       er=$(cd $unzip_path; echo "" > er_tmp; echo "" > er_fin; ./configure >/dev/null 2> er_tmp; cat er_tmp | awk -F'error:' '{print $2}' > er_fin; cat er_fin  )
       ## and yes I am using temporary files, I know it is recomended against it 
       # but to make it work I needed to do it as a start 
       # and I can see now that is still here, and I need to remove the files in the end.
       # I use 'awk' here as it is easyer to use when there is a string of more than 
       # one char as a separtor as for 'error:', I just discard stdout and keep stderr 
       
       if [[ $er ]]; then # if the error string is not empty there are errors  
         ##
	 echo missing libraries are installing..
	 sudo apt-get -y update 2> /dev/null  ## we update using apt-get before installing 
	                                      # and saying yes to all the questions, 
					      # maybe not that smart for some packages 
         for X in $er # for each word separated by space in the error message
	  do 
	    sudo apt-get -y install $X 2> /dev/null # try to install assuming a package
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
  echo executing make in: $unzip_path
  cd $unzip_path && sudo make 
 
  ##do checkinstall
  echo executing checkinstall in: $unzip_path
  cd $unzip_path && sudo checkinstall -y     # you need to have the checkinstall pre-installed


#we have a .deb file to install  
else
  pack_name=$(cd $inst_path && ls | grep '\.deb$' | grep $package | head -n1)
  cd $inst_path && mkdir $pack_name
  #pack_name_path="$inst_path/$pack_name"   
  pd=$(cd $inst_path; echo "" > pd_tmp && dpkg-deb -I $pack_name > pd_tmp && awk -F'Depends:' '{print $2}' pd_tmp)
  
  echo missing libraries are installing..
  sudo apt-get -y update 2> /dev/null
  for X in $pd 
    do 
      sudo apt-get -y install $X 2> /dev/null ; 
  done
  
  echo installing.. $pack_name
  cd $inst_path && sudo dpkg -i $pack_name; #sudo apt-get -y install $pack_name

fi




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

