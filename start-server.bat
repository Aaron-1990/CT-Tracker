@echo off
echo Iniciando Servidor VSM BorgWarner...
cd /d "%~dp0"
pm2 start ecosystem.config.js
pm2 save
echo Servidor iniciado como servicio
echo Dashboard disponible en: http://10.42.126.12:3001
pause
