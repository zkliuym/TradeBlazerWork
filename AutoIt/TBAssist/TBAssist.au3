;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; AutoIt脚本功能说明:
; TB自动登录并启动自动交易
; 监视TB实盘运行状态
; 自动发送TB登录事件、行情断开报警消息
; 发送方式:电子邮件,qq电子邮件可以通过微信或QQ接收,即时可以收到消息
; 作者: 251125998@qq.com
; 参考文档: TBMonitor@乐丁
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 头文件包含
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#include <file.au3>
#Include <date.au3>
#include <Process.au3>
#include <GuiHeader.au3>
#include <GuiListView.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>


;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 变量声明区
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Dim $logFileName														; 日志文件
Dim $DateString, $TimeString, $DateTimeString							; 日期时间字符串
Dim $WorkInfo															; 运行机器信息
Dim $PathEnvInfo														; 运行机器环境变量

; AutoIt将用到的具体的一些常量信息
Global $g_LoginText = "暂停自动登录交易帐户"
Global $g_MainTitle = "交易开拓者平台(旗舰版)"
Global $TBInstallPath = @ScriptDir
Global $TBHolidayFile = @ScriptDir&"\Holiday.csv"
Global $TBAssistConfig = @ScriptDir&"\TBAssist.ini"
Global $TBQiJianBanAppFile = @ScriptDir&"\TradeBlazer.exe"
Global $SendEmailExe = @ScriptDir&"\sendEmail\sendEmail.exe"
Global $TBOutPutFilePath = @ScriptDir&"\Quote_AccountID_Status.ini"

Global $TBloginname, $TBloginpassword, $LastSendTime0, $LastSendTime1, $LastSendTime2, $myTime, $bIsTradeDay, $TradeTime1, $TradeTime2
Global $DayStartTime, $DayEndTime, $NightStartTime, $NightEndTime, $ServerID, $AccountID1
Global $DayAccountLoginTime, $DayActiveAutoTradeTime, $TradeLogSendTime, $NightAccountLoginTime, $NightActiveAutoTradeTime
Global $OffLineAlert, $ChangeQuteIP, $OffLineIntervalSecond, $CFFEX, $SHFE, $DCE, $CZCE, $AlertLinkSpeedMS
Global $PositionMonitorIntervalMinute, $PositionAlertMail, $enSendTradeLog
Global $SmtpServer, $FromAddress, $ToAddress, $Username, $Password, $AccReportAddress

Global $ActivedAutoTrade = 0																		; 当日启动自动交易标记
Global $SendTradelog = 0																			; 当日发送交易记录标记

Global $SmtpServer, $FromAddress, $ToAddress, $Subject, $Body, $AttachFiles,$Username, $Password
Global $LastChkTime = "1970/01/01 00:00:00"															; 最近检查持仓匹配时间


;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 主程序区
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;myLog("AutoIt Start")
initVarData()    				; 对主要变量初始化
updateEnv()						; 更新环境变量信息，把sendemail程序加入环境变量
LoadIni()						; 读取配置文件信息，如有空的项目及时进行提示，并提示误输入后该如何修改
checkFileExist()				; 检查主要文件是否存在
mainCode()
myLog("AutoIt Finish")


;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 函数区
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;+++++++++++++++++++++++++++++++++++++
; 主模块
;+++++++++++++++++++++++++++++++++++++
Func mainCode()
   myLog("mainCode()")

   Local $myTime
   Local $FTIME = "1970/01/01 00:00:00"
   Local $RepeatLoginAccount = 1
   While 1
	  ;
	  $myTime = @HOUR*10000+@MIN*100+@SEC
	  $strNowDate = StringFormat("%04i/%02i/%02i", @YEAR, @MON, @MDAY)
	  $strNowTime = _NowTime()
	  ; myLog("$strNowDate: " & $strNowDate & "; $strNowTime: " & $strNowTime)

	  ; 定义交易日
	  If _DateDiff('n', $FTIME, _Now())>5 Then
		 Local $file = FileOpen($TBHolidayFile, $FO_READ)		; 读取节假日文件
		 If $file = -1 Then
			myLog("没有找到节假日文件："& $TBHolidayFile)
			; Exit
		 EndIf

		 Local $Holiday = 0
		 While 1
			Local $Line = FileReadLine($file)
			If @error = -1 Then ExitLoop
			If ($Line = $strNowDate) Then
			   $Holiday = 1
			EndIf
		 WEnd
		 FileClose($file)

		 if (@WDAY>1 And (@WDAY<7 Or (@WDAY=7 And $myTime<080000)) And $Holiday=0) Then
			$bIsTradeDay = 1
			; myLog("Today Is Trade Day")
		 Else
			$bIsTradeDay = 0
			; myLog("Today Not Trade Day")
		 EndIf

		 If(@WDAY==2 And $myTime<080000) Then ;周一早上非交易时间
			$bIsTradeDay = 0
		 EndIf
	  EndIf

	  ;TB运行时间，默认白盘是上午8点40至下午4点，夜盘是晚上20点40至凌晨3点
	  Local $IsDayRunTime = 0, $IsNightRunTime = 0
	  If ($myTime>$DayStartTime And $myTime<$DayEndTime) Then $IsDayRunTime = 1
	  If ($myTime>$NightStartTime And $myTime<=240000) Or ($myTime>=000000 And $myTime<$NightEndTime) Then $IsNightRunTime = 1

	  If (($IsDayRunTime = 1 Or $IsNightRunTime = 1) And $bIsTradeDay = 1) Then
		 ; myLog("(($IsDayRunTime = 1 Or $IsNightRunTime = 1) And $bIsTradeDay = 1) then run startTB")
		 Local $TBstatus=StartTB()	; 登录TB旗舰版
		 If (($myTime>=$DayAccountLoginTime And $IsDayRunTime = 1) Or ($myTime>=$NightAccountLoginTime And $IsNightRunTime = 1)) And $TBstatus=1 Then
			Local $ACstatus=LoginTradeAccount()	; 登录交易账户
		 EndIf

		 If (($myTime>=$DayActiveAutoTradeTime And $IsDayRunTime = 1) Or ($myTime>=$NightActiveAutoTradeTime And $IsNightRunTime = 1)) And $TBstatus=1 And $ACstatus=1 And $ActivedAutoTrade=0 Then
			myLog("启动自动交易")
			OpenAutoTrade($AccountID1)	; 启动自动交易
			$ActivedAutoTrade = 1
		 EndIf

		 If $ActivedAutoTrade = 1 Then
			myLog("头寸监视器,检查自动交易持仓匹配状态")
			PositionMonitor($PositionMonitorIntervalMinute,$PositionAlertMail)	; 头寸监视器,检查自动交易持仓匹配状态
		 EndIf

		 ; 下午收盘后发送账户权益持仓及当日交易记录，限用于32位版本TB(64位版本TB无法读取持仓及交易记录信息)
		 If ($myTime>=$TradeLogSendTime And $myTime<$DayEndTime And $bIsTradeDay = 1 And $enSendTradeLog=1) Then
			$TBstatus = StartTB()
			if ($SendTradelog=0 And $TBstatus=1 And Not(WinExists("交易开拓者平台(旗舰版) 64位"))) Then
			   SendTradeReport($enSendTradeLog)
			   $SendTradelog = 1
			EndIf
		 EndIf
	  ElseIf WinExists($g_MainTitle) then ;非交易时间关闭TB
		 myLog("当前处于非交易时间，关闭TB")
		 CloseTB()
		 $ActivedAutoTrade = 0
		 $SendTradelog = 0
	  EndIf

	  If (($myTime>091530 And $myTime<113000) Or ($myTime>130030 And $myTime<151500)) And $bIsTradeDay = 1 Then
		 myLog("中金所行情断开报警")
		 QuoteAlert($OffLineAlert,$ChangeQuteIP,$CFFEX,0,0,0)
	  EndIf
	  If ((($myTime>090030 And $myTime<101500) Or ($myTime>103030 And $myTime<113000) Or ($myTime>133030 And $myTime<150000)) Or (($myTime>210030 And $myTime<240000) Or ($myTime>000030 And $myTime<023000))) And $bIsTradeDay = 1 Then
		 myLog("上海行情断开报警")
		 QuoteAlert($OffLineAlert,$ChangeQuteIP,0,$SHFE,0,0)
	  EndIf
	  If ((($myTime>090030 And $myTime<101500) Or ($myTime>103030 And $myTime<113000) Or ($myTime>133030 And $myTime<150000)) Or ($myTime>210030 And $myTime<233000)) And $bIsTradeDay = 1 Then
		 myLog("大连行情断开报警")
		 QuoteAlert($OffLineAlert,$ChangeQuteIP,0,0,$DCE,0)
	  EndIf
	  If (($myTime>090030 And $myTime<101500) Or ($myTime>103030 And $myTime<113000) Or ($myTime>133030 And $myTime<150000)) And $bIsTradeDay = 1 Then
		 myLog("郑州行情断开报警")
		 QuoteAlert($OffLineAlert,$ChangeQuteIP,0,0,0,$CZCE)
	  EndIf

	  Sleep(3000);//延迟1000毫秒
   WEnd

   myLog("Func mainCode() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 启动TB
;+++++++++++++++++++++++++++++++++++++
Func StartTB()
	myLog("Func startTB()")
	Local $result = 0
	Local $LoginText = ""
	Local $SendMessage = ""
	$Eot1 = "交易开拓者平台(旗舰版) (未响应)"

	if WinExists($Eot1) = 1 Then
		ProcessClose("TradeBlazer.exe")
		ProcessClose("TBDataCenter.exe")
		Sleep(10000)
	EndIf

	If WinExists($g_MainTitle) Then
		$result = 1
	Else
		$ActivedAutoTrade = 0
		If Not WinExists($g_MainTitle) And ProcessExists("TradeBlazer.exe") Then
			myLog("开拓者旗舰版工作正常")
			ProcessClose("TradeBlazer.exe")
			ProcessClose("TBDataCenter.exe")
			Sleep(500)
		Else
			myLog("开拓者旗舰版未启动或处于无响应状态，准备重启")
			$NetWorkLine = myIniRead($TBAssistConfig, "TB运行参数", "NetWorkLine", "")
			Run($TBInstallPath & "\TradeBlazer.exe", $TBInstallPath)
			WinWaitActive("",$g_LoginText, 60)

			; 重置交易数据
			myLog("重置交易数据")
			ControlClick("",$g_LoginText, 3080) ; 数据重置
			WinWaitActive("数据重置", "", 20)
			ControlClick("数据重置", "", 1)
			WinWaitActive("确认", "数据重置后不能恢复", 20)
			ControlClick("确认", "数据重置后不能恢复", 6)
			WinWaitActive("提示", "已经成功重置", 20)
			ControlClick("提示", "已经成功重置", 2)
			Sleep(15)

			WinActivate("", $g_LoginText)
			ControlFocus("", $g_LoginText, "Edit1")
			ControlSetText("", $g_LoginText, "Edit1", $TBloginname)
			ControlFocus("", $g_LoginText, "Edit2")
			ControlSetText("", $g_LoginText, "Edit2", $TBloginpassword)

			If $NetWorkLine = "DX" Then
				ControlClick("", $g_LoginText, 3023)	; 电信线路
			Else
				ControlClick("", $g_LoginText, 3024)	; 联通线路
			EndIf
			Sleep(15)

			ControlClick("", $g_LoginText, 3008)		; 暂停自动登录交易帐户
			Sleep(15)

			ControlClick("", $g_LoginText, 1000)		; 登录
			Sleep(10000)

			if WinExists("确认", "本次连接的期货行情服务器") Then
				WinClose("确认", "本次连接的期货行情服务器")
				Sleep(1000)
			EndIf

			if WinExists("打开工作室", "") Then
				ControlClick("", "启动时显示", 1001)	; 关闭打开工作室
				WinClose("打开工作室", "")
				Sleep(1000)
			EndIf

			Sleep(10000)	;暂停10秒
			WinActivate($g_MainTitle)
			If WinExists("系统消息") Then
				WinActivate("系统消息")
				Sleep(1000)
				WinClose("系统消息")
				Sleep(1000)
			EndIf

			if WinExists($g_MainTitle) Then
				$SendMessage = "TB登录成功"
				$result = 1
				;MsgBox(0,$SendMessage,$SendMessage,10)
			Else
				$SendMessage = "TB登录失败,请手工检查确认"
				$result = 0
				;MsgBox(0,$SendMessage,$SendMessage,10)
			EndIf
		EndIf
	EndIf

	If $SendMessage <> "" Then
	  myLog("sendEmail about login tradeblazer info")
	  $Subject = $ServerID&$SendMessage;"TB登录信息"
	  $Body = $SendMessage
	  $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
	  myLog($sCommand)
	  _RunDos($sCommand&" -o message-charset=GBK")
	  myLog($sCommand&" -o message-charset=GBK")
	  Sleep(10000)
	EndIf
	myLog("Func startTB() End")
	Return $result
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 登录交易账户
;+++++++++++++++++++++++++++++++++++++
Func LoginTradeAccount($BuDengLu=0)
   myLog("Func LoginTradeAccount()")
   Local $TBAccountNumber = ControlListView ( $g_MainTitle , "", "SysListView321", "GetItemCount") 	; 查登录账户数量
   If $TBAccountNumber >=1 And $BuDengLu=0 Then	; 已经有账户登录了，不再重复登录操作
	  Return 1
   ElseIf $TBAccountNumber = 0 Or $BuDengLu=1 Then	; 账户汇总没有交易账户，则进行登录交易账户操作
	  myLog("账户汇总没有交易账户，则进行登录交易账户操作")
	  WinActivate($g_MainTitle)
	  Sleep(100)
	  WinMenuSelectItem($g_MainTitle,"","交易(&T)", "交易帐户登录")
	  Sleep(100)
	  WinActivate("帐户登录")
	  Sleep(100)
	  ControlClick("帐户登录","",1)
	  Sleep(200)
	  WinActivate($g_MainTitle)
	  Local $ChkT = _Now()
	  While $TBAccountNumber<1 And _DateDiff('n', $ChkT, _Now())<5
		 $TBAccountNumber = ControlListView ( $g_MainTitle , "", "SysListView321", "GetItemCount")
		 Sleep(5000)
	  WEnd
	  Sleep(10000)

	  ;$TBAccountNumber = ControlListView ( $g_MainTitle , "", "SysListView321", "GetItemCount") ;查登录账户数量
	  If $TBAccountNumber >=1 Then
		 $Subject = $ServerID&"交易账户登录OK"
		 $BodyFile = GetTBAccountFile()
		 Sleep(1000)
		 Local $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -o message-file="&$BodyFile
		 myLog($sCommand)
		 _RunDos($sCommand&" -o message-charset=GBK")
		 Return 1
	  Else
		 $Subject = $ServerID&"警告：交易账户登录失败"
		 $Body = $Subject&",请检查交易账户设置"
		 $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
		 myLog($sCommand)
		 _RunDos($sCommand&" -o message-charset=GBK")
		 Return 1
	  EndIf
	  Sleep(20000)
   EndIf
   myLog("Func LoginTradeAccount() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 启动自动交易
;+++++++++++++++++++++++++++++++++++++
Func OpenAutoTrade($sAC="")
   myLog("Func OpenAutoTrade()")
   WinActivate($g_MainTitle)
   $result = WinMenuSelectItem($g_MainTitle,"","文件(&F)", "启动所有自动交易")
   myLog("MENU 启动所有自动交易")
   Sleep(100)

If $result = 0 Then
	  WinActivate($g_MainTitle)
	  Sleep(100)
	  WinClose($g_MainTitle)
	  Sleep(100)
	  ControlClick("确认","","Button1")
	  $SendMessage = "警告:TB启动自动交易失败"
	  $Subject = $ServerID&"警告:TB启动自动交易失败"
   Else
	  Sleep(10000)
	  If $sAC<>"" Then
		 $AccountMessage = ""
		 $var = IniRead($TBOutPutFilePath, "交易帐户登录信息", $sAC, "NotFound")
		 If $var=$sAC Then
			$AccountMessage = "交易帐户"&$sAC&"启动自动交易成功"
		 Else
			$AccountMessage = "交易帐户"&$sAC&"警告:TB启动自动交易失败"
			$result = 0
		 EndIf
		 $SendMessage = $AccountMessage
	  Else
		 $SendMessage = "启动自动交易操作完成"
	  EndIf
	  $Subject = $ServerID&"TB启动自动交易OK"
   EndIf

   $Body = $Subject
   $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
   myLog($sCommand)
   _RunDos($sCommand&" -o message-charset=GBK")
   Sleep(10000)
   myLog("Func OpenAutoTrade() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 头寸监控器
;+++++++++++++++++++++++++++++++++++++
Func PositionMonitor($nChkInterMin=5,$nSendMail=1)
   myLog("PositionMonitor()")
   If $nChkInterMin>=1 Then
	  Local $strNow = _Now()
	  Local $iDateCalc = _DateDiff('n', $LastChkTime, $strNow)
	  If $iDateCalc >= $nChkInterMin Then
		 WinActivate($g_MainTitle)
		 Local $Title="自动交易头寸监控器"
		 If Not WinExists($Title) Then
			WinMenuSelectItem($g_MainTitle,"","交易(&T)", "监控器")
			Sleep(100)
		 EndIf

		 ControlClick($Title,"",2316)
		 Sleep(500)
		 ControlClick($Title,"",2316)
		 Sleep(500)
		 Local $Text26=ControlGetText($Title,"",2356)
		 myLog("$Str26:"&$Text26)
		 Local $Str1=StringSplit($Text26,"=")
		 Local $Str26=StringSplit($Str1[1],":")
		 myLog("$Str1:"&$Str1)
		 myLog("$Str26[2]:"&$Str26[2])

		 Local $Text27=ControlGetText($Title,"",2357)
		 myLog("$Str27:"&$Text27)
		 Local $Str2=StringSplit($Text27,"=")
		 Local $Str27=StringSplit($Str2[1],":")
		 myLog("$Str2:"&$Str2)
		 myLog("$Str27[2]:"&$Str27[2])

		 Local $Text28=ControlGetText($Title,"",2358)
		 myLog("$Str28:"&$Text28)
		 Local $Str3=StringSplit($Text28,"=")
		 Local $Str28=StringSplit($Str3[1],":")
		 myLog("$Str3:"&$Str3)
		 myLog("$Str28[2]:"&$Str28[2])

		 Local $nRow = $Str26[2]-$Str27[2]-$Str28[2]

		 If $nRow<>0 And $nSendMail=1 Then;发送报警邮件
			$Subject = $ServerID&"警告：持仓头寸不匹配"
			$Body = "自动交易头寸监视器持仓不匹配,请登录服务器检查持仓"
			$sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
			myLog($sCommand)
			_RunDos($sCommand&" -o message-charset=GBK")
		 EndIf
		 $LastChkTime = $strNow
	  EndIf
   EndIf
   ; myLog("PositionMonitor() End")
EndFunc
;CloseTB()

;+++++++++++++++++++++++++++++++++++++
; 关闭TB
;+++++++++++++++++++++++++++++++++++++
Func CloseTB()
   myLog("CloseTB()")
   WinActivate($g_MainTitle)
   Sleep(100)
   Local $s_unlock="交易开拓者旗舰版-解除保护"
   If WinExists($s_unlock) Then
	  WinActivate($s_unlock)
	  Sleep(100)
	  ControlSend($s_unlock,"","Edit1", $TBloginpassword)
	  Sleep(100)
	  ControlClick($s_unlock,"","Button1")
	  Sleep(10)
   EndIf

   WinMenuSelectItem($g_MainTitle,"","文件(&F)", "保存所有工作区")
   Sleep(10)
   WinMenuSelectItem($g_MainTitle,"","文件(&F)", "退出")
   MouseClick("left", 500, 500, 2)
   ControlClick("确认","","Button1")

   $Subject = $ServerID&"Close TB"
   $Body = $Subject&",收盘关闭TB"
   $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
   myLog($sCommand)
   _RunDos($sCommand&" -o message-charset=GBK")
   ;Sleep(2000)
   myLog("CloseTB() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 切换行情服务器IP
;+++++++++++++++++++++++++++++++++++++
Func GetTBQuoteServerIP()
   myLog("切换行情服务器IP GetTBQuoteServerIP()")
   Local $T1 ="TB数据中心"
   WinActivate($T1)
   Sleep(100)

   $QuoteServerIP = ControlListView($T1,"","SysListView321","GetText",0,0)
   ControlListView($T1,"","SysListView321","Select",0)
   ControlClick($T1,"","Button2")
   $T2 = "可选服务器列表"
   WinWaitActive($T2,"",10)

   $hListView=ControlGetHandle($T2,"","SysListView321")
   Local $nIP = _GUICtrlListView_GetItemCount($hListView)
   For $i = 0 To $nIP-1
	  $N1 = Random(0,$nIP-1)
	  $NewServerIP = ControlListView($T2,"","SysListView321","GetText",$N1,1)

	  If $NewServerIP <> $QuoteServerIP Then
		 ControlListView($T2,"","SysListView321","Select",$N1)
		 ExitLoop
	  EndIf
   Next

   ControlClick($T2,"","Button1")
   $T3 = "确认"
   WinWaitActive($T3,"切换服务器",10)
   ControlClick($T3,"切换服务器","Button1")
   Sleep(2000)

   $NewIP = ControlListView($T1,"","SysListView321","GetText",0,0)
   Local $s_Msg = $QuoteServerIP & "已经断开并已切换行情服务器为" & $NewIP
   myLog($s_Msg)
   myLog("切换行情服务器IP GetTBQuoteServerIP() end")
   Return $s_Msg
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 行情断开报警
;+++++++++++++++++++++++++++++++++++++
Func QuoteAlert($nAlert=0,$ChangeIP=0,$nCFFEX=0,$nSHFE=0,$nDCE=0,$nCZCE=0)
   if $OffLineIntervalSecond>=1 Then
	  $AlertMessage = ""
	  $strNow = _Now()
      if $nCFFEX = 1 Then
		 $ZJTime = IniRead($TBOutPutFilePath, "TB行情刷新时间", "中国金融期货交易所", "NotFound")
		 Local $iDateCalc = _DateDiff('s', $ZJTime, $strNow)
         if $iDateCalc>$OffLineIntervalSecond Then $AlertMessage = "TB行情断开-中金所"
	  EndIf
	  If $nSHFE = 1 Then
		 $SHTime = IniRead($TBOutPutFilePath, "TB行情刷新时间", "上海期货交易所", "NotFound")
         Local $iDateCalc = _DateDiff('s', $SHTime, $strNow)
         if $iDateCalc>$OffLineIntervalSecond Then $AlertMessage = "行情断开-上海,"
	  EndIf
	  If $nDCE = 1 Then
		 $DLTime = IniRead($TBOutPutFilePath, "TB行情刷新时间", "大连商品交易所", "NotFound")
         $iDateCalc = _DateDiff('s', $DLTime, $strNow)
         if $iDateCalc>$OffLineIntervalSecond Then $AlertMessage = $AlertMessage & "行情断开-大连,"
	  EndIf
	  If $nCZCE = 1 Then
		 $ZZTime = IniRead($TBOutPutFilePath, "TB行情刷新时间", "郑州商品交易所", "NotFound")
         $iDateCalc = _DateDiff('s', $ZZTime, $strNow)
         if $iDateCalc>$OffLineIntervalSecond Then $AlertMessage = $AlertMessage & "行情断开-郑州,"
	  EndIf
      if $AlertMessage<>"" And _DateDiff('n', $LastSendTime1, $strNow)>5  Then ;同一报警消息间隔5分钟发送一次
		 If $ChangeIP = 1 Then
			$AlertMessage = $AlertMessage & "QuoteServerIP:" & GetTBQuoteServerIP()
		 EndIf
		 If $nAlert = 1 Then
			myLog($ServerID&"警告：服务器行情断开")
			$Subject = $ServerID&"警告：服务器行情断开"
			$Body = $AlertMessage&"(备注:在连续交易时间段内,如果在" & $OffLineIntervalSecond & "秒内数据不更新则认为行情服务器断开,据此发送邮件报警,仅供参考)"
			$sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
			myLog($sCommand)
			_RunDos($sCommand&" -o message-charset=GBK")
		 EndIf
	     $LastSendTime1 = $strNow
      EndIf

	  Local $T1 ="TB数据中心"
	  Local $LinkSpeedMS=Int(ControlListView($T1,"","SysListView321","GetText",0,0));//读取行情服务器连接速度，单位毫秒
	  If ($LinkSpeedMS>$AlertLinkSpeedMS) Then $AlertMessage = "行情连接速度超过"&$AlertLinkSpeedMS&"毫秒,"
	  if $AlertMessage<>"" And _DateDiff('n', $LastSendTime2, $strNow)>5  Then ;同一报警消息间隔5分钟发送一次
		 If $ChangeIP = 1 Then
			$AlertMessage = $AlertMessage & "QuoteServerIP:" & GetTBQuoteServerIP()
		 EndIf
		 If $nAlert = 1 Then
		    $Subject = $ServerID&"警告:行情服务器连接速度慢"
	        $Body = $AlertMessage&"(当前行情服务器连接速度为"&$LinkSpeedMS&"毫秒)"
		    $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$ToAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -m "&$Body
			myLog($sCommand)
		    _RunDos($sCommand&" -o message-charset=GBK")
		 EndIf
		 $LastSendTime2 = $strNow
      EndIf
	  Sleep(500)
   EndIf
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 发送全部账户汇总、持仓统计、交易记录到操盘手邮箱
;+++++++++++++++++++++++++++++++++++++
Func SendTradeReport($enSendMail=0)
   myLog("SendTradeReport")
   GetTBTradeLogFile($enSendMail,0)
   $Title = $g_MainTitle
   Local $TBAccountNumber = ControlListView ( $Title , "", "SysListView321", "GetItemCount") ;查登录账户数量
   Local $s_Account
   If $TBAccountNumber>1 Then
	  For $i=0 To $TBAccountNumber-1
		 $s_Account=ControlListView($Title,"","SysListView321","GetText",$i,0)
		 If Not StringInStr($s_Account,"汇总") Then
			GetTBTradeLogFile($enSendMail,$s_Account);//单独账户汇总、持仓统计、交易记录到客户指定邮箱
		 EndIf
	  Next
   EndIf
   myLog("SendTradeReport endl")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 保存账户汇总、持仓统计、当日交易记录
;+++++++++++++++++++++++++++++++++++++
Func GetTBTradeLogFile($enSendMail=0,$s_Account=0)
   myLog("GetTBTradeLogFile")
   Local $Title,$StrDate,$TBMessage,$Index,$StrItem,$nColumn,$nRow,$iColumn,$iRow,$tmpTBMessage,$TmpAddress
   $Title = $g_MainTitle
   Local $TBAccountNumber = ControlListView ( $Title , "", "SysListView321", "GetItemCount") ;查登录账户数量
   If $s_Account=0 Then
	  $filename=$sTBtradelogDir&"\"&"全部帐户权益持仓及TB交易记录"&@YEAR&@MON&@MDAY&".csv"
   Else
	  $filename=$sTBtradelogDir&"\"&$s_Account&"帐户权益持仓及TB交易记录"&@YEAR&@MON&@MDAY&".csv"
   EndIf

   Local $file = FileOpen($filename, 2)

   ; 保存帐户汇总到文件
   Local $SysHeaderTitle = ""
   $hWnd=ControlGetHandle( $Title , "", "SysHeader321")
   $nHeaderCount=_GUICtrlHeader_GetItemCount($hWnd)
   For $iIndex = 0 To $nHeaderCount - 1
	  $SysHeaderTitle = $SysHeaderTitle & _GUICtrlHeader_GetItemText($hWnd, $iIndex)
	  If $iIndex <> $nHeaderCount - 1 Then
		 $SysHeaderTitle = $SysHeaderTitle & ","
	  EndIf
   Next

   FileWriteLine($file,$SysHeaderTitle)
   $Title = $g_MainTitle
   $nRow = ControlListView ( $Title , "", "SysListView321", "GetItemCount")
   $nColumn = ControlListView ( $Title , "", "SysListView321", "GetSubItemCount")

   For $iRow=0 to $nRow-1
	  $tmpTBMessage = ""
	  If ($s_Account=0 Or $s_Account=ControlListView($Title,"","SysListView321","GetText",$iRow,0)) Then
		 For $iColumn=0 to $nColumn-1
			$tmpTBMessage = $tmpTBMessage & ControlListView($Title,"","SysListView321","GetText",$iRow,$iColumn)
			If $iColumn<>$nColumn-1 then
			   $tmpTBMessage = $tmpTBMessage &","
			EndIf
			   If $iColumn=$nColumn-1 then FileWriteLine($file,$tmpTBMessage)
		 Next
	  EndIf
   Next

   FileWriteLine($file,"")

   ; 保存持仓统计到文件
   Local $SysHeaderTitle = ""
   $hWnd=ControlGetHandle( $Title , "", "SysHeader322")
   $nHeaderCount=_GUICtrlHeader_GetItemCount($hWnd)
   For $iIndex = 0 To $nHeaderCount - 1
	  $SysHeaderTitle = $SysHeaderTitle & _GUICtrlHeader_GetItemText($hWnd, $iIndex)
	  If $iIndex <> $nHeaderCount - 1 Then
		 $SysHeaderTitle = $SysHeaderTitle & ","
	  EndIf
   Next

   FileWriteLine($file,$SysHeaderTitle)
   $Title = $g_MainTitle
   $nRow = ControlListView ( $Title , "", "SysListView322", "GetItemCount")
   $nColumn = ControlListView ( $Title , "", "SysListView322", "GetSubItemCount")
   For $iRow=0 to $nRow-1
	  $tmpTBMessage = ""
	  If ($s_Account=0 Or $s_Account=ControlListView($Title,"","SysListView322","GetText",$iRow,0)) Then
		 For $iColumn=0 to $nColumn-1
			$tmpTBMessage = $tmpTBMessage & ControlListView($Title,"","SysListView322","GetText",$iRow,$iColumn)
			If $iColumn<>$nColumn-1 then
			   $tmpTBMessage = $tmpTBMessage &","
			EndIf
			If $iColumn=$nColumn-1 then FileWriteLine($file,$tmpTBMessage)
		 Next
	  EndIf
   Next


   FileWriteLine($file,"")
   ;//保存当日交易记录到文件
   Local $SysHeaderTitle = ""
   $hWnd=ControlGetHandle( $Title , "", "SysHeader323")
   $nHeaderCount=_GUICtrlHeader_GetItemCount($hWnd)
   For $iIndex = 0 To $nHeaderCount - 1
	  $SysHeaderTitle = $SysHeaderTitle & _GUICtrlHeader_GetItemText($hWnd, $iIndex)
	  If $iIndex <> $nHeaderCount - 1 Then
		 $SysHeaderTitle = $SysHeaderTitle & ","
	  EndIf
   Next

   FileWriteLine($file,$SysHeaderTitle)
   $TBMessage=""
   $nRow = ControlListView ( $Title , "", "SysListView323", "GetItemCount");交易记录行数
   $nColumn = ControlListView ( $Title , "", "SysListView323", "GetSubItemCount");交易记录列数
   Local $n=2
   if $TBAccountNumber=1 Then $n =1

   For $i = 0 To $TBAccountNumber-$n
	  if $s_Account=0 Or $s_Account=ControlListView($Title,"","SysListView321","GetText",$i,0) Then
	  for $iRow=0 to $nRow-1
		 $tmpTBMessage=""
		 if ControlListView($Title,"","SysListView323","GetText",$iRow,0) = ControlListView($Title,"","SysListView321","GetText",$i,0) Then
			for $iColumn=0 to $nColumn - 1
			   $tmpTBMessage = $tmpTBMessage & ControlListView($Title,"","SysListView323","GetText",$iRow,$iColumn)
			   if $iColumn < $nColumn - 1 then
				  $tmpTBMessage = $tmpTBMessage &","
			   EndIf
			Next

			$tmpTBMessage = $tmpTBMessage & @CRLF
			FileWriteLine($file,$tmpTBMessage);
		 EndIf
	  Next

	  If $tmpTBMessage = "" Then $tmpTBMessage = "账户"&ControlListView($Title,"","SysListView321","GetText",$i,0)&"无交易记录"
		 $TBMessage = $TBMessage & $tmpTBMessage & @CRLF
	  EndIf
   Next
   FileClose($file)

   If $enSendMail=1 Then
	  $Body = GetTBAccountFile();"请用Excel打开附件"
	  If $s_Account=0 Then
		 $Subject = $ServerID&"全部帐户权益持仓及TB交易记录"&@YEAR&@MON&@MDAY
		 $TmpAddress = $AccReportAddress
	  Else
		 $Subject = $s_Account&"帐户权益持仓及TB交易记录"&@YEAR&@MON&@MDAY
		 $TmpAddress = IniRead($TBAssistConfig,"邮件参数",$s_Account, "")
	  EndIf

	  $sCommand = @ScriptDir&"\sendEmail\SendEmail.exe -f "&$FromAddress&" -t "&$TmpAddress&" -s "&$SmtpServer&" -xu "&$UserName&" -xp "&$Password&" -u "&$Subject&" -a "&$filename&" -o message-file="&$Body
	  myLog($sCommand)
	  _RunDos($sCommand)
	  Sleep(10000)
   EndIf
   myLog("GetTBTradeLogFile end")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 保存帐户汇总到文件
;+++++++++++++++++++++++++++++++++++++
Func GetTBAccountFile($s_Account=0)
   myLog("Func GetTBAccountFile()")
   Local $Title,$StrDate,$TBMessage,$Index,$StrItem,$nColumn,$nRow,$iColumn,$iRow,$tmpTBMessage
   $Title = $g_MainTitle
   If $s_Account=0 Then
	  $filename=$sTBtradelogDir&"\全部帐户汇总.csv"
   Else
	  $filename=$sTBtradelogDir&"\"&$s_Account&"帐户汇总.csv"
   EndIf

   Local $file = FileOpen($filename, 2)
   Local $SysHeaderTitle = ""
   $hWnd=ControlGetHandle( $Title , "", "SysHeader321")
   $nHeaderCount=_GUICtrlHeader_GetItemCount($hWnd)
   For $iIndex = 0 To $nHeaderCount - 1
	  $SysHeaderTitle = $SysHeaderTitle & _GUICtrlHeader_GetItemText($hWnd, $iIndex)
	  If $iIndex <> $nHeaderCount - 1 Then
		 $SysHeaderTitle = $SysHeaderTitle & ","
	  EndIf
   Next

   FileWriteLine($file,$SysHeaderTitle)
   $nRow = ControlListView ( $Title , "", "SysListView321", "GetItemCount")
   $nColumn = ControlListView ( $Title , "", "SysListView321", "GetSubItemCount")
   For $iRow=0 to $nRow-1
	  $tmpTBMessage = ""
	  If ($s_Account=0 Or $s_Account=ControlListView($Title,"","SysListView321","GetText",$iRow,0)) Then
		 For $iColumn=0 to $nColumn-1
			$tmpTBMessage = $tmpTBMessage & ControlListView($Title,"","SysListView321","GetText",$iRow,$iColumn)
			If $iColumn<>$nColumn-1 then
			   $tmpTBMessage = $tmpTBMessage &","
			EndIf
			If $iColumn=$nColumn-1 then FileWriteLine($file,$tmpTBMessage)
		 Next
	  EndIf
   Next

   FileClose($file)
   myLog("Func GetTBAccountFile() End")
   Return $filename
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 输出日志信息
;+++++++++++++++++++++++++++++++++++++
Func myLog($logInfo = "")
   Local $fileName = "AutoIt." & $DateString & ".log"
   $logInfo = $logInfo
   _FileWriteLog($fileName, $logInfo, -1)
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 对主要变量初始化
;+++++++++++++++++++++++++++++++++++++
Func initVarData()
   $DateString = @YEAR & "-" & @MON & "-" & @MDAY
   $TimeString = @HOUR & ":" & @MIN & ":" & @SEC & ":" & @MSEC
   $DateTimeString = $DateString & " " & $TimeString & " "
   myLog("- ")
   myLog("AutoIt Start")
   myLog("initVarData()")

   $WorkInfo = @UserName & "@" &@ComputerName & "["& @IPAddress1 & "]"
   $TBAssistConfig = @ScriptDir & "\TBAssist.ini"

   $LastSendTime0 = "1970/01/01 00:00:00"
   $LastSendTime1 = $LastSendTime0
   $LastSendTime2 = $LastSendTime0

   Global $sTBtradelogDir = @ScriptDir&"\TB交易记录"; 帐户汇总持仓统计当日交易文件存放文件夹
   If DirGetSize($sTBtradelogDir) = -1 Then
	  DirCreate($sTBtradelogDir)
   EndIf
   myLog("Func initVarData() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 检查主要文件是否存在
;+++++++++++++++++++++++++++++++++++++
;Global $TBAssistConfig = @ScriptDir&"\TBAssist.ini"
;Global $TBHolidayFile = @ScriptDir&"\Holiday.csv"
;Global $SendEmailExe = @ScriptDir&"\sendEmail\sendEmail.exe"
;Global $TBOutPutFilePath = @ScriptDir&"\Quote_AccountID_Status.ini"
Func checkFileExist()
   myLog("checkFileExist()")
   If Not FileExists($TBAssistConfig) Then
	  myLog($TBAssistConfig&"不存在！请检查！01")
	  MsgBox(4096, "错误", $TBAssistConfig&"不存在！请检查！")
	  Exit
   EndIf

   If Not FileExists($TBHolidayFile) Then
	  myLog($TBHolidayFile&"不存在！请检查！02")
	  MsgBox(4096, "错误", $TBHolidayFile&"不存在！请检查！")
	  Exit
   EndIf

   If Not FileExists($SendEmailExe) Then
	  myLog($SendEmailExe&"不存在！请检查！03")
	  MsgBox(4096, "错误", $SendEmailExe&"不存在！请检查！")
	  Exit
   EndIf

   If Not FileExists($TBOutPutFilePath) Then
	  myLog($TBOutPutFilePath&"不存在！请检查！04")
	  ;MsgBox(4096, "错误", $TBOutPutFilePath&"不存在！请检查！")
	  ;Exit
   EndIf

   If Not FileExists($TBQiJianBanAppFile) Then
	  myLog($TBQiJianBanAppFile&"不存在！请检查！05")
	  MsgBox(4096, "错误", $TBQiJianBanAppFile&"不存在！请检查！")
	  Exit
   EndIf

   If Not FileExists($TBOutPutFilePath) Then
	  ;myLog($TBOutPutFilePath&"不存在！请检查！06")
	  ;MsgBox(4096, "错误", $TBOutPutFilePath&"不存在！请检查！")
	  ;Exit
   EndIf

   $TBAssistFormulaDll = @ScriptDir&"\user\"&$TBloginname&"\Formula\study\Quote_AccountID_Status.dll"
   If Not FileExists($TBAssistFormulaDll) Then
	  myLog($TBAssistFormulaDll&"不存在！请检查！")
	  ;MsgBox(4096, "错误", $TBAssistFormulaDll&"不存在！请检查！")
	  ;Exit
   EndIf
   myLog("checkFileExist() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 更新环境变量信息，把sendemail程序加入环境变量
;+++++++++++++++++++++++++++++++++++++
Func updateEnv()
	myLog("updateEnv()")
	$PathEnvInfo = EnvGet("PATH");
    ;myLog($PathEnvInfo);
	;myLog(@ScriptDir & "\sendEmail")
	If StringInStr($PathEnvInfo, @ScriptDir & "\sendEmail") Then
		myLog("already in env")
	Else
		myLog("sendEmail folder not in env, and try to add it")
		$PathEnvInfo = $PathEnvInfo & ";" & @ScriptDir & "\sendEmail" & ";"
		; EnvSet设置的环境变量只能被那些由 AutoIt 启动的程序(比如使用Run或RunWait)访问.一旦 AutoIt 被关闭则该环境变量将不复存在.
		If EnvSet("PATH", $PathEnvInfo) Then
			myLog("set sendEmail.exe to path env success")
		Else
			myLog("set sendEmail.exe to path env fail")
		EndIf
		EnvUpdate()
	EndIf
	myLog("Func updateEnv() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 读取配置文件信息
;+++++++++++++++++++++++++++++++++++++
Func LoadIni()
   myLog("--- Func LoadIni() TBAssistConfig: " & $TBAssistConfig)
   $TBloginname = myIniRead($TBAssistConfig, "TB运行参数", "Username", "")							; TB登录ID
   ;myLog($TBloginname)
   $TBloginpassword = myIniRead($TBAssistConfig, "TB运行参数", "Password", "")						; TB登录密码
   $AccountID1 = myIniRead($TBAssistConfig, "TB运行参数", "AccountID1", "")							;用于确认启动自动交易成功的交易账号

   $ServerID = @UserName & "@" & @ComputerName 														; 服务器标识
   $TBloginname = myIniRead($TBAssistConfig, "TB运行参数", "Username", "")							; TB登录ID
   $TBloginpassword = myIniRead($TBAssistConfig, "TB运行参数", "Password", "")						; TB登录密码
   $AccountID1 = myIniRead($TBAssistConfig, "TB运行参数", "AccountID1", "")							; 用于确认启动自动交易成功的交易账号

   $DayStartTime = myIniRead($TBAssistConfig, "TB运行参数", "DayStartTime", "")						; 白盘TB启动时间
   $DayAccountLoginTime = myIniRead($TBAssistConfig, "TB运行参数", "DayAccountLoginTime", "")		; 白盘交易帐户登录时间
   $DayActiveAutoTradeTime = myIniRead($TBAssistConfig, "TB运行参数", "DayActiveAutoTradeTime", "")	; 白盘启动自动交易时间
   $TradeLogSendTime = myIniRead($TBAssistConfig, "TB运行参数", "TradeLogSendTime", "")				; 下午收盘发送账户汇总、持仓统计、当日交易发送时间
   $DayEndTime = myIniRead($TBAssistConfig, "TB运行参数", "DayEndTime", "")							; 白盘关闭TB时间

   $NightStartTime = myIniRead($TBAssistConfig, "TB运行参数", "NightStartTime", "")					; 夜盘TB启动时间
   $NightAccountLoginTime = myIniRead($TBAssistConfig, "TB运行参数", "NightAccountLoginTime", "")	; 夜盘交易帐户登录时间
   $NightActiveAutoTradeTime = myIniRead($TBAssistConfig, "TB运行参数", "NightAccountLoginTime", ""); 夜盘启动自动交易时间
   $NightEndTime = myIniRead($TBAssistConfig, "TB运行参数", "NightEndTime", "")						; 夜盘关闭TB时间

   $OffLineAlert = myIniRead($TBAssistConfig, "TB运行参数", "OffLineAlert", "")						; 行情不走报警开关
   $ChangeQuteIP = myIniRead($TBAssistConfig, "TB运行参数", "ChangeQuteIP", "")						; 切换行情ip开关
   $OffLineIntervalSecond = myIniRead($TBAssistConfig, "TB运行参数", "OffLineIntervalSecond", "")	; 行情不走判断时间间隔
   $CFFEX = myIniRead($TBAssistConfig, "TB运行参数", "CFFEX", "")									; 中金所行情监控开关
   $SHFE = myIniRead($TBAssistConfig, "TB运行参数", "SHFE", "")										; 上期所行情监控开关
   $DCE = myIniRead($TBAssistConfig, "TB运行参数", "DCE", "")										; 大商所行情监控开关
   $CZCE = myIniRead($TBAssistConfig, "TB运行参数", "CZCE", "")										; 郑商所行情监控开关
   $AlertLinkSpeedMS = myIniRead($TBAssistConfig, "TB运行参数", "AlertLinkSpeedMS", "")				; 行情服务器连接速度报警开关

   $PositionMonitorIntervalMinute = myIniRead($TBAssistConfig, "TB运行参数", "PositionMonitorIntervalMinute", "");自动交易持仓匹配检查间隔，单位分钟，大于等于1为检查持仓匹配，小于1则不检查持仓匹配
   $PositionAlertMail = myIniRead($TBAssistConfig, "TB运行参数", "PositionAlertMail", "")			; 1为发送持仓不匹配报警邮件，其他为不报警
   $enSendTradeLog = myIniRead($TBAssistConfig, "TB运行参数", "enSendTradeLog", "")					; 交易记录文件是否发送邮件，1为发送，其他为不发送

   $SmtpServer = myIniRead($TBAssistConfig, "邮件参数", "SmtpServer", "")
   $FromAddress = myIniRead($TBAssistConfig, "邮件参数", "FromAddress", "")
   $ToAddress = myIniRead($TBAssistConfig, "邮件参数", "ToAddress", "")
   $Username = myIniRead($TBAssistConfig, "邮件参数", "Username", "")
   $Password = myIniRead($TBAssistConfig, "邮件参数", "Password", "")
   $AccReportAddress = myIniRead($TBAssistConfig, "邮件参数", "AccReportAddress", "")
   myLog("--- Func LoadIni() End")
EndFunc

;+++++++++++++++++++++++++++++++++++++
; 读取配置文件信息，如有空的项目及时进行提示，并提示误输入后该如何修改
;+++++++++++++++++++++++++++++++++++++
Func myIniRead($ConfigFile = $TBAssistConfig, $DiscName = "", $ItemName = "", $DefaultValue = "")
   Local $IniValueTemp = IniRead($ConfigFile, $DiscName, $ItemName, $DefaultValue); TB登录ID
   myLog("myIniRead() " & $ItemName &": " & $IniValueTemp)
   If $IniValueTemp == $DefaultValue Then
	  MsgBox($MB_SYSTEMMODAL, "提示", "请用记事本编辑" & $ConfigFile & "，并输入"& $ItemName & "信息及其他相关信息，然后重新运行本程序。后续如需修改操作同该操作。")
	  Local $iPID = Run("notepad.exe " & $ConfigFile, "")
	  WinWait("[CLASS:Notepad]", $ConfigFile, 10)
	  Sleep(2000)
	  WinWaitClose("[CLASS:Notepad]")
	  Exit
   EndIf
   return $IniValueTemp;
EndFunc

