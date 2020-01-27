#!/bin/bash

RED='\033[1;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BROWN='\033[0;34m'
NC='\033[0m' # No Color

# CONFIGURATION
NAME="monkey"
NAMEALIAS="monk"
WALLETVERSION="2.3.0"

# ADDITINAL CONFIGURATION
WALLETDLFOLDER="${NAME}-${WALLETVERSION}"
WALLETDL="${WALLETDLFOLDER}-x86_64-linux-gnu.tar.gz"
URL="https://github.com/MONKEYPROJECT/MonkeyV2/releases/download/v${WALLETVERSION}/${WALLETDL}"
CONF_FILE="${NAME}.conf"
CONF_DIR_TMP=~/"${NAME}_tmp"
BOOTSTRAPURL="http://167.86.97.235/${NAMEALIAS}/bootstrap/bootstrap.zip"
PORT=37233
RPCPORT=9234

cd ~
echo "******************************************************************************"
echo "* Ubuntu 16.04 is the recommended operating system for this install.         *"
echo "*                                                                            *"
echo "* This script will install and configure your ${NAME} Coin masternodes (v${WALLETVERSION}).*"
echo "******************************************************************************"
echo && echo && echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                                                 !"
echo "! Make sure you double check before hitting enter !"
echo "!                                                 !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo && echo && echo

if [[ $(lsb_release -d) != *16.04* ]]; then
   echo -e "${RED}The operating system is not Ubuntu 16.04. You must be running on Ubuntu 16.04! Do you really want to continue? [y/n]${NC}"
   read OS_QUESTION
   if [[ ${OS_QUESTION,,} =~ "y" ]] ; then
      echo -e "${RED}You are on your own now!${NC}"
   else
      exit -1
   fi
fi

function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}

get_ip
IP=NODEIP
IPONE=$(curl -s4 icanhazip.com)

echo -e "${YELLOW}Do you want to install all needed dependencies (no if you did it before, yes if you are installing your first node)? [y/n]${NC}"
read DOSETUP

if [[ ${DOSETUP,,} =~ "y" ]] ; then
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y dist-upgrade
   sudo apt-get install -y nano htop git
   sudo apt-get install -y software-properties-common
   sudo apt-get install -y build-essential libtool autotools-dev pkg-config libssl-dev
   sudo apt-get install -y libboost-all-dev
   sudo apt-get install -y libevent-dev
   sudo apt-get install -y libminiupnpc-dev
   sudo apt-get install -y autoconf
   sudo apt-get install -y automake unzip
   sudo add-apt-repository  -y  ppa:bitcoin/bitcoin
   sudo apt-get update
   sudo apt-get install -y libdb4.8-dev libdb4.8++-dev
   sudo apt-get install -y dos2unix
   sudo apt-get install -y jq

   cd /var
   sudo touch swap.img
   sudo chmod 600 swap.img
   sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
   sudo mkswap /var/swap.img
   sudo swapon /var/swap.img
   sudo free
   sudo echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
   cd

   ## COMPILE AND INSTALL
   if [ -d "$CONF_DIR_TMP" ]; then
      rm -rfd $CONF_DIR_TMP
   fi

   mkdir -p $CONF_DIR_TMP   
   cd $CONF_DIR_TMP   
   
   wget ${URL}
   chmod 775 ${WALLETDL}
   tar -xvzf ${WALLETDL}
   cd ./${WALLETDLFOLDER}/bin
   sudo chmod 775 *
   sudo mv ./${NAME}* /usr/bin
   #read
   cd ~
   rm -rfd $CONF_DIR_TMP   

   sudo apt-get install -y ufw
   sudo ufw allow ssh/tcp
   sudo ufw limit ssh/tcp
   sudo ufw logging on
   echo "y" | sudo ufw enable
   sudo ufw status

   mkdir -p ~/bin
   echo 'export PATH=~/bin:$PATH' > ~/.bash_aliases
   source ~/.bashrc
fi

## Setup conf
mkdir -p ~/bin
rm ~/bin/masternode_config.txt &>/dev/null &
COUNTER=1

MNCOUNT=""
REBOOTRESTART=""
re='^[0-9]+$'
while ! [[ $MNCOUNT =~ $re ]] ; do
   echo -e "${YELLOW}How many nodes do you want to create on this server?, followed by [ENTER]:${NC}"
   read MNCOUNT
   echo -e "${YELLOW}Do you want wallets to restart on reboot? [y/n]${NC}"
   read REBOOTRESTART
done

for (( ; ; ))
do  
   #echo "************************************************************"
   #echo ""
   #echo "Enter alias for new node. Name must be unique! (Don't use same names as for previous nodes on old chain if you didn't delete old chain folders!)"
   echo -e "${YELLOW}Enter alphanumeric alias for new nodes.[default: mn]${NC}"
   read ALIAS1

   if [ -z "$ALIAS1" ]; then
      ALIAS1="mn"
   fi   

   ALIAS1=${ALIAS1,,}  

   if [[ "$ALIAS1" =~ [^0-9A-Za-z]+ ]] ; then
      echo -e "${RED}$ALIAS1 has characters which are not alphanumeric. Please use only alphanumeric characters.${NC}"
   elif [ -z "$ALIAS1" ]; then
      echo -e "${RED}$ALIAS1 in empty!${NC}"
   else
      CONF_DIR=~/.${NAME}_$ALIAS1
      if [ -d "$CONF_DIR" ]; then
         echo -e "${RED}$ALIAS1 is already used. $CONF_DIR already exists!${NC}"
      else
         # OK !!!
         break
      fi	
   fi  
done

if [ -d "$CONF_DIR_TMP" ]; then
   rm -rfd $CONF_DIR_TMP
fi

mkdir -p $CONF_DIR_TMP   
cd $CONF_DIR_TMP  
echo "Copy BLOCKCHAIN without conf files"
wget ${BOOTSTRAPURL} -O bootstrap.zip
cd ~

for STARTNUMBER in `seq 1 1 $MNCOUNT`; do 
   for (( ; ; ))
   do  
      echo "************************************************************"
      echo ""
      EXIT='NO'
      ALIAS="$ALIAS1$STARTNUMBER"
      ALIAS0="${ALIAS1}0${STARTNUMBER}"
      ALIAS=${ALIAS,,}  
      echo $ALIAS
      echo "" 

      # check ALIAS
      if [[ "$ALIAS" =~ [^0-9A-Za-z]+ ]] ; then
         echo -e "${RED}$ALIAS has characters which are not alphanumeric. Please use only alphanumeric characters.${NC}"
         EXIT='YES'
	   elif [ -z "$ALIAS" ]; then
	      echo -e "${RED}$ALIAS in empty!${NC}"
         EXIT='YES'
      else
	      CONF_DIR=~/.${NAME}_${ALIAS}
         CONF_DIR0=~/.${NAME}_${ALIAS0}
	  
         if [ -d "$CONF_DIR" ]; then
            echo -e "${RED}$ALIAS is already used. $CONF_DIR already exists!${NC}"
            STARTNUMBER=$[STARTNUMBER + 1]
         elif  [ -d "$CONF_DIR0" ]; then
            echo -e "${RED}$ALIAS is already used. $CONF_DIR0 already exists!${NC}"
            STARTNUMBER=$[STARTNUMBER + 1]            
         else
            # OK !!!
            break
         fi	
      fi  
   done   

   if [ $EXIT == 'YES' ]
   then
      exit 1
   fi
  
   PORT1=""
   for (( ; ; ))
   do
      PORT1=$(netstat -peanut | grep -i listen | grep -i $PORT)

      if [ -z "$PORT1" ]; then
         break
      else
         PORT=$[PORT + 1]
      fi
   done  
   echo "PORT "$PORT 

   RPCPORT1=""
   for (( ; ; ))
   do
      RPCPORT1=$(netstat -peanut | grep -i listen | grep -i $RPCPORT)

      if [ -z "$RPCPORT1" ]; then
         break
      else
         RPCPORT=$[RPCPORT + 1]
      fi
   done  
   echo "RPCPORT "$RPCPORT

   PRIVKEY=""
   echo ""
  
   if [[ "$COUNTER" -lt 2 ]]; then
      ALIASONE=$(echo $ALIAS)
   fi  
   echo "ALIASONE="$ALIASONE

   # Create scripts
   echo '#!/bin/bash' > ~/bin/${NAME}d_$ALIAS.sh
   echo "${NAME}d -daemon -conf=$CONF_DIR/${NAME}.conf -datadir=$CONF_DIR "'$*' >> ~/bin/${NAME}d_$ALIAS.sh
   echo "${NAME}-cli -conf=$CONF_DIR/${NAME}.conf -datadir=$CONF_DIR "'$*' > ~/bin/${NAME}-cli_$ALIAS.sh
   chmod 755 ~/bin/${NAME}*.sh

   mkdir -p $CONF_DIR
   echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> ${NAME}.conf_TEMP
   echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> ${NAME}.conf_TEMP
   echo "rpcallowip=127.0.0.1" >> ${NAME}.conf_TEMP
   echo "rpcport=$RPCPORT" >> ${NAME}.conf_TEMP
   echo "listen=1" >> ${NAME}.conf_TEMP
   echo "server=1" >> ${NAME}.conf_TEMP
   echo "daemon=1" >> ${NAME}.conf_TEMP
   echo "logtimestamps=1" >> ${NAME}.conf_TEMP
   echo "maxconnections=256" >> ${NAME}.conf_TEMP

   echo "" >> ${NAME}.conf_TEMP
   echo "port=$PORT" >> ${NAME}.conf_TEMP
  
   if [ -z "$PRIVKEY" ]; then
      echo ""
   else
      echo "masternode=1" >> ${NAME}.conf_TEMP
      echo "masternodeprivkey=$PRIVKEY" >> ${NAME}.conf_TEMP
   fi

   sudo ufw allow $PORT/tcp
   mv ${NAME}.conf_TEMP $CONF_DIR/monkey.conf
 
   if [ -z "$PRIVKEY" ]; then
	   PID=`ps -ef | grep -i ${NAME} | grep -i ${ALIASONE}/ | grep -v grep | awk '{print $2}'`
	
	   if [ -z "$PID" ]; then
         # start wallet
         sh ~/bin/${NAME}d_$ALIASONE.sh  
	      sleep 1
	   fi
  
	   for (( ; ; ))
	   do  
	      echo "Please wait ..."
         sleep 2
	      PRIVKEY=$(~/bin/monkey-cli_${ALIASONE}.sh masternode genkey)
	      echo "PRIVKEY=$PRIVKEY"
	      if [ -z "$PRIVKEY" ]; then
	         echo "PRIVKEY is null"
	      else
	         break
         fi
	   done
	
	   sleep 1
	
	   for (( ; ; ))
	   do
		   PID=`ps -ef | grep -i ${NAME} | grep -i ${ALIAS}/ | grep -v grep | awk '{print $2}'`
		   if [ -z "$PID" ]; then
		      echo ""
		   else
		      #STOP 
		      ~/bin/monkey-cli_$ALIAS.sh stop
		   fi
		   echo "Please wait ..."
		   sleep 2 # wait 2 seconds 
		   PID=`ps -ef | grep -i ${NAME} | grep -i ${ALIAS}/ | grep -v grep | awk '{print $2}'`
		   echo "PID="$PID	
		
		   if [ -z "$PID" ]; then
		      sleep 1 # wait 1 second
		      echo "masternode=1" >> $CONF_DIR/monkey.conf
		      echo "masternodeprivkey=$PRIVKEY" >> $CONF_DIR/monkey.conf
		      break
	      fi
	   done
   fi
  
   sleep 2
   PID=`ps -ef | grep -i ${NAME} | grep -i ${ALIAS}/ | grep -v grep | awk '{print $2}'`
   echo "PID="$PID
  
   if [ -z "$PID" ]; then
      echo ""
   else
      ~/bin/monkey-cli_$ALIAS.sh stop
	   sleep 2 # wait 2 seconds 
   fi	
  
   if [ -z "$PID" ]; then
      cd $CONF_DIR
      echo "Copy BLOCKCHAIN without conf files"
	   rm -R ./database &>/dev/null &
	   rm -R ./blocks	&>/dev/null &
	   rm -R ./sporks &>/dev/null &
	   rm -R ./chainstate &>/dev/null &
      cp $CONF_DIR_TMP/bootstrap.zip .
      unzip  bootstrap.zip
      rm ./bootstrap.zip
      sh ~/bin/${NAME}d_$ALIAS.sh		
      sleep 2 # wait 2 seconds 
   fi		  

  
   MNCONFIG=$(echo $ALIAS $IPONE:$PORT $PRIVKEY "txhash" "outputidx")
   echo $MNCONFIG >> ~/bin/masternode_config.txt
  
   if [[ ${REBOOTRESTART,,} =~ "y" ]] ; then
      (crontab -l 2>/dev/null; echo "@reboot sh ~/bin/${NAME}d_$ALIAS.sh") | crontab -
	   (crontab -l 2>/dev/null; echo "@reboot sh /root/bin/${NAME}d_$ALIAS.sh") | crontab -
	   sudo service cron reload
   fi
  
   COUNTER=$[COUNTER + 1]
done

if [ -d "$CONF_DIR_TMP" ]; then
   rm -rfd $CONF_DIR_TMP
fi

echo ""
echo -e "${YELLOW}****************************************************************"
echo -e "**Copy/Paste lines below in Hot wallet masternode.conf file**"
echo -e "**and replace txhash and outputidx with data from masternode outputs command**"
echo -e "**in hot wallet console**"
echo -e "**Tutorial: http://www.monkey.vision/ubuntu-masternodes/ **"
echo -e "****************************************************************${NC}"
echo -e "${RED}"
cat ~/bin/masternode_config.txt
echo -e "${NC}"
echo "****************************************************************"
echo ""
