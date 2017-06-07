// getCtpData2SQLite.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include "sfit/include/ThostFtdcMdApi.h"
#include "sfit/include/ThostFtdcTraderApi.h"

#include "mdspi.h"
#include "traderspi.h"

//
HANDLE g_hEvent;

//
string strNeedQuote;

// 请求编号
int requestId=0;

// 前置地址
//char mdFront[]   ="tcp://180.168.212.229:41213";
//char tradeFront[]="tcp://180.168.212.229:41205";
//TThostFtdcBrokerIDType		appId	= "8080";
//TThostFtdcUserIDType		userId	= "";
//TThostFtdcPasswordType	    passwd	= "";
char mdFront[]   ="tcp://61.144.241.113:41213";
char tradeFront[]="tcp://61.144.241.113:41205";
TThostFtdcBrokerIDType		appId	= "8090";
TThostFtdcUserIDType		userId	= "";
TThostFtdcPasswordType	    passwd	= "";


const char* gszFile = "test.db";

int _tmain(int argc, _TCHAR* argv[])
{
	CppSQLite3DB db;

	cout << "SQLite Header Version: " << CppSQLite3DB::SQLiteHeaderVersion() << endl;
	cout << "SQLite Library Version: " << CppSQLite3DB::SQLiteLibraryVersion() << endl;
	cout << "SQLite Library Version Number: " << CppSQLite3DB::SQLiteLibraryVersionNumber() << endl;

	remove(gszFile);
	db.open(gszFile);

	////////////////////////////////////////////////////////////////////////////////
	// Demonstrate getStringField(), getIntField(), getFloatField()
	////////////////////////////////////////////////////////////////////////////////
	db.execDML("create table parts(no int, name char(20), qty int, cost number);");
	db.execDML("insert into parts values(1, 'part1', 100, 1.11);");
	db.execDML("insert into parts values(2, null, 200, 2.22);");
	db.execDML("insert into parts values(3, 'part3', null, 3.33);");
	db.execDML("insert into parts values(4, 'part4', 400, null);");

	cout << endl << "CppSQLite3Query getStringField(), getIntField(), getFloatField() tests" << endl;
	CppSQLite3Query q = db.execQuery("select * from parts;");
	while (!q.eof())
	{
		cout << q.getIntField(0) << "|";
		cout << q.getStringField(1) << "|";
		cout << q.getInt64Field(2) << "|";
		cout << q.getFloatField(3) << "|" << endl;
		q.nextRow();
	}

	cout << endl << "specify NULL values tests" << endl;
	q = db.execQuery("select * from parts;");
	while (!q.eof())
	{
		cout << q.getIntField(0) << "|";
		cout << q.getStringField(1, "NULL") << "|";
		cout << q.getIntField(2, -1) << "|";
		cout << q.getFloatField(3, -3.33) << "|" << endl;
		q.nextRow();
	}

	cout << endl << "Specify fields by name" << endl;
	q = db.execQuery("select * from parts;");
	while (!q.eof())
	{
		cout << q.getIntField("no") << "|";
		cout << q.getStringField("name") << "|";
		cout << q.getInt64Field("qty") << "|";
		cout << q.getFloatField("cost") << "|" << endl;
		q.nextRow();
	}

	cout << endl << "specify NULL values tests" << endl;
	system("pause");
	return 0;

	g_hEvent=CreateEvent(NULL, true, false, NULL); 

	//初始化UserApi
	CThostFtdcMdApi* pMdUserApi=CThostFtdcMdApi::CreateFtdcMdApi();
	CtpMdSpi* pMdUserSpi=new CtpMdSpi(pMdUserApi); //创建回调处理类对象MdSpi
	pMdUserApi->RegisterSpi(pMdUserSpi);			 // 回调对象注入接口类
	pMdUserApi->RegisterFront(mdFront);		     // 注册行情前置地址
	pMdUserApi->Init();      //接口线程启动, 开始工作	
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	//初始化UserApi
	CThostFtdcTraderApi* pTraderUserApi = CThostFtdcTraderApi::CreateFtdcTraderApi();
	CtpTraderSpi* pTraderUserSpi = new CtpTraderSpi(pTraderUserApi);
	pTraderUserApi->RegisterSpi((CThostFtdcTraderSpi*)pTraderUserSpi);			// 注册事件类
	pTraderUserApi->SubscribePublicTopic(THOST_TERT_RESTART);					// 注册公有流
	pTraderUserApi->SubscribePrivateTopic(THOST_TERT_RESTART);			  // 注册私有流
	pTraderUserApi->RegisterFront(tradeFront);							// 注册交易前置地址
	pTraderUserApi->Init();
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	// 登录行情
	pMdUserSpi->ReqUserLogin(appId,userId,passwd);
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	// 登录交易
	pTraderUserSpi->ReqUserLogin(appId,userId,passwd);
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	// 确认结算单
	pTraderUserSpi->ReqSettlementInfoConfirm();
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	// 查询合约
	TThostFtdcInstrumentIDType instId = "";
	pTraderUserSpi->ReqQryInstrument(instId);
	WaitForSingleObject(g_hEvent,INFINITE);
	ResetEvent(g_hEvent);

	//
	//pMdUserSpi->SubscribeMarketData((char*)strNeedQuote.c_str());

	//pMdUserApi->Join();      //等待接口线程退出
	//pTraderUserApi->Join();  

	printf("Input q to quit!");
	char ch;
	ch = getchar();
	if(ch == 'q') 
		exit(0);

	//system("pause");
	return 0;
}

