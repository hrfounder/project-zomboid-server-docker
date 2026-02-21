FROM cm2network/steamcmd:root

LABEL maintainer="daniel.carrasco@electrosoftcloud.com"

ENV STEAMAPPID=380870
ENV STEAMAPP=pz
ENV STEAMAPPDIR="${HOMEDIR}/${STEAMAPP}-dedicated"
ENV HOME="${HOMEDIR}"

# Install dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends --no-install-suggests \
  dos2unix locales \
  && sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen \
  && locale-gen \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p "${STEAMAPPDIR}" "${HOMEDIR}/Zomboid" "/server/scripts" \
    && chown -R "${USER}:${USER}" "${STEAMAPPDIR}" "${HOMEDIR}/Zomboid" "/server/scripts"

# Copy scripts
COPY --chown=${USER}:${USER} scripts/entry.sh /server/scripts/entry.sh
COPY --chown=${USER}:${USER} scripts/search_folder.sh /server/scripts/search_folder.sh

# Ensure scripts are executable and fix line endings
RUN dos2unix /server/scripts/entry.sh /server/scripts/search_folder.sh \
    && chmod +x /server/scripts/entry.sh /server/scripts/search_folder.sh

WORKDIR ${HOMEDIR}
EXPOSE 16261-16262/udp 27015/tcp

# START AS ROOT to allow the entry script to fix permissions
USER root

ENTRYPOINT ["/server/scripts/entry.sh"]