#!/bin/sh
# Busca algun proceso RMI registrado en el servidor
ps -fea | egrep '(java|rmiregistry)' | grep $1 | grep -v grep
