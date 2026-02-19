//+------------------------------------------------------------------+
//|                                                ChartPatterns.mqh |
//|                              Forex Bot Pro v7.0 - Chart Patterns |
//|                              M, W, Head & Shoulders Detector     |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

struct ChartPatternResult
{
   ENUM_CHART_PATTERN pattern;
   ENUM_SIGNAL_TYPE signal;
   double confidence;
   string name;
   double targetPrice;
   double neckline;
};

struct PivotPoint
{
   int index;
   double price;
   bool isHigh;
};

class CChartPatternDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_lookback;
   int m_pivotStrength;
   double m_tolerance;
   
   PivotPoint m_highs[];
   PivotPoint m_lows[];
   
public:
   CChartPatternDetector()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_lookback = 100;
      m_pivotStrength = 3;
      m_tolerance = 0.02;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES timeframe, int lookback=100)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_lookback = lookback;
   }
   
   void FindPivots(MqlRates &rates[], int size)
   {
      ArrayResize(m_highs, 0);
      ArrayResize(m_lows, 0);
      
      for(int i = m_pivotStrength; i < size - m_pivotStrength; i++)
      {
         bool isHighPivot = true;
         bool isLowPivot = true;
         
         for(int j = 1; j <= m_pivotStrength; j++)
         {
            if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
               isHighPivot = false;
            if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
               isLowPivot = false;
         }
         
         if(isHighPivot)
         {
            int idx = ArraySize(m_highs);
            ArrayResize(m_highs, idx + 1);
            m_highs[idx].index = i;
            m_highs[idx].price = rates[i].high;
            m_highs[idx].isHigh = true;
         }
         
         if(isLowPivot)
         {
            int idx = ArraySize(m_lows);
            ArrayResize(m_lows, idx + 1);
            m_lows[idx].index = i;
            m_lows[idx].price = rates[i].low;
            m_lows[idx].isHigh = false;
         }
      }
   }
   
   bool CheckVolumeConfirmation(MqlRates &rates[], int idx1, int idx2)
   {
      if(idx1 < 0 || idx2 < 0) return true;
      
      long vol1 = rates[idx1].tick_volume;
      long vol2 = rates[idx2].tick_volume;
      
      long avgVol = 0;
      int count = MathMin(20, ArraySize(rates));
      for(int i = 0; i < count; i++)
         avgVol += rates[i].tick_volume;
      avgVol /= count;
      
      return (vol1 > avgVol * 0.8 || vol2 > avgVol * 0.8);
   }
   
   ChartPatternResult DetectWBottom(MqlRates &rates[], int size)
   {
      ChartPatternResult result;
      result.pattern = CHART_PATTERN_NONE;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 0;
      result.name = "None";
      result.targetPrice = 0;
      result.neckline = 0;
      
      int lowCount = ArraySize(m_lows);
      if(lowCount < 2) return result;
      
      PivotPoint l1 = m_lows[lowCount - 2];
      PivotPoint l2 = m_lows[lowCount - 1];
      
      double tolerance = MathAbs(l1.price) * m_tolerance;
      
      if(MathAbs(l1.price - l2.price) < tolerance && l2.index > l1.index)
      {
         double middleHigh = 0;
         for(int i = l1.index; i <= l2.index && i < size; i++)
         {
            if(rates[i].high > middleHigh)
               middleHigh = rates[i].high;
         }
         
         if(middleHigh > l1.price * 1.01)
         {
            bool volConfirm = CheckVolumeConfirmation(rates, l1.index, l2.index);
            double baseConf = 82.0 + MathMin(13.0, (l2.index - l1.index) / 2.0);
            
            result.pattern = CHART_PATTERN_W_BOTTOM;
            result.signal = SIGNAL_BUY;
            result.confidence = volConfirm ? MathMin(95.0, baseConf * 1.1) : baseConf * 0.8;
            result.name = "W Bottom (Double Bottom)";
            result.neckline = middleHigh;
            result.targetPrice = middleHigh + (middleHigh - l1.price);
         }
      }
      
      return result;
   }
   
   ChartPatternResult DetectMTop(MqlRates &rates[], int size)
   {
      ChartPatternResult result;
      result.pattern = CHART_PATTERN_NONE;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 0;
      result.name = "None";
      result.targetPrice = 0;
      result.neckline = 0;
      
      int highCount = ArraySize(m_highs);
      if(highCount < 2) return result;
      
      PivotPoint h1 = m_highs[highCount - 2];
      PivotPoint h2 = m_highs[highCount - 1];
      
      double tolerance = MathAbs(h1.price) * m_tolerance;
      
      if(MathAbs(h1.price - h2.price) < tolerance && h2.index > h1.index)
      {
         double middleLow = DBL_MAX;
         for(int i = h1.index; i <= h2.index && i < size; i++)
         {
            if(rates[i].low < middleLow)
               middleLow = rates[i].low;
         }
         
         if(middleLow < h1.price * 0.99)
         {
            bool volConfirm = CheckVolumeConfirmation(rates, h1.index, h2.index);
            double baseConf = 82.0 + MathMin(13.0, (h2.index - h1.index) / 2.0);
            
            result.pattern = CHART_PATTERN_M_TOP;
            result.signal = SIGNAL_SELL;
            result.confidence = volConfirm ? MathMin(95.0, baseConf * 1.1) : baseConf * 0.8;
            result.name = "M Top (Double Top)";
            result.neckline = middleLow;
            result.targetPrice = middleLow - (h1.price - middleLow);
         }
      }
      
      return result;
   }
   
   ChartPatternResult DetectHeadShoulders(MqlRates &rates[], int size)
   {
      ChartPatternResult result;
      result.pattern = CHART_PATTERN_NONE;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 0;
      result.name = "None";
      result.targetPrice = 0;
      result.neckline = 0;
      
      int highCount = ArraySize(m_highs);
      if(highCount >= 3)
      {
         PivotPoint h1 = m_highs[highCount - 3];
         PivotPoint h2 = m_highs[highCount - 2];
         PivotPoint h3 = m_highs[highCount - 1];
         
         double shoulderTolerance = MathAbs(h1.price) * 0.03;
         
         if(MathAbs(h1.price - h3.price) < shoulderTolerance &&
            h2.price > h1.price * 1.02 && h2.price > h3.price * 1.02)
         {
            double neckline = 0;
            for(int i = h1.index; i <= h3.index && i < size; i++)
            {
               if(rates[i].low < neckline || neckline == 0)
                  neckline = rates[i].low;
            }
            
            bool volConfirm = CheckVolumeConfirmation(rates, h1.index, h3.index);
            double baseConf = 88.0;
            
            result.pattern = CHART_PATTERN_HEAD_SHOULDERS;
            result.signal = SIGNAL_SELL;
            result.confidence = volConfirm ? MathMin(95.0, baseConf * 1.1) : baseConf * 0.85;
            result.name = "Head and Shoulders";
            result.neckline = neckline;
            result.targetPrice = neckline - (h2.price - neckline);
            return result;
         }
      }
      
      int lowCount = ArraySize(m_lows);
      if(lowCount >= 3)
      {
         PivotPoint l1 = m_lows[lowCount - 3];
         PivotPoint l2 = m_lows[lowCount - 2];
         PivotPoint l3 = m_lows[lowCount - 1];
         
         double shoulderTolerance = MathAbs(l1.price) * 0.03;
         
         if(MathAbs(l1.price - l3.price) < shoulderTolerance &&
            l2.price < l1.price * 0.98 && l2.price < l3.price * 0.98)
         {
            double neckline = 0;
            for(int i = l1.index; i <= l3.index && i < size; i++)
            {
               if(rates[i].high > neckline)
                  neckline = rates[i].high;
            }
            
            bool volConfirm = CheckVolumeConfirmation(rates, l1.index, l3.index);
            double baseConf = 88.0;
            
            result.pattern = CHART_PATTERN_INV_HEAD_SHOULDERS;
            result.signal = SIGNAL_BUY;
            result.confidence = volConfirm ? MathMin(95.0, baseConf * 1.1) : baseConf * 0.85;
            result.name = "Inverse Head and Shoulders";
            result.neckline = neckline;
            result.targetPrice = neckline + (neckline - l2.price);
            return result;
         }
      }
      
      return result;
   }
   
   ChartPatternResult DetectAll()
   {
      ChartPatternResult result;
      result.pattern = CHART_PATTERN_NONE;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 0;
      result.name = "None";
      result.targetPrice = 0;
      result.neckline = 0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, m_lookback, rates);
      if(copied < 30) return result;
      
      FindPivots(rates, copied);
      
      ChartPatternResult hs = DetectHeadShoulders(rates, copied);
      if(hs.pattern != CHART_PATTERN_NONE && hs.confidence > result.confidence)
         result = hs;
      
      ChartPatternResult wBottom = DetectWBottom(rates, copied);
      if(wBottom.pattern != CHART_PATTERN_NONE && wBottom.confidence > result.confidence)
         result = wBottom;
      
      ChartPatternResult mTop = DetectMTop(rates, copied);
      if(mTop.pattern != CHART_PATTERN_NONE && mTop.confidence > result.confidence)
         result = mTop;
      
      return result;
   }
};
