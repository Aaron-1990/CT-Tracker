@echo off
echo Iniciando servidor VSM en modo produccion...
echo.
echo Verificando dependencias...
npm install --production
echo.
echo Iniciando con PM2...
npm run pm2:start
echo.
echo Para ver logs: npm run pm2:logs
echo Para detener: npm run pm2:stop
