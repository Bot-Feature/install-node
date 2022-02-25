#!/bin/bash
set -e

lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

OS=`lowercase \`uname\``

OS=`uname`
if [ "${OS}" = "Linux" ] ; then
    if [ -f /etc/redhat-release ] ; then
        DIST=`cat /etc/redhat-release |sed s/\ release.*//`
        REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
    elif [ -f /etc/debian_version ] ; then
        DIST=`cat /etc/os-release | grep '^ID' | awk -F=  '{ print $2 }'`
        REV=`cat /etc/os-release | grep '^VERSION_ID' | awk -F=  '{ print $2 }' | cut -d '"' -f 2`
    else
      echo -e "\e[31mNo compatible OS found\e[0m"
      exit 1
    fi

    if [ -f /etc/UnitedLinux-release ] ; then
        DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
    fi

    DIST=`lowercase $DIST`
    REV=`lowercase $REV`
else
  echo -e "\e[31mPlease use a Linux distribution\e[0m"
  exit 1
fi

# Update repositories list
apt update && apt upgrade -y

# Install dependencies
apt -y install git libopus-dev ffmpeg youtube-dl apt-transport-https wget sudo

# Load repositories of dotnet
wget "https://packages.microsoft.com/config/${DIST}/${REV}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb

# Update all dependencies
apt update

# Install dotnet
apt -y install dotnet-sdk-3.1

# Go into the base path, clone TS3Audiobot and navigate to folder
cd /opt && git clone https://github.com/Bot-Feature/TS3AudioBot.git && cd TS3AudioBot

# Build bot with dotnet
dotnet build --framework netcoreapp3.1 --configuration Release TS3AudioBot

echo -e "Please enter you Teamspeak Hostname/IP Address: "
read address

echo -e "Please enter a Server password (leave blank for no password): "
read serverpassword

# Add getmy uid permissions for first start
echo "[[rule]]
\"+\" = [
        # Basic stuff
        \"cmd.getmy.*\"
]" > /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/rights.toml

# Add bots and default bot directory
mkdir /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/bots
mkdir /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/bots/default

# Add default Bot config
echo "#Starts the instance when the TS3AudioBot is launched.
      run = true

      [commands]

      [commands.alias]

      [connect]
      #The server password. Leave empty for none.
      server_password = { pw = \"${serverpassword}\" }
      #The default channel password. Leave empty for none.
      channel_password = {  }
      #Overrides the displayed version for the ts3 client. Leave empty for default.
      client_version = {  }
      #The address, ip or nickname (and port; default: 9987) of the TeamSpeak3 server
      address = \"${address}\"

      [connect.identity]
      #||| DO NOT MAKE THIS KEY PUBLIC ||| The client identity. You can import a teamspeak3 identity here too.
      key = \"\"
      #The client identity offset determining the security level.
      offset = 26

      [reconnect]

      [audio]
      #When a new song starts the volume will be trimmed to between min and max.
      #When the current volume already is between min and max nothing will happen.
      #To completely or partially disable this feature, set min to 0 and/or max to 100.
      volume = {  }

      [playlists]

      [history]

      [events]" > /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/bots/default/bot.toml

# Execute after build
echo -e "\e[33mWrite the bot with !getmy uid private and copy the output. Then you have to press ctrl+c and paste the copied UID.\e[0m"
cd /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/ && dotnet TS3AudioBot.dll

echo -e "Please paste your copied UID here: "
read uid

# Set permissions for api token creation after first start
echo "[[rule]]
        # Set your admin Group Ids here, ex: [ 13, 42 ]
        groupid = []
        # And/Or your admin Client Uids here
        useruid = [ \"${uid}\" ]
        # By default treat requests from localhost as admin
        ip = [ \"127.0.0.1\", \"::1\" ]

        \"+\" = \"*\"" > /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/rights.toml

# Create service file
echo "[Unit]
Description=\"TS3AudioBot\"

[Service]
ExecStart=/usr/bin/dotnet TS3AudioBot.dll
WorkingDirectory=/opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=TS3AudioBot

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/ts3audiobot.service

# Enable service
systemctl enable ts3audiobot

# Reload daemon
systemctl daemon-reload

# Start ts3audiobot with the created service
systemctl start ts3audiobot

# Installing dependencies of youtube-dl
apt -y install python

# Download youtube-dl
sudo curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
sudo chmod a+rx /usr/local/bin/youtube-dl

# Now we configure the ts3audiobot
echo "#! IMPORTANT !
#All config tables here starting with 'bot.*' will only be used as default values for each bot.
#To make bot-instance specific changes go to the 'Bots' folder (configs.bots_path) and set your configuration values in the desired bot config.
[bot]
#This field will be automatically set when you call '!bot setup'.
#The bot will use the specified group to set/update the required permissions and add himself into it.
#You can set this field manually if you already have a preexisting group the bot should add himself to.
bot_group_id = 0
#Tries to fetch a cover image when playing.
generate_status_avatar = true
#Sets the description of the bot to the current song title.
set_status_description = true
#The language the bot should use to respond to users. (Make sure you have added the required language packs)
language = \"en\"
#Starts the instance when the TS3AudioBot is launched.
run = false

[bot.commands]
#Defines how the bot tries to match your !commands. Possible types:
# - exact : Only when the command matches exactly.
# - substring : The shortest command starting with the given prefix.
# - ic3 : 'interleaved continuous character chain' A fuzzy algorithm similar to hamming distance but preferring characters at the start.
matcher = \"ic3\"
#Defines how the bot handles messages which are too long for a single ts3 message. Options are:
# - split : The message will be split up into multiple messages.
# - drop : Does not send the message.
long_message = \"Split\"
#Limits the split count for long messages. When for example set to 1 the message will simply be trimmed to one message.
long_message_split_limit = 1
#Enables colors and text highlights for respones.
color = true
#Limits the maximum command complexity to prevent endless loops.
command_complexity = 64

[bot.commands.alias]

[bot.connect]
#The server password. Leave empty for none.
server_password = { pw = \"\", hashed = false, autohash = false }
#The default channel password. Leave empty for none.
channel_password = { pw = \"\", hashed = false, autohash = false }
#Overrides the displayed version for the ts3 client. Leave empty for default.
client_version = { build = \"\", platform = \"\", sign = \"\" }
#The address, ip or nickname (and port; default: 9987) of the TeamSpeak3 server
address = \"\"
#Default channel when connecting. Use a channel path or \"/<id>\".
#Examples: \"Home/Lobby\", \"/5\", \"Home/Afk \\/ Not Here\".
channel = \"\"
#The client badges. You can set a comma seperated string with max three GUID's. Here is a list: http://yat.qa/ressourcen/abzeichen-badges/
badges = \"\"
#Client nickname when connecting.
name = \"TS3AudioBot\"

[bot.connect.identity]
#||| DO NOT MAKE THIS KEY PUBLIC ||| The client identity. You can import a teamspeak3 identity here too.
key = \"\"
#The client identity offset determining the security level.
offset = 0
#The client identity security level which should be calculated before connecting
#or -1 to generate on demand when connecting.
level = -1

[bot.reconnect]
ontimeout = [\"1s\", \"2s\", \"5s\", \"10s\", \"30s\", \"1m\", \"5m\", \"repeat last\"]
onkick = []
onban = []
onerror = [\"30s\", \"repeat last\"]
onshutdown = [\"5m\"]

[bot.audio]
#When a new song starts the volume will be trimmed to between min and max.
#When the current volume already is between min and max nothing will happen.
#To completely or partially disable this feature, set min to 0 and/or max to 100.
volume = { default = 50.0, min = 25.0, max = 75.0 }
#The maximum volume a normal user can request. Only user with the 'ts3ab.admin.volume' permission can request higher volumes.
max_user_volume = 100.0
#Specifies the bitrate (in kbps) for sending audio.
#Values between 8 and 98 are supported, more or less can work but without guarantees.
#Reference values: 16 - very poor (~3KiB/s), 24 - poor (~4KiB/s), 32 - okay (~5KiB/s), 48 - good (~7KiB/s), 64 - very good (~9KiB/s), 96 - deluxe (~13KiB/s)
bitrate = 48
#How the bot should play music. Options are:
# - whisper : Whispers to the channel where the request came from. Other users can join with '!subscribe'.
# - voice : Sends via normal voice to the current channel. '!subscribe' will not work in this mode.
# - !... : A custom command. Use '!xecute (!a) (!b)' for example to execute multiple commands.
send_mode = \"voice\"

[bot.playlists]

[bot.history]
#Enable or disable history features completely to save resources.
enabled = true
#Whether or not deleted history ids should be filled up with new songs.
fill_deleted_ids = true

[bot.events]
#Called when the bot is connected.
onconnect = \"\"
#Called when the bot gets disconnected.
ondisconnect = \"\"
#Called when the bot does not play anything for a certain amount of time.
onidle = \"\"
#Specifies how long the bot has to be idle until the 'onidle' event gets fired.
#You can specify the time in the ISO-8601 format \"PT30S\" or like: 15s, 1h, 3m30s
idletime = \"0s\"
#Called when the last client leaves the channel of the bot. Delay can be specified
onalone = \"\"
#Specifies how long the bot has to be alone until the 'onalone' event gets fired.
#You can specify the time in the ISO-8601 format \"PT30S\" or like: 15s, 1h, 3m30s
alone_delay = \"0s\"
#Called when the bot was alone and a client joins his channel. Delay can be specified.
onparty = \"\"
#Specifies how long the bot has to be alone until the 'onalone' event gets fired.
#You can specify the time in the ISO-8601 format \"PT30S\" or like: 15s, 1h, 3m30s
party_delay = \"0s\"
#Called when a new song starts.
onsongstart = \"\"

[configs]
#Path to a folder where the configuration files for each bot template will be stored.
bots_path = \"bots\"
#Enable to contribute to the global stats tracker to help us improve our service.
#We do NOT send/store any IPs, identifiable information or logs for this.
#If you want to check how a stats packet looks like you can run the bot with 'TS3AudioBot --stats-example'.
#To disable contributing without config you can run the bot with 'TS3AudioBot --stats-disabled'. This will ignore the config value.
send_stats = true

[db]
#The path to the database file for persistent data.
path = \"ts3audiobot.db\"

[factories]
#The default path to look for local resources.
media = { path = \"\" }

[factories.youtube]
#Changes how to try to resolve youtube songs
# - youtubedl : uses youtube-dl only
# - internal : uses the internal resolver, then youtube-dl
prefer_resolver = \"YoutubeDl\"
#Set your own youtube api key to keep using the old youtube factory loader.
#This feature is unsupported and may break at any time
youtube_api_key = \"\"

[tools]
#Path to the youtube-dl binary or local git repository.
youtube-dl = { path = \"/usr/local/bin/youtube-dl\" }

#The path to ffmpeg.
[tools.ffmpeg]
path = \"ffmpeg\"

[rights]
#Path to the permission file. The file will be generated if it doesn't exist.
path = \"rights.toml\"

[plugins]
#The path to the plugins folder.
path = \"plugins\"

[plugins.load]

[web]
#An array of all urls the web api should be possible to be accessed with.
hosts = [\"*\"]
#The port for the web server.
port = 58913

[web.api]
#If you want to enable the web api.
enabled = true
#Limits the maximum command complexity to prevent endless loops.
command_complexity = 64
#See: bot.commands.matcher
matcher = \"exact\"

[web.interface]
#If you want to enable the webinterface.
enabled = false
#The webinterface folder to host. Leave empty to let the bot look for default locations.
path = \"\"" > /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/ts3audiobot.toml

echo -e "\e[33mNow you can write to the bot again with !api token. Copy the output and save it securely.\e[0m Then to complete the installation enter \"y\""
read copiedtoken

# If api token is copied, than delete default bot
if [ "${copiedtoken}" == "y" ]; then
    rm -r /opt/TS3AudioBot/TS3AudioBot/bin/Release/netcoreapp3.1/bots/default
    systemctl restart ts3audiobot
fi