#!/bin/bash

CONFIG_FILE="/root/config.txt"
source $CONFIG_FILE
export DISPLAY=:0

if [ -z "$1" ] || [ -z "$2" ] ||  [ -z "$3" ]
	then
	echo "Missing variable"
	exit 1
fi
# getting number of gpu
gpu_info=`nvidia-smi -L`
IFS=$'\n' read -d '' -r -a gpu_list <<< "$gpu_info"
gpu_number=${#gpu_list[@]}
# splitting OC values devided by comma into arrays
IFS=', ' read -r -a core_clk <<< "$1"
IFS=', ' read -r -a memo_clk <<< "$2"
IFS=', ' read -r -a powr_lim <<< "$3"

# checking user input
function OptionMod() {
	declare -n array=$1
	if [ ${#array[@]} -ge $gpu_number ]; then
		# Already ok
		:
	elif [ ${#array[@]} -eq 1 ]; then
		# Using first for all
		for (( i = 1; i < $gpu_number; i++ )); do
			array+=(${array[0]})
		done
	else
		# If number of parameters less then gpu's number, use last for rest.
		for (( i = $gpu_number - ${#array[@]}; i < $gpu_number ; i++ )); do
			array+=(${array[-1]})
		done
	fi
}
OptionMod core_clk
OptionMod memo_clk
OptionMod powr_lim

# Checking if we dealing with p106, 1050 or 1050 Ti
function gpu_check() {
	line_n=$1
re='[[:space:]](GTX[[:space:]]1050)|(P106-100)[[:space:]]'
	if [[ "${gpu_list[$line_n]}" =~ $re ]]; then
		true
	else
		false
	fi
}

# checking if user trying to set unsupported power limit
function power_limit_set {
	pow_array=()
	regexp='([0-9]+)\.[0-9]+[[:space:]]W,[[:space:]]([0-9]+)\.[0-9]+[[:space:]]W'
	pow_inf=`nvidia-smi -i $2 --format=csv --query-gpu=power.min_limit,power.max_limit`
	[[ $pow_inf =~ $regexp ]] && for (( i = 0; i < 3; i++ )); do
		pow_array+=("${BASH_REMATCH[$i]}")
	done
	# If user set power limit less than maxinum
	if [ "$1" -lt "${pow_array[1]}" ]; then
		echo "Available power limit for GPU $2 is ${pow_array[0]}"
		echo "Applying PowerLimit: ${pow_array[1]} for GPU $2"
		sudo nvidia-smi --id=$2 -pl ${pow_array[1]} > /dev/null 2>&1 &
	# If user set power limit higer than maximum
	elif [ "$1" -gt "${pow_array[2]}" ]; then
		echo "Available power limit for GPU $2 is ${pow_array[0]}"
		echo "Applying PowerLimit: ${pow_array[2]} watt for GPU $2"
		sudo nvidia-smi --id=$2 -pl ${pow_array[2]} > /dev/null 2>&1 &
		# Finally!
	else
		echo "Applying PowerLimit: $1 watt for GPU $2"
		sudo nvidia-smi --id=$2 -pl $1 > /dev/null 2>&1 &
	fi
}

# OC'ing core with negative values and cheching user input
function core_clock_set() {
	local core_arr=()
	local str=`LC_ALL=C nvidia-settings -q [gpu:$1]/GPUGraphicsClockOffset[$2]`
	# checking valid core OC values
	local re='range (-*[0-9]*) - (-*[0-9]+)'
	[[ $str =~ $re ]] && for (( i = 0; i < 3; i++ )); do
		core_arr+=("${BASH_REMATCH[$i]}")
	done
	if [[ "$3" -lt "${core_arr[1]}" ]]; then
		echo "Available core offset for GPU $1 is in ${core_arr[0]}"
		echo "Applying CoreOffset: ${core_arr[1]}"
		nvidia-settings -a [gpu:$1]/GPUGraphicsClockOffset[$2]=${core_arr[1]} > /dev/null 2>&1 &
	elif [[ "$3" -gt "${core_arr[2]}" ]]; then
		echo "Available core offset for GPU $1 is in ${core_arr[0]}"
		echo "Applying CoreOffset: ${core_arr[2]}"
		nvidia-settings -a [gpu:$1]/GPUGraphicsClockOffset[$2]=${core_arr[2]} > /dev/null 2>&1 &
	else
		# echo "Applying CoreOffset: $3 for GPU $1"
		nvidia-settings -a [gpu:$1]/GPUGraphicsClockOffset[$2]=$3 > /dev/null 2>&1 &
	fi
}

# Setting Parameters to each gpu
sudo nvidia-smi -pm 1 &
for ((x=0; x<gpu_number; x++))  do
	if gpu_check $x; then
		gpu_type=2
	else
		gpu_type=3
	fi
	echo "Applying CoreOffset: ${core_clk[$x]} MemoryOffset: ${memo_clk[$x]} for GPU $x with GPU Type: $gpu_type"
	nvidia-settings -a [gpu:$x]/GpuPowerMizerMode=1 > /dev/null 2>&1 &
	core_clock_set $x $gpu_type ${core_clk[$x]}
	# nvidia-settings -a [gpu:$x]/GPUGraphicsClockOffset[$gpu_type]=${core_clk[$x]} > /dev/null 2>&1 &
	# call above moved to core_clock_set function.
	nvidia-settings -a [gpu:$x]/GPUMemoryTransferRateOffset[$gpu_type]=${memo_clk[$x]} > /dev/null 2>&1 &
	power_limit_set "${powr_lim[$x]}" $x
	sleep 0.2
done
