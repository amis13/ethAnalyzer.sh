#!/bin/bash

# Author: Ismael Salas (aka amis13)

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -e "\n${redColour}[!] Saliendo...\n${endColour}"

	rm ut.t* 2>/dev/null
	tput cnorm; exit 1
}

function helpPanel(){
	echo -e "\n${yellowColour}[!]Uso: ./ethAnalyzer.sh${endColour}"
	for i in $(seq 1 80); do echo -ne "${yellowColour}-"; done; echo -ne "${endColour}"
	echo -e "\n\n\t${grayColour}[-e]${endColour}${yellowColour} Modo exploración${endColour}"
	echo -e "\t\t${purpleColour}unconfirmed_transactions${endColour}${yellowColour}:\t Listar transacciones no confirmadas${endColour}"
	echo -e "\t\t${purpleColour}inspect${endColour}${yellowColour}:\t\t\t Inspeccionar una transaccion por su hash${endColour}"
	echo -e "\t\t${purpleColour}address${endColour}${yellowColour}:\t\t\t Inspeccionar una direccion${endColour}"
	echo -e "\n\t${grayColour}[-n]${endColour}${yellowColour} Limitar el numero de resultados${endColour}${blueColour} (Ejemplo: -n 10)${endColour}"
	echo -e "\n\t${grayColour}[-i]${endColour}${yellowColour} Proporcionar el hash de la transaccion${endColour}${blueColour} (Ejemplo: -i ba3893n2j34dwq2e23df48j88u)${endColour}"
	echo -e "\n\t${grayColour}[-a]${endColour}${yellowColour} Proporcionar la direccion${endColour}${blueColour} (Ejemplo: -a ba3893n2j34dwq2e23df48j88u)${endColour}"
	echo -e "\n${grayColour}[-h]${endColour}${yellowColour} Mostrar este panel de ayuda${endColour}"

	tput cnorm; exit 1
}

function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function unconfirmedTransactions(){

	number_output=$1
	echo '' > ut.tmp

	while [ "$(cat ut.tmp | wc -l)" == "1" ]; do
		curl -s "$unconfirmed_transactions" | html2text | less -S > ut.tmp
	done

	hashes=$(cat ut.tmp | grep -A 100 "Hash" | grep -v -E "Hash|2023|ago|\--|out" | awk '{print $1}' | grep "^0x............" | head -n $number_output)

	echo "Hash_Cantidad_Tipo" > ut.table

	for hash in $hashes; do
		echo "${hash}_$(cat ut.tmp | grep "$hash" | awk '{print $9}' | grep -v -E "a|e|i|o|u|x|y|s|z|d|E|\--")_$(cat ut.tmp | grep "$hash" | awk '{print $2}' | grep -v -E "0|1")" >> ut.table
	done

	echo -ne "${blueColour}"
	printTable '_' "$(cat ut.table)"
	echo -ne "${endColour}"

	rm ut.t* 2>/dev/null
	tput cnorm; exit 0
}

function inspectTransaction(){
	inspect_transaction_hash=$1

	echo "Direccion de entrada_Direccion de salida" > entradas.tmp

	while [ "$(cat entradas.tmp | wc -l)" == "1" ]; do
		curl -s "${inspect_transaction_url}${inspect_transaction_hash}" | html2text | grep -E "From|^To" -A 1 | grep -v -E "From|To|\--|=|Address|Logs|Transactions|Internal|call" | awk '{print $1}' | xargs | tr ' ' '_' >> entradas.tmp
	done

	echo -ne "${greenColour}"
	printTable '_' "$(cat entradas.tmp)"
	echo -ne "${endColour}"
	rm entradas.tmp 2>/dev/null

	echo "Entrada total_Valor" > total_entrada_salida.tmp

	while [ "$(cat total_entrada_salida.tmp | wc -l)" == "1" ]; do
		curl -s "${inspect_transaction_url}${inspect_transaction_hash}" | html2text | grep "Value" -A 1 | grep -v -E "Type|Logs|\--|Value|Address|call|Topics" | tr ' ' '_' | sed 's/_ETH/ ETH/g' | tr -d '()' >> total_entrada_salida.tmp
	done

	echo -ne "${grayColour}"
	printTable '_' "$(cat total_entrada_salida.tmp)"
	echo -ne "${endColour}"
	rm total_entrada_salida.tmp 2>/dev/null

	tput cnorm

}

function inspectAddress(){
	address_hash=$1
	echo "Balance_Valor" > address.information
	curl -s "${inspect_address_url}${address_hash}" | html2text | grep "Eth Value" -C 1 | grep -v "Eth" | xargs | awk '{print $1 " " $2 "_" $3}' >> address.information
	echo "Tokens" > address.information2
	curl -s "${inspect_address_url}${address_hash}" | html2text | grep "Tokens" | awk 'NR==3{print $2 " " $3}' | tr -d "()" >> address.information2

	echo -ne "${yellowColour}"
	printTable '_' "$(cat address.information)"
	printTable '_' "$(cat address.information2)"
	echo -ne "${endColour}"
	rm address.information addres.information2 2>/dev/null

	tput cnorm
}

# Variables globales
unconfirmed_transactions="https://etherscan.io/txs"
inspect_transaction_url="https://etherscan.io/tx/"
inspect_address_url="https://etherscan.io/address/"

parameter_counter=0; while getopts "e:n:i:a:h:" arg; do
	case $arg in
		e) exploration_mode=$OPTARG; let parameter_counter+=1;;
		n) number_output=$OPTARG; let parameter_counter+=1;;
		i) inspect_transaction=$OPTARG; let parameter_counter+=1;;
		a) inspect_address=$OPTARG; let parameter_counter+=1;;
		h) helpPanel;;
	esac
done

tput civis

if [ $parameter_counter -eq 0 ]; then
	helpPanel
else

	if [ "$(echo $exploration_mode)" == "unconfirmed_transactions" ]; then

		if [ ! "$number_output" ]; then
			number_output=100
			unconfirmedTransactions $number_output
		else
			unconfirmedTransactions $number_output
		fi

	elif [ "$(echo $exploration_mode)" == "inspect" ]; then
		inspectTransaction $inspect_transaction

	elif [ "$(echo $exploration_mode)" == "address" ]; then
		inspectAddress $inspect_address
	fi

fi
