FROM lochnair/base:alpine-jre8

MAINTAINER Lochnair <me@lochnair.net>

LABEL Description="Docker image for CrashPlan"

EXPOSE 4242 4243

ARG CRASHPLAN_VER="4.8.0"

ENV FULL_CP "/app/lib/com.backup42.desktop.jar:/app/lang"
ENV MANIFESTDIR "/app/manifest"
ENV SRV_JAVA_OPTS "-Dfile.encoding=UTF-8 -Dapp=CrashPlanService -DappBaseName=CrashPlan -Xms20m -Xmx1024m -Dsun.net.inetaddr.ttl=300 -Dnetworkaddress.cache.ttl=300 -Dsun.net.inetaddr.negative.ttl=0 -Dnetworkaddress.cache.negative.ttl=0 -Dc42.native.md5.enabled=false"

# Install dependencies
RUN \
apk add \
	--no-cache \
	--update \
	coreutils \
	cpio \
	findutils \
	procps

# Remove initialization scripts we don't need
RUN \
rm /etc/cont-init.d/10-adduser && \
rm /etc/cont-init.d/90-fix-perms

# Download CrashPlan
RUN \
curl -L -o "/tmp/crashplan.tgz" "https://download.code42.com/installs/linux/install/CrashPlan/CrashPlan_${CRASHPLAN_VER}_Linux.tgz"

# Install CrashPlan
RUN \
tar xf "/tmp/crashplan.tgz" -C /tmp/ && \
cd /app && \
zcat "/tmp/crashplan-install/CrashPlan_${CRASHPLAN_VER}.cpi" | cpio -i && \
rm -rf /tmp/*

# Set correct manifest path
RUN \
sed -i "s|<manifestPath>.*</manifestPath>|<manifestPath>${MANIFESTDIR}</manifestPath>|g" ${TARGETDIR}/conf/default.service.xml && \
sed -i "s|<backupConfig>|<backupConfig>\n\t\t\t<manifestPath>${MANIFESTDIR}</manifestPath>|g" ${TARGETDIR}/conf/default.service.xml

# Bind the UI port 4243 to the container ip
RUN \
sed -i "s|</servicePeerConfig>|</servicePeerConfig>\n\t<serviceUIConfig>\n\t\t\
<serviceHost>0.0.0.0</serviceHost>\n\t\t<servicePort>4243</servicePort>\n\t\t\
<connectCheck>0</connectCheck>\n\t\t<showFullFilePath>false</showFullFilePath>\n\t\
</serviceUIConfig>|g" /app/conf/default.service.xml

RUN \
mkdir /data

VOLUME /config
VOLUME /data