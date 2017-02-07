FROM lochnair/base:alpine-glibc

MAINTAINER Lochnair <me@lochnair.net>

LABEL Description="Docker image for CrashPlan"

EXPOSE 4242 4243

ARG CRASHPLAN_VER="4.8.0"

ENV FULL_CP "/app/lib/com.backup42.desktop.jar:/app/lang:/app"
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
	paxctl \
	procps

# Install Oracle Server JRE 8
RUN \
curl -o "/tmp/java.tar.gz" -fLH "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/server-jre-8u121-linux-x64.tar.gz" && \
mkdir -p /opt/jre && \
tar --strip-components=1 -xf /tmp/java.tar.gz -C /opt/jre && \
# Disable PaX MPROTECT
paxctl -c /opt/jre/bin/java && \
paxctl -m /opt/jre/bin/java

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
cp /tmp/crashplan-install/scripts/run.conf /app/bin/ && \
rm -rf /tmp/*

# Set correct manifest path
RUN \
sed -i "s|<manifestPath>.*</manifestPath>|<manifestPath>${MANIFESTDIR}</manifestPath>|g" /app/conf/default.service.xml && \
sed -i "s|<backupConfig>|<backupConfig>\n\t\t\t<manifestPath>${MANIFESTDIR}</manifestPath>|g" /app/conf/default.service.xml

# Bind the UI port 4243 to the container ip
RUN \
sed -i "s|</servicePeerConfig>|</servicePeerConfig>\n\t<serviceUIConfig>\n\t\t\
<serviceHost>0.0.0.0</serviceHost>\n\t\t<servicePort>4243</servicePort>\n\t\t\
<connectCheck>0</connectCheck>\n\t\t<showFullFilePath>false</showFullFilePath>\n\t\
</serviceUIConfig>|g" /app/conf/default.service.xml

# Move configuration to /config
RUN \
mv /app/conf /config/conf

# Create configuration symlinks
RUN \
ln -sf /config/conf /app/conf && \
ln -sf /config /var/lib/crashplan

RUN \
mkdir /data

VOLUME /config
VOLUME /data

COPY root/ /