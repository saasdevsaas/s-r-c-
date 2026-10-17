import os,csv,json,time,traceback
from datetime import datetime,timedelta,timezone
import MetaTrader5 as mt5
OUT=r'Z:\\data'; STATUS=OUT+r'\\status.json'
def stat(**kw):
    with open(STATUS,'w',encoding='utf-8') as f: json.dump(kw,f,default=str)
def main():
    login=int(os.environ['FN_LOGIN']); password=os.environ['FN_PASSWORD']; server=os.environ.get('FN_SERVER','FundedNext-Server3')
    path=r'C:\\Program Files\\MetaTrader 5\\terminal64.exe'; symbol=os.environ.get('FN_SYMBOL','BTCUSD')
    stat(state='initializing',server=server,symbol=symbol)
    if not mt5.initialize(path=path,login=login,password=password,server=server,timeout=120000): raise RuntimeError('initialize failed: %r'%(mt5.last_error(),))
    ai=mt5.account_info(); ti=mt5.terminal_info()
    if not mt5.symbol_select(symbol,True): raise RuntimeError('symbol_select failed: %r'%(mt5.last_error(),))
    si=mt5.symbol_info(symbol)
    meta={k:getattr(si,k,None) for k in ['name','digits','point','trade_contract_size','volume_min','volume_max','volume_step','swap_long','swap_short','trade_tick_size','trade_tick_value']}
    meta.update({'company':getattr(ai,'company',None),'server':getattr(ai,'server',None),'connected':getattr(ti,'connected',None)})
    with open(OUT+r'\\meta.json','w',encoding='utf-8') as f: json.dump(meta,f,default=str,indent=2)
    start=datetime.fromisoformat(os.environ.get('FN_FROM','2020-01-01')).replace(tzinfo=timezone.utc); end=datetime.fromisoformat(os.environ.get('FN_TO','2026-08-05')).replace(tzinfo=timezone.utc)
    fn=OUT+r'\\BTCUSD_M5.csv'; total=0; first=None; last=None
    with open(fn,'w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['time','open','high','low','close','tick_volume','spread','real_volume']); cur=start
        while cur<end:
            nxt=min(cur+timedelta(days=14),end); arr=mt5.copy_rates_range(symbol,mt5.TIMEFRAME_M5,cur,nxt-timedelta(seconds=1))
            if arr is None: time.sleep(2); arr=mt5.copy_rates_range(symbol,mt5.TIMEFRAME_M5,cur,nxt-timedelta(seconds=1))
            if arr is not None:
                for r in arr:
                    ts=int(r['time']); w.writerow([ts,float(r['open']),float(r['high']),float(r['low']),float(r['close']),int(r['tick_volume']),int(r['spread']),int(r['real_volume'])]); total+=1; first=ts if first is None else first; last=ts
                f.flush()
            stat(state='fetching',bars=total,current=cur.isoformat(),last_error=mt5.last_error(),meta=meta); cur=nxt
    mt5.shutdown(); stat(state='done',bars=total,first=first,last=last,meta=meta)
if __name__=='__main__':
    try: main()
    except Exception as e: stat(state='error',error=str(e),trace=traceback.format_exc()[-4000:]); raise
