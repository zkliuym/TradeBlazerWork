@echo off
title Net test
:: By s.w. 2017/01/05

:default
set name1=QQ
set aim1=www.qq.com
set name2=253
set aim2=101.226.178.253
set name3=178
set aim3=222.73.164.178
set outfile="NetTest_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt"
set times=100
set wait=3000
set delay=2

:readset
findstr "[settings]" "settings.ini" >>nul || goto :main
for /f "skip=1 tokens=* eol=#" %%i in (settings.ini) do call set %%i

:main
set /a num=0,num_1=0,num_2=0,num_3=0
set outfile=%outfile: =0%
(echo,Net Test
echo,Date:%date%
echo,Timeout:%wait% ms
echo,Delay:%delay% s
echo,The result is based on the last %times% records.
echo,
echo,%name1%:%aim1%
echo,%name2%:%aim2%
echo,%name3%:%aim3%
echo,
echo,Time		%name1%	%name2%	%name3%	SUM	SUM1	SUM2	SUM3
)>%outfile%
echo,
echo,%name1%:%aim1%
echo,%name2%:%aim2%
echo,%name3%:%aim3%
echo,
echo,Time		%name1%	%name2%	%name3%	SUM	SUM1	SUM2	SUM3

set /a delay*=1000

:xunhuan
set /a num+=1
if %num% LEQ %times% (
set /a startnum=1,count=%num%
) else (
set /a startnum=%num%-%times%,count=%times%
)
ping %aim1% -n 1 -w %wait% >nul&&(set "status1=  "&set a%num%=0)||(set "status1=- "&set /a a%num%=1)
ping %aim2% -n 1 -w %wait% >nul&&(set "status2=  "&set b%num%=0)||(set "status2=- "&set /a b%num%=1)
ping %aim3% -n 1 -w %wait% >nul&&(set "status3=  "&set c%num%=0)||(set "status3=- "&set /a c%num%=1)
call :cal
if "%status1%" EQU "  " ( set ".num_1=" ) else set .num_1=%num_1%
if "%status2%" EQU "  " ( set ".num_2=" ) else set .num_2=%num_2%
if "%status3%" EQU "  " ( set ".num_3=" ) else set .num_3=%num_3%
echo,%time%	%status1%%ratenum1%%%	%status2%%ratenum2%%%	%status3%%ratenum3%%%	%num%	%.num_1%	%.num_2%	%.num_3%
echo,%time%	%status1%%ratenum1%%%	%status2%%ratenum2%%%	%status3%%ratenum3%%%	%num%	%.num_1%	%.num_2%	%.num_3% >>%outfile%
if %ratenum1% LSS 10 ( set "mark1= " ) else set "mark1="
if %ratenum2% LSS 10 ( set "mark2= " ) else set "mark2="
if %ratenum3% LSS 10 ( set "mark3= " ) else set "mark3="
title Net Test     %ratenum1%%% %mark1%          %ratenum2%%% %mark2%          %ratenum3%%% %mark3%    %num%
ping 1.1 -n 1 -w %delay%>>nul
goto :xunhuan

:cal
set /a num_1+=a%num%,num_2+=b%num%,num_3+=c%num%
set sum_a=0
set sum_b=0
set sum_c=0
for /l %%i in (%startnum%,1,%num%) do set /a sum_a+=a%%i,sum_b+=b%%i,sum_c+=c%%i
set /a ratenum1=sum_a*100/count,ratenum2=sum_b*100/count,ratenum3=sum_c*100/count
exit /b

goto :eof
