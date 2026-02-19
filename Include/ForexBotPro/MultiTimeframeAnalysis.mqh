//+------------------------------------------------------------------+
//|                                      MultiTimeframeAnalysis.mqh |
//|                              Forex Bot Pro v7.1 - MTF Analysis   |
//|                              H1, H4, D1 with Previous Day HL     |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.1"
#property strict

struct DayReference
{
   double prevDayHigh;
   double prevDayLow;
   double prevDayOpen;
   double prevDayClose;
   double prevDayMid;
   double prevDayRange;
   double todayHigh;
   double todayLow;
   double todayOpen;
   double adr;
   double adrUsedPercent;
   bool priceAbovePrevMid;
   bool priceNearPrevHigh;
   bool priceNearPrevLow;
};

struct TimeframeTrend
{
   bool isBullish;
   double strength;
   double ema20;
   double ema50;
   double ema200;
   double ema800;
   double rsi;
   double momentum;
   bool emaAligned;
   bool ema800Aligned;
   bool hasBreakout;
   string description;
};

struct MTFAnalysis
{
   TimeframeTrend h1;
   TimeframeTrend h4;
   TimeframeTrend d1;
   DayReference dayRef;
   double overallScore;
   double trendAlignment;
   bool allTimeframesAligned;
   ENUM_TIMEFRAMES dominantTrend;
   string recommendation;
};

class CMultiTimeframeAnalysis
{
private:
   string m_symbol;
   int m_h1Ema20, m_h1Ema50, m_h1Ema200, m_h1Rsi;
   int m_h4Ema20, m_h4Ema50, m_h4Ema200, m_h4Ema800, m_h4Rsi;
   int m_d1Ema20, m_d1Ema50, m_d1Ema200, m_d1Ema800, m_d1Rsi;
   bool m_initialized;
   MTFAnalysis m_lastAnalysis;
   datetime m_lastUpdate;
   
   double m_nearThresholdPercent;
   
public:
   CMultiTimeframeAnalysis()
   {
      m_symbol = _Symbol;
      m_initialized = false;
      m_lastUpdate = 0;
      m_nearThresholdPercent = 0.15;
      ZeroMemory(m_lastAnalysis);
   }
   
   ~CMultiTimeframeAnalysis()
   {
      ReleaseHandles();
   }
   
   void Init(string symbol)
   {
      m_symbol = symbol;
      
      m_h1Ema20 = iMA(m_symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Ema50 = iMA(m_symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Ema200 = iMA(m_symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Rsi = iRSI(m_symbol, PERIOD_H1, 14, PRICE_CLOSE);
      
      m_h4Ema20 = iMA(m_symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_h4Ema50 = iMA(m_symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_h4Ema200 = iMA(m_symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_h4Ema800 = iMA(m_symbol, PERIOD_H4, 800, 0, MODE_EMA, PRICE_CLOSE);
      m_h4Rsi = iRSI(m_symbol, PERIOD_H4, 14, PRICE_CLOSE);
      
      m_d1Ema20 = iMA(m_symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_d1Ema50 = iMA(m_symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_d1Ema200 = iMA(m_symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_d1Ema800 = iMA(m_symbol, PERIOD_D1, 800, 0, MODE_EMA, PRICE_CLOSE);
      m_d1Rsi = iRSI(m_symbol, PERIOD_D1, 14, PRICE_CLOSE);
      
      m_initialized = true;
   }
   
   void ReleaseHandles()
   {
      if(m_h1Ema20 != INVALID_HANDLE) IndicatorRelease(m_h1Ema20);
      if(m_h1Ema50 != INVALID_HANDLE) IndicatorRelease(m_h1Ema50);
      if(m_h1Ema200 != INVALID_HANDLE) IndicatorRelease(m_h1Ema200);
      if(m_h1Rsi != INVALID_HANDLE) IndicatorRelease(m_h1Rsi);
      if(m_h4Ema20 != INVALID_HANDLE) IndicatorRelease(m_h4Ema20);
      if(m_h4Ema50 != INVALID_HANDLE) IndicatorRelease(m_h4Ema50);
      if(m_h4Ema200 != INVALID_HANDLE) IndicatorRelease(m_h4Ema200);
      if(m_h4Ema800 != INVALID_HANDLE) IndicatorRelease(m_h4Ema800);
      if(m_h4Rsi != INVALID_HANDLE) IndicatorRelease(m_h4Rsi);
      if(m_d1Ema20 != INVALID_HANDLE) IndicatorRelease(m_d1Ema20);
      if(m_d1Ema50 != INVALID_HANDLE) IndicatorRelease(m_d1Ema50);
      if(m_d1Ema200 != INVALID_HANDLE) IndicatorRelease(m_d1Ema200);
      if(m_d1Ema800 != INVALID_HANDLE) IndicatorRelease(m_d1Ema800);
      if(m_d1Rsi != INVALID_HANDLE) IndicatorRelease(m_d1Rsi);
   }
   
   DayReference AnalyzeDayReference()
   {
      DayReference ref;
      ZeroMemory(ref);
      
      MqlRates daily[];
      ArraySetAsSeries(daily, true);
      
      int copied = CopyRates(m_symbol, PERIOD_D1, 0, 22, daily);
      if(copied < 2) return ref;
      
      ref.todayHigh = daily[0].high;
      ref.todayLow = daily[0].low;
      ref.todayOpen = daily[0].open;
      
      ref.prevDayHigh = daily[1].high;
      ref.prevDayLow = daily[1].low;
      ref.prevDayOpen = daily[1].open;
      ref.prevDayClose = daily[1].close;
      ref.prevDayMid = (ref.prevDayHigh + ref.prevDayLow) / 2.0;
      ref.prevDayRange = ref.prevDayHigh - ref.prevDayLow;
      
      double sumRange = 0;
      for(int i = 1; i <= 20 && i < copied; i++)
         sumRange += daily[i].high - daily[i].low;
      ref.adr = sumRange / MathMin(20, copied - 1);
      
      double todayRange = ref.todayHigh - ref.todayLow;
      ref.adrUsedPercent = (ref.adr > 0) ? (todayRange / ref.adr) * 100 : 0;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      ref.priceAbovePrevMid = (currentPrice > ref.prevDayMid);
      
      double nearThreshold = ref.prevDayRange * m_nearThresholdPercent;
      ref.priceNearPrevHigh = (MathAbs(currentPrice - ref.prevDayHigh) <= nearThreshold);
      ref.priceNearPrevLow = (MathAbs(currentPrice - ref.prevDayLow) <= nearThreshold);
      
      return ref;
   }
   
   TimeframeTrend AnalyzeTimeframe(ENUM_TIMEFRAMES tf, int ema20Handle, int ema50Handle, 
                                   int ema200Handle, int rsiHandle, int ema800Handle = INVALID_HANDLE)
   {
      TimeframeTrend trend;
      ZeroMemory(trend);
      
      double ema20[], ema50[], ema200[], rsi[], ema800[];
      ArraySetAsSeries(ema20, true);
      ArraySetAsSeries(ema50, true);
      ArraySetAsSeries(ema200, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(ema800, true);
      
      if(CopyBuffer(ema20Handle, 0, 0, 5, ema20) < 5) return trend;
      if(CopyBuffer(ema50Handle, 0, 0, 5, ema50) < 5) return trend;
      if(CopyBuffer(ema200Handle, 0, 0, 5, ema200) < 5) return trend;
      if(CopyBuffer(rsiHandle, 0, 0, 5, rsi) < 5) return trend;
      
      trend.ema20 = ema20[0];
      trend.ema50 = ema50[0];
      trend.ema200 = ema200[0];
      trend.rsi = rsi[0];
      
      if(ema800Handle != INVALID_HANDLE && CopyBuffer(ema800Handle, 0, 0, 5, ema800) >= 1)
         trend.ema800 = ema800[0];
      else
         trend.ema800 = 0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol, tf, 0, 10, rates) < 5) return trend;
      
      double currentPrice = rates[0].close;
      
      trend.isBullish = (ema20[0] > ema50[0] && currentPrice > ema200[0]);
      trend.emaAligned = (ema20[0] > ema50[0] && ema50[0] > ema200[0]) ||
                         (ema20[0] < ema50[0] && ema50[0] < ema200[0]);
      
      if(trend.ema800 > 0)
      {
         bool bullish800 = (currentPrice > trend.ema800) && (ema200[0] > trend.ema800);
         bool bearish800 = (currentPrice < trend.ema800) && (ema200[0] < trend.ema800);
         trend.ema800Aligned = (trend.isBullish && bullish800) || (!trend.isBullish && bearish800);
      }
      else
         trend.ema800Aligned = false;
      
      trend.momentum = (ema20[0] - ema20[4]) / ema20[0] * 100;
      
      double priceFromEma200 = (currentPrice - ema200[0]) / ema200[0] * 100;
      double emaSeparation = MathAbs(ema20[0] - ema50[0]) / ema50[0] * 100;
      
      trend.strength = MathMin(100, MathAbs(priceFromEma200) * 20 + emaSeparation * 10);
      if(trend.ema800Aligned) trend.strength = MathMin(100, trend.strength + 10);
      
      double recentHigh = rates[1].high, recentLow = rates[1].low;
      for(int i = 2; i < 5; i++)
      {
         if(rates[i].high > recentHigh) recentHigh = rates[i].high;
         if(rates[i].low < recentLow) recentLow = rates[i].low;
      }
      trend.hasBreakout = (rates[0].close > recentHigh) || (rates[0].close < recentLow);
      
      if(trend.isBullish && trend.emaAligned && trend.ema800Aligned)
         trend.description = "Ultra Strong Bullish (EMA800 Aligned)";
      else if(trend.isBullish && trend.emaAligned)
         trend.description = "Strong Bullish";
      else if(trend.isBullish)
         trend.description = "Bullish";
      else if(!trend.isBullish && trend.emaAligned && trend.ema800Aligned)
         trend.description = "Ultra Strong Bearish (EMA800 Aligned)";
      else if(!trend.isBullish && trend.emaAligned)
         trend.description = "Strong Bearish";
      else
         trend.description = "Bearish";
      
      return trend;
   }
   
   MTFAnalysis Analyze()
   {
      if(!m_initialized) 
      {
         ZeroMemory(m_lastAnalysis);
         return m_lastAnalysis;
      }
      
      datetime now = TimeCurrent();
      if(now - m_lastUpdate < 60)
         return m_lastAnalysis;
      
      m_lastUpdate = now;
      
      m_lastAnalysis.h1 = AnalyzeTimeframe(PERIOD_H1, m_h1Ema20, m_h1Ema50, m_h1Ema200, m_h1Rsi);
      m_lastAnalysis.h4 = AnalyzeTimeframe(PERIOD_H4, m_h4Ema20, m_h4Ema50, m_h4Ema200, m_h4Rsi, m_h4Ema800);
      m_lastAnalysis.d1 = AnalyzeTimeframe(PERIOD_D1, m_d1Ema20, m_d1Ema50, m_d1Ema200, m_d1Rsi, m_d1Ema800);
      m_lastAnalysis.dayRef = AnalyzeDayReference();
      
      int bullCount = 0;
      if(m_lastAnalysis.h1.isBullish) bullCount++;
      if(m_lastAnalysis.h4.isBullish) bullCount++;
      if(m_lastAnalysis.d1.isBullish) bullCount++;
      
      m_lastAnalysis.allTimeframesAligned = (bullCount == 0 || bullCount == 3);
      m_lastAnalysis.trendAlignment = (bullCount == 3 || bullCount == 0) ? 100 :
                                      (bullCount == 2 || bullCount == 1) ? 60 : 30;
      
      m_lastAnalysis.overallScore = (m_lastAnalysis.d1.strength * 0.4 +
                                     m_lastAnalysis.h4.strength * 0.35 +
                                     m_lastAnalysis.h1.strength * 0.25) *
                                     (m_lastAnalysis.trendAlignment / 100);
      
      if(m_lastAnalysis.allTimeframesAligned)
      {
         if(m_lastAnalysis.d1.emaAligned)
            m_lastAnalysis.overallScore += 15;
         if(m_lastAnalysis.d1.ema800Aligned)
            m_lastAnalysis.overallScore += 10;
      }
      
      if(m_lastAnalysis.dayRef.adrUsedPercent < 50)
         m_lastAnalysis.overallScore += 5;
      else if(m_lastAnalysis.dayRef.adrUsedPercent > 80)
         m_lastAnalysis.overallScore -= 10;
      
      m_lastAnalysis.overallScore = MathMax(0, MathMin(100, m_lastAnalysis.overallScore));
      
      m_lastAnalysis.dominantTrend = PERIOD_D1;
      
      bool macroAligned = m_lastAnalysis.d1.ema800Aligned || m_lastAnalysis.h4.ema800Aligned;
      
      if(bullCount == 3 && macroAligned)
         m_lastAnalysis.recommendation = "ULTRA STRONG BUY - All TFs + EMA800 aligned";
      else if(bullCount == 3)
         m_lastAnalysis.recommendation = "STRONG BUY - All TFs aligned bullish";
      else if(bullCount == 0 && macroAligned)
         m_lastAnalysis.recommendation = "ULTRA STRONG SELL - All TFs + EMA800 aligned";
      else if(bullCount == 0)
         m_lastAnalysis.recommendation = "STRONG SELL - All TFs aligned bearish";
      else if(bullCount == 2 && m_lastAnalysis.d1.isBullish)
         m_lastAnalysis.recommendation = "BUY - D1 bullish with H4/H1 confirmation";
      else if(bullCount == 1 && !m_lastAnalysis.d1.isBullish)
         m_lastAnalysis.recommendation = "SELL - D1 bearish with partial confirmation";
      else
         m_lastAnalysis.recommendation = "NEUTRAL - Mixed signals";
      
      return m_lastAnalysis;
   }
   
   double GetMTFConfirmationScore(bool isBuy)
   {
      MTFAnalysis analysis = Analyze();
      double score = 50;
      
      if(isBuy)
      {
         if(analysis.d1.isBullish) score += 20;
         if(analysis.h4.isBullish) score += 15;
         if(analysis.h1.isBullish) score += 10;
         
         if(analysis.allTimeframesAligned && analysis.d1.isBullish)
            score += 15;
         
         if(analysis.dayRef.priceAbovePrevMid) score += 5;
         if(analysis.dayRef.priceNearPrevLow) score += 10;
         
         if(analysis.d1.rsi > 70) score -= 15;
         if(analysis.d1.rsi < 30) score += 10;
      }
      else
      {
         if(!analysis.d1.isBullish) score += 20;
         if(!analysis.h4.isBullish) score += 15;
         if(!analysis.h1.isBullish) score += 10;
         
         if(analysis.allTimeframesAligned && !analysis.d1.isBullish)
            score += 15;
         
         if(!analysis.dayRef.priceAbovePrevMid) score += 5;
         if(analysis.dayRef.priceNearPrevHigh) score += 10;
         
         if(analysis.d1.rsi < 30) score -= 15;
         if(analysis.d1.rsi > 70) score += 10;
      }
      
      if(analysis.dayRef.adrUsedPercent > 90)
         score -= 20;
      else if(analysis.dayRef.adrUsedPercent < 30)
         score += 10;
      
      return MathMax(0, MathMin(100, score));
   }
   
   MTFAnalysis GetLastAnalysis() { return m_lastAnalysis; }
   
   void GetMTFFeatures(double &features[], int startIdx)
   {
      MTFAnalysis analysis = Analyze();
      
      features[startIdx + 0] = analysis.h1.isBullish ? 1.0 : -1.0;
      features[startIdx + 1] = analysis.h1.strength / 100.0;
      features[startIdx + 2] = (analysis.h1.rsi - 50) / 50.0;
      
      features[startIdx + 3] = analysis.h4.isBullish ? 1.0 : -1.0;
      features[startIdx + 4] = analysis.h4.strength / 100.0;
      features[startIdx + 5] = (analysis.h4.rsi - 50) / 50.0;
      
      features[startIdx + 6] = analysis.d1.isBullish ? 1.0 : -1.0;
      features[startIdx + 7] = analysis.d1.strength / 100.0;
      features[startIdx + 8] = (analysis.d1.rsi - 50) / 50.0;
      
      features[startIdx + 9] = analysis.trendAlignment / 100.0;
      features[startIdx + 10] = analysis.allTimeframesAligned ? 1.0 : 0.0;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double prevRange = analysis.dayRef.prevDayRange;
      if(prevRange > 0)
      {
         features[startIdx + 11] = (currentPrice - analysis.dayRef.prevDayLow) / prevRange - 0.5;
         features[startIdx + 12] = (currentPrice - analysis.dayRef.prevDayMid) / prevRange;
      }
      else
      {
         features[startIdx + 11] = 0;
         features[startIdx + 12] = 0;
      }
      
      features[startIdx + 13] = MathMin(1.0, analysis.dayRef.adrUsedPercent / 100.0);
   }
   
   string GetAnalysisSummary()
   {
      MTFAnalysis analysis = Analyze();
      
      string summary = "=== MTF Analysis ===\n";
      summary += "D1: " + analysis.d1.description + " (RSI: " + DoubleToString(analysis.d1.rsi, 1) + ")\n";
      summary += "H4: " + analysis.h4.description + " (RSI: " + DoubleToString(analysis.h4.rsi, 1) + ")\n";
      summary += "H1: " + analysis.h1.description + " (RSI: " + DoubleToString(analysis.h1.rsi, 1) + ")\n";
      summary += "Alignment: " + DoubleToString(analysis.trendAlignment, 0) + "%\n";
      summary += "Prev Day: H=" + DoubleToString(analysis.dayRef.prevDayHigh, 5) +
                 " L=" + DoubleToString(analysis.dayRef.prevDayLow, 5) + "\n";
      summary += "ADR Used: " + DoubleToString(analysis.dayRef.adrUsedPercent, 1) + "%\n";
      summary += "Recommendation: " + analysis.recommendation;
      
      return summary;
   }
};
