#property script_show_inputs

#define FROM_DATE "2024.02.05 00:00"
#define TO_DATE   "2026.08.05 00:00"

string FindBTCSymbol()
{
   string preferred="BTCUSD";
   if(SymbolSelect(preferred,true)) return preferred;
   int total=SymbolsTotal(false);
   for(int i=0;i<total;i++)
   {
      string s=SymbolName(i,false);
      string u=s;
      StringToUpper(u);
      if(StringFind(u,"BTC")>=0 && StringFind(u,"USD")>=0)
      {
         if(SymbolSelect(s,true)) return s;
      }
   }
   return "";
}

void WriteStatus(string state,string detail="")
{
   int h=FileOpen("FN_status.json",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   string safe=detail;
   StringReplace(safe,"\\","\\\\");
   StringReplace(safe,"\"","\\\"");
   FileWriteString(h,"{\"state\":\""+state+"\",\"detail\":\""+safe+"\"}\n");
   FileClose(h);
}

bool ExportTF(string sym,ENUM_TIMEFRAMES tf,string filename,datetime from,datetime to)
{
   int h=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return false;
   FileWrite(h,"time","open","high","low","close","tick_volume","spread","real_volume");
   datetime cur=from;
   long rows=0;
   while(cur<to)
   {
      datetime nxt=cur+30*86400;
      if(nxt>to) nxt=to;
      MqlRates r[];
      ArraySetAsSeries(r,false);
      int got=-1;
      for(int a=0;a<8;a++)
      {
         ResetLastError();
         got=CopyRates(sym,tf,cur,nxt-1,r);
         if(got>0) break;
         Sleep(1500);
      }
      if(got>0)
      {
         for(int i=0;i<got;i++)
         {
            FileWrite(h,(long)r[i].time,r[i].open,r[i].high,r[i].low,r[i].close,(long)r[i].tick_volume,(int)r[i].spread,(long)r[i].real_volume);
            rows++;
         }
         FileFlush(h);
      }
      cur=nxt;
   }
   FileClose(h);
   return rows>0;
}

void WriteMeta(string sym)
{
   int h=FileOpen("FN_meta.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE) return;
   FileWrite(h,"symbol","server","company","digits","point","contract_size","volume_min","volume_max","volume_step","swap_long","swap_short","time_trade_server","time_gmt");
   FileWrite(h,sym,AccountInfoString(ACCOUNT_SERVER),AccountInfoString(ACCOUNT_COMPANY),(int)SymbolInfoInteger(sym,SYMBOL_DIGITS),SymbolInfoDouble(sym,SYMBOL_POINT),SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX),SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),SymbolInfoDouble(sym,SYMBOL_SWAP_LONG),SymbolInfoDouble(sym,SYMBOL_SWAP_SHORT),(long)TimeTradeServer(),(long)TimeGMT());
   FileClose(h);
}

void OnStart()
{
   WriteStatus("starting");
   for(int i=0;i<90 && !TerminalInfoInteger(TERMINAL_CONNECTED);i++) Sleep(1000);
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      WriteStatus("error","terminal_not_connected");
      TerminalClose(11);
      return;
   }
   string sym=FindBTCSymbol();
   if(sym=="")
   {
      WriteStatus("error","btc_symbol_not_found");
      TerminalClose(12);
      return;
   }
   WriteMeta(sym);
   datetime from=StringToTime(FROM_DATE);
   datetime to=StringToTime(TO_DATE);
   WriteStatus("exporting_m1",sym);
   bool ok1=ExportTF(sym,PERIOD_M1,"FN_BTCUSD_M1.csv",from,to);
   WriteStatus("exporting_m5",sym);
   bool ok5=ExportTF(sym,PERIOD_M5,"FN_BTCUSD_M5.csv",from,to);
   if(ok1 && ok5) WriteStatus("done",sym);
   else WriteStatus("error","history_export_failed");
   TerminalClose((ok1 && ok5)?0:13);
}
