#!/bin/sh

# Wazuh Installer Functions
# Copyright (C) 2016 Wazuh Inc.
# November 18, 2016.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

# File dependencies:
# ./src/init/shared.sh
# ./src/init/template-select.sh

## Templates
. ./src/init/template-select.sh

HEADER_TEMPLATE="./etc/templates/config/generic/header-comments.template"
GLOBAL_TEMPLATE="./etc/templates/config/generic/global.template"
GLOBAL_AR_TEMPLATE="./etc/templates/config/generic/global-ar.template"

RULES_TEMPLATE="./etc/templates/config/generic/rules.template"
AR_COMMANDS_TEMPLATE="./etc/templates/config/generic/ar-commands.template"
AR_DEFINITIONS_TEMPLATE="./etc/templates/config/generic/ar-definitions.template"
ALERTS_TEMPLATE="./etc/templates/config/generic/alerts.template"
LOGGING_TEMPLATE="./etc/templates/config/generic/logging.template"
REMOTE_SEC_TEMPLATE="./etc/templates/config/generic/remote-secure.template"
REMOTE_SYS_TEMPLATE="./etc/templates/config/generic/remote-syslog.template"

LOCALFILES_TEMPLATE="./etc/templates/config/generic/localfile-logs/*.template"

AUTH_TEMPLATE="./etc/templates/config/generic/auth.template"

##########
# WriteSyscheck()
##########
WriteSyscheck()
{
    # Adding to the config file
    if [ "X$SYSCHECK" = "Xyes" ]; then
      SYSCHECK_TEMPLATE=$(GetTemplate "syscheck.$1.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      if [ "$SYSCHECK_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
        SYSCHECK_TEMPLATE=$(GetTemplate "syscheck.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      fi
      cat ${SYSCHECK_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    else
      if [ "$1" = "manager" ]; then
        echo "  <syscheck>" >> $NEWCONFIG
        echo "    <disabled>yes</disabled>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
        echo "    <scan_on_start>yes</scan_on_start>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
        echo "    <!-- Generate alert when new file detected -->" >> $NEWCONFIG
        echo "    <alert_new_files>yes</alert_new_files>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
        echo "  </syscheck>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
      else
        echo "  <syscheck>" >> $NEWCONFIG
        echo "    <disabled>yes</disabled>" >> $NEWCONFIG
        echo "  </syscheck>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
      fi
    fi
}


##########
# WriteRootcheck()
##########
WriteRootcheck()
{
    # Adding to the config file
    if [ "X$ROOTCHECK" = "Xyes" ]; then
      ROOTCHECK_TEMPLATE=$(GetTemplate "rootcheck.$1.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      if [ "$ROOTCHECK_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
        ROOTCHECK_TEMPLATE=$(GetTemplate "rootcheck.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      fi
      sed -e "s|\${INSTALLDIR}|$INSTALLDIR|g" "${ROOTCHECK_TEMPLATE}" >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    else
      echo "  <rootcheck>" >> $NEWCONFIG
      echo "    <disabled>yes</disabled>" >> $NEWCONFIG
      echo "  </rootcheck>" >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi
}

##########
# WriteOpenSCAP()
##########
WriteOpenSCAP()
{
    # Adding to the config file
    if [ "X$OPENSCAP" = "Xyes" ]; then
      OPENSCAP_TEMPLATE=$(GetTemplate "wodle-openscap.$1.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      if [ "$OPENSCAP_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
        OPENSCAP_TEMPLATE=$(GetTemplate "wodle-openscap.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
      fi
      cat ${OPENSCAP_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi
}


##########
# WriteLogs()
##########
WriteLogs()
{
  LOCALFILES_TMP=`cat ${LOCALFILES_TEMPLATE}`
  for i in ${LOCALFILES_TMP}; do
      field1=$(echo $i | cut -d\: -f1)
      field2=$(echo $i | cut -d\: -f2)
      field3=$(echo $i | cut -d\: -f3)
      if [ "X$field1" = "Xskip_check_exist" ]; then
          SKIP_CHECK_FILE="yes"
          LOG_FORMAT="$field2"
          FILE="$field3"
      else
          SKIP_CHECK_FILE="no"
          LOG_FORMAT="$field1"
          FILE="$field2"
      fi

      # Check installation directory
      if [ $(echo $FILE | grep "INSTALL_DIR") ]; then
        FILE=$(echo $FILE | sed -e "s|INSTALL_DIR|${INSTALLDIR}|g")
      fi

      # If log file present or skip file
      if [ -f "$FILE" ] || [ "X$SKIP_CHECK_FILE" = "Xyes" ]; then
        if [ "$1" = "echo" ]; then
          echo "    -- $FILE"
        elif [ "$1" = "add" ]; then
          echo "  <localfile>" >> $NEWCONFIG
          if [ "$FILE" = "snort" ]; then
            head -n 1 $FILE|grep "\[**\] "|grep -v "Classification:" > /dev/null
            if [ $? = 0 ]; then
              echo "    <log_format>snort-full</log_format>" >> $NEWCONFIG
            else
              echo "    <log_format>snort-fast</log_format>" >> $NEWCONFIG
            fi
          else
            echo "    <log_format>$LOG_FORMAT</log_format>" >> $NEWCONFIG
          fi
          echo "    <location>$FILE</location>" >>$NEWCONFIG
          echo "  </localfile>" >> $NEWCONFIG
          echo "" >> $NEWCONFIG
        fi
      fi
  done
}

##########
# SetHeaders() 1-agent|manager|local
##########
SetHeaders()
{
    HEADERS_TMP="/tmp/wazuh-headers.tmp"
    if [ "$DIST_VER" = "0" ]; then
        sed -e "s/TYPE/$1/g; s/DISTRIBUTION/${DIST_NAME}/g; s/VERSION//g" "$HEADER_TEMPLATE" > $HEADERS_TMP
    else
      if [ "$DIST_SUBVER" = "0" ]; then
        sed -e "s/TYPE/$1/g; s/DISTRIBUTION/${DIST_NAME}/g; s/VERSION/${DIST_VER}/g" "$HEADER_TEMPLATE" > $HEADERS_TMP
      else
        sed -e "s/TYPE/$1/g; s/DISTRIBUTION/${DIST_NAME}/g; s/VERSION/${DIST_VER}.${DIST_SUBVER}/g" "$HEADER_TEMPLATE" > $HEADERS_TMP
      fi
    fi
    cat $HEADERS_TMP
    rm -f $HEADERS_TMP
}

##########
# Generate the ossec-init.conf
##########
GenerateInitConf()
{
    NEWINIT="./ossec-init.conf.temp"
    echo "DIRECTORY=\"${INSTALLDIR}\"" > ${NEWINIT}
    echo "NAME=\"${NAME}\"" >> ${NEWINIT}
    echo "VERSION=\"${VERSION}\"" >> ${NEWINIT}
    echo "REVISION=\"${REVISION}\"" >> ${NEWINIT}
    echo "DATE=\"`date`\"" >> ${NEWINIT}
    echo "TYPE=\"${INSTYPE}\"" >> ${NEWINIT}
    cat "$NEWINIT"
    rm "$NEWINIT"
}

##########
# WriteAgent() $1="no_locafiles" or empty
##########
WriteAgent()
{
    NO_LOCALFILES=$1

    HEADERS=$(SetHeaders "Agent")
    echo "$HEADERS" > $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "<ossec_config>" >> $NEWCONFIG
    echo "  <client>" >> $NEWCONFIG
    echo "    <server>" >> $NEWCONFIG
    if [ "X${HNAME}" = "X" ]; then
      echo "      <address>$SERVER_IP</address>" >> $NEWCONFIG
    else
      echo "      <address>$HNAME</address>" >> $NEWCONFIG
    fi
    echo "      <port>1514</port>" >> $NEWCONFIG
    echo "      <protocol>udp</protocol>" >> $NEWCONFIG
    echo "    </server>" >> $NEWCONFIG
    if [ "X${USER_AGENT_CONFIG_PROFILE}" != "X" ]; then
         PROFILE=${USER_AGENT_CONFIG_PROFILE}
         echo "    <config-profile>$PROFILE</config-profile>" >> $NEWCONFIG
    else
      if [ "$DIST_VER" = "0" ]; then
        echo "    <config-profile>$DIST_NAME</config-profile>" >> $NEWCONFIG
      else
        if [ "$DIST_SUBVER" = "0" ]; then
          echo "    <config-profile>$DIST_NAME, $DIST_NAME$DIST_VER</config-profile>" >> $NEWCONFIG
        else
          echo "    <config-profile>$DIST_NAME, $DIST_NAME$DIST_VER, $DIST_NAME$DIST_VER.$DIST_SUBVER</config-profile>" >> $NEWCONFIG
        fi
      fi
    fi
    echo "    <notify_time>10</notify_time>" >> $NEWCONFIG
    echo "    <time-reconnect>60</time-reconnect>" >> $NEWCONFIG
    echo "    <auto_restart>yes</auto_restart>" >> $NEWCONFIG
    echo "  </client>" >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "  <client_buffer>" >> $NEWCONFIG
    echo "    <!-- Agent buffer options -->" >> $NEWCONFIG
    echo "    <disable>no</disable>" >> $NEWCONFIG
    echo "    <queue_size>5000</queue_size>" >> $NEWCONFIG
    echo "    <events_per_second>500</events_per_second>" >> $NEWCONFIG
    echo "  </client_buffer>" >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Rootcheck
    WriteRootcheck "agent"

    # OpenSCAP
    WriteOpenSCAP "agent"

    # Syscheck
    WriteSyscheck "agent"

    # Write the log files
    if [ "X${NO_LOCALFILES}" = "X" ]; then
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
      WriteLogs "add"
    else
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
    fi

    # Localfile commands
    LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.agent.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    if [ "$LOCALFILE_COMMANDS_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
      LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    fi
    cat ${LOCALFILE_COMMANDS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "  <!-- Active response -->" >> $NEWCONFIG

    echo "  <active-response>" >> $NEWCONFIG
    if [ "X$ACTIVERESPONSE" = "Xyes" ]; then
        echo "    <disabled>no</disabled>" >> $NEWCONFIG
    else
        echo "    <disabled>yes</disabled>" >> $NEWCONFIG
    fi
    echo "    <ca_store>${INSTALLDIR}/etc/wpk_root.pem</ca_store>" >> $NEWCONFIG

    if [ -n "$CA_STORE" ]
    then
        echo "    <ca_store>${CA_STORE}</ca_store>" >> $NEWCONFIG
    fi

    echo "  </active-response>" >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Logging format
    cat ${LOGGING_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "</ossec_config>" >> $NEWCONFIG
}


##########
# WriteManager() $1="no_locafiles" or empty
##########
WriteManager()
{
    NO_LOCALFILES=$1

    HEADERS=$(SetHeaders "Manager")
    echo "$HEADERS" > $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "<ossec_config>" >> $NEWCONFIG

    if [ "$EMAILNOTIFY" = "yes"   ]; then
        sed -e "s|<email_notification>no</email_notification>|<email_notification>yes</email_notification>|g; \
        s|<smtp_server>smtp.example.wazuh.com</smtp_server>|<smtp_server>${SMTP}</smtp_server>|g; \
        s|<email_from>ossecm@example.wazuh.com</email_from>|<email_from>ossecm@${HOST}</email_from>|g; \
        s|<email_to>recipient@example.wazuh.com</email_to>|<email_to>${EMAIL}</email_to>|g;" "${GLOBAL_TEMPLATE}" >> $NEWCONFIG
    else
        cat ${GLOBAL_TEMPLATE} >> $NEWCONFIG
    fi
    echo "" >> $NEWCONFIG

    # Alerts level
    cat ${ALERTS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Logging format
    cat ${LOGGING_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Remote connection secure
    if [ "X$RLOG" = "Xyes" ]; then
      cat ${REMOTE_SYS_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi

    # Remote connection syslog
    if [ "X$SLOG" = "Xyes" ]; then
      cat ${REMOTE_SEC_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi

    # Write rootcheck
    WriteRootcheck "manager"

    # Write OpenSCAP
    WriteOpenSCAP "manager"

    # Write syscheck
    WriteSyscheck "manager"

    # Active response
    if [ "$SET_WHITE_LIST"="true" ]; then
       sed -e "/  <\/global>/d" "${GLOBAL_AR_TEMPLATE}" >> $NEWCONFIG
      # Nameservers in /etc/resolv.conf
      for ip in ${NAMESERVERS} ${NAMESERVERS2};
        do
          if [ ! "X${ip}" = "X" ]; then
              echo "    <white_list>${ip}</white_list>" >>$NEWCONFIG
          fi
      done
      # Read string
      for ip in ${IPS};
        do
          if [ ! "X${ip}" = "X" ]; then
            echo $ip | grep -E "^[0-9./]{5,20}$" > /dev/null 2>&1
            if [ $? = 0 ]; then
              echo "    <white_list>${ip}</white_list>" >>$NEWCONFIG
            fi
          fi
        done
        echo "  </global>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
    else
      cat ${GLOBAL_AR_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi

    cat ${AR_COMMANDS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG
    cat ${AR_DEFINITIONS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Write the log files
    if [ "X${NO_LOCALFILES}" = "X" ]; then
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
      WriteLogs "add"
    else
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
    fi

    # Localfile commands
    LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.manager.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    if [ "$LOCALFILE_COMMANDS_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
      LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    fi
    cat ${LOCALFILE_COMMANDS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Writting rules configuration
    cat ${RULES_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Writting auth configuration
    cat ${AUTH_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "</ossec_config>" >> $NEWCONFIG
}

##########
# WriteLocal() $1="no_locafiles" or empty
##########
WriteLocal()
{
    NO_LOCALFILES=$1

    HEADERS=$(SetHeaders "Local")
    echo "$HEADERS" > $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "<ossec_config>" >> $NEWCONFIG

    if [ "$EMAILNOTIFY" = "yes"   ]; then
        sed -e "s|<email_notification>no</email_notification>|<email_notification>yes</email_notification>|g; \
        s|<smtp_server>smtp.example.wazuh.com</smtp_server>|<smtp_server>${SMTP}</smtp_server>|g; \
        s|<email_from>ossecm@example.wazuh.com</email_from>|<email_from>ossecm@${HOST}</email_from>|g; \
        s|<email_to>recipient@example.wazuh.com</email_to>|<email_to>${EMAIL}</email_to>|g;" "${GLOBAL_TEMPLATE}" >> $NEWCONFIG
    else
        cat ${GLOBAL_TEMPLATE} >> $NEWCONFIG
    fi
    echo "" >> $NEWCONFIG

    # Alerts level
    cat ${ALERTS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Logging format
    cat ${LOGGING_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Write rootcheck
    WriteRootcheck "manager"

    # Write OpenSCAP
    WriteOpenSCAP "manager"

    # Write syscheck
    WriteSyscheck "manager"

    # Active response
    if [ "$SET_WHITE_LIST"="true" ]; then
       sed -e "/  <\/global>/d" "${GLOBAL_AR_TEMPLATE}" >> $NEWCONFIG
      # Nameservers in /etc/resolv.conf
      for ip in ${NAMESERVERS} ${NAMESERVERS2};
        do
          if [ ! "X${ip}" = "X" ]; then
              echo "    <white_list>${ip}</white_list>" >>$NEWCONFIG
          fi
      done
      # Read string
      for ip in ${IPS};
        do
          if [ ! "X${ip}" = "X" ]; then
            echo $ip | grep -E "^[0-9./]{5,20}$" > /dev/null 2>&1
            if [ $? = 0 ]; then
              echo "    <white_list>${ip}</white_list>" >>$NEWCONFIG
            fi
          fi
        done
        echo "  </global>" >> $NEWCONFIG
        echo "" >> $NEWCONFIG
    else
      cat ${GLOBAL_AR_TEMPLATE} >> $NEWCONFIG
      echo "" >> $NEWCONFIG
    fi

    cat ${AR_COMMANDS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG
    cat ${AR_DEFINITIONS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Write the log files
    if [ "X${NO_LOCALFILES}" = "X" ]; then
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
      WriteLogs "add"
    else
      echo "  <!-- Log analysis -->" >> $NEWCONFIG
    fi

    # Localfile commands
    LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.manager.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    if [ "$LOCALFILE_COMMANDS_TEMPLATE" = "ERROR_NOT_FOUND" ]; then
      LOCALFILE_COMMANDS_TEMPLATE=$(GetTemplate "localfile-commands.template" ${DIST_NAME} ${DIST_VER} ${DIST_SUBVER})
    fi
    cat ${LOCALFILE_COMMANDS_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    # Writting rules configuration
    cat ${RULES_TEMPLATE} >> $NEWCONFIG
    echo "" >> $NEWCONFIG

    echo "</ossec_config>" >> $NEWCONFIG
}

InstallCommon(){

    PREFIX='/var/ossec'
    OSSEC_GROUP='ossec'
    OSSEC_USER='ossec'
    OSSEC_USER_MAIL='ossecm'
    OSSEC_USER_REM='ossecr'
    EXTERNAL_LUA='external/lua-5.2.3/'
    INSTALL="install"

    if [ ${INSTYPE} = 'server' ]; then
        OSSEC_CONTROL_SRC='./init/ossec-server.sh'
        OSSEC_CONF_SRC='../etc/ossec-server.conf'
    elif [ ${INSTYPE} = 'agent' ]; then
        OSSEC_CONTROL_SRC='./init/ossec-client.sh'
        OSSEC_CONF_SRC='../etc/ossec-agent.conf'
    elif [ ${INSTYPE} = 'local' ]; then
        OSSEC_CONTROL_SRC='./init/ossec-local.sh'
        OSSEC_CONF_SRC='../etc/ossec-local.conf'
    fi

    if [ ! ${PREFIX} = ${INSTALLDIR} ]; then
        PREFIX=${INSTALLDIR}
    fi

    if [ ${DIST_NAME} = "SunOS" ]; then
        INSTALL="ginstall"
    elif [ ${DIST_NAME} = "HP-UX" ]; then
        INSTALL="/usr/local/coreutils/bin/install"
    fi

    ./init/adduser.sh ${OSSEC_USER} ${OSSEC_USER_MAIL} ${OSSEC_USER_REM} ${OSSEC_GROUP} ${PREFIX} ${INSTYPE}

	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/
	${INSTALL} -d -m 0770 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/logs
	${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/logs/ossec
	${INSTALL} -m 0660 -o ${OSSEC_USER} -g ${OSSEC_GROUP} /dev/null ${PREFIX}/logs/ossec.log
	${INSTALL} -m 0660 -o ${OSSEC_USER} -g ${OSSEC_GROUP} /dev/null ${PREFIX}/logs/ossec.json
	${INSTALL} -m 0660 -o ${OSSEC_USER} -g ${OSSEC_GROUP} /dev/null ${PREFIX}/logs/active-responses.log

	${INSTALL} -d -m 0750 -o root -g 0 ${PREFIX}/bin
	${INSTALL} -d -m 0750 -o root -g 0 ${PREFIX}/lua
	${INSTALL} -d -m 0750 -o root -g 0 ${PREFIX}/lua/native
	${INSTALL} -d -m 0750 -o root -g 0 ${PREFIX}/lua/compiled
	${INSTALL} -m 0750 -o root -g 0 ossec-logcollector ${PREFIX}/bin
	${INSTALL} -m 0750 -o root -g 0 ossec-syscheckd ${PREFIX}/bin
	${INSTALL} -m 0750 -o root -g 0 ossec-execd ${PREFIX}/bin
	${INSTALL} -m 0750 -o root -g 0 manage_agents ${PREFIX}/bin
	${INSTALL} -m 0750 -o root -g 0 ${EXTERNAL_LUA}src/ossec-lua ${PREFIX}/bin/
	${INSTALL} -m 0750 -o root -g 0 ${EXTERNAL_LUA}src/ossec-luac ${PREFIX}/bin/
	${INSTALL} -m 0750 -o root -g 0 ../contrib/util.sh ${PREFIX}/bin/
	${INSTALL} -m 0750 -o root -g 0 ${OSSEC_CONTROL_SRC} ${PREFIX}/bin/ossec-control
	${INSTALL} -m 0750 -o root -g 0 wazuh-modulesd ${PREFIX}/bin/

	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/queue
	${INSTALL} -d -m 0770 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/alerts
	${INSTALL} -d -m 0770 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/ossec
	${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/syscheck
	${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/diff
	${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/agents

	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/wodles
	${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/wodles
	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/wodles/oscap
	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/wodles/oscap/content

	${INSTALL} -m 0750 -o root -g ${OSSEC_GROUP} ../wodles/oscap/oscap.py ${PREFIX}/wodles/oscap
	${INSTALL} -m 0750 -o root -g ${OSSEC_GROUP} ../wodles/oscap/template_*.xsl ${PREFIX}/wodles/oscap

    if [ -d "../wodles/oscap/content" ]; then
        if [ $(ls ../wodles/oscap/content | wc -l) -gt 0 ]; then
            ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} ../wodles/oscap/content/* ${PREFIX}/wodles/oscap/content
        fi
    fi

	${INSTALL} -d -m 0770 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/etc

    if [ -f /etc/localtime ]
    then
	       ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} /etc/localtime ${PREFIX}/etc
    fi

	${INSTALL} -d -m 1750 -o root -g ${OSSEC_GROUP} ${PREFIX}/tmp

    if [ -f /etc/TIMEZONE ]; then
	       ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} /etc/TIMEZONE ${PREFIX}/etc/
    fi
    # Solaris Needs some extra files
    if [ ${DIST_NAME} = "SunOS" ]; then
	    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/usr/share/lib/zoneinfo/
        cp -rf /usr/share/lib/zoneinfo/* ${PREFIX}/usr/share/lib/zoneinfo/
        chown root:${OSSEC_GROUP} ${PREFIX}/usr/share/lib/zoneinfo/*
        find ${PREFIX}/usr/share/lib/zoneinfo/ -type d -exec chmod 0750 {} +
        find ${PREFIX}/usr/share/lib/zoneinfo/ -type f -exec chmod 0640 {} +
    fi

    ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/internal_options.conf ${PREFIX}/etc/

    if [ ! -f ${PREFIX}/etc/local_internal_options.conf ]; then
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} ../etc/local_internal_options.conf ${PREFIX}/etc/local_internal_options.conf
    fi

    if [ ! -f ${PREFIX}/etc/client.keys ]; then
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} /dev/null ${PREFIX}/etc/client.keys
    fi

    if [ ! -f ${PREFIX}/etc/ossec.conf ]; then
        if [ -f  ../etc/ossec.mc ]; then
            ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} ../etc/ossec.mc ${PREFIX}/etc/ossec.conf
        else
            ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} ${OSSEC_CONF_SRC} ${PREFIX}/etc/ossec.conf
        fi
    fi

	${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/shared
	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/active-response
	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/active-response/bin
	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/agentless
	${INSTALL} -m 0750 -o root -g ${OSSEC_GROUP} agentlessd/scripts/* ${PREFIX}/agentless/

	${INSTALL} -d -m 0700 -o root -g ${OSSEC_GROUP} ${PREFIX}/.ssh

	${INSTALL} -m 0750 -o root -g ${OSSEC_GROUP} ../active-response/*.sh ${PREFIX}/active-response/bin/
	${INSTALL} -m 0750 -o root -g ${OSSEC_GROUP} ../active-response/firewalls/*.sh ${PREFIX}/active-response/bin/

	${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/var
	${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/run

    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/backup

	./init/fw-check.sh execute
}

InstallLocal(){

    InstallCommon

    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/decoders
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/rules
    ${INSTALL} -d -m 770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/db
    ${INSTALL} -d -m 770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/db/agents
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/upgrade
    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/logs/archives
    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/logs/alerts
    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/logs/firewall
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/rootcheck
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/shared/default

    ${INSTALL} -m 0750 -o root -g 0 ossec-agentlessd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-analysisd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-monitord ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-reportd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-maild ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-logtest ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-csyslogd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-dbd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-makelists ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 verify-agent-conf ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 clear_stats ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 list_agents ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 ossec-regex ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 syscheck_update ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 agent_control ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 syscheck_control ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 rootcheck_control ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 ossec-integratord ${PREFIX}/bin/
    ${INSTALL} -m 0750 -o root -g 0 -b update/ruleset/update_ruleset.py ${PREFIX}/bin/update_ruleset

    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/stats
    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/ruleset
    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/ruleset/decoders
    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/ruleset/rules

    ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b update/ruleset/RULESET_VERSION ${PREFIX}/ruleset/VERSION
    ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/rules/*.xml ${PREFIX}/ruleset/rules
    ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/decoders/*.xml ${PREFIX}/ruleset/decoders
    ${INSTALL} -m 0660 -o root -g ${OSSEC_GROUP} rootcheck/db/*.txt ${PREFIX}/etc/shared/default
    ${INSTALL} -m 0660 -o root -g ${OSSEC_GROUP} rootcheck/db/*.txt ${PREFIX}/etc/rootcheck
    ${INSTALL} -m 0660 -o root -g ${OSSEC_GROUP} ../etc/agent.conf ${PREFIX}/etc/shared/default

    ${MAKEBIN} -C ../framework install PREFIX=${PREFIX}

    if [ ! -f ${PREFIX}/etc/decoders/local_decoder.xml ]; then
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/local_decoder.xml ${PREFIX}/etc/decoders/local_decoder.xml
    fi
    if [ ! -f ${PREFIX}/etc/rules/local_rules.xml ]; then
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/local_rules.xml ${PREFIX}/etc/rules/local_rules.xml
    fi
    if [ ! -f ${PREFIX}/etc/lists ]; then
        ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/lists
    fi
    if [ ! -f ${PREFIX}/etc/lists/amazon ]; then
        ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/etc/lists/amazon
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/lists/amazon/* ${PREFIX}/etc/lists/amazon/
    fi
    if [ ! -f ${PREFIX}/etc/lists/audit-keys ]; then
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/lists/audit-keys ${PREFIX}/etc/lists/audit-keys
        ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} -b ../etc/lists/audit-keys.cdb ${PREFIX}/etc/lists/audit-keys.cdb
    fi

    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/fts

    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/rootcheck

    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/agentless

    ${INSTALL} -d -m 0750 -o root -g ${OSSEC_GROUP} ${PREFIX}/integrations
    ${INSTALL} -m 750 -o root -g ${OSSEC_GROUP} ../integrations/* ${PREFIX}/integrations
    touch ${PREFIX}/logs/integrations.log
    chmod 640 ${PREFIX}/logs/integrations.log
    chown ${OSSEC_USER_MAIL}:${OSSEC_GROUP} ${PREFIX}/logs/integrations.log
}

InstallServer(){

    InstallLocal

    ${INSTALL} -m 0750 -o root -g 0 ossec-remoted ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 ossec-authd ${PREFIX}/bin

    ${INSTALL} -d -m 0770 -o ${OSSEC_USER_REM} -g ${OSSEC_GROUP} ${PREFIX}/queue/agent-info
    ${INSTALL} -d -m 0770 -o ${OSSEC_USER_REM} -g ${OSSEC_GROUP} ${PREFIX}/queue/rids
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/queue/agent-groups
    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/backup/agents
    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/backup/groups

    rm -f ${PREFIX}/etc/shared/merged.mg
}

InstallAgent(){

    InstallCommon

    ${INSTALL} -m 0750 -o root -g 0 ossec-agentd ${PREFIX}/bin
    ${INSTALL} -m 0750 -o root -g 0 agent-auth ${PREFIX}/bin

    ${INSTALL} -d -m 0750 -o ${OSSEC_USER} -g ${OSSEC_GROUP} ${PREFIX}/queue/rids
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/incoming
    ${INSTALL} -d -m 0770 -o root -g ${OSSEC_GROUP} ${PREFIX}/var/upgrade
    ${INSTALL} -m 0660 -o root -g ${OSSEC_GROUP} rootcheck/db/*.txt ${PREFIX}/etc/shared/
    ${INSTALL} -m 0640 -o root -g ${OSSEC_GROUP} ../etc/wpk_root.pem ${PREFIX}/etc/

}

InstallWazuh(){
    if [ "X$INSTYPE" = "Xagent" ]; then
        InstallAgent
    elif [ "X$INSTYPE" = "Xserver" ]; then
        InstallServer
    elif [ "X$INSTYPE" = "Xlocal" ]; then
        InstallLocal
    fi
}
