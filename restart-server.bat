@echo off
echo Reiniciando Servidor VSM BorgWarner...
pm2 restart vsm-dashboard-borgwarner
echo Servidor reiniciado
echo Dashboard disponible en: http://10.42.126.12:3001
pause
