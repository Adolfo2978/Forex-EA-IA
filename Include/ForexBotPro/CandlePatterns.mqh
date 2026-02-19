//+------------------------------------------------------------------+
//|                                               CandlePatterns.mqh |
//|                              Forex Bot Pro v7.0 - Candle Patterns |
//|              Enhanced with 12 patterns from image + S/R context  |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

struct CandlePatternResult
{
   ENUM_CANDLE_PATTERN pattern;
   ENUM_SIGNAL_TYPE signal;
   double confidence;
   string name;
   bool nearSupport;
   bool nearResistance;
   int barsAgo;
};

class CCandlePatternDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double m_bodyRatio;
   double m_dojiRatio;
   double m_shadowRatio;
   double m_supportLevel;
   double m_resistanceLevel;
   
   double GetBody(double open, double close) { return MathAbs(close - open); }
   double GetUpperShadow(double high, double open, double close) { return high - MathMax(open, close); }
   double GetLowerShadow(double low, double open, double close) { return MathMin(open, close) - low; }
   double GetRange(double high, double low) { return high - low; }
   bool IsBullish(double open, double close) { return close > open; }
   bool IsBearish(double open, double close) { return close < open; }
   
   bool IsNearSupport(double price)
   {
      if(m_supportLevel == 0) return false;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      return MathAbs(price - m_supportLevel) < 30 * point * 10;
   }
   
   bool IsNearResistance(double price)
   {
      if(m_resistanceLevel == 0) return false;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      return MathAbs(price - m_resistanceLevel) < 30 * point * 10;
   }
   
public:
   CCandlePatternDetector()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_bodyRatio = 0.1;
      m_dojiRatio = 0.05;
      m_shadowRatio = 2.0;
      m_supportLevel = 0;
      m_resistanceLevel = 0;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
   }
   
   void SetSupportResistance(double support, double resistance)
   {
      m_supportLevel = support;
      m_resistanceLevel = resistance;
   }
   
   bool IsDoji(double open, double high, double low, double close)
   {
      double body = GetBody(open, close);
      double range = GetRange(high, low);
      if(range == 0) return false;
      return (body / range) < m_dojiRatio;
   }
   
   bool IsHammer(double open, double high, double low, double close)
   {
      double body = GetBody(open, close);
      double range = GetRange(high, low);
      double lowerShadow = GetLowerShadow(low, open, close);
      double upperShadow = GetUpperShadow(high, open, close);
      
      if(range == 0 || body == 0) return false;
      
      return (lowerShadow >= body * m_shadowRatio) && 
             (upperShadow < body * 0.5) &&
             (body / range >= 0.1);
   }
   
   bool IsInvertedHammer(double open, double high, double low, double close)
   {
      double body = GetBody(open, close);
      double range = GetRange(high, low);
      double lowerShadow = GetLowerShadow(low, open, close);
      double upperShadow = GetUpperShadow(high, open, close);
      
      if(range == 0 || body == 0) return false;
      
      return (upperShadow >= body * m_shadowRatio) && 
             (lowerShadow < body * 0.5) &&
             (body / range >= 0.1);
   }
   
   bool IsMarubozu(double open, double high, double low, double close)
   {
      double body = GetBody(open, close);
      double range = GetRange(high, low);
      double lowerShadow = GetLowerShadow(low, open, close);
      double upperShadow = GetUpperShadow(high, open, close);
      
      if(range == 0) return false;
      
      return (body / range >= 0.9) && (lowerShadow < body * 0.05) && (upperShadow < body * 0.05);
   }
   
   bool IsEngulfingBullish(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double prevOpen = rates[pos+1].open;
      double prevClose = rates[pos+1].close;
      double currOpen = rates[pos].open;
      double currClose = rates[pos].close;
      
      if(!IsBearish(prevOpen, prevClose)) return false;
      if(!IsBullish(currOpen, currClose)) return false;
      
      return (currOpen < prevClose && currClose > prevOpen);
   }
   
   bool IsEngulfingBearish(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double prevOpen = rates[pos+1].open;
      double prevClose = rates[pos+1].close;
      double currOpen = rates[pos].open;
      double currClose = rates[pos].close;
      
      if(!IsBullish(prevOpen, prevClose)) return false;
      if(!IsBearish(currOpen, currClose)) return false;
      
      return (currOpen > prevClose && currClose < prevOpen);
   }
   
   bool IsMorningStar(MqlRates &rates[], int pos)
   {
      if(pos < 2) return false;
      
      double body1 = GetBody(rates[pos+2].open, rates[pos+2].close);
      double body2 = GetBody(rates[pos+1].open, rates[pos+1].close);
      double body3 = GetBody(rates[pos].open, rates[pos].close);
      
      bool firstBearish = IsBearish(rates[pos+2].open, rates[pos+2].close);
      bool secondSmall = body2 < body1 * 0.3;
      bool thirdBullish = IsBullish(rates[pos].open, rates[pos].close);
      bool thirdCloseHigh = rates[pos].close > (rates[pos+2].open + rates[pos+2].close) / 2;
      
      return firstBearish && secondSmall && thirdBullish && thirdCloseHigh;
   }
   
   bool IsEveningStar(MqlRates &rates[], int pos)
   {
      if(pos < 2) return false;
      
      double body1 = GetBody(rates[pos+2].open, rates[pos+2].close);
      double body2 = GetBody(rates[pos+1].open, rates[pos+1].close);
      double body3 = GetBody(rates[pos].open, rates[pos].close);
      
      bool firstBullish = IsBullish(rates[pos+2].open, rates[pos+2].close);
      bool secondSmall = body2 < body1 * 0.3;
      bool thirdBearish = IsBearish(rates[pos].open, rates[pos].close);
      bool thirdCloseLow = rates[pos].close < (rates[pos+2].open + rates[pos+2].close) / 2;
      
      return firstBullish && secondSmall && thirdBearish && thirdCloseLow;
   }
   
   bool IsThreeWhiteSoldiers(MqlRates &rates[], int pos)
   {
      if(pos < 2) return false;
      
      for(int i = 0; i <= 2; i++)
      {
         if(!IsBullish(rates[pos+i].open, rates[pos+i].close)) return false;
         double body = GetBody(rates[pos+i].open, rates[pos+i].close);
         double range = GetRange(rates[pos+i].high, rates[pos+i].low);
         if(range > 0 && body / range < 0.5) return false;
      }
      
      return (rates[pos+1].close > rates[pos+2].close) && 
             (rates[pos].close > rates[pos+1].close);
   }
   
   bool IsThreeBlackCrows(MqlRates &rates[], int pos)
   {
      if(pos < 2) return false;
      
      for(int i = 0; i <= 2; i++)
      {
         if(!IsBearish(rates[pos+i].open, rates[pos+i].close)) return false;
         double body = GetBody(rates[pos+i].open, rates[pos+i].close);
         double range = GetRange(rates[pos+i].high, rates[pos+i].low);
         if(range > 0 && body / range < 0.5) return false;
      }
      
      return (rates[pos+1].close < rates[pos+2].close) && 
             (rates[pos].close < rates[pos+1].close);
   }
   
   bool IsPiercingLine(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      if(!IsBearish(rates[pos+1].open, rates[pos+1].close)) return false;
      if(!IsBullish(rates[pos].open, rates[pos].close)) return false;
      
      double prevMid = (rates[pos+1].open + rates[pos+1].close) / 2;
      
      return (rates[pos].open < rates[pos+1].close) && 
             (rates[pos].close > prevMid) &&
             (rates[pos].close < rates[pos+1].open);
   }
   
   bool IsDarkCloud(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      if(!IsBullish(rates[pos+1].open, rates[pos+1].close)) return false;
      if(!IsBearish(rates[pos].open, rates[pos].close)) return false;
      
      double prevMid = (rates[pos+1].open + rates[pos+1].close) / 2;
      
      return (rates[pos].open > rates[pos+1].close) && 
             (rates[pos].close < prevMid) &&
             (rates[pos].close > rates[pos+1].open);
   }
   
   bool IsTweezerTops(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tolerance = 5 * point * 10;
      
      if(MathAbs(rates[pos].high - rates[pos+1].high) < tolerance)
      {
         if(IsBullish(rates[pos+1].open, rates[pos+1].close) && 
            IsBearish(rates[pos].open, rates[pos].close))
            return true;
      }
      return false;
   }
   
   bool IsTweezerBottoms(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tolerance = 5 * point * 10;
      
      if(MathAbs(rates[pos].low - rates[pos+1].low) < tolerance)
      {
         if(IsBearish(rates[pos+1].open, rates[pos+1].close) && 
            IsBullish(rates[pos].open, rates[pos].close))
            return true;
      }
      return false;
   }
   
   bool IsBullishBreakout(MqlRates &rates[], int pos)
   {
      if(pos < 1 || m_resistanceLevel == 0) return false;
      
      if(rates[pos+1].close < m_resistanceLevel && 
         rates[pos].close > m_resistanceLevel &&
         IsBullish(rates[pos].open, rates[pos].close))
      {
         double body = GetBody(rates[pos].open, rates[pos].close);
         double range = GetRange(rates[pos].high, rates[pos].low);
         return (body > range * 0.5);
      }
      return false;
   }
   
   bool IsBearishBreakout(MqlRates &rates[], int pos)
   {
      if(pos < 1 || m_supportLevel == 0) return false;
      
      if(rates[pos+1].close > m_supportLevel && 
         rates[pos].close < m_supportLevel &&
         IsBearish(rates[pos].open, rates[pos].close))
      {
         double body = GetBody(rates[pos].open, rates[pos].close);
         double range = GetRange(rates[pos].high, rates[pos].low);
         return (body > range * 0.5);
      }
      return false;
   }
   
   bool IsRejectionImpulsionBull(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double body1 = GetBody(rates[pos].open, rates[pos].close);
      double body2 = GetBody(rates[pos+1].open, rates[pos+1].close);
      double lowerWick2 = GetLowerShadow(rates[pos+1].low, rates[pos+1].open, rates[pos+1].close);
      
      return (lowerWick2 > body2 && IsBullish(rates[pos].open, rates[pos].close) && body1 > body2 * 1.5);
   }
   
   bool IsRejectionImpulsionBear(MqlRates &rates[], int pos)
   {
      if(pos < 1) return false;
      
      double body1 = GetBody(rates[pos].open, rates[pos].close);
      double body2 = GetBody(rates[pos+1].open, rates[pos+1].close);
      double upperWick2 = GetUpperShadow(rates[pos+1].high, rates[pos+1].open, rates[pos+1].close);
      
      return (upperWick2 > body2 && IsBearish(rates[pos].open, rates[pos].close) && body1 > body2 * 1.5);
   }
   
   CandlePatternResult DetectPattern(int lookback=10)
   {
      CandlePatternResult result;
      result.pattern = PATTERN_NONE;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 0;
      result.name = "None";
      result.nearSupport = false;
      result.nearResistance = false;
      result.barsAgo = 0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, lookback, rates);
      if(copied < 3) return result;
      
      if(IsThreeWhiteSoldiers(rates, 0))
      {
         result.pattern = PATTERN_THREE_WHITE_SOLDIERS;
         result.signal = SIGNAL_STRONG_BUY;
         result.confidence = 90.0;
         result.name = "Three White Soldiers";
         result.nearSupport = IsNearSupport(rates[2].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 5.0);
         return result;
      }
      
      if(IsThreeBlackCrows(rates, 0))
      {
         result.pattern = PATTERN_THREE_BLACK_CROWS;
         result.signal = SIGNAL_STRONG_SELL;
         result.confidence = 90.0;
         result.name = "Three Red Crows";
         result.nearResistance = IsNearResistance(rates[2].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 5.0);
         return result;
      }
      
      if(IsMorningStar(rates, 0))
      {
         result.pattern = PATTERN_MORNING_STAR;
         result.signal = SIGNAL_STRONG_BUY;
         result.confidence = 88.0;
         result.name = "Morning Star";
         result.nearSupport = IsNearSupport(rates[1].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 7.0);
         return result;
      }
      
      if(IsEveningStar(rates, 0))
      {
         result.pattern = PATTERN_EVENING_STAR;
         result.signal = SIGNAL_STRONG_SELL;
         result.confidence = 88.0;
         result.name = "Evening Star";
         result.nearResistance = IsNearResistance(rates[1].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 7.0);
         return result;
      }
      
      if(IsTweezerTops(rates, 0))
      {
         result.pattern = PATTERN_TWEEZER_TOPS;
         result.signal = SIGNAL_SELL;
         result.confidence = 75.0;
         result.name = "Tweezer Tops";
         result.nearResistance = IsNearResistance(rates[0].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 15.0);
         return result;
      }
      
      if(IsTweezerBottoms(rates, 0))
      {
         result.pattern = PATTERN_TWEEZER_BOTTOMS;
         result.signal = SIGNAL_BUY;
         result.confidence = 75.0;
         result.name = "Tweezer Bottoms";
         result.nearSupport = IsNearSupport(rates[0].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 15.0);
         return result;
      }
      
      if(IsBullishBreakout(rates, 0))
      {
         result.pattern = PATTERN_BULLISH_BREAKOUT;
         result.signal = SIGNAL_STRONG_BUY;
         result.confidence = 85.0;
         result.name = "Bullish Breakout";
         result.barsAgo = 1;
         return result;
      }
      
      if(IsBearishBreakout(rates, 0))
      {
         result.pattern = PATTERN_BEARISH_BREAKOUT;
         result.signal = SIGNAL_STRONG_SELL;
         result.confidence = 85.0;
         result.name = "Bearish Breakout";
         result.barsAgo = 1;
         return result;
      }
      
      if(IsRejectionImpulsionBull(rates, 0))
      {
         result.pattern = PATTERN_REJECTION_IMPULSION_BULL;
         result.signal = SIGNAL_BUY;
         result.confidence = 80.0;
         result.name = "Rejection + Impulsion (Bull)";
         result.nearSupport = IsNearSupport(rates[1].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsRejectionImpulsionBear(rates, 0))
      {
         result.pattern = PATTERN_REJECTION_IMPULSION_BEAR;
         result.signal = SIGNAL_SELL;
         result.confidence = 80.0;
         result.name = "Rejection + Impulsion (Bear)";
         result.nearResistance = IsNearResistance(rates[1].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsEngulfingBullish(rates, 0))
      {
         result.pattern = PATTERN_ENGULFING_BULLISH;
         result.signal = SIGNAL_BUY;
         result.confidence = 82.0;
         result.name = "Bullish Engulfing";
         result.nearSupport = IsNearSupport(rates[0].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsEngulfingBearish(rates, 0))
      {
         result.pattern = PATTERN_ENGULFING_BEARISH;
         result.signal = SIGNAL_SELL;
         result.confidence = 82.0;
         result.name = "Bearish Engulfing";
         result.nearResistance = IsNearResistance(rates[0].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsPiercingLine(rates, 0))
      {
         result.pattern = PATTERN_PIERCING_LINE;
         result.signal = SIGNAL_BUY;
         result.confidence = 78.0;
         result.name = "Piercing Line";
         result.nearSupport = IsNearSupport(rates[0].low);
         result.barsAgo = 1;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsDarkCloud(rates, 0))
      {
         result.pattern = PATTERN_DARK_CLOUD;
         result.signal = SIGNAL_SELL;
         result.confidence = 78.0;
         result.name = "Dark Cloud";
         result.nearResistance = IsNearResistance(rates[0].high);
         result.barsAgo = 1;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 10.0);
         return result;
      }
      
      if(IsHammer(rates[0].open, rates[0].high, rates[0].low, rates[0].close))
      {
         result.pattern = PATTERN_HAMMER;
         result.signal = SIGNAL_BUY;
         result.confidence = 75.0;
         result.name = "Bullish Rejection (Hammer)";
         result.nearSupport = IsNearSupport(rates[0].low);
         result.barsAgo = 0;
         if(result.nearSupport) result.confidence = MathMin(95.0, result.confidence + 15.0);
         return result;
      }
      
      if(IsInvertedHammer(rates[0].open, rates[0].high, rates[0].low, rates[0].close))
      {
         result.pattern = PATTERN_INVERTED_HAMMER;
         result.signal = SIGNAL_SELL;
         result.confidence = 75.0;
         result.name = "Bearish Rejection (Shooting Star)";
         result.nearResistance = IsNearResistance(rates[0].high);
         result.barsAgo = 0;
         if(result.nearResistance) result.confidence = MathMin(95.0, result.confidence + 15.0);
         return result;
      }
      
      if(IsMarubozu(rates[0].open, rates[0].high, rates[0].low, rates[0].close))
      {
         if(IsBullish(rates[0].open, rates[0].close))
         {
            result.pattern = PATTERN_MARUBOZU_BULLISH;
            result.signal = SIGNAL_BUY;
            result.confidence = 80.0;
            result.name = "Bullish Marubozu";
            result.nearSupport = IsNearSupport(rates[0].low);
         }
         else
         {
            result.pattern = PATTERN_MARUBOZU_BEARISH;
            result.signal = SIGNAL_SELL;
            result.confidence = 80.0;
            result.name = "Bearish Marubozu";
            result.nearResistance = IsNearResistance(rates[0].high);
         }
         result.barsAgo = 0;
         return result;
      }
      
      if(IsDoji(rates[0].open, rates[0].high, rates[0].low, rates[0].close))
      {
         result.pattern = PATTERN_DOJI;
         result.signal = SIGNAL_NEUTRAL;
         result.confidence = 60.0;
         result.name = "Doji";
         result.barsAgo = 0;
         return result;
      }
      
      return result;
   }
   
   double GetBullishScore()
   {
      CandlePatternResult result = DetectPattern();
      if(result.signal == SIGNAL_BUY || result.signal == SIGNAL_STRONG_BUY || 
         result.signal == SIGNAL_WEAK_BUY)
         return result.confidence;
      return 0;
   }
   
   double GetBearishScore()
   {
      CandlePatternResult result = DetectPattern();
      if(result.signal == SIGNAL_SELL || result.signal == SIGNAL_STRONG_SELL || 
         result.signal == SIGNAL_WEAK_SELL)
         return result.confidence;
      return 0;
   }
};
