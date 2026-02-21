###########################################################
# Dockerfile that builds a Project Zomboid Gameserver
###########################################################
FROM cm2network/steamcmd:root

LABEL maintainer="daniel.carrasco@electrosoftcloud.com"

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
# Fix for a new installation problem in the Steamcmd client
ENV HOME="${HOMEDIR}"

# Receive the value from docker-compose as an ARG
ARG STEAMAPPBRANCH="public"
# Promote the ARG value to an ENV for runtime
ENV STEAMAPPBRANCH=$STEAMAPPBRANCH

# 1. Install required packages and set up locales
RUN apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
  dos2unix \
  && sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen \
  && locale-gen \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# 2. Pre-create directories and fix permissions as ROOT
RUN mkdir -p "${STEAMAPPDIR}" "${HOMEDIR}/Zomboid" "/server/scripts" \
    && chown -R "${USER}:${USER}" "${STEAMAPPDIR}" "${HOMEDIR}/Zomboid" "/server/scripts"

# 3. Switch to the 'steam' user to perform the download
# This prevents permission mismatch (Exit Code 8) during disk writes
USER ${USER}

# 4. Download Project Zomboid
RUN bash "${STEAMCMDDIR}/steamcmd.sh" \
  +force_install_dir "${STEAMAPPDIR}" \
  +login anonymous \
  +app_update "${STEAMAPPID}" -beta "${STEAMAPPBRANCH}" validate \
  +quit

# 5. Switch back to ROOT to copy scripts and set final permissions
USER root

# Copy the entry point files
COPY --chown=${USER}:${USER} scripts/entry.sh /server/scripts/entry.sh
COPY --chown=${USER}:${USER} scripts/search_folder.sh /server/scripts/search_folder.sh

# Ensure scripts are executable
RUN chmod 550 /server/scripts/entry.sh /server/scripts/search_folder.sh

WORKDIR ${HOMEDIR}

# Expose ports
EXPOSE 16261-16262/udp \
  27015/tcp

# Switch back to the steam user for security before running the app
USER ${USER}

ENTRYPOINT ["/server/scripts/entry.sh"]