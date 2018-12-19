#!/bin/bash

PARAM1=$*

if [ -z "$PARAM1" ]; then
  PARAM1="*"  	  
else
  PARAM1=${PARAM1,,} 
fi

sudo apt-get install -y jq > /dev/null 2>&1

for FILE in ~/bin/monkeyd_$PARAM1.sh; do
  sleep 2
  echo "****************************************************************************"
  echo FILE: " $FILE"

  MONKSTARTPOS=$(echo $FILE | grep -b -o _)
  MONKLENGTH=$(echo $FILE | grep -b -o .sh)
  MONKSTARTPOS_1=$(echo ${MONKSTARTPOS:0:2})
  MONKSTARTPOS_1=$[MONKSTARTPOS_1 + 1]
  MONKNAME=$(echo ${FILE:MONKSTARTPOS_1:${MONKLENGTH:0:2}-MONKSTARTPOS_1})  
  
  MONKPID=`ps -ef | grep -i $MONKNAME | grep -i monkeyd | grep -v grep | awk '{print $2}'`
  echo "MONKPID="$MONKPID

  if [ -z "$MONKPID" ]; then
    echo "Monk $MONKNAME is STOPPED can't check if synced!"
  else
  
	  LASTBLOCK=$(~/bin/monkey-cli_$MONKNAME.sh getblockcount)
	  GETBLOCKHASH=$(~/bin/monkey-cli_$MONKNAME.sh getblockhash $LASTBLOCK)  
	  
	  #LASTBLOCKCOINEXPLORERMONK=$(curl -s4 https://www.coinexplorer.net/api/MONK/block/latest)
	  #BLOCKHASHCOINEXPLORERMONK=', ' read -r -a array <<< $LASTBLOCKCOINEXPLORERMONK
	  #BLOCKHASHCOINEXPLORERMONK=${array[6]}
	  #BLOCKHASHCOINEXPLORERMONK=$(echo $BLOCKHASHCOINEXPLORERMONK | tr , " ")
	  #BLOCKHASHCOINEXPLORERMONK=$(echo $BLOCKHASHCOINEXPLORERMONK | tr '"' " ")
	  #BLOCKHASHCOINEXPLORERMONK="$(echo -e "${BLOCKHASHCOINEXPLORERMONK}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	  
	  BLOCKHASHCOINEXPLORERMONK=$(curl -s4 https://www.coinexplorer.net/api/MONK/block/latest | jq -r ".result.hash")
	  
	  WALLETVERSION=$(~/bin/monkey-cli_$MONKNAME.sh getinfo | grep -i \"version\")
	  WALLETVERSION=$(echo $WALLETVERSION | tr , " ")
	  WALLETVERSION=$(echo $WALLETVERSION | tr '"' " ")
	  WALLETVERSION=$(echo $WALLETVERSION | tr 'version : ' " ")
	  WALLETVERSION=$(echo $WALLETVERSION | tr -d ' ' )
	  
	  if ! [ "$WALLETVERSION" == "2030003" ]; then
	     echo "!!!Your wallet $MONKNAME is OUTDATED!!!"
	  fi

	  echo "LASTBLOCK="$LASTBLOCK
	  echo "GETBLOCKHASH="$GETBLOCKHASH
	  echo "BLOCKHASHCOINEXPLORERMONK="$BLOCKHASHCOINEXPLORERMONK
	  echo "WALLETVERSION="$WALLETVERSION
	  
	  if [ "$GETBLOCKHASH" == "$BLOCKHASHCOINEXPLORERMONK" ]; then
		echo "Wallet $FILE is SYNCED!"
	  else
		if [ "$BLOCKHASHCOINEXPLORERMONK" == "Too" ]; then
		   echo "COINEXPLORERMONK Too many requests"
		else 
		   echo "Wallet $FILE is NOT SYNCED!"
		fi
	  fi
  fi
done