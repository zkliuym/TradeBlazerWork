
#include "stdafx.h"

#include "mdspi.h"
#pragma warning(disable : 4996)

extern int requestId;  
extern HANDLE g_hEvent;

void CtpMdSpi::OnRspError(CThostFtdcRspInfoField *pRspInfo,
						  int nRequestID, bool bIsLast)
{
	IsErrorRspInfo(pRspInfo);
}

void CtpMdSpi::OnFrontDisconnected(int nReason)
{
	cerr<<" 响应 | 连接中断..." 
		<< " reason=" << nReason << endl;
}

void CtpMdSpi::OnHeartBeatWarning(int nTimeLapse)
{
	cerr<<" 响应 | 心跳超时警告..." 
		<< " TimerLapse = " << nTimeLapse << endl;
}

void CtpMdSpi::OnFrontConnected()
{
	cerr<<" 连接交易前置...成功"<<endl;
	SetEvent(g_hEvent);
}

void CtpMdSpi::ReqUserLogin(TThostFtdcBrokerIDType	appId,
							TThostFtdcUserIDType	userId,	TThostFtdcPasswordType	passwd)
{
	CThostFtdcReqUserLoginField req;
	memset(&req, 0, sizeof(req));
	strcpy(req.BrokerID, appId);
	strcpy(req.UserID, userId);
	strcpy(req.Password, passwd);
	int ret = pUserApi->ReqUserLogin(&req, ++requestId);
	cerr<<" 请求 | 发送登录..."<<((ret == 0) ? "成功" :"失败") << endl;	
	SetEvent(g_hEvent);
}

void CtpMdSpi::OnRspUserLogin(CThostFtdcRspUserLoginField *pRspUserLogin,
							  CThostFtdcRspInfoField *pRspInfo, int nRequestID, bool bIsLast)
{
	if (!IsErrorRspInfo(pRspInfo) && pRspUserLogin)
	{
		cerr<<" 响应 | 登录成功...当前交易日:"
			<<pRspUserLogin->TradingDay<<endl;
	}
	if(bIsLast) SetEvent(g_hEvent);
}

void CtpMdSpi::SubscribeMarketData(char* instIdList)
{
	vector<char*> list;
	char *token = strtok(instIdList, ",");
	while( token != NULL ){
		list.push_back(token); 
		token = strtok(NULL, ",");
	}
	unsigned int len = list.size();
	char** pInstId = new char* [len];  
	for(unsigned int i=0; i<len;i++)  pInstId[i]=list[i]; 
	int ret=pUserApi->SubscribeMarketData(pInstId, len);
	cerr<<" 请求 | 发送行情订阅... "<<((ret == 0) ? "成功" : "失败")<< endl;
	SetEvent(g_hEvent);
}

void CtpMdSpi::OnRspSubMarketData(
	CThostFtdcSpecificInstrumentField *pSpecificInstrument, 
	CThostFtdcRspInfoField *pRspInfo, int nRequestID, bool bIsLast)
{
	cerr<<" 响应 |  行情订阅...成功"<<endl;
	if(bIsLast)  SetEvent(g_hEvent);
}

void CtpMdSpi::OnRspUnSubMarketData(
	CThostFtdcSpecificInstrumentField *pSpecificInstrument,
	CThostFtdcRspInfoField *pRspInfo, int nRequestID, bool bIsLast)
{
	cerr<<" 响应 |  行情取消订阅...成功"<<endl;
	if(bIsLast)  SetEvent(g_hEvent);
}

void CtpMdSpi::string_replace(string&s1,const string&s2,const string&s3)
{
	string::size_type pos=0;
	string::size_type a=s2.size();
	string::size_type b=s3.size();
	while((pos=s1.find(s2,pos))!=string::npos)
	{
		s1.replace(pos,a,s3);
		pos+=b;
	}
}

string CtpMdSpi::getDBNameFromInstrumentID(TThostFtdcInstrumentIDType InstrumentID)
{
	char buf[16] = {0};
	// http://blog.chinaunix.net/uid-26284412-id-3189214.html
	//  sscanf的高级用法
	sscanf(InstrumentID, "%[^0-9]", buf);
	string strDbName = string(buf)+string("_DB");
	return strDbName;
}

string CtpMdSpi::getDbSQLFromInstrumentID(
	TThostFtdcInstrumentIDType InstrumentID)
{
	string strDbName = getDBNameFromInstrumentID(InstrumentID);
	string strSQL = "create table if not exists TableNameXXX(Contracts varchar(20), date datetime, \
					Open numeric(15,2), High numeric(15,2),Low numeric(15,2),Close numeric(15,2), Volume numeric(25,2),OpenInt numeric(25,2), Turnover numeric(25,2), \
					PreSettlement numeric(15,2), PreClose numeric(15,2), PreOpenInt numeric(15,2));";
	// create index IF_DB_INDEX on IF_DB(Contracts, date);
	
	string_replace(strSQL, "TableNameXXX", strDbName);
	return strSQL;
}

void CtpMdSpi::updateSQLiteData(CThostFtdcDepthMarketDataField *pDepthMarketData)
{
	string sSQL = "insert into IF_DB values(2, null, 200, 2.22);";
	char buf[1024] = {0};
	sprintf(buf,"insert into %s values(2, null, 200, 2.22);", getDBNameFromInstrumentID(pDepthMarketData->InstrumentID).c_str());  
}

void CtpMdSpi::OnRtnDepthMarketData(
	CThostFtdcDepthMarketDataField *pDepthMarketData)
{
	cerr<<"MdSpi 行情 | 合约:"<<pDepthMarketData->InstrumentID
		<<" 现价:"<<pDepthMarketData->LastPrice
		<<" 最高价:" << pDepthMarketData->HighestPrice
		<<" 最低价:" << pDepthMarketData->LowestPrice
		<<" 卖一价:" << pDepthMarketData->AskPrice1 
		<<" 卖一量:" << pDepthMarketData->AskVolume1 
		<<" 买一价:" << pDepthMarketData->BidPrice1
		<<" 买一量:" << pDepthMarketData->BidVolume1
		<<" 持仓量:"<< pDepthMarketData->OpenInterest <<endl;

	// 从数据库查找对应的表，如果没有对应表格，则创建表格
	string strSql = getDbSQLFromInstrumentID(pDepthMarketData->InstrumentID);
	m_db.execDML(strSql.c_str());
	m_db.execDML("insert into IF_DB values('IF1706', '2016-06-12', 200, 300, 400, 500, 1000, 2000, 3000, 4000, 5000, 6000);");
	
	// 从表格查询当日的IF K线，没有则创建
	// 更新k线的开高低收
	// 
	//CppSQLite3DB db;

	//cout << "SQLite Header Version: " << CppSQLite3DB::SQLiteHeaderVersion() << endl;
	//cout << "SQLite Library Version: " << CppSQLite3DB::SQLiteLibraryVersion() << endl;
	//cout << "SQLite Library Version Number: " << CppSQLite3DB::SQLiteLibraryVersionNumber() << endl;

	////remove(gszFile);
	//db.open(gszFile);
	//db.execDML("create table if not exists if_db(Contracts varchar(20), date datetime, \
	//		   Open numeric(15,2), High numeric(15,2),Low numeric(15,2),Close numeric(15,2), Volume numeric(25,2),OpenInt numeric(25,2), Turnover numeric(25,2), \
	//		   PreSettlement numeric(15,2), PreClose numeric(15,2), PreOpenInt numeric(15,2));");
	// 
	// 
	// 
	// 
	// 
	// 
	// 
}

bool CtpMdSpi::IsErrorRspInfo(CThostFtdcRspInfoField *pRspInfo)
{	
	bool ret = ((pRspInfo) && (pRspInfo->ErrorID != 0));
	if (ret){
		cerr<<" 响应 | "<<pRspInfo->ErrorMsg<<endl;
	}
	return ret;
}