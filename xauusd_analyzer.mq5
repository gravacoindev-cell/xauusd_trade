//+------------------------------------------------------------------+
//| XAUUSD Analyzer - M15                                            |
//| ANALYSIS ONLY - NO TRADING                                       |
//+------------------------------------------------------------------+
#property strict

input int FastMA = 50;
input int SlowMA = 400;

input int LookbackSR = 30;
input double WickRatio = 2.0;
input double RiskReward1 = 1.5;
input double RiskReward2 = 2.0;

int maFastHandle;
int maSlowHandle;

datetime lastSignalTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   maFastHandle = iMA(_Symbol, PERIOD_M15, FastMA, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_M15, SlowMA, 0, MODE_EMA, PRICE_CLOSE);

   if(maFastHandle == INVALID_HANDLE ||
      maSlowHandle == INVALID_HANDLE)
   {
      Print("Gagal membuat MA handle");
      return(INIT_FAILED);
   }

   Print("XAUUSD Analyzer aktif - ANALYSIS ONLY");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(maFastHandle);
   IndicatorRelease(maSlowHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBar = 0;

   datetime currentBar = iTime(_Symbol, PERIOD_M15, 0);

   // Hanya analisa ketika candle baru terbentuk
   if(currentBar == lastBar)
      return;

   lastBar = currentBar;

   AnalyzeMarket();
}

//+------------------------------------------------------------------+
void AnalyzeMarket()
{
   MqlRates rates[];

   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, PERIOD_M15, 0, LookbackSR + 10, rates) <= 0)
      return;

   double fastMA[];
   double slowMA[];

   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);

   if(CopyBuffer(maFastHandle, 0, 0, 5, fastMA) <= 0)
      return;

   if(CopyBuffer(maSlowHandle, 0, 0, 5, slowMA) <= 0)
      return;

   // Candle terakhir yang sudah close
   MqlRates candle = rates[1];

   double body = MathAbs(candle.close - candle.open);

   double upperWick =
      candle.high - MathMax(candle.open, candle.close);

   double lowerWick =
      MathMin(candle.open, candle.close) - candle.low;

   if(body <= 0)
      return;

   bool bullishTrend = fastMA[1] > slowMA[1];
   bool bearishTrend = fastMA[1] < slowMA[1];

   //==============================================================
   // SUPPORT & RESISTANCE
   //==============================================================

   double support = rates[2].low;
   double resistance = rates[2].high;

   for(int i = 2; i <= LookbackSR; i++)
   {
      if(rates[i].low < support)
         support = rates[i].low;

      if(rates[i].high > resistance)
         resistance = rates[i].high;
   }

   double price = candle.close;

   //==============================================================
   // REJECTION
   //==============================================================

   bool bullishRejection =
      lowerWick >= body * WickRatio &&
      candle.close > candle.open;

   bool bearishRejection =
      upperWick >= body * WickRatio &&
      candle.close < candle.open;

   //==============================================================
   // BUY SETUP
   //==============================================================

   if(bullishTrend &&
      bullishRejection &&
      price > support)
   {
      GenerateSignal(
         "BUY",
         price,
         candle.low,
         RiskReward1,
         RiskReward2
      );

      return;
   }

   //==============================================================
   // SELL SETUP
   //==============================================================

   if(bearishTrend &&
      bearishRejection &&
      price < resistance)
   {
      GenerateSignal(
         "SELL",
         price,
         candle.high,
         RiskReward1,
         RiskReward2
      );

      return;
   }
}

//+------------------------------------------------------------------+
void GenerateSignal(
   string direction,
   double entry,
   double extreme,
   double rr1,
   double rr2
)
{
   datetime signalTime = iTime(_Symbol, PERIOD_M15, 1);

   // Hindari sinyal yang sama berulang
   if(signalTime == lastSignalTime)
      return;

   lastSignalTime = signalTime;

   double sl;
   double risk;

   if(direction == "BUY")
   {
      sl = extreme;
      risk = entry - sl;
   }
   else
   {
      sl = extreme;
      risk = sl - entry;
   }

   if(risk <= 0)
      return;

   double tp1;
   double tp2;

   if(direction == "BUY")
   {
      tp1 = entry + risk * rr1;
      tp2 = entry + risk * rr2;
   }
   else
   {
      tp1 = entry - risk * rr1;
      tp2 = entry - risk * rr2;
   }

   string message =
      "\n============================\n" +
      "XAUUSD M15 SIGNAL\n" +
      "============================\n" +
      "Signal : " + direction + "\n" +
      "Entry  : " + DoubleToString(entry, _Digits) + "\n" +
      "SL     : " + DoubleToString(sl, _Digits) + "\n" +
      "TP1    : " + DoubleToString(tp1, _Digits) + "\n" +
      "TP2    : " + DoubleToString(tp2, _Digits) + "\n" +
      "RR1    : 1:" + DoubleToString(rr1, 1) + "\n" +
      "RR2    : 1:" + DoubleToString(rr2, 1) + "\n" +
      "============================";

   Print(message);

   Alert(message);

   Comment(message);
}
//+------------------------------------------------------------------+
