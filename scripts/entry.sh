#!/bin/bash

# ==========================================
# 1. PRE-START: PERMISSIONS & INITIALIZATION
# ==========================================

# Define the server name file for use in paths
SERVERNAME_FILE="${SERVERNAME:-servertest}"

echo "*** INFO: Fixing permissions for volumes... ***"
# Fix ownership of the mounted volumes so the steam user can write to them
chown -R steam:steam "${HOMEDIR}/Zomboid"
chown -R steam:steam "${STEAMAPPDIR}"
# Ensure workshop folder exists and has correct permissions
mkdir -p "${HOMEDIR}/pz-dedicated/steamapps/workshop"
chown -R steam:steam "${HOMEDIR}/pz-dedicated/steamapps/workshop"
chmod 755 "${HOMEDIR}/Zomboid"

# Ensure the Server directory and .ini file exist so 'sed' commands do not fail
mkdir -p "${HOMEDIR}/Zomboid/Server/"
if [ ! -f "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini" ]; then
    echo "*** INFO: Initializing ${SERVERNAME_FILE}.ini... ***"
    touch "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
    chown steam:steam "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
fi

# Ensure spawnregions file exists (often used in the map logic below)
if [ ! -f "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_spawnregions.lua" ]; then
    touch "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_spawnregions.lua"
    chown steam:steam "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_spawnregions.lua"
fi

# ==========================================
# 2. RUNTIME INSTALL / UPDATE
# ==========================================

# This replaces the failing Dockerfile build step. 
# It downloads the game into the volume on the first run.
echo "*** INFO: Checking for game updates (App ID: ${STEAMAPPID})... ***"
su steam -c "bash ${STEAMCMDDIR}/steamcmd.sh +force_install_dir ${STEAMAPPDIR} +login anonymous +app_update ${STEAMAPPID} -beta ${STEAMAPPBRANCH} validate +quit"

# ==========================================
# 3. ORIGINAL SCRIPT LOGIC START
# ==========================================

cd ${STEAMAPPDIR}

# Force an update of steamclient.so if requested
if [ "${FORCESTEAMCLIENTSOUPDATE}" == "1" ] || [ "${FORCESTEAMCLIENTSOUPDATE,,}" == "true" ]; then
  echo "FORCESTEAMCLIENTSOUPDATE variable is set, updating steamclient.so in Zomboid's server"
  cp "${STEAMCMDDIR}/linux64/steamclient.so" "${STEAMAPPDIR}/linux64/steamclient.so"
  cp "${STEAMCMDDIR}/linux32/steamclient.so" "${STEAMAPPDIR}/steamclient.so"
fi

# Process the arguments in variables
ARGS=""

# Set the server memory
if [ -n "${MIN_MEMORY}" ] && [ -n "${MAX_MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MIN_MEMORY} -Xmx${MAX_MEMORY}"
elif [ -n "${MEMORY}" ]; then
  ARGS="${ARGS} -Xms${MEMORY} -Xmx${MEMORY}"
fi

# Option to perform a Soft Reset
if [ "${SOFTRESET}" == "1" ] || [ "${SOFTRESET,,}" == "true" ]; then
  ARGS="${ARGS} -Dsoftreset"
fi

# End of Java arguments
ARGS="${ARGS} -- "

# Game mode options
if [ "${COOP}" == "1" ] || [ "${COOP,,}" == "true" ]; then
  ARGS="${ARGS} -coop"
fi

if [ "${NOSTEAM}" == "1" ] || [ "${NOSTEAM,,}" == "true" ]; then
  ARGS="${ARGS} -nosteam"
fi

if [ -n "${CACHEDIR}" ]; then
  ARGS="${ARGS} -cachedir=${CACHEDIR}"
fi

if [ -n "${MODFOLDERS}" ]; then
  ARGS="${ARGS} -modfolders ${MODFOLDERS}"
fi

if [ "${DEBUG}" == "1" ] || [ "${DEBUG,,}" == "true" ]; then
  ARGS="${ARGS} -debug"
fi

if [ -n "${ADMINUSERNAME}" ]; then
  ARGS="${ARGS} -adminusername ${ADMINUSERNAME}"
fi

if [ -n "${ADMINPASSWORD}" ]; then
  ARGS="${ARGS} -adminpassword ${ADMINPASSWORD}"
fi

if [ -n "${SERVERNAME}" ]; then
  ARGS="${ARGS} -servername ${SERVERNAME}"
fi

# Handle Server Presets
if [ -n "${SERVERPRESET}" ]; then
  if [ ! -f "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" ]; then
    echo "*** ERROR: the preset ${SERVERPRESET} doesn't exists. ***"
    exit 1
  elif [ ! -f "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_SandboxVars.lua" ] || [ "${SERVERPRESETREPLACE,,}" == "true" ]; then
    echo "*** INFO: New server will be created using the preset ${SERVERPRESET} ***"
    mkdir -p "${HOMEDIR}/Zomboid/Server/"
    cp -nf "${STEAMAPPDIR}/media/lua/shared/Sandbox/${SERVERPRESET}.lua" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_SandboxVars.lua"
    sed -i "1s/return.*/SandboxVars = \{/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_SandboxVars.lua"
    dos2unix "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_SandboxVars.lua"
    chmod 644 "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_SandboxVars.lua"
  fi
fi

# Network configuration
if [ -n "${IP}" ]; then
  ARGS="${ARGS} ${IP} -ip ${IP}"
fi

if [ -n "${PORT}" ]; then
  ARGS="${ARGS} -port ${PORT}"
fi

if [ -n "${STEAMVAC}" ] && { [ "${STEAMVAC,,}" == "true" ] || [ "${STEAMVAC,,}" == "false" ]; }; then
  ARGS="${ARGS} -steamvac ${STEAMVAC,,}"
fi

if [ -n "${STEAMPORT1}" ]; then
  ARGS="${ARGS} -steamport1 ${STEAMPORT1}"
fi
if [ -n "${STEAMPORT2}" ]; then
  ARGS="${ARGS} -steamport2 ${STEAMPORT2}"
fi

# Apply .ini settings via sed
if [ -n "${PASSWORD}" ]; then
	sed -i "s/^Password=.*/Password=${PASSWORD}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
fi

if [ -n "${RCONPASSWORD}" ]; then
	sed -i "s/^RCONPassword=.*/RCONPassword=${RCONPASSWORD}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
fi

if [ "${PUBLIC}" == "1" ] || [ "${PUBLIC,,}" == "true" ]; then
  sed -i "s/^Public=.*/Public=true/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
elif [ "${PUBLIC}" == "0" ] || [ "${PUBLIC,,}" == "false" ]; then
  sed -i "s/^Public=.*/Public=false/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
fi

if [ -n "${DISPLAYNAME}" ]; then
  sed -i "s/^PublicName=.*/PublicName=${DISPLAYNAME}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
fi

# Mod Handling
if [ "${SELF_MANAGED_MODS}" == "1" ] || [ "${SELF_MANAGED_MODS,,}" == "true" ]; then
  echo "*** INFO: SELF_MANAGED_MODS is set; leaving Mods and WorkshopItems untouched ***"
else
  if [ -n "${MOD_IDS}" ]; then
    echo "*** INFO: Found Mods including ${MOD_IDS} ***"
    sed -i "s/Mods=.*/Mods=${MOD_IDS}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
  fi

  if [ -n "${WORKSHOP_IDS}" ]; then
    echo "*** INFO: Found Workshop IDs including ${WORKSHOP_IDS} ***"
    sed -i "s/WorkshopItems=.*/WorkshopItems=${WORKSHOP_IDS}/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
  else
    echo "*** INFO: Workshop IDs is empty, clearing configuration ***"
    sed -i 's/WorkshopItems=.*$/WorkshopItems=/' "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"
  fi
fi

# Workshop Map integration
sed -i 's/\r$//' /server/scripts/search_folder.sh
if [ -e "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600" ]; then
  map_list=""
  source /server/scripts/search_folder.sh "${HOMEDIR}/pz-dedicated/steamapps/workshop/content/108600"
  map_list=$(<"${HOMEDIR}/maps.txt")  
  rm "${HOMEDIR}/maps.txt"

  if [ -n "${map_list}" ]; then
    echo "*** INFO: Added maps including ${map_list} ***"
    sed -i "s/Map=.*/Map=${map_list}Muldraugh, KY/" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}.ini"

    IFS=";" read -ra strings <<< "$map_list"
    for string in "${strings[@]}"; do
        if ! grep -q "$string" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_spawnregions.lua"; then
          if [ -e "${HOMEDIR}/pz-dedicated/media/maps/$string/spawnpoints.lua" ]; then
            result="{ name = \"$string\", file = \"media/maps/$string/spawnpoints.lua\" },"
            sed -i "/function SpawnRegions()/,/return {/ {    /return {/ a\
            \\\t\t$result
            }" "${HOMEDIR}/Zomboid/Server/${SERVERNAME_FILE}_spawnregions.lua"
          fi
        fi
    done
  fi 
fi

# Fix library pathing
export LD_LIBRARY_PATH="${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}"

# Final ownership check before dropping privileges
chown -R steam:steam "${HOMEDIR}/Zomboid"
chown -R steam:steam "${STEAMAPPDIR}"

# ==========================================
# 4. START THE SERVER
# ==========================================
# We use 'exec su steam -c' to ensure the steam user runs the game 
# and the process correctly receives stop signals.
echo "*** INFO: Launching Project Zomboid Dedicated Server... ***"
exec su steam -c "export LANG=${LANG} && export LD_LIBRARY_PATH=\"${STEAMAPPDIR}/jre64/lib:${LD_LIBRARY_PATH}\" && cd ${STEAMAPPDIR} && ./start-server.sh ${ARGS}"