#!/bin/sh
# Script usado para inicializar un RMI con las politicas de seguridad
# default de Java SE
# Autor: @gabnetx

PORT=2001
IP=`ifconfig | awk '/inet addr/{print substr($2,6)}' | head -n1`

#Si no existe registro del RMI se procede al inicio
if [ `./search_rmi.sh $PORT | wc -l | cut -f1` -ge 1 ]
then
        date
        echo "Ya existe un registro en el puerto ${PORT}"
        exit
else
        #Se inicia el registro del RMI
        nohup date
        nohup rmiregistry $PORT &
        nohup java -Xmx16M -Djava.rmi.server.hostname=$IP \
-Djava.security.policy=java.policy \
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.local.only=false \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Dcom.sun.management.jmxremote.port=9005 \
ejemploRMI.Server $PORT &

fi

exit
