@echo off
echo Mostrando logs del Servidor VSM...
pm2 logs vsm-dashboard-borgwarner --lines 50
pause
