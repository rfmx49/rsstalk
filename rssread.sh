#!/bin/bash

#SIMPLE JOB CREATION
creation () {
	options=$(zenity --forms --title="Add Feed" --text="Enter information about your feed. Sorry enter also does not work" --separator=";" \
				--add-entry="Job Name(avoid spaces)" \
				--add-entry="RSS Link" \
				--add-entry="Max posts to read(integer)" )
	echo $options
	arroptions=(${options//;/ })
	if [ -z "${arroptions[2]}" ]; then
		echo "something went wrong"
		return
	fi
	show="yes"
	while [ "$show" != "no" ]; do
		arroptions[3]=$(zenity --entry --title="What language?" \
			--text="What languages would you like? Seperate with semicolon \n\n\
			Ex. for english scotish english-female type\n\
			en;en-sc;en+f3\n\n\
			To view full list press cancel." \
			--entry-text="en;en-sc;en+f3")
		if [ $? == "1" ]; then
			zenity --info --text="coming soon type \"espeak --voices\" into terminal for list"
		else
			show="no"
		fi
	done
	
	zenity --question --title="Email settings" --text="Do you want to email the recording?\n\nEmail must be configured in sh file if not using Gmail."
		if [ $? == "0" ]; then
			emailinfo=$(zenity --forms --title="Add Feed" --text="Enter information about your feed. Sorry enter also does not work" \
				--separator=";" \
				--add-entry="Email" \
				--add-password="Password" )
		fi	
		aaremailinfo=(${emailinfo//;/ })

		arroptions[4]=${aaremailinfo[0]}
		aaremailinfo[1]=$(echo ${aaremailinfo[1]} | base64)
		echo ${aaremailinfo[1]}
		arroptions[5]=${aaremailinfo[1]}
		
		#write config file
		echo ${arroptions[0]} > "$LOCATION/${arroptions[0]}.conf"
		echo ${arroptions[1]} >> "$LOCATION/${arroptions[0]}.conf"
		echo ${arroptions[2]} >> "$LOCATION/${arroptions[0]}.conf"
		echo ${arroptions[3]} >> "$LOCATION/${arroptions[0]}.conf"
		echo ${arroptions[4]} >> "$LOCATION/${arroptions[0]}.conf"
		echo ${arroptions[5]} >> "$LOCATION/${arroptions[0]}.conf"
}

#XML CREATION
xmlcreation () {
	#get config file
	#awk -v line=$[i-2] 'NR==line{print;exit}'
	conffile=`cat "$LOCATION/$1.conf"`
	feed=`awk -v line=1 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	link=`awk -v line=2 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	maxitems=`awk -v line=3 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	lang=`awk -v line=4 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	email=`awk -v line=5 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	password=`awk -v line=6 'NR==line{print;exit}' "$LOCATION/$1.conf"`
	maxitems=$[maxitems+2]
	echo "Creating $feed at $link to get $maxitems items, will then speak in $lang. will email to $email with pw $password."
	
	#Create folder and get feed
	rm -rf "$LOCATION/$feed"
	mkdir "$LOCATION/$feed"
	wget -O "$LOCATION/$feed/$feed.xml" $link
	#adds new line after every closing tag for poorly formatted feeds.
	sed 's/<\/[a-zA-Z][a-zA-Z]*>/&\n/gi' "$LOCATION/$feed/$feed.xml" > "$LOCATION/$feed/temp.xml"
	mv "$LOCATION/$feed/temp.xml" "$LOCATION/$feed/$feed.xml"
	
	#separate and get voices
	langs=(${lang//;/ })
	numoflangs=${#langs[@]}
	x=$[numoflangs-1]
	
	#initialize ssml xml file
	echo '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"' > "$LOCATION/$feed/read$feed.xml"
	echo -e '\txmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' >> "$LOCATION/$feed/read$feed.xml"
	echo -e '\txsi:schemaLocation="http://www.w3.org/TR/speech-synthesis/synthesis.xsd"' >> "$LOCATION/$feed/read$feed.xml"
	echo -e '\txml:lang="en-US">' >> "$LOCATION/$feed/read$feed.xml"
	
	#File to be read
	toread1=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=1 'NR==line{print;exit}')
	toread2=$(sed -n 's/.*<description>\([^\.]*\)[\.<].*\/description>.*/\1\./gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=1 'NR==line{print;exit}')
	toread3=$(sed -n 's/.*<lastBuildDate>\(.*\)<\/lastBuildDate>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=1 'NR==line{print;exit}')
	if [ -z "$toread3" ]; then
		echo "no lastbuilddate found"
		toread3="today"
	else	
		cleandate "$toread3"
		toread3=$cleaneddate
	fi

	#XML file write
	towrite='\n\t<voice name="'"${langs[$x]}"'">"Hello, and welcome to, '"$toread1"' <break time="800ms" /> '"$toread2"'. Here is the news from '"$toread3"'."</voice>'
	echo -e "$towrite" >> "$LOCATION/$feed/read$feed.xml"
	
	##ending will be written at end.
	endingwrite='\n\n\t<voice name="'"${langs[$x]}"'">"Well, that does it for us here at, '"$toread1"' Have a good day! <break time="600ms" /> Good-bye"</voice>'

	#time to get articles	
	numberofposts=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | grep -c ".*")
	#limiter is used here	
	if [ "$numberofposts" -gt "$maxitems" ]; then
		numberofposts=$maxitems
	fi
	echo "number of posts is $numberofposts"
	done="no"
	#DEBUG i=3
	i=3
	x=0
	while [ $done != "yes" ]; do
		toread1=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=$i 'NR==line{print;exit}')
		#title quick clean
		toread1=`echo "$toread1" | sed -e 's/&quot;//gi' -e 's/<[^>]*>//gi' -e 's/amp;//gi'`
		toread2=$(sed -n 's/.*<description>\(.*\)<\/description>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=$[i-1] 'NR==line{print;exit}')
		toread3=$(sed -n 's/.*<pubDate>\(.*\)<\/pubDate>.*/\1/gpi' "$LOCATION/$feed/$feed.xml" | awk -v line=$[i-2] 'NR==line{print;exit}')
		cleandate "$toread3"
		toread3=$cleaneddate
		cleandesc "$toread2"
		toread2="$description"
		if [ -z "$toread2" ]; then
			echo "to work with $toread2"
			toread2=$(cat "$LOCATION/$feed/$feed.xml" | tr "\n" " " | tr "\t" " " |  sed -e 's/>[ ]*</></g' -e 's/<\/item>/&\t\n/gi' | grep -m $[i-2] "<item>" | awk -v line=$[i-2] 'NR==line{print;exit}' | sed -n 's/.*<p>\(.*\)<\/p>.*/\1/gpi')
			toread2=$(echo "$toread2" | tr "\n" " ")
			cleandesc "$toread2"
			toread2="$description"
		fi	
		#XML file write 3 date 1 title 2 desc
		towrite='\n\n\t<voice name="'"${langs[$x]}"'">"From '"$toread3"' <break time="600ms" /> '"$toread1"'. '"$toread2"'."</voice>'
		echo -e "$towrite" >> "$LOCATION/$feed/read$feed.xml"
		
		#next language		
		echo "language used is ${langs[$x]}"		
		x=$[x+1]
		if [ "$x" -ge "$numoflangs" ]; then
			x=0
		fi
		
		#are we done yet?
		if [ "$i" == "$numberofposts" ]; then
			done="yes"
		else
			i=$[i+1]
		fi
	done
	
	#end tag of xml file
	echo -e "$endingwrite"'\n\n</speak>'  >> "$LOCATION/$feed/read$feed.xml"

	#clean annoyances 1 removes .. spoken as pause "dot"
	sed '/[^\.]\.\.[^\.]/s/\.\./\./gi' "$LOCATION/$feed/read$feed.xml" > "$LOCATION/$feed/temp.xml"
	mv "$LOCATION/$feed/temp.xml" "$LOCATION/$feed/read$feed.xml"

	#save and convert
	clear
	echo "Speaking to file..."
	espeak -mf "$LOCATION/$feed/read$feed.xml" -s 160 -w "$LOCATION/$feed/$feed.wav"
	echo "Converting to mp3..."
	avconv -b 64 -i "$LOCATION/$feed/$feed.wav" "$LOCATION/$feed/$feed.mp3"
	rm "$LOCATION/$feed/$feed.wav"
	
}

getyttittle () {
	ytlink=$1
	# sed -n 's/<meta name=\"title\" content="\([^"]*\)">*/\1/p'
	echo "attempting to get YT title of $1"
	wget -O "$LOCATION/$feed/temp.html" $ytlink
	if [ $? != "0" ]; then
			yttitle="Unknown"
			return
	fi
	yttitle=""
	yttitle=`sed -n 's/<meta name=\"title\" content="\([^"]*\)">*/\1/p' "$LOCATION/$feed/temp.html"`
	rm "$LOCATION/$feed/temp.html"
	#a fucking annoyance??
	yttitle=`echo $yttitle | sed -e 's/&#39;//gi'`
	yttitle=`echo $yttitle | sed -e 's/&#039;//gi'`
	echo $yttitle
	echo "YT title"
}

getwebtitle () {
	weblink=$1
	wget -O "$LOCATION/$feed/temp.html" $weblink
	if [ $? != "0" ]; then
			webtitle="Unknown"
			return
	fi
	webtitle=""
	wcontent=$(grep -m 1 '<title>' "$LOCATION/$feed/temp.html")
	searchstring='<title>'
	srchpos1=$(awk -v a="$wcontent" -v b="$searchstring" 'BEGIN{print index(a,b)}')
	wcontent=${wcontent:srchpos1-1:2000}
	webtitle=`echo $wcontent | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/pi'`
	rm "$LOCATION/$feed/temp.html"
	webtitle=`echo $webtitle | sed -e 's/&#39;//gi'`
	webtitle=`echo $webtitle | sed -e 's/&#039;//gi'`
	echo $webtitle
}

cleandesc () {
	description="$1"
	#rules/cleaning
	#Clears Junk
	description=`echo $description | sed -e 's/&#34;/'"\""'/gi' \
							-e 's/&lt;/\</g' \
							-e 's/&gt;/\>/g'\
							-e 's/<br*.>//gi' \
							-e 's/<br \/>//gi' \
							-e 's/&#39/'\''/gi' \
							-e 's/#39;//gi' \
							-e 's/&quot;/'"\""'/gi' \
							-e 's/amp;//gi'`
	#gets number of reddit comments
	description=`echo $description | sed -e 's/<a href="http[s]*:\/\/www\.reddit\.com\/r\/[^\/]*\/comments\/[^\/]*\/[^\/]*\/">\[\([^<]*\)]<\/a>/\1/gi'`
	#gets reddit submitter
	description=`echo $description | sed -e 's/ <a href="http[s]*:\/\/www\.reddit\.com\/user[^"]*"> \([^ ]* \)<\/a>/ reddit user, \1/gi'`

	#converts links with youtube video to video titles
	linksconverted="no"
	while [ $linksconverted != "yes" ]; do
		#convert youtube links
		ytlink=""
		yttitle=""
		ytlink=`echo $description | sed -n 's/.*<a href="\(http[s]*:\/\/www\.youtube.com\/watch?v=[^"]*\)".*/\1/pi'`
		if [ "$ytlink" != "" ]; then
			echo "yt link found is $ytlink"
			getyttittle "$ytlink"
			echo $yttitle
			if [ -z "$yttitle" ]; then yttitle="Unknown"; fi
			description=`echo $description | sed -e 's/<a href="http[s]*:\/\/www\.youtube.com\/watch?v=[^>]*>\([^<]*\)<\/a>/, Youtube video titled, '"$yttitle"', captioned, \1/gi'`
		fi
		ytlink=""
		yttitle=""
		ytlink=`echo $description | sed -n 's/.*<a href="\(http[s]*:\/\/youtu\.be[^"]*\)".*/\1/pi'`
		if [ "$ytlink" != "" ]; then
			echo "yt link found is $ytlink"
			getyttittle "$ytlink"
			echo $yttitle
			if [ -z "$yttitle" ]; then yttitle="Unknown"; fi
			description=`echo $description | sed -n 's/<a href="http[s]*:\/\/youtu\.be[^>]*>\([^<]*\)<\/a>/, Youtube video titled, '"$yttitle"', captioned, \1/gpi'`
		fi

		#check
		echo "$description" | grep "a href=\"http[s]*://you"
		if [ $? = "1" ]; then
			linksconverted="yes"
		fi
	done

	#converts weblinks to page titles
	linksconverted="no"
	while [ $linksconverted != "yes" ]; do
		# web link caption sed -n 's/.*<a href="http:\/\/[^>]*>\([^<]*\)<\/a>.*/Web link captioned, \1/gp'
		# web link it self sed -n 's/.*<a href="\(http:\/\/[^"]*\)">.*/Web link captioned, \1/gp'
		webtitle=""
		weblink=""
		weblink=`echo $description | sed -n 's/.*<a href="\(http[s]*:\/\/[^"]*\)">.*/\1/gpi'`
		if [ "$weblink" != "" ]; then
			echo "web link found is $weblink"
			getwebtitle "$weblink"
			echo $webtitle
			if [ -z "$webtitle" ]; then webtitle="Unknown"; fi
			description=`echo $description | sed -n 's/<a href="http[s]*:\/\/[^>]*>\([^<]*\)<\/a>/, Web link titled, '"$webtitle"', captioned, \1/gpi'`
		fi
		#check
		echo "$description" | grep "a href=http"
		if [ $? = "1" ]; then
			linksconverted="yes"
		fi
	done

	#Removes all other tags
	#remove remaining tags
	#more cleaning on finished product.
	echo "before: $description"
	description=`echo "$description" | sed -e 's/&quot;//gi' -e 's/<[^>]*>//gi' -e 's/amp;//gi' -e 's/ ,/,/gi'`	
	echo "after: $description"
	echo $description
}


#CLEAN DATE
cleandate () {
	#sample "Tue, 11 Sep 2012 20:34:55 +0000"
	#want Tuesday eleventh September at 20, 35.
	date=$1
	#gets Tue
	dayname=$(echo $date | sed -ne 's/\([A-Z][a-z][a-z]\).*/\1/pi')
	case $dayname in
		"Sun") dayname2="Sunday" ;;
		"Mon") dayname2="Monday" ;;
		"Tue") dayname2="Tuesday" ;;
		"Wed") dayname2="Wednesday" ;;
		"Thu") dayname2="Thursday" ;;
		"Fri") dayname2="Friday" ;;
		"Sat") dayname2="Saturday" ;;
	esac
	#gets Sep
	monthname=$(echo $date | sed -ne 's/.*\([A-Z][a-z][a-z]\).*/\1/pi')
	case $monthname in
		"Jan") monthname2="January" ;;
		"Feb") monthname2="February" ;;
		"Mar") monthname2="March" ;;
		"Apr") monthname2="April" ;;
		"May") monthname2="May" ;;
		"Jun") monthname2="June" ;;
		"Jul") monthname2="July" ;;
		"Aug") monthname2="August" ;;
		"Sep") monthname2="September" ;;
		"Oct") monthname2="October" ;;
		"Nov") monthname2="November" ;;
		"Dec") monthname2="December" ;;
	esac
	#gets day
	daynumber=$(echo $date | sed -ne 's/.* \([0-9][0-9]\) .*/\1/pi')
	#gets hour
	hour=$(echo $date | sed -ne 's/.* \([0-9][0-9]\):.*/\1/pi')
	#gets minute
	minute=$(echo $date | sed -ne 's/.*:\([0-9][0-9]\):.*/\1/pi')
	getnumberth2 $daynumber
	cleaneddate="$dayname2 $numberth at: $hour $minute"
	#more informal also took out $monthname2 from output
	if [ "$dayname2" = "`date +%A`" ]; then
		dayname2="Today"
		cleaneddate="$dayname2 at: $hour $minute"
	fi
	if [ "$dayname2" = "`date -d '1 day ago' +%A`" ]; then 
		dayname2="Yesterday"
		cleaneddate="$dayname2 at: $hour $minute"
	fi
	echo $cleaneddate
}

#GET NUMBER WITH TH
getnumberth2 () {
	number=$1
	echo "$number to change"
	num2=${number:1:1}
	if [ $number -lt "9" ]; then
		num2=${number:0:1}
	elif [ $number -eq "11" ]; then
		num2="4"
	fi
	case $num2 in
		1) th="st"; numberth=${number}${th}; echo "$numberth"; return ;;
		2) th="nd"; numberth=${number}${th}; echo "$numberth"; return ;;
		3) th="rd"; numberth=${number}${th}; echo "$numberth"; return ;;
		*) th="th"; numberth=${number}${th}; echo "$numberth"; return ;;
	esac
}

debugmenu () {
	case $1 in
		"swcheck") softwarecheck; return ;;
		"getnum") getnumberth2 $2; espeak $numberth; return ;;
		"go") xmlcreation $2; return ;;
		*) return ;;
	esac
}


#SOFTWARE CHECK
softwarecheck () {
	echo "Checking for zenity"
	swcheck=$(zenity --version)	
	if [ -z "$swcheck" ]; then		
		echo "ZENITY NOT FOUND INSTALL ZENITY! sudo apt-get install zenity"
		wait 1
		echo "Do you want to install zenity? y or n"
		read zenans
			if [ "$zenans" == "y" ]; then
				echo "command to be run: sudo apt-get install zenity"
				sudo apt-get install zenity
			else
				return 1
			fi
		
	else
		echo "zenity installed"
	fi

	echo "Checking for espeak"
	swcheck=$(espeak --version)	
	if [ -z "$swcheck" ]; then		
		zenity --question --text="espeak not instaled correctly:\n\nespeak command not found\n\nDo you want to skip this check?\n\n\nChoose no for an option to install software"
		if [ $? == "1" ]; then
			zenity --question --text="Do you want to install missing software now?"
			if [ $? == "0" ]; then
				echo "Install"
				echo "Command to be run sudo apt-get install espeak"
				sudo apt-get install espeak
			else
				return 1
			fi
		fi
	else
		echo "espeak installed"
	fi

	echo "Checking for ffmpeg"
	swcheck=$(ffmpeg -v)	
	if [ -z "$swcheck" ]; then		
		zenity --question --text="ffmpeg not instaled correctly:\n\nffmpeg command not found\n\nDo you want to skip this check?\n\n\nChoose no for an option to install software"
		if [ $? == "1" ]; then
			zenity --question --text="Do you want to install missing software now?"
			if [ $? == "0" ]; then
				echo "Install"
				echo "Command to be run sudo apt-get install ffmpeg ubuntu-restricted-extras"
				sudo apt-get install ffmpeg ubuntu-restricted-extras
			else
				return 1
			fi
		fi
	else
		echo "espeak installed"
	fi
	
	echo "Checking for wget"
	swcheck=$(wget --version)	
	if [ -z "$swcheck" ]; then		
		zenity --question --text="wget not instaled correctly:\n\nwget command not found\n\nDo you want to skip this check?\n\n\nChoose no for an option to install software"
		if [ $? == "1" ]; then
			zenity --question --text="Do you want to install missing software now?"
			if [ $? == "0" ]; then
				echo "Install"
				echo "Command to be run sudo apt-get install wget"
				sudo apt-get install wget
			else
				return 1
			fi
		fi
	else
		echo "wget installed"
	fi
}

LOCATION="`pwd`"
if [ -z "$1" ]; then
	quit="no"
	softwarecheck
	while [ $quit != "yes" ]; do				
		choice=$(zenity --list --height=310 --width=225 --text="Choose what operation you would like to complete." \
		--column=Channel --column=Name \
		"1" "Job Creation" \
		"2" "Advance" \
		)
		case $choice in
			1) creation ;;
			2) echo "false" ;;
			"") echo "Quitting" ; quit="yes" ;;
			*) echo "$choice is not valid"
			sleep 1 ;;
		esac
	done

else
	## If arguments are sent with opening file	
	if [ "$1" = "debug" ]; then debugmenu $2 $3 $4; fi
	if [ "$1" = "go" ]; then xmlcreation $2; fi
fi
