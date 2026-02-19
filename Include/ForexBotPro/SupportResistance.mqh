//+------------------------------------------------------------------+
//|                                           SupportResistance.mqh |
//|                              Forex Bot Pro v7.0 - S/R Analyzer   |
//|                              Dynamic Support and Resistance      |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

struct SRLevels
{
   double support[];
   double resistance[];
   double nearestSupport;
   double nearestResistance;
};

struct BreakoutResult
{
   bool detected;
   string type;
   double confidence;
   double level;
};

class CSupportResistanceAnalyzer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_lookback;
   int m_numLevels;
   double m_clusterTolerance;
   
public:
   CSupportResistanceAnalyzer()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_lookback = 100;
      m_numLevels = 5;
      m_clusterTolerance = 0.005;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES timeframe, int lookback=100)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_lookback = lookback;
   }
   
   bool IsLevelUnique(double level, double &levels[], int count, double tolerance)
   {
      for(int i = 0; i < count; i++)
      {
         if(MathAbs(level - levels[i]) / levels[i] < tolerance)
            return false;
      }
      return true;
   }
   
   SRLevels FindLevels()
   {
      SRLevels result;
      ArrayResize(result.support, 0);
      ArrayResize(result.resistance, 0);
      result.nearestSupport = 0;
      result.nearestResistance = 0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, m_lookback, rates);
      if(copied < 20) return result;
      
      double highs[];
      double lows[];
      ArrayResize(highs, copied);
      ArrayResize(lows, copied);
      
      for(int i = 0; i < copied; i++)
      {
         highs[i] = rates[i].high;
         lows[i] = rates[i].low;
      }
      
      ArraySort(highs);
      ArraySort(lows);
      
      double tempResistance[];
      double tempSupport[];
      ArrayResize(tempResistance, m_numLevels * 3);
      ArrayResize(tempSupport, m_numLevels * 3);
      
      int resistanceCount = 0;
      for(int i = copied - 1; i >= 0 && resistanceCount < m_numLevels; i--)
      {
         if(IsLevelUnique(highs[i], result.resistance, ArraySize(result.resistance), m_clusterTolerance))
         {
            int idx = ArraySize(result.resistance);
            ArrayResize(result.resistance, idx + 1);
            result.resistance[idx] = highs[i];
            resistanceCount++;
         }
      }
      
      int supportCount = 0;
      for(int i = 0; i < copied && supportCount < m_numLevels; i++)
      {
         if(IsLevelUnique(lows[i], result.support, ArraySize(result.support), m_clusterTolerance))
         {
            int idx = ArraySize(result.support);
            ArrayResize(result.support, idx + 1);
            result.support[idx] = lows[i];
            supportCount++;
         }
      }
      
      ArraySort(result.support);
      ArraySort(result.resistance);
      
      double currentPrice = rates[0].close;
      
      for(int i = ArraySize(result.support) - 1; i >= 0; i--)
      {
         if(result.support[i] < currentPrice)
         {
            result.nearestSupport = result.support[i];
            break;
         }
      }
      
      for(int i = 0; i < ArraySize(result.resistance); i++)
      {
         if(result.resistance[i] > currentPrice)
         {
            result.nearestResistance = result.resistance[i];
            break;
         }
      }
      
      return result;
   }
   
   BreakoutResult CheckBreakout()
   {
      BreakoutResult result;
      result.detected = false;
      result.type = "none";
      result.confidence = 0;
      result.level = 0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, m_lookback, rates);
      if(copied < 10) return result;
      
      double currentPrice = rates[0].close;
      
      MqlRates previousRates[];
      ArraySetAsSeries(previousRates, true);
      CopyRates(m_symbol, m_timeframe, 1, m_lookback - 1, previousRates);
      
      SRLevels levels = FindLevels();
      
      for(int i = 0; i < ArraySize(levels.resistance); i++)
      {
         double r = levels.resistance[i];
         bool allBelow = true;
         
         for(int j = 1; j <= 5 && j < ArraySize(rates); j++)
         {
            if(rates[j].close >= r)
            {
               allBelow = false;
               break;
            }
         }
         
         if(currentPrice > r && allBelow)
         {
            result.detected = true;
            result.type = "resistance_breakout";
            result.confidence = 85.0;
            result.level = r;
            return result;
         }
      }
      
      for(int i = 0; i < ArraySize(levels.support); i++)
      {
         double s = levels.support[i];
         bool allAbove = true;
         
         for(int j = 1; j <= 5 && j < ArraySize(rates); j++)
         {
            if(rates[j].close <= s)
            {
               allAbove = false;
               break;
            }
         }
         
         if(currentPrice < s && allAbove)
         {
            result.detected = true;
            result.type = "support_breakout";
            result.confidence = 85.0;
            result.level = s;
            return result;
         }
      }
      
      return result;
   }
   
   double GetDistanceToLevel(double price, double level)
   {
      if(level == 0) return DBL_MAX;
      return MathAbs(price - level) / price * 100;
   }
   
   bool IsPriceNearLevel(double price, double level, double tolerancePct=0.5)
   {
      if(level == 0) return false;
      return GetDistanceToLevel(price, level) <= tolerancePct;
   }
};
