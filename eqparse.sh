#!/bin/bash

# EQParse does not interact with the EverQuest client in any way.
# This shell script merely parses the log file output. This script complies
# With the Project1999 Play Nice Policy (PNP).

# This script is under the MIT license. Copyright 2021, Talzahr
# LICENSE must be included with all copies/forks.


#      ---- USER CONFIG ----

# Location of the log file to parse
log=/cygdrive/f/everquest/Logs/eqlog_Sathyn_P1999Green.txt


#     Buff tracking:
# Bear in mind that duration often increases by level.
# EQ works in 6s ticks, so duration can be off by as much as ~6s.
# The arrays bufffailtrigger and bufffailaudio are monitored
# by the bufffail() function every 0.3s by default.
# This should be for critically important drops (or warning of drop)
# in effects such as invis, fear, mez, etc. Another benefit
# of the fail arrays are that drop messages are zone-wide.
# I like to set duration a couple of seconds early so that the
# EXPIRED msg will appear for a moment on display().

buffname+=("Dark Pact")
buffduration+=(154)
buffstarttrigger+=("You feel your health begin to drain")
buffendtrigger+=("You feel better")
bufffailtrigger+=("")
bufffailaudio+=("")

buffname+=("Shielding")
buffduration+=(2158)
buffstarttrigger+=("You feel armored")
buffendtrigger+=("Your shielding fades")
bufffailtrigger+=("")
bufffailaudio+=("")

buffname+=("Gather Shadows")
buffduration+=(1198)
buffstarttrigger+=("You gather shadows about you")
buffendtrigger+=("Your shadows fade")
bufffailtrigger+=("You feel yourself starting to appear")
bufffailaudio+=("beep-03.wav")

buffname+=("Invisibility versus Undead")
buffduration+=(1618)
buffstarttrigger+=("You feel your skin tingle")
buffendtrigger+=("Your skin stops tingling")
bufffailtrigger+=("You feel yourself starting to appear")
bufffailaudio+=("beep-03.wav")

buffname+=("Banshee Aura")
buffduration+=(250)
buffstarttrigger+=("A shrieking aura surrounds you")
buffendtrigger+=("The shrieking aura fades")
bufffailtrigger+=("")
bufffailaudio+=("")

buffname+=("Shieldskin")
buffduration+=(2158)
buffstarttrigger+=("A mystic force shields your skin")
buffendtrigger+=("Your skin returns to normal")
bufffailtrigger+=("")
bufffailaudio+=("")

buffname+=("Spirit Armor")
buffduration+=(2158)
buffstarttrigger+=("Translucent armor gathers around you")
buffendtrigger+=("Your spiritual armor fades")
bufffailtrigger+=("")
bufffailaudio+=("")

# Loot we want to track with a counter
specialloot+=("Bone Chips")
specialloot+=("Spider Silk")
specialloot+=("Spiderling Silk")


#      ---- END USER CONFIG ----

# activeeffects array has three values:
# 0=inacitve, 1=active, 2=active but not passed through timekeeping() yet.
for i in "${!buffname[@]}"; do
	activeeffects["$i"]="0"
done

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

		if [[ ! -z "${bufffailtrigger[$i]}" ]] \
		   && [[ "${activeeffects[$i]}" -eq 1 ]]; then

			bufffailread[$i]=$(\
				awk "/\] ${bufffailtrigger[$i]}/ {count++} END{print count}" $log)

			if [[ "${bufffailread[$i]}" -eq "${bufffailendct[$i]}" ]]; then

				paplay ${bufffailaudio[$i]} 2>> eqparse.log
				buffdisplaystatus["$i"]=1
				buffdisplay["$i"]="\e[91m!! \e[93m${buffname[$i]} FAIL!\e[0m"

				((bufffailendct["$i"]++))

			fi

		fi

	done
}


# Coin counter, for now autosplit must be enabled
# as not to pick up vendor sells and simplify code
coincount () {
	local cct=($(\
		awk '/\] You receive.*your split/ {for (I=1;I<NF;I++) if ($I == "copper") print $(I-1)}' $log))
	local sct=($(\
		awk '/\] You receive.*your split/ {for (I=1;I<NF;I++) if ($I == "silver") print $(I-1)}' $log))
	local gct=($(\
		awk '/\] You receive.*your split/ {for (I=1;I<NF;I++) if ($I == "gold") print $(I-1)}' $log))
	local pct=($(\
		awk '/\] You receive.*your split/ {for (I=1;I<NF;I++) if ($I == "platinum") print $(I-1)}' $log))

	csum=0 ssum=0 gsum=0 psum=0
	# copper
	for i in ${cct[@]}; do
		(( csum += i ))
	done
	if [[ $csum -ge 10 ]]; then
		ssum=$(( csum / 10 )) # carry the quotient integer to silver
		csum=$(( csum % 10 )) # leave only the remainder in copper
	fi

	# silver
	for i in ${sct[@]}; do
		(( ssum += i ))
	done
	if [[ $ssum -ge 10 ]]; then
		gsum=$(( ssum / 10 ))
		ssum=$(( ssum % 10 ))
	fi

	# gold
	for i in ${gct[@]}; do
		(( gsum += i ))
	done
	if [[ $gsum -ge 10 ]]; then
		psum=$(( gsum / 10 ))
		gsum=$(( gsum % 10 ))
	fi

	# platinum
	for i in ${pct[@]}; do
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

	echo "-------- EverQuest Stats --------"
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
}



# Is the dot/dd on?
# Has the dot ended, mob died, or player died?
# If the mob dies before dot ended then dmg is partial

# reset log on each script invocation
echo "--Log reset by EQParse at $(date)--" > $log

# Zero out each buff array so we don't have nulls to play with
buffct=()
i=0

while [[ $i -lt ${#buffname[@]} ]]; do

	buffct+=(1)
	buffendct+=(1)
	bufffailendct+=(1)
	buffread+=(0)
	buffendread+=(0)

	((i++))

done


ct=0
starttime=$(date +%s) # for our uptime
csum=0 ssum=0 gsum=0 psum=0 # zero out for display function

# Main loop
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
		&& display



	sleep 0.3
	((ct++))
done
