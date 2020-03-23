# Bamboo Server

FROM adoptopenjdk:8-jdk-hotspot-bionic
LABEL maintainer="Devanathan Kandhasamy" \
      description="Bamboo Agent Docker Image"

ENV BAMBOO_USER=bamboo
ENV BAMBOO_GROUP=bamboo


RUN set -x && \
     apt-get update && \
     apt-get install maven -y && \
     apt-get install nodejs -y && \
     apt-get install git -y && \
     apt-get install -y --no-install-recommends curl && \
     mkdir -m 755 -p /usr/lib/jvm && \
     ln -s "${JAVA_HOME}" /usr/lib/jvm/java-8-openjdk-amd64 && \
     rm -rf /var/lib/apt/lists/*

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Environment
# ENV HOME /root/

# Expose web and agent ports
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add runit service
ADD run.sh /run.sh
ADD trust-certs trust-certs
RUN chmod +x /*.sh

# Add locales after locale-gen as needed
# Upgrade packages on image
# Install JDK 8 (latest edition), SVN, git  and wget
RUN locale-gen en_US.UTF-8 &&\
    apt-get -q update &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends openjdk-8-jdk &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y subversion wget git --no-install-recommends &&\
    apt-get -q autoremove &&\
    apt-get install ca-certificates -y &&\
    rm -rf /var/cache/apk/* &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin && rm -f /var/tmp/*

COPY trust-certs/ /usr/local/share/ca-certificates/
RUN update-ca-certificates && \
    ls -1 /usr/local/share/ca-certificates | while read cert; do \
        openssl x509 -outform der -in /usr/local/share/ca-certificates/$cert -out $cert.der; \
        /java/bin/keytool -import -alias $cert -keystore /java/jre/lib/security/cacerts -trustcacerts -file $cert.der -storepass changeit -noprompt; \
        rm $cert.der; \
    done

CMD ["/run.sh"]
