@echo off
REM Script de rotaciÃ³n de logs del servicio VSM
echo [%date% %time%] Rotando logs del servicio VSM...

cd /d "C:\Aplicaciones\mi-servidor-web\logs"

REM Rotar logs si son mayores a 50MB
for %%f in (service-output.log service-error.log) do (
    if exist %%f (
        for %%s in (%%f) do (
            if %%~zs gtr 52428800 (
                ren %%f %%f.old
                echo. > %%f
                echo [%date% %time%] Log rotado por tamaÃ±o > %%f
            )
        )
    )
)

echo [%date% %time%] RotaciÃ³n completada
