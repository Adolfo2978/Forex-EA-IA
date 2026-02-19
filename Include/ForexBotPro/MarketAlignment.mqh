//+------------------------------------------------------------------+
//|                                             MarketAlignment.mqh |
//|                              Forex Bot Pro v7.0 - Market Align   |
//|                              EMA 50/200 + Multi-Timeframe        |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

struct AlignmentResult
{
   ENUM_TREND_DIRECTION direction;
   double confidence;
   bool emaAligned;
   bool mtfAligned;
   bool ema800Aligned;
   double ema50;
   double ema200;
   double ema800;
   string description;
};

struct MarketPhaseResult
{
   ENUM_MARKET_PHASE phase;
   double confidence;
   double volumeRatio;
   string description;
};

class CMarketAlignment
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_primaryTF;
   ENUM_TIMEFRAMES m_secondaryTF;
   int m_emaFast;
   int m_emaSlow;
   int m_emaTrend;
   int m_emaMacro;
   
public:
   CMarketAlignment()
   {
      m_symbol = _Symbol;
      m_primaryTF = PERIOD_M15;
      m_secondaryTF = PERIOD_M30;
      m_emaFast = 21;
      m_emaSlow = 50;
      m_emaTrend = 200;
      m_emaMacro = 800;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES primaryTF, ENUM_TIMEFRAMES secondaryTF,
             int emaFast=21, int emaSlow=50, int emaTrend=200, int emaMacro=800)
   {
      m_symbol = symbol;
      m_primaryTF = primaryTF;
      m_secondaryTF = secondaryTF;
      m_emaFast = emaFast;
      m_emaSlow = emaSlow;
      m_emaTrend = emaTrend;
      m_emaMacro = emaMacro;
   }
   
   double CalculateEMA(ENUM_TIMEFRAMES tf, int period, int shift=0)
   {
      double ema[];
      ArraySetAsSeries(ema, true);
      int handle = iMA(m_symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return 0;
      
      CopyBuffer(handle, 0, shift, 1, ema);
      IndicatorRelease(handle);
      
      return ArraySize(ema) > 0 ? ema[0] : 0;
   }
   
   AlignmentResult GetEMAAlignment()
   {
      AlignmentResult result;
      result.direction = TREND_NEUTRAL;
      result.confidence = 50.0;
      result.emaAligned = false;
      result.mtfAligned = false;
      result.ema800Aligned = false;
      result.ema50 = 0;
      result.ema200 = 0;
      result.ema800 = 0;
      result.description = "Neutral";
      
      double close[];
      ArraySetAsSeries(close, true);
      int copied = CopyClose(m_symbol, m_primaryTF, 0, 1, close);
      if(copied < 1) return result;
      
      double currentPrice = close[0];
      result.ema50 = CalculateEMA(m_primaryTF, m_emaSlow, 0);
      result.ema200 = CalculateEMA(m_primaryTF, m_emaTrend, 0);
      result.ema800 = CalculateEMA(PERIOD_H4, m_emaMacro, 0);
      
      if(result.ema50 == 0 || result.ema200 == 0) return result;
      
      bool priceAboveEMA50 = currentPrice > result.ema50;
      bool priceAboveEMA200 = currentPrice > result.ema200;
      bool ema50AboveEMA200 = result.ema50 > result.ema200;
      
      bool priceAboveEMA800 = (result.ema800 > 0) && (currentPrice > result.ema800);
      bool ema200AboveEMA800 = (result.ema800 > 0) && (result.ema200 > result.ema800);
      result.ema800Aligned = priceAboveEMA800 && ema200AboveEMA800;
      
      if(priceAboveEMA50 && priceAboveEMA200 && ema50AboveEMA200)
      {
         result.direction = TREND_BULLISH;
         result.emaAligned = true;
         result.confidence = result.ema800Aligned ? 92.0 : 85.0;
         result.description = result.ema800Aligned ? 
            "Ultra Strong Bullish: Price > EMA50 > EMA200 > EMA800" :
            "Strong Bullish: Price > EMA50 > EMA200";
      }
      else if(!priceAboveEMA50 && !priceAboveEMA200 && !ema50AboveEMA200)
      {
         result.direction = TREND_BEARISH;
         result.emaAligned = true;
         bool bearishMacro = (result.ema800 > 0) && (currentPrice < result.ema800) && (result.ema200 < result.ema800);
         result.confidence = bearishMacro ? 92.0 : 85.0;
         result.description = bearishMacro ? 
            "Ultra Strong Bearish: Price < EMA50 < EMA200 < EMA800" :
            "Strong Bearish: Price < EMA50 < EMA200";
      }
      else if(priceAboveEMA200 && ema50AboveEMA200)
      {
         result.direction = TREND_BULLISH;
         result.emaAligned = false;
         result.confidence = 70.0;
         result.description = "Bullish: Price below EMA50 but above EMA200";
      }
      else if(!priceAboveEMA200 && !ema50AboveEMA200)
      {
         result.direction = TREND_BEARISH;
         result.emaAligned = false;
         result.confidence = 70.0;
         result.description = "Bearish: Price above EMA50 but below EMA200";
      }
      else
      {
         result.direction = TREND_SIDEWAYS;
         result.emaAligned = false;
         result.confidence = 50.0;
         result.description = "Sideways/Transition";
      }
      
      return result;
   }
   
   bool CheckMTFAlignment()
   {
      double ema50_M15 = CalculateEMA(m_primaryTF, m_emaSlow, 0);
      double ema200_M15 = CalculateEMA(m_primaryTF, m_emaTrend, 0);
      double ema50_M30 = CalculateEMA(m_secondaryTF, m_emaSlow, 0);
      double ema200_M30 = CalculateEMA(m_secondaryTF, m_emaTrend, 0);
      
      if(ema50_M15 == 0 || ema200_M15 == 0 || ema50_M30 == 0 || ema200_M30 == 0)
         return false;
      
      bool bullishM15 = ema50_M15 > ema200_M15;
      bool bullishM30 = ema50_M30 > ema200_M30;
      
      return (bullishM15 == bullishM30);
   }
   
   bool DetectGoldenCross(ENUM_TIMEFRAMES tf, int lookback=4)
   {
      double ema50Prev = CalculateEMA(tf, m_emaSlow, lookback);
      double ema200Prev = CalculateEMA(tf, m_emaTrend, lookback);
      double ema50Curr = CalculateEMA(tf, m_emaSlow, 0);
      double ema200Curr = CalculateEMA(tf, m_emaTrend, 0);
      
      if(ema50Prev == 0 || ema200Prev == 0 || ema50Curr == 0 || ema200Curr == 0)
         return false;
      
      return (ema50Prev < ema200Prev && ema50Curr > ema200Curr);
   }
   
   bool DetectDeathCross(ENUM_TIMEFRAMES tf, int lookback=4)
   {
      double ema50Prev = CalculateEMA(tf, m_emaSlow, lookback);
      double ema200Prev = CalculateEMA(tf, m_emaTrend, lookback);
      double ema50Curr = CalculateEMA(tf, m_emaSlow, 0);
      double ema200Curr = CalculateEMA(tf, m_emaTrend, 0);
      
      if(ema50Prev == 0 || ema200Prev == 0 || ema50Curr == 0 || ema200Curr == 0)
         return false;
      
      return (ema50Prev > ema200Prev && ema50Curr < ema200Curr);
   }
   
   MarketPhaseResult DetectMarketPhase()
   {
      MarketPhaseResult result;
      result.phase = PHASE_ACCUMULATION;
      result.confidence = 50.0;
      result.volumeRatio = 1.0;
      result.description = "Unknown";
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_primaryTF, 0, 100, rates);
      if(copied < 30) return result;
      
      double sumVol = 0;
      for(int i = 0; i < copied; i++)
         sumVol += (double)rates[i].tick_volume;
      double avgVolume = sumVol / copied;
      
      double recentVol = 0;
      for(int i = 0; i < 10; i++)
         recentVol += (double)rates[i].tick_volume;
      recentVol /= 10;
      
      result.volumeRatio = avgVolume > 0 ? recentVol / avgVolume : 1.0;
      
      double priceHigh = rates[0].high;
      double priceLow = rates[0].low;
      for(int i = 0; i < 30; i++)
      {
         if(rates[i].high > priceHigh) priceHigh = rates[i].high;
         if(rates[i].low < priceLow) priceLow = rates[i].low;
      }
      
      double priceRange = priceHigh - priceLow;
      double avgPrice = (priceHigh + priceLow) / 2;
      double rangePercent = avgPrice > 0 ? (priceRange / avgPrice) * 100 : 0;
      
      double currentPrice = rates[0].close;
      double ema50 = CalculateEMA(m_primaryTF, m_emaSlow, 0);
      double ema200 = CalculateEMA(m_primaryTF, m_emaTrend, 0);
      
      if(rangePercent < 2.0 && result.volumeRatio > 1.2)
      {
         result.phase = PHASE_ACCUMULATION;
         result.confidence = 75.0 + MathMin(20.0, result.volumeRatio * 10);
         result.description = "Accumulation: Low range, high volume";
      }
      else if(currentPrice > priceHigh * 0.98 && result.volumeRatio > 1.2)
      {
         result.phase = PHASE_DISTRIBUTION;
         result.confidence = 75.0;
         result.description = "Distribution: Near highs with volume";
      }
      else if(ema50 > ema200 && currentPrice > ema50)
      {
         result.phase = PHASE_MARKUP;
         result.confidence = 70.0;
         result.description = "Markup: Bullish trend";
      }
      else if(ema50 < ema200 && currentPrice < ema50)
      {
         result.phase = PHASE_MARKDOWN;
         result.confidence = 70.0;
         result.description = "Markdown: Bearish trend";
      }
      
      return result;
   }
   
   double GetAlignmentScore(bool isBuySignal)
   {
      AlignmentResult emaResult = GetEMAAlignment();
      bool mtfAligned = CheckMTFAlignment();
      
      double score = 50.0;
      
      if(isBuySignal)
      {
         if(emaResult.direction == TREND_BULLISH)
         {
            score += 20.0;
            if(emaResult.emaAligned) score += 15.0;
         }
         else if(emaResult.direction == TREND_BEARISH)
         {
            score -= 20.0;
         }
      }
      else
      {
         if(emaResult.direction == TREND_BEARISH)
         {
            score += 20.0;
            if(emaResult.emaAligned) score += 15.0;
         }
         else if(emaResult.direction == TREND_BULLISH)
         {
            score -= 20.0;
         }
      }
      
      if(mtfAligned)
         score += 15.0;
      
      return MathMax(0, MathMin(100, score));
   }
};
