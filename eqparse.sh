#!/bin/bash

# EQParse does not interact with the EverQuest client in any way.
# This shell script merely parses the log file output. This script complies
# With the Project1999 Play Nice Policy (PNP).

# This script is under the MIT license. Copyright 2021, Talzahr
# LICENSE must be included with all copies/forks.


#      ---- USER CONFIG ----

# Location of the log file to parse
# This is temporary. Will have script determine latest log file being written by EQ client
# and use that with a character/server-specific config file. 
log="/home/talzahr/nvme-home/prefixes/wine32/drive_c/everquest/Logs/eqlog_Sathyn_P1999Green.txt"
note="/home/talzahr/nvme-home/prefixes/wine32/drive_c/everquest/notes.txt"
conf="eqparse.conf"


script="EQparse"
ver="1.1"



error () {

   if [[ "$1" -eq 1 ]]; then
      echo "$script: No \$buffnames in $conf, are you sure it's the correct file?" && exit 1
   elif [[ "$1" -eq 2 ]]; then
      echo "$script: $conf not writeable or does not exist." && exit 2
   elif [[ "$1" -eq 3 ]]; then
      echo "$script: $log not writeable or does not exist." && exit 3
   elif [[ "$1" -eq 4 ]]; then
      echo "$script: $note not writeable." && exit 4
   else
      echo "Undefined error" && exit 255
   fi
         
}

configparse () {

   if [[ ! -w $conf ]]; then
      error 2
   fi

   local buffnamect=$(awk '/buffname/{print $0}' $conf | wc -l)

   if [[ "$buffnamect" -lt 1 ]]; then
      error 1
   fi

   IFS=$'\n\t' # IFS to separate newlines and not spaces

   # Populate the arrays
   buffname=($(awk -F '=' '/buffname/{printf "%s\n", $2}' "$conf"))
   buffduration=($(awk -F '=' '/buffduration/{printf "%d\n", $2}' "$conf"))
   buffstarttrigger=($(awk -F '=' '/buffstarttrigger/{printf "%s\n", $2}' "$conf"))
   buffendtrigger=($(awk -F '=' '/buffendtrigger/{printf "%s\n", $2}' "$conf"))
   bufffailtrigger=($(awk -F '=' '/bufffailtrigger/{if ($2==""){print "null"} else {printf "%s\n", $2}}' "$conf"))
   bufffailaudio=($(awk -F '=' '/bufffailaudio/{if ($2==""){print "null"} else {printf "%s\n", $2}}' "$conf"))

   specialloot=($(awk -F '=' '/specialloot/{printf "%s\n", $2}' "$conf"))
   speciaauctionitem=($(awk -F '=' '/auctionitem/{printf "%s\n", $2}' "$conf"))

   return 0

}

buffup () {

	local i=0
	while [[ "$i" -lt "${#buffname[@]}" ]]; do

		buffread[$i]=$(awk "/\] ${buffstarttrigger[$i]}/ {count++} END{print count}" $log)
		((i++))

	done

	local i=0
	for i in "${!activeeffects[@]}"; do

		if [[ "${buffread[$i]}" -eq "${buffct[$i]}" ]]; then

			buffdisplay[$i]="\e[92m--\e[0m ${buffname[$i]} is ACTIVE"
			activeeffects["$i"]=2
			((buffct[$i]++))

		fi

	((i++))

	done
}

buffdown () {

	local i=0
	while [[ "$i" -lt "${#buffname[@]}" ]]; do

		buffendread[$i]=$(awk "/\] ${buffendtrigger[$i]}/ {count++} END{print count}" $log)
      [[ -z "${buffendread[$i]}" ]] && buffendread["$i"]=0
		((i++))

	done


	for i in ${!activeeffects[@]}; do

		if [[ "${buffendread[$i]}" -eq "${buffendct[$i]}" ]]; then

			unset buffdisplay["$i"]
			activeeffects["$i"]=0 # buff is now inactive
			buffexpiration["$i"]=0 # zero out our timer
			buffdisplaystatus["$i"]=0 # For bufffail() to change display msg
			((buffendct[$i]++))

		fi

	done
}

timekeeping () {

	for i in "${!activeeffects[@]}"; do

		if [[ "${activeeffects[$i]}" -eq 2 ]]; then

			buffstarttime["$i"]="$(date +%s)"
			buffendtime["$i"]="$(( ${buffstarttime[$i]} + ${buffduration[$i]} ))"
			activeeffects["$i"]=1

		elif [[ "${activeeffects[$i]}" -eq 0 ]]; then

			continue
		fi

		buffexpiration["$i"]="$(( ${buffendtime[$i]} - $(date +%s) ))"

		if [[ "${buffexpiration[$i]}" -gt 0 ]]; then

			if [[ "${buffexpiration[$i]}" -ge 60 ]]; then

				bufftimer["$i"]="$(( ${buffexpiration[$i]} / 60))m$(( ${buffexpiration[$i]} % 60))s"

			else

				bufftimer["$i"]="${buffexpiration[$i]}s"

			fi
		else

		bufftimer[$i]="EXPIRED!"

		fi
	done
}

bufffail () {
	for i in "${!activeeffects[@]}"; do

		if [ ! "${bufffailtrigger[$i]}" = "null" ] && [[ ${activeeffects[$i]} -eq 1 ]]; then

			bufffailread[$i]=$(\
				awk "/\] ${bufffailtrigger[$i]}/ {count++} END{print count}" $log)
         [[ -z "${bufffailread[$i]}" ]] && bufffailread["$i"]=0

			if [[ "${bufffailread[$i]}" -eq "${bufffailendct[$i]}" ]]; then

				paplay ${bufffailaudio[$i]} 2>> eqparse.log
				buffdisplaystatus["$i"]=1
				buffdisplay["$i"]="\e[91m!! \e[93m${buffname[$i]} FAIL!\e[0m"

				((bufffailendct["$i"]++))

			fi

		fi

	done
}


# Coin counter 

coincount () {

   # looting coin. '~' operator in awk because sometimes 'platinum' is 'platinum,' etc
	local cct=($(\
      awk '/\] You receive.*(from the corpse|your split)/ {for (I=1;I<NF;I++) if ($I ~ "copper") print $(I-1)}' "$log"))
	local sct=($(\
      awk '/\] You receive.*(from the corpse|your split)/ {for (I=1;I<NF;I++) if ($I ~ "silver") print $(I-1)}' "$log"))
	local gct=($(\
      awk '/\] You receive.*(from the corpse|your split)/ {for (I=1;I<NF;I++) if ($I ~ "gold") print $(I-1)}' "$log"))
	local pct=($(\
      awk '/\] You receive.*(from the corpse|your split)/ {for (I=1;I<NF;I++) if ($I ~ "platinum") print $(I-1)}' "$log"))

	csum=0 ssum=0 gsum=0 psum=0
	# copper
   for i in "${cct[@]}"; do
		(( csum += i ))
	done
	if [[ $csum -ge 10 ]]; then
		ssum=$(( csum / 10 )) # carry the quotient to silver
		csum=$(( csum % 10 )) # leave only the remainder in copper
	fi

	# silver
   for i in "${sct[@]}"; do
		(( ssum += i ))
   done
	if [[ $ssum -ge 10 ]]; then
		gsum=$(( ssum / 10 ))
		ssum=$(( ssum % 10 ))
	fi

	# gold
   for i in "${gct[@]}"; do
		(( gsum += i ))
   done
	if [[ $gsum -ge 10 ]]; then
		psum=$(( gsum / 10 ))
		gsum=$(( gsum % 10 ))
	fi

	# platinum
   for i in "${pct[@]}"; do
		(( psum += i ))
   done

}

# For bone chips, tradeskill items, etc.
specialloot () {

	local c=0
	for str in "${specialloot[@]}"; do

		lootct[$c]=$(awk "/\] --You have looted a $str/ {count++} END{print count}" $log)
		[[ -z "${lootct[$c]}" ]] && lootct[$c]="0"
		((c++))

	done

	local c=0
	for i in "${lootct[@]}"; do

		if [[ "${lootct[$c]}" -gt 0 ]]; then

			displayloot[$c]="${specialloot[$c]}: $i"

		fi

		((c++))

	done
}

auctionparse () {
	return
}


#### notes.txt input parsing functions

inputinit () {

   # If nothing in the notes file then we do nothing
   if [[ ! -s "$note" ]]; then
      return 0
   fi

   # Clear the msg after 20 loops
   if [[ $(( "$inputinitloop" % 20 )) -eq 0 ]]; then
      inputreply=""
   fi
   
   # Populate input arr with all fields from the first record if the first field is 'eqparse'
   #inputstring=($(awk '{OFS = "\n"} NR==1 {for (I=1;I<=NF;I++) if ($1 == "eqparse") {print $(I)} else {print "null"}}' "$note"))
   inputstring=($(awk '
      {

         OFS = "\n"
         NR==1

         for (I=1;I<=NF;I++)
            if ($1 == "eqparse")
               print $(I)
            else
               print "null"
         exit

      }' "$note"))

   # Return to main loop when array is null or second parm is empty
   if [ "$inputstring[0]" = "null" ] || [[ "${#inputstring[1]}" -eq 0 ]]; then
      return 0
   fi   

   for ((i=0;i<1;i++)); do

      # reset our reply accumulator and clear the notes.txt
      echo "" > "$note"
      inputinitloop=0

      case "${inputstring[1]}" in
         rlc)
            sed -i '/\] You receive.*(from the corpse|your split)/d' "$log"
            csum=0 ssum=0 gsum=0 psum=0
            inputreply="Looted coin counter has been reset."
            ;;
         help)
            inputreply=" help -- This dialog\n rlc  -- Reset looted coin counter"
            ;;
         *)
            inputreply="Unknown command. See 'eqparse help'"
            ;;
      esac

   done


   ((inputinitloop++))
}


display () {

	local uptimesecs=$(expr $(date +%s) - $starttime)

	if [[ $uptimesecs -ge 3600 ]]; then

		local uptime="$(echo $(expr $uptimesecs / 3600)h$(expr $uptimesecs / 60 % 60)m)"

	elif [[ $uptimesecs -ge 60 ]]; then

		local uptime="$(echo $(expr $uptimesecs / 60)m$(expr $uptimesecs % 60)s)"

	else

		local uptime=$(echo "$uptimesecs"\s)
	fi

	clear

	echo "-------- $script v$ver Stats --------"
	echo "Uptime: $uptime"
	echo "Looted coin: $psum plat, $gsum gold, $ssum silver, $csum copper"

	for str in "${displayloot[@]}"; do

		echo "$str"

	done

	echo ""

	for i in "${!activeeffects[@]}"; do

		if [[ "${activeeffects[$i]}" -gt 0 ]]; then

			if [[ "${buffdisplaystatus[$i]}" -eq 1 ]]; then

				echo -e "${buffdisplay[$i]}"
				continue

			elif [[ "${buffexpiration[i]}" -le 15 ]]; then

				echo -e "${buffdisplay[$i]} until \e[93m${bufftimer[$i]}\e[0m"
				continue

			fi

			echo -e "${buffdisplay[$i]} until ${bufftimer[$i]}"

		fi

   done

   echo "------------------------------------"

   if [[ "${#inputreply}" -gt 0 ]]; then

      echo -e "$inputreply"

   fi
}

userexit () {

# Main loop has terminated by signal
# This is very temporary code, dumping vars to a file for a possible preserved state feature later. 

   touch /tmp/eqparse.state
   if [[ "$?" -gt 0 ]]; then
      exit 0 # let's leave silently, this doesn't yet matter much
   fi

   printf "\nPreserving state to /tmp/eqparse.state"
   printf 'LOOTCOINSTATE=%d,%d,%d,%d\n' "$psum" "$gsum" "$ssum" "$csum" > /tmp/eqparse.state

   ct=0
   for str in "${specialloot[@]}"; do

      printf 'SPECIALLOOTSTATE=%s,%d\n' "$str" "${lootct[$ct]}" >> /tmp/eqparse.state
      ((ct++))

   done
   exit 0

}

##################################
#### Setting up the main loop ####
##################################

# activeeffects array has three values:
# 0=inacitve, 1=active, 2=active but not passed through timekeeping() yet.
for i in "${!buffname[@]}"; do
	activeeffects["$i"]="0"
done

# Reset our EQ log file
echo "--Log reset by EQParse at $(date)--" > $log

# notes.txt must stay clean. May change in the future so it can be used for intended purpose.
echo "" > "$note"
if [[ "$?" -gt 0 ]]; then
   error 4
fi

# If we cannot access the EQ log file
if [[ ! -w "$log" ]]; then
   error 3
fi

# To populate the arrays from .conf
configparse

for i in "${!buffname[@]}"; do
	activeeffects["$i"]="0"
done

# Zero out each buff array so we don't have nulls to play with
buffct=()
i=0
inputinitloop=0
inputreply=""

while [[ $i -lt ${#buffname[@]} ]]; do

	buffct+=(1)
	buffendct+=(1)
	bufffailendct+=(1)
   bufffailread+=(0)
	buffread+=(0)
	buffendread+=(0)

	((i++))

done


ct=0
starttime=$(date +%s) # for our uptime
csum=0 ssum=0 gsum=0 psum=0 # zero out for display function

### Main loop ###

while true; do

	# Things that must run without delay, such as detecting a dropping invis/IVU
	bufffail

	# 6 seconds
	[[ $(( "$ct" % 20 )) -eq 0 ]] \
		&& coincount \
		&& specialloot

	#  4.5 seconds
	[[ $(( "$ct" % 15 )) -eq 0 ]] \
		&& buffup \
		&& buffdown

	# 1.2 seconds
	[[ $(( "$ct" % 4 )) -eq 0 ]] \
		&& timekeeping \
		&& inputinit \
      && display

   # 30 seconds
   [[ $(( "$ct" % 100 )) -eq 0 ]] \
      && configparse # Apply any config changes

   trap 'userexit' 0

	sleep 0.3
	((ct++))
done

