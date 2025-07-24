@echo off
echo Estado del Servidor VSM BorgWarner:
echo.
pm2 status
echo.
pm2 info vsm-dashboard-borgwarner
pause
