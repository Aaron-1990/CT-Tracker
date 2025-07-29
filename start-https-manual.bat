@echo off
title HTTPS Server - Puerto 3443
cd /d "C:\Aplicaciones\mi-servidor-web"
set NODE_ENV=production
set HTTPS_PORT=3443
set HOST=0.0.0.0

echo Iniciando servidor HTTPS en puerto 3443...
node server-https.js
