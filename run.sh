#!/bin/bash
ENV MY_CERT
ENV MY_CERT_NAME
RUN wget ${MY_CERT}
RUN mc ${MY_CERT} /usr/local/share/ca-certificates/
# COPY trust-certs/ /usr/local/share/ca-certificates/
RUN update-ca-certificates && \
    ls -1 /usr/local/share/ca-certificates | while read cert; do \
        openssl x509 -outform der -in /usr/local/share/ca-certificates/$cert -out $cert.der; \
        keytool -import -alias $cert -keystore /opt/java/openjdk/jre/lib/security/cacerts -trustcacerts -file $cert.der -storepass changeit -noprompt; \
        rm $cert.der; \
    done


## Installing requested packages
if [ "${PACKAGES}" != "" ]
then
  echo "Packages to install: "${PACKAGES}
  apt-get -q update &&\
  DEBIAN_FRONTEND="noninteractive" apt-get -q upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends &&\
  DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends ${PACKAGES} &&\  
  apt-get -q autoremove &&\
  apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin && rm -f /var/tmp/
else
  echo "Nothing to install."
fi

if [ -z "${BAMBOO_HOME}" ]
then
  cd $HOME
  BAMBOO_HOME=$HOME
else
  mkdir -p ${BAMBOO_HOME}
  cd ${BAMBOO_HOME}
fi
echo "BAMBOO_HOME: "${BAMBOO_HOME}

# Function used to validate if JAR File Exists
function validate_url(){
  if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]]
  then
    echo "true"
  fi
}

# Download Bamboo Agent
if [ -n ${AGENT_VERSION} ] && [ -n ${BAMBOO_SERVER} ]
then
  SLEEP="120"
  echo "Provided Data:"
  echo "AGENT_VERSION: "${AGENT_VERSION}
  echo "BAMBOO_SERVER: "${BAMBOO_SERVER}
  echo "BAMBOO_SERVER: "${BAMBOO_AGENT_INSTALLER_SERVER}
  echo "BAMBOO_SECURITY_TOKEN: "${BAMBOO_SECURITY_TOKEN}
  echo "BAMBOO_CAPABILITIES: " ${BAMBOO_CAPABILITIES}
  if [ -z "${BAMBOO_SECURITY_TOKEN}" ]
  then
    CONNECTION_STRING="${BAMBOO_SERVER}/agentServer/"
  else
    CONNECTION_STRING="${BAMBOO_SERVER}/agentServer/ -t ${BAMBOO_SECURITY_TOKEN}"
  fi
  echo "CONNECTION_STRING: "${CONNECTION_STRING}
  AGENT_JAR=${BAMBOO_AGENT_INSTALLER_SERVER}
  CHECK_AGENT_JAR=`validate_url $AGENT_JAR`
  echo "AGENT_JAR: "${AGENT_JAR}
  echo "###############################################"
  echo ""
  echo "Downloading Bamboo Agent from Bamboo Server: ${BAMBOO_SERVER}..."
  echo "Checking if Bambo Server is setup..."
  if [ ${CHECK_AGENT_JAR}=="true" ]
  then
    echo "Found Bamboo Agent at ${AGENT_JAR}"
    wget -c ${AGENT_JAR}
    if [ $? == "0" ]
    then
      if [ ! -z "${BAMBOO_CAPABILITIES}" ]
      then
        echo "bamboo-capabilities.properties will be created"
        mkdir -p ${BAMBOO_HOME}/bin
        echo "${BAMBOO_CAPABILITIES}" > ${BAMBOO_HOME}/bin/bamboo-capabilities.properties
      fi
      echo "Starting Bamboo Agent."
      java -Dbamboo.agent.ignoreServerCertName=true -Dbamboo.home=${BAMBOO_HOME} -jar atlassian-bamboo-agent-installer-${AGENT_VERSION}.jar ${CONNECTION_STRING}
      if [ $? != 0 ]
      then
        echo "JAR File corrupted. Downloading again..."
        rm -fv atlassian-bamboo-agent-installer*.jar
        wget -c ${AGENT_JAR}
        java -Dbamboo.agent.ignoreServerCertName=true -Dbamboo.home=${BAMBOO_HOME} -jar atlassian-bamboo-agent-installer-${AGENT_VERSION}.jar ${CONNECTION_STRING}
      fi
    else
      echo "Problem with downloading data from ${BAMBOO_SERVER}"
      echo "Could not find ${AGENT_JAR}"
      echo "Is Bambo Server already configured?"
      echo "Sleeping for ${SLEEP}s"
      sleep ${SLEEP}
    fi
  else
    echo "Waiting for a Bamboo Server Setup..."
    echo "Sleeping for ${SLEEP}s"
    sleep ${SLEEP}
  fi
else
  echo "Not all needed data was provided."
  echo "AGENT_VERSION: "${AGENT_VERSION}
  echo "BAMBOO_SERVER: "${BAMBOO_SERVER}
  echo "BAMBOO_SERVER_PORT: "${BAMBOO_SERVER_PORT}
  echo "BAMBOO_SECURITY_TOKEN: "${BAMBOO_SECURITY_TOKEN}
  echo "Exiting."
fi

