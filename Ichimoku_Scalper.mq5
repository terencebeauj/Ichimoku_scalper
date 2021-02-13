//+------------------------------------------------------------------+
//|                                             Ichimoku_Scalper.mq5 |
//|                                                 Terence Beaujour |
//|                                            beaujour.t@hotmail.fr |
//+------------------------------------------------------------------+
#property copyright "Terence Beaujour"
#property version   "1.00"

#include <Trade/trade.mqh>
#include <Trade/PositionInfo.mqh>

// Input for Optimization
input ENUM_TIMEFRAMES my_timeframe = PERIOD_CURRENT;
input int start_hour=0;
input int end_hour=23;
input long my_magic_number;
input int my_slippage;
input double my_volume=0.01;
input unsigned int sl_buy;
input unsigned int sl_sell;
input unsigned int tp_buy;
input unsigned int tp_sell;
input double TrailStopBuy = 100;
input double TrailStepBuy = 50;
input double TrailStopSell = 100;
input double TrailStepSell = 50;

// Global variables
int ichimoku_handle;
int sar_handle;
int tradenow=0;
double ssa_buff[], ssb_buff[];
double sar_buff[];
bool buyflag, sellflag;

CTrade trade;
CPositionInfo positionInfo;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ichimoku_handle = iIchimoku(Symbol(),my_timeframe,9,26,52);
   sar_handle = iSAR(Symbol(),my_timeframe,0.02,0.2);

   if(ichimoku_handle==INVALID_HANDLE || sar_handle==INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(my_magic_number);
   trade.SetAsyncMode(false);
   trade.SetDeviationInPoints(my_slippage);

   ArraySetAsSeries(ssa_buff,true);
   ArraySetAsSeries(ssb_buff,true);
   ArraySetAsSeries(sar_buff,true);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlRates my_candles[];
   MqlTick my_tick;
   int err1=0, err2=0, err3=0, err4=0;
   double buy_sl, buy_tp, sell_sl, sell_tp;

   if(SymbolInfoTick(Symbol(), my_tick))
     {
      MqlDateTime time;
      TimeCurrent(time);
      
      Trail(my_tick);
      ArraySetAsSeries(my_candles,true);
      err1=CopyBuffer(ichimoku_handle,2,0,9,ssa_buff);
      err2=CopyBuffer(ichimoku_handle,3,0,9,ssb_buff);
      err3=CopyBuffer(sar_handle,0,0,9,sar_buff);
      err4=CopyRates(Symbol(),my_timeframe,0,10,my_candles);

      if(err1<=0 || err2<=0 || err3<=0 || err4<=0)
         return;

      buyflag = (my_candles[2].close>ssa_buff[2] && my_candles[2].close>ssb_buff[2] && my_candles[1].close>ssa_buff[1] && my_candles[1].close>ssb_buff[1]) && (sar_buff[2]>my_candles[2].close && sar_buff[1]<my_candles[1].close && my_candles[1].open<my_candles[1].close) && (sar_buff[1]>ssa_buff[1] && sar_buff[1]>ssb_buff[1]);
      sellflag = (my_candles[2].close<ssa_buff[2] && my_candles[2].close<ssb_buff[2] && my_candles[1].close<ssa_buff[1] && my_candles[1].close<ssb_buff[1]) && (sar_buff[2]<my_candles[2].close && sar_buff[1]>my_candles[1].close && my_candles[1].open>my_candles[1].close) && (sar_buff[1]<ssa_buff[1] && sar_buff[1]<ssb_buff[1]);

      if(buyflag && NewCandle() && time.hour>=start_hour && time.hour<=end_hour)
        {
         for(int i=PositionsTotal()-1; i>=0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(ticket>0)
              {
               if(positionInfo.PositionType()==POSITION_TYPE_SELL)
                  trade.PositionClose(ticket,my_slippage);
              }
           }
         buy_sl = NormalizeDouble(my_tick.bid-(Point()*sl_buy), Digits());
         buy_tp = NormalizeDouble(my_tick.bid+(Point()*tp_buy), Digits());
         trade.Buy(my_volume,Symbol(),my_tick.ask,buy_sl,buy_tp);
        }

      if(sellflag && NewCandle() && time.hour>=start_hour && time.hour<=end_hour)
        {
         for(int i= PositionsTotal()-1; i>=0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(ticket>0)
              {
               if(positionInfo.PositionType()==POSITION_TYPE_BUY)
                  trade.PositionClose(ticket,my_slippage);
              }
           }
         sell_sl = NormalizeDouble(my_tick.ask+(Point()*sl_sell), Digits());
         sell_tp = NormalizeDouble(my_tick.ask-(Point()*tp_buy), Digits());
         trade.Sell(my_volume,Symbol(),my_tick.bid,sell_sl,sell_tp);
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Check if there is a new candle
bool NewCandle()
  {
   static int BarsOnChart=0;
   if(Bars(Symbol(),my_timeframe)==BarsOnChart)
      return false;
   BarsOnChart = Bars(Symbol(),my_timeframe);
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Function to do the trailling stop
void Trail(MqlTick &my_tick)
  {
   int pt = PositionsTotal();

   for(int i=pt; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_TYPE)==0 && my_tick.bid-PositionGetDouble(POSITION_PRICE_OPEN)>TrailStopBuy*Point() && my_tick.bid-(TrailStepBuy*Point())>PositionGetDouble(POSITION_SL))
           {
            double tp = PositionGetDouble(POSITION_TP);
            double sl = NormalizeDouble(my_tick.bid-(TrailStepBuy*Point()), Digits());
            if(TrailStepBuy*Point()>=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) && SymbolInfoInteger(Symbol(),SYMBOL_SPREAD)<=NormalizeDouble(MathAbs(my_tick.bid-sl),Digits())*MathPow(10,Digits()))
               trade.PositionModify(ticket,sl,tp);
           }
         if(PositionGetInteger(POSITION_TYPE)==1 && PositionGetDouble(POSITION_PRICE_OPEN)-my_tick.ask>TrailStopSell*Point() && my_tick.ask+(TrailStepSell*Point())<PositionGetDouble(POSITION_SL))
           {
            double tp = PositionGetDouble(POSITION_TP);
            double sl = NormalizeDouble(my_tick.ask+(TrailStepSell*Point()),Digits());
            if(TrailStepSell*Point()>=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) && SymbolInfoInteger(Symbol(),SYMBOL_SPREAD)<=NormalizeDouble(MathAbs(my_tick.ask-sl),Digits())*MathPow(10,Digits()))
               trade.PositionModify(ticket,sl,tp);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+