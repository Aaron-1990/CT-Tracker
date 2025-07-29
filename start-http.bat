@echo off 
title Dashboard HTTP - Puerto 3001 
cd /d "C:\Aplicaciones\mi-servidor-web" 
set NODE_ENV=production 
set PORT=3001 
set HOST=0.0.0.0 
echo [%date% %time%] Iniciando servidor HTTP en puerto 3001... 
node server.js 
