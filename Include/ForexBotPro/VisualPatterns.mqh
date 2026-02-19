//+------------------------------------------------------------------+
//|                                               VisualPatterns.mqh |
//|                     Forex Bot Pro v7.0 - Visual M/W Pattern      |
//|              Market Maker Method with Retracement Detection      |
//|                    + MMM Methodology Integration                 |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"
#include "CandlePatterns.mqh"
#include "SupportResistance.mqh"
#include "MMMMethodology.mqh"

enum ENUM_PATTERN_VARIANT
{
   VARIANT_CLASSIC,
   VARIANT_DEEP_RETRACE,
   VARIANT_SHALLOW_RETRACE,
   VARIANT_ASYMMETRIC,
   VARIANT_EXTENDED
};

enum ENUM_TREND_STATE
{
   TSTATE_STRONG_UP,
   TSTATE_UP,
   TSTATE_NEUTRAL,
   TSTATE_DOWN,
   TSTATE_STRONG_DOWN
};

enum ENUM_MARKET_CYCLE
{
   CYCLE_ACCUMULATION,
   CYCLE_MARKUP,
   CYCLE_DISTRIBUTION,
   CYCLE_MARKDOWN
};

struct CandleConfirmation
{
   bool hasConfirmation;
   string patternName;
   int barIndex;
   double confidence;
   datetime confirmTime;
};

struct SRZoneConfirmation
{
   bool atSupportZone;
   bool atResistanceZone;
   double nearestSupport;
   double nearestResistance;
   double distanceToSupport;
   double distanceToResistance;
   double zoneConfidence;
};

struct TrendConfirmation
{
   ENUM_TREND_STATE trendState;
   bool alignedWithPattern;
   double ema20;
   double ema50;
   double ema200;
   double trendStrength;
   double trendConfidence;
};

struct MarketCycleConfirmation
{
   ENUM_MARKET_CYCLE cycle;
   bool optimalForEntry;
   double cycleProgress;
   double cycleConfidence;
};

struct PatternLearningData
{
   ENUM_PATTERN_VARIANT variant;
   string variantName;
   double historicalWinRate;
   int totalOccurrences;
   double avgRetracementLevel;
   double optimalEntryLevel;
};

struct MWPatternData
{
   bool isValid;
   bool isMPattern;
   double peak1;
   double peak2;
   double valley;
   double neckline;
   double retracementLevel;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   datetime peak1Time;
   datetime peak2Time;
   datetime valleyTime;
   datetime retracementTime;
   int peak1Bar;
   int peak2Bar;
   int valleyBar;
   double confidence;
   bool retracementConfirmed;
   bool engulfingConfirmed;
   string engulfingType;
   CandleConfirmation candleConfirm;
   double aiPrediction;
   double setupScore;
   datetime setupStartTime;
   datetime setupEndTime;
   double setupHighPrice;
   double setupLowPrice;
   SRZoneConfirmation srZone;
   TrendConfirmation trend;
   MarketCycleConfirmation cycle;
   PatternLearningData learning;
   double totalConfirmationScore;
   bool fullSetupConfirmed;
};

struct MMMPatternScore
{
   double movementScore;
   double cycleScore;
   double sessionScore;
   double harmonicBonus;
   double totalMMMScore;
   bool isHarmonic;
   string movementType;
   string cycleName;
   string sessionName;
};

class CVisualPatternDetector
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int m_lookbackBars;
   int m_pivotStrength;
   double m_retracementMin;
   double m_retracementMax;
   bool m_drawOnChart;
   string m_objectPrefix;
   color m_mPatternColor;
   color m_wPatternColor;
   color m_entryColor;
   color m_slColor;
   color m_tpColor;
   int m_lineWidth;
   ENUM_LINE_STYLE m_lineStyle;
   
   MWPatternData m_lastMPattern;
   MWPatternData m_lastWPattern;
   
   CSupportResistanceAnalyzer m_srAnalyzer;
   SRLevels m_currentSRLevels;
   
   CMMMMethodology m_mmmAnalyzer;
   bool m_mmmEnabled;
   MMMPatternScore m_lastMMMScore;
   
   double m_wPatternWinRates[5];
   double m_mPatternWinRates[5];
   int m_wPatternCounts[5];
   int m_mPatternCounts[5];
   
public:
   CVisualPatternDetector()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_lookbackBars = 100;
      m_pivotStrength = 5;
      m_retracementMin = 0.382;
      m_retracementMax = 0.786;
      m_drawOnChart = true;
      m_objectPrefix = "FBPMW_";
      m_mPatternColor = clrRed;
      m_wPatternColor = clrLime;
      m_entryColor = clrYellow;
      m_slColor = clrRed;
      m_tpColor = clrLime;
      m_lineWidth = 2;
      m_lineStyle = STYLE_SOLID;
      m_mmmEnabled = true;
      
      ZeroMemory(m_lastMPattern);
      ZeroMemory(m_lastWPattern);
      ZeroMemory(m_lastMMMScore);
      
      for(int i = 0; i < 5; i++)
      {
         m_wPatternWinRates[i] = 65.0;
         m_mPatternWinRates[i] = 65.0;
         m_wPatternCounts[i] = 0;
         m_mPatternCounts[i] = 0;
      }
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 100, int pivotStr = 5, int gmtOffset = 0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookbackBars = lookback;
      m_pivotStrength = pivotStr;
      m_objectPrefix = "FBPMW_" + m_symbol + "_";
      
      m_srAnalyzer.Init(symbol, tf, lookback);
      m_currentSRLevels = m_srAnalyzer.FindLevels();
      
      if(m_mmmEnabled)
      {
         m_mmmAnalyzer.Init(symbol, tf, gmtOffset);
      }
   }
   
   void SetMMMEnabled(bool enabled) { m_mmmEnabled = enabled; }
   
   MMMPatternScore CalculateMMMScore(bool isBullish)
   {
      MMMPatternScore score;
      ZeroMemory(score);
      
      if(!m_mmmEnabled) 
      {
         score.totalMMMScore = 70.0;
         return score;
      }
      
      m_mmmAnalyzer.UpdateIntradayState();
      m_mmmAnalyzer.AnalyzeMovement();
      m_mmmAnalyzer.AnalyzeCycle();
      
      MMMMovementAnalysis movement = m_mmmAnalyzer.GetCurrentMovement();
      MMMCycleAnalysis cycle = m_mmmAnalyzer.GetCurrentCycle();
      MMMIntradayState intraday = m_mmmAnalyzer.GetIntradayState();
      
      score.movementScore = movement.confidenceScore;
      score.cycleScore = cycle.phaseConfidence;
      score.sessionScore = intraday.killZoneScore;
      score.isHarmonic = movement.isHarmonic;
      score.harmonicBonus = movement.isHarmonic ? 10.0 : 0;
      
      score.movementType = m_mmmAnalyzer.GetMovementTypeName(movement.movementType);
      score.cycleName = m_mmmAnalyzer.GetCyclePhaseName(cycle.currentPhase);
      score.sessionName = m_mmmAnalyzer.GetSessionName(intraday.currentSession);
      
      bool cycleAligned = false;
      if(isBullish)
         cycleAligned = (cycle.currentPhase == MMM_CYCLE_ACCUMULATION || 
                        cycle.currentPhase == MMM_CYCLE_MARKUP);
      else
         cycleAligned = (cycle.currentPhase == MMM_CYCLE_DISTRIBUTION || 
                        cycle.currentPhase == MMM_CYCLE_MARKDOWN);
      
      double cycleMultiplier = cycleAligned ? 1.0 : 0.6;
      
      score.totalMMMScore = (score.movementScore * 0.35 + 
                            score.cycleScore * cycleMultiplier * 0.35 + 
                            score.sessionScore * 0.30) + score.harmonicBonus;
      
      score.totalMMMScore = MathMin(100, score.totalMMMScore);
      
      m_lastMMMScore = score;
      return score;
   }
   
   MMMPatternScore GetLastMMMScore() { return m_lastMMMScore; }
   
   CMMMMethodology* GetMMMAnalyzer() { return &m_mmmAnalyzer; }
   
   void UpdateSRLevels()
   {
      m_currentSRLevels = m_srAnalyzer.FindLevels();
   }
   
   SRZoneConfirmation CheckSRZone(double price, bool isBullishPattern)
   {
      SRZoneConfirmation result;
      ZeroMemory(result);
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double zoneTolerance = 50 * point * 10;
      
      result.nearestSupport = m_currentSRLevels.nearestSupport;
      result.nearestResistance = m_currentSRLevels.nearestResistance;
      
      if(result.nearestSupport > 0)
         result.distanceToSupport = MathAbs(price - result.nearestSupport);
      if(result.nearestResistance > 0)
         result.distanceToResistance = MathAbs(price - result.nearestResistance);
      
      result.atSupportZone = (result.distanceToSupport <= zoneTolerance);
      result.atResistanceZone = (result.distanceToResistance <= zoneTolerance);
      
      if(isBullishPattern && result.atSupportZone)
         result.zoneConfidence = 90.0 - (result.distanceToSupport / zoneTolerance) * 20;
      else if(!isBullishPattern && result.atResistanceZone)
         result.zoneConfidence = 90.0 - (result.distanceToResistance / zoneTolerance) * 20;
      else
         result.zoneConfidence = 50.0;
      
      result.zoneConfidence = MathMax(40.0, MathMin(95.0, result.zoneConfidence));
      
      return result;
   }
   
   TrendConfirmation CheckTrendAlignment(MqlRates &rates[], bool isBullishPattern)
   {
      TrendConfirmation result;
      ZeroMemory(result);
      
      int size = ArraySize(rates);
      if(size < 200) return result;
      
      double sum20 = 0, sum50 = 0, sum200 = 0;
      for(int i = 0; i < 20; i++) sum20 += rates[i].close;
      for(int i = 0; i < 50; i++) sum50 += rates[i].close;
      for(int i = 0; i < 200; i++) sum200 += rates[i].close;
      
      result.ema20 = sum20 / 20;
      result.ema50 = sum50 / 50;
      result.ema200 = sum200 / 200;
      
      double currentPrice = rates[0].close;
      
      if(currentPrice > result.ema20 && result.ema20 > result.ema50 && result.ema50 > result.ema200)
         result.trendState = TSTATE_STRONG_UP;
      else if(currentPrice > result.ema50 && result.ema50 > result.ema200)
         result.trendState = TSTATE_UP;
      else if(currentPrice < result.ema20 && result.ema20 < result.ema50 && result.ema50 < result.ema200)
         result.trendState = TSTATE_STRONG_DOWN;
      else if(currentPrice < result.ema50 && result.ema50 < result.ema200)
         result.trendState = TSTATE_DOWN;
      else
         result.trendState = TSTATE_NEUTRAL;
      
      if(isBullishPattern)
      {
         result.alignedWithPattern = (result.trendState == TSTATE_UP || result.trendState == TSTATE_STRONG_UP ||
                                      result.trendState == TSTATE_NEUTRAL);
         if(result.trendState == TSTATE_STRONG_UP) result.trendStrength = 100.0;
         else if(result.trendState == TSTATE_UP) result.trendStrength = 80.0;
         else if(result.trendState == TSTATE_NEUTRAL) result.trendStrength = 60.0;
         else result.trendStrength = 30.0;
      }
      else
      {
         result.alignedWithPattern = (result.trendState == TSTATE_DOWN || result.trendState == TSTATE_STRONG_DOWN ||
                                      result.trendState == TSTATE_NEUTRAL);
         if(result.trendState == TSTATE_STRONG_DOWN) result.trendStrength = 100.0;
         else if(result.trendState == TSTATE_DOWN) result.trendStrength = 80.0;
         else if(result.trendState == TSTATE_NEUTRAL) result.trendStrength = 60.0;
         else result.trendStrength = 30.0;
      }
      
      result.trendConfidence = result.alignedWithPattern ? result.trendStrength : result.trendStrength * 0.5;
      
      return result;
   }
   
   MarketCycleConfirmation DetectMarketCycle(MqlRates &rates[], bool isBullishPattern)
   {
      MarketCycleConfirmation result;
      ZeroMemory(result);
      
      int size = ArraySize(rates);
      if(size < 50) return result;
      
      double recentVol = 0, pastVol = 0;
      for(int i = 0; i < 10; i++) recentVol += (rates[i].high - rates[i].low);
      for(int i = 20; i < 30; i++) pastVol += (rates[i].high - rates[i].low);
      recentVol /= 10;
      pastVol /= 10;
      
      double volRatio = pastVol > 0 ? recentVol / pastVol : 1.0;
      
      double priceChange = rates[0].close - rates[20].close;
      bool priceRising = priceChange > 0;
      
      if(volRatio < 0.8 && !priceRising)
         result.cycle = CYCLE_ACCUMULATION;
      else if(volRatio >= 1.0 && priceRising)
         result.cycle = CYCLE_MARKUP;
      else if(volRatio < 0.8 && priceRising)
         result.cycle = CYCLE_DISTRIBUTION;
      else
         result.cycle = CYCLE_MARKDOWN;
      
      if(isBullishPattern)
      {
         result.optimalForEntry = (result.cycle == CYCLE_ACCUMULATION || result.cycle == CYCLE_MARKUP);
         result.cycleConfidence = result.optimalForEntry ? 85.0 : 50.0;
      }
      else
      {
         result.optimalForEntry = (result.cycle == CYCLE_DISTRIBUTION || result.cycle == CYCLE_MARKDOWN);
         result.cycleConfidence = result.optimalForEntry ? 85.0 : 50.0;
      }
      
      result.cycleProgress = MathMin(100.0, volRatio * 50);
      
      return result;
   }
   
   PatternLearningData IdentifyPatternVariant(double peak1, double peak2, double valley, double retracementLevel, bool isMPattern)
   {
      PatternLearningData result;
      ZeroMemory(result);
      
      double patternHeight = isMPattern ? (MathMax(peak1, peak2) - valley) : (valley - MathMin(peak1, peak2));
      double peakDiff = MathAbs(peak1 - peak2) / patternHeight;
      double retracementRatio = retracementLevel;
      
      if(peakDiff < 0.1 && retracementRatio >= 0.5 && retracementRatio <= 0.618)
      {
         result.variant = VARIANT_CLASSIC;
         result.variantName = "Classic";
         result.historicalWinRate = 72.0;
      }
      else if(retracementRatio > 0.618)
      {
         result.variant = VARIANT_DEEP_RETRACE;
         result.variantName = "Deep Retrace";
         result.historicalWinRate = 68.0;
      }
      else if(retracementRatio < 0.382)
      {
         result.variant = VARIANT_SHALLOW_RETRACE;
         result.variantName = "Shallow Retrace";
         result.historicalWinRate = 60.0;
      }
      else if(peakDiff >= 0.1 && peakDiff < 0.25)
      {
         result.variant = VARIANT_ASYMMETRIC;
         result.variantName = "Asymmetric";
         result.historicalWinRate = 65.0;
      }
      else
      {
         result.variant = VARIANT_EXTENDED;
         result.variantName = "Extended";
         result.historicalWinRate = 58.0;
      }
      
      int variantIdx = (int)result.variant;
      if(isMPattern && variantIdx < 5)
      {
         result.totalOccurrences = m_mPatternCounts[variantIdx];
         if(m_mPatternCounts[variantIdx] > 0)
            result.historicalWinRate = m_mPatternWinRates[variantIdx];
      }
      else if(!isMPattern && variantIdx < 5)
      {
         result.totalOccurrences = m_wPatternCounts[variantIdx];
         if(m_wPatternCounts[variantIdx] > 0)
            result.historicalWinRate = m_wPatternWinRates[variantIdx];
      }
      
      result.avgRetracementLevel = retracementRatio;
      result.optimalEntryLevel = (result.variant == VARIANT_DEEP_RETRACE) ? 0.618 : 0.50;
      
      return result;
   }
   
   void UpdatePatternLearning(bool isMPattern, ENUM_PATTERN_VARIANT variant, bool wasWin)
   {
      int variantIdx = (int)variant;
      if(variantIdx >= 5) return;
      
      if(isMPattern)
      {
         m_mPatternCounts[variantIdx]++;
         double oldRate = m_mPatternWinRates[variantIdx];
         double newResult = wasWin ? 100.0 : 0.0;
         m_mPatternWinRates[variantIdx] = (oldRate * (m_mPatternCounts[variantIdx] - 1) + newResult) / m_mPatternCounts[variantIdx];
      }
      else
      {
         m_wPatternCounts[variantIdx]++;
         double oldRate = m_wPatternWinRates[variantIdx];
         double newResult = wasWin ? 100.0 : 0.0;
         m_wPatternWinRates[variantIdx] = (oldRate * (m_wPatternCounts[variantIdx] - 1) + newResult) / m_wPatternCounts[variantIdx];
      }
   }
   
   double CalculateTotalConfirmationScore(MWPatternData &pattern)
   {
      double score = 0;
      double weights[6] = {0.20, 0.15, 0.15, 0.10, 0.15, 0.25};
      
      score += pattern.confidence * weights[0];
      score += pattern.candleConfirm.confidence * weights[1] * (pattern.candleConfirm.hasConfirmation ? 1.0 : 0.5);
      score += pattern.srZone.zoneConfidence * weights[2];
      score += pattern.trend.trendConfidence * weights[3];
      score += pattern.cycle.cycleConfidence * weights[4];
      
      MMMPatternScore mmmScore = CalculateMMMScore(!pattern.isMPattern);
      score += mmmScore.totalMMMScore * weights[5];
      
      if(pattern.retracementConfirmed) score += 5.0;
      if(pattern.srZone.atSupportZone || pattern.srZone.atResistanceZone) score += 5.0;
      if(pattern.trend.alignedWithPattern) score += 3.0;
      if(pattern.cycle.optimalForEntry) score += 3.0;
      if(mmmScore.isHarmonic) score += 5.0;
      
      MMMCycleAnalysis cycle = m_mmmAnalyzer.GetCurrentCycle();
      bool mmmCycleAligned = false;
      if(!pattern.isMPattern)
         mmmCycleAligned = (cycle.currentPhase == MMM_CYCLE_ACCUMULATION || 
                           cycle.currentPhase == MMM_CYCLE_MARKUP);
      else
         mmmCycleAligned = (cycle.currentPhase == MMM_CYCLE_DISTRIBUTION || 
                           cycle.currentPhase == MMM_CYCLE_MARKDOWN);
      
      if(mmmCycleAligned) score += 5.0;
      
      score = MathMax(40.0, MathMin(100.0, score));
      
      return score;
   }
   
   double CalculateTotalConfirmationScoreWithMMM(MWPatternData &pattern, double mmmExternalScore)
   {
      double score = 0;
      double weights[6] = {0.20, 0.15, 0.15, 0.10, 0.15, 0.25};
      
      score += pattern.confidence * weights[0];
      score += pattern.candleConfirm.confidence * weights[1] * (pattern.candleConfirm.hasConfirmation ? 1.0 : 0.5);
      score += pattern.srZone.zoneConfidence * weights[2];
      score += pattern.trend.trendConfidence * weights[3];
      score += pattern.cycle.cycleConfidence * weights[4];
      score += mmmExternalScore * weights[5];
      
      if(pattern.retracementConfirmed) score += 5.0;
      if(pattern.srZone.atSupportZone || pattern.srZone.atResistanceZone) score += 5.0;
      if(pattern.trend.alignedWithPattern) score += 3.0;
      if(pattern.cycle.optimalForEntry) score += 3.0;
      
      score = MathMax(40.0, MathMin(100.0, score));
      
      return score;
   }
   
   void SetRetracementLevels(double minRet, double maxRet)
   {
      m_retracementMin = minRet;
      m_retracementMax = maxRet;
   }
   
   void SetDrawingEnabled(bool enabled) { m_drawOnChart = enabled; }
   
   void SetColors(color mColor, color wColor, color entry, color sl, color tp)
   {
      m_mPatternColor = mColor;
      m_wPatternColor = wColor;
      m_entryColor = entry;
      m_slColor = sl;
      m_tpColor = tp;
   }
   
   void SetLineStyle(int width, ENUM_LINE_STYLE style)
   {
      m_lineWidth = width;
      m_lineStyle = style;
   }
   
   bool IsPivotHigh(MqlRates &rates[], int index, int strength)
   {
      if(index < strength || index >= ArraySize(rates) - strength)
         return false;
      
      double highPrice = rates[index].high;
      
      for(int i = 1; i <= strength; i++)
      {
         if(rates[index - i].high >= highPrice || rates[index + i].high >= highPrice)
            return false;
      }
      return true;
   }
   
   bool IsPivotLow(MqlRates &rates[], int index, int strength)
   {
      if(index < strength || index >= ArraySize(rates) - strength)
         return false;
      
      double lowPrice = rates[index].low;
      
      for(int i = 1; i <= strength; i++)
      {
         if(rates[index - i].low <= lowPrice || rates[index + i].low <= lowPrice)
            return false;
      }
      return true;
   }
   
   double CalculateFibRetracement(double from, double to, double level)
   {
      return to + (from - to) * level;
   }
   
   bool IsInRetracementZone(double price, double peak, double valley, bool isMPattern)
   {
      double retMin, retMax;
      
      if(isMPattern)
      {
         retMin = CalculateFibRetracement(valley, peak, m_retracementMin);
         retMax = CalculateFibRetracement(valley, peak, m_retracementMax);
         return (price >= retMin && price <= retMax);
      }
      else
      {
         retMin = CalculateFibRetracement(peak, valley, m_retracementMin);
         retMax = CalculateFibRetracement(peak, valley, m_retracementMax);
         return (price >= retMin && price <= retMax);
      }
   }
   
   bool IsBullishEngulfing(MqlRates &rates[], int pos)
   {
      if(pos < 1 || pos >= ArraySize(rates) - 1) return false;
      
      double currOpen = rates[pos].open;
      double currClose = rates[pos].close;
      double currHigh = rates[pos].high;
      double currLow = rates[pos].low;
      double prevOpen = rates[pos + 1].open;
      double prevClose = rates[pos + 1].close;
      double prevHigh = rates[pos + 1].high;
      double prevLow = rates[pos + 1].low;
      
      bool prevBearish = (prevClose < prevOpen);
      bool currBullish = (currClose > currOpen);
      
      if(!prevBearish || !currBullish) return false;
      
      double prevBody = MathAbs(prevClose - prevOpen);
      double currBody = MathAbs(currClose - currOpen);
      
      if(currBody < prevBody * 1.1) return false;
      
      if(currOpen > prevClose || currClose < prevOpen) return false;
      
      double prevRange = prevHigh - prevLow;
      if(prevBody < prevRange * 0.3) return false;
      
      return true;
   }
   
   bool IsBearishEngulfing(MqlRates &rates[], int pos)
   {
      if(pos < 1 || pos >= ArraySize(rates) - 1) return false;
      
      double currOpen = rates[pos].open;
      double currClose = rates[pos].close;
      double currHigh = rates[pos].high;
      double currLow = rates[pos].low;
      double prevOpen = rates[pos + 1].open;
      double prevClose = rates[pos + 1].close;
      double prevHigh = rates[pos + 1].high;
      double prevLow = rates[pos + 1].low;
      
      bool prevBullish = (prevClose > prevOpen);
      bool currBearish = (currClose < currOpen);
      
      if(!prevBullish || !currBearish) return false;
      
      double prevBody = MathAbs(prevClose - prevOpen);
      double currBody = MathAbs(currClose - currOpen);
      
      if(currBody < prevBody * 1.1) return false;
      
      if(currOpen < prevClose || currClose > prevOpen) return false;
      
      double prevRange = prevHigh - prevLow;
      if(prevBody < prevRange * 0.3) return false;
      
      return true;
   }
   
   int FindRecentEngulfing(MqlRates &rates[], int lookback, bool searchBullish)
   {
      for(int i = 0; i < lookback && i < ArraySize(rates) - 2; i++)
      {
         if(searchBullish && IsBullishEngulfing(rates, i))
            return i;
         if(!searchBullish && IsBearishEngulfing(rates, i))
            return i;
      }
      return -1;
   }
   
   bool IsHammer(MqlRates &rates[], int pos)
   {
      if(pos >= ArraySize(rates)) return false;
      
      double open = rates[pos].open;
      double close = rates[pos].close;
      double high = rates[pos].high;
      double low = rates[pos].low;
      
      double body = MathAbs(close - open);
      double range = high - low;
      double lowerShadow = MathMin(open, close) - low;
      double upperShadow = high - MathMax(open, close);
      
      if(range == 0 || body == 0) return false;
      
      return (lowerShadow >= body * 2.0) && (upperShadow < body * 0.5) && (body / range >= 0.1);
   }
   
   bool IsPinBar(MqlRates &rates[], int pos, bool bullish)
   {
      if(pos >= ArraySize(rates)) return false;
      
      double open = rates[pos].open;
      double close = rates[pos].close;
      double high = rates[pos].high;
      double low = rates[pos].low;
      
      double body = MathAbs(close - open);
      double range = high - low;
      double lowerShadow = MathMin(open, close) - low;
      double upperShadow = high - MathMax(open, close);
      
      if(range == 0) return false;
      
      if(bullish)
      {
         return (lowerShadow >= range * 0.6) && (body / range <= 0.3) && (upperShadow < range * 0.2);
      }
      else
      {
         return (upperShadow >= range * 0.6) && (body / range <= 0.3) && (lowerShadow < range * 0.2);
      }
   }
   
   bool IsMorningStar(MqlRates &rates[], int pos)
   {
      if(pos < 2 || pos >= ArraySize(rates) - 2) return false;
      
      double body1 = MathAbs(rates[pos+2].close - rates[pos+2].open);
      double body2 = MathAbs(rates[pos+1].close - rates[pos+1].open);
      double body3 = MathAbs(rates[pos].close - rates[pos].open);
      
      bool firstBearish = rates[pos+2].close < rates[pos+2].open;
      bool secondSmall = body2 < body1 * 0.4;
      bool thirdBullish = rates[pos].close > rates[pos].open;
      bool thirdCloseHigh = rates[pos].close > (rates[pos+2].open + rates[pos+2].close) / 2;
      
      return firstBearish && secondSmall && thirdBullish && thirdCloseHigh && body1 > 0;
   }
   
   bool IsPiercingLine(MqlRates &rates[], int pos)
   {
      if(pos < 1 || pos >= ArraySize(rates) - 1) return false;
      
      bool prevBearish = rates[pos+1].close < rates[pos+1].open;
      bool currBullish = rates[pos].close > rates[pos].open;
      
      if(!prevBearish || !currBullish) return false;
      
      double prevMid = (rates[pos+1].open + rates[pos+1].close) / 2;
      
      return (rates[pos].open < rates[pos+1].close) && 
             (rates[pos].close > prevMid) &&
             (rates[pos].close < rates[pos+1].open);
   }
   
   bool IsTweezerBottoms(MqlRates &rates[], int pos)
   {
      if(pos < 1 || pos >= ArraySize(rates) - 1) return false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double tolerance = 8 * point * 10;
      
      if(MathAbs(rates[pos].low - rates[pos+1].low) < tolerance)
      {
         bool prevBearish = rates[pos+1].close < rates[pos+1].open;
         bool currBullish = rates[pos].close > rates[pos].open;
         return prevBearish && currBullish;
      }
      return false;
   }
   
   bool IsBullishMarubozu(MqlRates &rates[], int pos)
   {
      if(pos >= ArraySize(rates)) return false;
      
      double open = rates[pos].open;
      double close = rates[pos].close;
      double high = rates[pos].high;
      double low = rates[pos].low;
      
      if(close <= open) return false;
      
      double body = close - open;
      double range = high - low;
      double lowerShadow = open - low;
      double upperShadow = high - close;
      
      if(range == 0) return false;
      
      return (body / range >= 0.85) && (lowerShadow < body * 0.08) && (upperShadow < body * 0.08);
   }
   
   CandleConfirmation FindBullishCandleConfirmation(MqlRates &rates[], int lookback)
   {
      CandleConfirmation confirm;
      ZeroMemory(confirm);
      confirm.hasConfirmation = false;
      confirm.confidence = 0;
      
      for(int i = 0; i < lookback && i < ArraySize(rates) - 3; i++)
      {
         if(IsBullishEngulfing(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Bullish Engulfing";
            confirm.barIndex = i;
            confirm.confidence = 90.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsMorningStar(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Morning Star";
            confirm.barIndex = i;
            confirm.confidence = 88.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsHammer(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Hammer";
            confirm.barIndex = i;
            confirm.confidence = 82.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsPinBar(rates, i, true))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Bullish Pin Bar";
            confirm.barIndex = i;
            confirm.confidence = 85.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsPiercingLine(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Piercing Line";
            confirm.barIndex = i;
            confirm.confidence = 80.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsTweezerBottoms(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Tweezer Bottoms";
            confirm.barIndex = i;
            confirm.confidence = 78.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsBullishMarubozu(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Bullish Marubozu";
            confirm.barIndex = i;
            confirm.confidence = 83.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
      }
      
      return confirm;
   }
   
   CandleConfirmation FindBearishCandleConfirmation(MqlRates &rates[], int lookback)
   {
      CandleConfirmation confirm;
      ZeroMemory(confirm);
      confirm.hasConfirmation = false;
      confirm.confidence = 0;
      
      for(int i = 0; i < lookback && i < ArraySize(rates) - 3; i++)
      {
         if(IsBearishEngulfing(rates, i))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Bearish Engulfing";
            confirm.barIndex = i;
            confirm.confidence = 90.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
         
         if(IsPinBar(rates, i, false))
         {
            confirm.hasConfirmation = true;
            confirm.patternName = "Bearish Pin Bar";
            confirm.barIndex = i;
            confirm.confidence = 85.0;
            confirm.confirmTime = rates[i].time;
            return confirm;
         }
      }
      
      return confirm;
   }
   
   double CalculateAIPrediction(MqlRates &rates[], bool isBullish, double patternConfidence)
   {
      if(ArraySize(rates) < 20) return 50.0;
      
      double momentum = 0;
      for(int i = 0; i < 5; i++)
      {
         momentum += (rates[i].close - rates[i].open);
      }
      double avgMomentum = momentum / 5;
      
      double volatility = 0;
      for(int i = 0; i < 10; i++)
      {
         volatility += (rates[i].high - rates[i].low);
      }
      double avgVolatility = volatility / 10;
      
      double volumeRatio = 1.0;
      if(rates[0].tick_volume > 0 && rates[5].tick_volume > 0)
      {
         double recentVol = (rates[0].tick_volume + rates[1].tick_volume + rates[2].tick_volume) / 3.0;
         double pastVol = (rates[5].tick_volume + rates[6].tick_volume + rates[7].tick_volume) / 3.0;
         if(pastVol > 0) volumeRatio = recentVol / pastVol;
      }
      
      double trendStrength = 0;
      double ema5 = 0, ema20 = 0;
      for(int i = 0; i < 5; i++) ema5 += rates[i].close;
      ema5 /= 5;
      for(int i = 0; i < 20; i++) ema20 += rates[i].close;
      ema20 /= 20;
      
      if(isBullish)
         trendStrength = (ema5 > ema20) ? 10.0 : -5.0;
      else
         trendStrength = (ema5 < ema20) ? 10.0 : -5.0;
      
      double aiScore = patternConfidence;
      
      if(isBullish && avgMomentum > 0) aiScore += 5.0;
      else if(!isBullish && avgMomentum < 0) aiScore += 5.0;
      
      if(volumeRatio > 1.2) aiScore += 3.0;
      
      aiScore += trendStrength;
      
      aiScore = MathMax(40.0, MathMin(98.0, aiScore));
      
      return aiScore;
   }
   
   MWPatternData DetectMPattern()
   {
      MWPatternData result;
      ZeroMemory(result);
      result.isValid = false;
      result.isMPattern = true;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, m_lookbackBars, rates);
      if(copied < 30) return result;
      
      int pivotHighs[];
      double pivotHighPrices[];
      datetime pivotHighTimes[];
      
      for(int i = m_pivotStrength; i < copied - m_pivotStrength; i++)
      {
         if(IsPivotHigh(rates, i, m_pivotStrength))
         {
            int size = ArraySize(pivotHighs);
            ArrayResize(pivotHighs, size + 1);
            ArrayResize(pivotHighPrices, size + 1);
            ArrayResize(pivotHighTimes, size + 1);
            pivotHighs[size] = i;
            pivotHighPrices[size] = rates[i].high;
            pivotHighTimes[size] = rates[i].time;
         }
      }
      
      int numHighs = ArraySize(pivotHighs);
      if(numHighs < 2) return result;
      
      int ph1Idx = pivotHighs[numHighs - 2];
      int ph2Idx = pivotHighs[numHighs - 1];
      double ph1 = pivotHighPrices[numHighs - 2];
      double ph2 = pivotHighPrices[numHighs - 1];
      datetime ph1Time = pivotHighTimes[numHighs - 2];
      datetime ph2Time = pivotHighTimes[numHighs - 1];
      
      double tolerance = MathAbs(ph1) * 0.015;
      if(MathAbs(ph1 - ph2) > tolerance)
         return result;
      
      double valleyLow = DBL_MAX;
      int valleyIdx = -1;
      datetime valleyTime = 0;
      
      for(int i = ph1Idx; i >= ph2Idx; i--)
      {
         if(rates[i].low < valleyLow)
         {
            valleyLow = rates[i].low;
            valleyIdx = i;
            valleyTime = rates[i].time;
         }
      }
      
      if(valleyLow >= ph1 * 0.995)
         return result;
      
      double currentPrice = rates[0].close;
      double neckline = valleyLow;
      
      double patternHeight = MathMax(ph1, ph2) - valleyLow;
      
      double retracementLevel = CalculateFibRetracement(valleyLow, MathMax(ph1, ph2), 0.618);
      
      bool retracementConfirmed = false;
      if(currentPrice >= neckline && currentPrice <= retracementLevel * 1.02)
      {
         retracementConfirmed = true;
      }
      
      CandleConfirmation candleConfirm = FindBearishCandleConfirmation(rates, 7);
      
      int engulfingBar = FindRecentEngulfing(rates, 5, false);
      bool engulfingConfirmed = (engulfingBar >= 0 && engulfingBar <= 3);
      
      result.isValid = true;
      result.isMPattern = true;
      result.peak1 = ph1;
      result.peak2 = ph2;
      result.valley = valleyLow;
      result.neckline = neckline;
      result.peak1Time = ph1Time;
      result.peak2Time = ph2Time;
      result.valleyTime = valleyTime;
      result.peak1Bar = ph1Idx;
      result.peak2Bar = ph2Idx;
      result.valleyBar = valleyIdx;
      result.retracementLevel = retracementLevel;
      result.retracementConfirmed = retracementConfirmed;
      result.engulfingConfirmed = engulfingConfirmed || candleConfirm.hasConfirmation;
      result.engulfingType = candleConfirm.hasConfirmation ? candleConfirm.patternName : 
                             (engulfingConfirmed ? "Bearish Engulfing" : "");
      result.candleConfirm = candleConfirm;
      
      result.setupStartTime = ph1Time;
      result.setupEndTime = TimeCurrent();
      result.setupHighPrice = MathMax(ph1, ph2);
      result.setupLowPrice = valleyLow;
      
      result.entryPrice = CalculateFibRetracement(valleyLow, MathMax(ph1, ph2), 0.50);
      result.stopLoss = MathMax(ph1, ph2) + (patternHeight * 0.1);
      result.takeProfit = neckline - patternHeight;
      
      double heightDiff = MathAbs(ph1 - ph2) / tolerance;
      result.confidence = 85.0 - (heightDiff * 10.0);
      if(retracementConfirmed)
         result.confidence += 10.0;
      if(candleConfirm.hasConfirmation)
         result.confidence += (candleConfirm.confidence - 70) * 0.15;
      else if(engulfingConfirmed)
         result.confidence += 8.0;
      result.confidence = MathMax(50.0, MathMin(98.0, result.confidence));
      
      result.aiPrediction = CalculateAIPrediction(rates, false, result.confidence);
      
      result.srZone = CheckSRZone(MathMax(ph1, ph2), false);
      result.trend = CheckTrendAlignment(rates, false);
      result.cycle = DetectMarketCycle(rates, false);
      result.learning = IdentifyPatternVariant(ph1, ph2, valleyLow, 0.618, true);
      
      result.totalConfirmationScore = CalculateTotalConfirmationScore(result);
      result.setupScore = result.totalConfirmationScore;
      
      result.fullSetupConfirmed = result.retracementConfirmed && 
                                   result.candleConfirm.hasConfirmation &&
                                   result.srZone.atResistanceZone &&
                                   result.trend.alignedWithPattern;
      
      m_lastMPattern = result;
      
      if(m_drawOnChart)
         DrawMPattern(result, rates);
      
      return result;
   }
   
   MWPatternData DetectWPattern()
   {
      MWPatternData result;
      ZeroMemory(result);
      result.isValid = false;
      result.isMPattern = false;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, m_lookbackBars, rates);
      if(copied < 30) return result;
      
      int pivotLows[];
      double pivotLowPrices[];
      datetime pivotLowTimes[];
      
      for(int i = m_pivotStrength; i < copied - m_pivotStrength; i++)
      {
         if(IsPivotLow(rates, i, m_pivotStrength))
         {
            int size = ArraySize(pivotLows);
            ArrayResize(pivotLows, size + 1);
            ArrayResize(pivotLowPrices, size + 1);
            ArrayResize(pivotLowTimes, size + 1);
            pivotLows[size] = i;
            pivotLowPrices[size] = rates[i].low;
            pivotLowTimes[size] = rates[i].time;
         }
      }
      
      int numLows = ArraySize(pivotLows);
      if(numLows < 2) return result;
      
      int pl1Idx = pivotLows[numLows - 2];
      int pl2Idx = pivotLows[numLows - 1];
      double pl1 = pivotLowPrices[numLows - 2];
      double pl2 = pivotLowPrices[numLows - 1];
      datetime pl1Time = pivotLowTimes[numLows - 2];
      datetime pl2Time = pivotLowTimes[numLows - 1];
      
      double tolerance = MathAbs(pl1) * 0.015;
      if(MathAbs(pl1 - pl2) > tolerance)
         return result;
      
      double peakHigh = 0;
      int peakIdx = -1;
      datetime peakTime = 0;
      
      for(int i = pl1Idx; i >= pl2Idx; i--)
      {
         if(rates[i].high > peakHigh)
         {
            peakHigh = rates[i].high;
            peakIdx = i;
            peakTime = rates[i].time;
         }
      }
      
      if(peakHigh <= pl1 * 1.005)
         return result;
      
      double currentPrice = rates[0].close;
      double neckline = peakHigh;
      
      double patternHeight = peakHigh - MathMin(pl1, pl2);
      
      double retracementLevel = CalculateFibRetracement(peakHigh, MathMin(pl1, pl2), 0.618);
      
      bool retracementConfirmed = false;
      if(currentPrice <= neckline && currentPrice >= retracementLevel * 0.98)
      {
         retracementConfirmed = true;
      }
      
      CandleConfirmation candleConfirm = FindBullishCandleConfirmation(rates, 7);
      
      int engulfingBar = FindRecentEngulfing(rates, 5, true);
      bool engulfingConfirmed = (engulfingBar >= 0 && engulfingBar <= 3);
      
      result.isValid = true;
      result.isMPattern = false;
      result.peak1 = pl1;
      result.peak2 = pl2;
      result.valley = peakHigh;
      result.neckline = neckline;
      result.peak1Time = pl1Time;
      result.peak2Time = pl2Time;
      result.valleyTime = peakTime;
      result.peak1Bar = pl1Idx;
      result.peak2Bar = pl2Idx;
      result.valleyBar = peakIdx;
      result.retracementLevel = retracementLevel;
      result.retracementConfirmed = retracementConfirmed;
      result.engulfingConfirmed = engulfingConfirmed || candleConfirm.hasConfirmation;
      result.engulfingType = candleConfirm.hasConfirmation ? candleConfirm.patternName : 
                             (engulfingConfirmed ? "Bullish Engulfing" : "");
      result.candleConfirm = candleConfirm;
      
      result.setupStartTime = pl1Time;
      result.setupEndTime = TimeCurrent();
      result.setupHighPrice = peakHigh;
      result.setupLowPrice = MathMin(pl1, pl2);
      
      result.entryPrice = CalculateFibRetracement(peakHigh, MathMin(pl1, pl2), 0.50);
      result.stopLoss = MathMin(pl1, pl2) - (patternHeight * 0.1);
      result.takeProfit = neckline + patternHeight;
      
      double heightDiff = MathAbs(pl1 - pl2) / tolerance;
      result.confidence = 85.0 - (heightDiff * 10.0);
      if(retracementConfirmed)
         result.confidence += 10.0;
      if(candleConfirm.hasConfirmation)
         result.confidence += (candleConfirm.confidence - 70) * 0.15;
      else if(engulfingConfirmed)
         result.confidence += 8.0;
      result.confidence = MathMax(50.0, MathMin(98.0, result.confidence));
      
      result.aiPrediction = CalculateAIPrediction(rates, true, result.confidence);
      
      result.srZone = CheckSRZone(MathMin(pl1, pl2), true);
      result.trend = CheckTrendAlignment(rates, true);
      result.cycle = DetectMarketCycle(rates, true);
      result.learning = IdentifyPatternVariant(pl1, pl2, peakHigh, 0.618, false);
      
      result.totalConfirmationScore = CalculateTotalConfirmationScore(result);
      result.setupScore = result.totalConfirmationScore;
      
      result.fullSetupConfirmed = result.retracementConfirmed && 
                                   result.candleConfirm.hasConfirmation &&
                                   result.srZone.atSupportZone &&
                                   result.trend.alignedWithPattern;
      
      m_lastWPattern = result;
      
      if(m_drawOnChart)
         DrawWPattern(result, rates);
      
      return result;
   }
   
   void DrawMPattern(MWPatternData &pattern, MqlRates &rates[])
   {
      if(!pattern.isValid) return;
      
      ClearPatternObjects("M_");
      
      string prefix = m_objectPrefix + "M_";
      datetime endTime = TimeCurrent() + PeriodSeconds(m_timeframe) * 20;
      
      DrawSetupRectangle(prefix + "SetupZone", pattern.setupStartTime, pattern.setupHighPrice,
                         pattern.setupEndTime, pattern.setupLowPrice, clrMaroon);
      
      DrawTrendLine(prefix + "Peak1Valley", pattern.peak1Time, pattern.peak1, 
                    pattern.valleyTime, pattern.valley, m_mPatternColor);
      DrawTrendLine(prefix + "ValleyPeak2", pattern.valleyTime, pattern.valley,
                    pattern.peak2Time, pattern.peak2, m_mPatternColor);
      
      DrawTrendLine(prefix + "Peak2Retrace", pattern.peak2Time, pattern.peak2,
                    TimeCurrent(), pattern.retracementLevel, clrOrange);
      
      DrawHorizontalLine(prefix + "Entry", pattern.entryPrice, m_entryColor, "ENTRY");
      DrawHorizontalLine(prefix + "SL", pattern.stopLoss, m_slColor, "SL");
      DrawHorizontalLine(prefix + "TP", pattern.takeProfit, m_tpColor, "TP");
      
      DrawHorizontalLine(prefix + "Neckline", pattern.neckline, clrGray, "Neckline");
      
      DrawHorizontalLine(prefix + "Retrace", pattern.retracementLevel, clrOrange, "Retrace 61.8%");
      
      if(pattern.candleConfirm.hasConfirmation)
      {
         DrawLabel(prefix + "CandleConfirm", pattern.candleConfirm.confirmTime, 
                   pattern.stopLoss + ((pattern.stopLoss - pattern.neckline) * 0.05), 
                   "setup", clrRed);
      }
      
      double entryToSL = MathAbs(pattern.stopLoss - pattern.entryPrice);
      double entryToTP = MathAbs(pattern.takeProfit - pattern.entryPrice);
      double rrRatio = entryToTP / entryToSL;
      
      string confirmStr = pattern.candleConfirm.hasConfirmation ? pattern.candleConfirm.patternName : "Pendiente";
      string labelText = StringFormat("M Pattern (SELL)\nConf: %.1f%% | AI: %.1f%%\nR:R = 1:%.1f\nCandle: %s", 
                                       pattern.confidence, pattern.aiPrediction, rrRatio, confirmStr);
      DrawLabel(prefix + "Info", pattern.peak1Time, pattern.peak1 + 
                (pattern.peak1 - pattern.valley) * 0.1, labelText, m_mPatternColor);
   }
   
   void DrawWPattern(MWPatternData &pattern, MqlRates &rates[])
   {
      if(!pattern.isValid) return;
      
      ClearPatternObjects("W_");
      
      string prefix = m_objectPrefix + "W_";
      datetime endTime = TimeCurrent() + PeriodSeconds(m_timeframe) * 20;
      
      DrawSetupRectangle(prefix + "SetupZone", pattern.setupStartTime, pattern.setupHighPrice,
                         pattern.setupEndTime, pattern.setupLowPrice, clrMaroon);
      
      DrawTrendLine(prefix + "Low1Peak", pattern.peak1Time, pattern.peak1,
                    pattern.valleyTime, pattern.valley, m_wPatternColor);
      DrawTrendLine(prefix + "PeakLow2", pattern.valleyTime, pattern.valley,
                    pattern.peak2Time, pattern.peak2, m_wPatternColor);
      
      DrawTrendLine(prefix + "Low2Retrace", pattern.peak2Time, pattern.peak2,
                    TimeCurrent(), pattern.retracementLevel, clrOrange);
      
      DrawHorizontalLine(prefix + "Entry", pattern.entryPrice, m_entryColor, "ENTRY");
      DrawHorizontalLine(prefix + "SL", pattern.stopLoss, m_slColor, "SL");
      DrawHorizontalLine(prefix + "TP", pattern.takeProfit, m_tpColor, "TP");
      
      DrawHorizontalLine(prefix + "Neckline", pattern.neckline, clrGray, "Neckline");
      
      DrawHorizontalLine(prefix + "Retrace", pattern.retracementLevel, clrOrange, "Retrace 61.8%");
      
      if(pattern.candleConfirm.hasConfirmation)
      {
         DrawLabel(prefix + "CandleConfirm", pattern.candleConfirm.confirmTime, 
                   pattern.stopLoss - ((pattern.neckline - pattern.stopLoss) * 0.05), 
                   "setup", clrLime);
      }
      
      double entryToSL = MathAbs(pattern.stopLoss - pattern.entryPrice);
      double entryToTP = MathAbs(pattern.takeProfit - pattern.entryPrice);
      double rrRatio = entryToTP / entryToSL;
      
      string confirmStr = pattern.candleConfirm.hasConfirmation ? pattern.candleConfirm.patternName : "Pendiente";
      string labelText = StringFormat("W Pattern (BUY)\nConf: %.1f%% | AI: %.1f%%\nR:R = 1:%.1f\nCandle: %s", 
                                       pattern.confidence, pattern.aiPrediction, rrRatio, confirmStr);
      DrawLabel(prefix + "Info", pattern.peak1Time, pattern.peak1 - 
                (pattern.valley - pattern.peak1) * 0.1, labelText, m_wPatternColor);
   }
   
   void DrawSetupRectangle(string name, datetime t1, double p1, datetime t2, double p2, color clr)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_FILL, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   
   void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, m_lineWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, m_lineStyle);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   
   void DrawHorizontalLine(string name, double price, color clr, string tooltip = "")
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, m_lineWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      
      if(StringLen(tooltip) > 0)
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   }
   
   void DrawLabel(string name, datetime time, double price, string text, color clr)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
      
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   void ClearPatternObjects(string patternType = "")
   {
      string searchPrefix = m_objectPrefix + patternType;
      int total = ObjectsTotal(0);
      
      for(int i = total - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, searchPrefix) == 0)
            ObjectDelete(0, objName);
      }
   }
   
   void ClearAllPatterns()
   {
      ClearPatternObjects("");
   }
   
   MWPatternData GetLastMPattern() { return m_lastMPattern; }
   MWPatternData GetLastWPattern() { return m_lastWPattern; }
   
   bool HasValidMPattern() { return m_lastMPattern.isValid; }
   bool HasValidWPattern() { return m_lastWPattern.isValid; }
   
   bool IsMPatternRetraceConfirmed() { return m_lastMPattern.isValid && m_lastMPattern.retracementConfirmed; }
   bool IsWPatternRetraceConfirmed() { return m_lastWPattern.isValid && m_lastWPattern.retracementConfirmed; }
   
   bool IsMPatternEngulfingConfirmed() { return m_lastMPattern.isValid && m_lastMPattern.engulfingConfirmed; }
   bool IsWPatternEngulfingConfirmed() { return m_lastWPattern.isValid && m_lastWPattern.engulfingConfirmed; }
   
   bool IsMPatternFullyConfirmed() { return m_lastMPattern.isValid && m_lastMPattern.retracementConfirmed && m_lastMPattern.engulfingConfirmed; }
   bool IsWPatternFullyConfirmed() { return m_lastWPattern.isValid && m_lastWPattern.retracementConfirmed && m_lastWPattern.engulfingConfirmed; }
   
   string GetPatternStatus()
   {
      string status = "";
      
      if(m_lastMPattern.isValid)
      {
         status += StringFormat("M Pattern (SELL) [%s]: Score %.1f%%",
                                m_lastMPattern.learning.variantName, m_lastMPattern.totalConfirmationScore);
         status += StringFormat("\n  Conf %.1f%% | AI %.1f%% | WinRate %.1f%%",
                                m_lastMPattern.confidence, m_lastMPattern.aiPrediction,
                                m_lastMPattern.learning.historicalWinRate);
         status += StringFormat("\n  Entry %.5f, SL %.5f, TP %.5f",
                                m_lastMPattern.entryPrice, m_lastMPattern.stopLoss, m_lastMPattern.takeProfit);
         status += "\n  Confirms:";
         if(m_lastMPattern.retracementConfirmed) status += " [RETRACE]";
         if(m_lastMPattern.candleConfirm.hasConfirmation) status += " [" + m_lastMPattern.candleConfirm.patternName + "]";
         if(m_lastMPattern.srZone.atResistanceZone) status += " [RESISTANCE]";
         if(m_lastMPattern.trend.alignedWithPattern) status += " [TREND]";
         if(m_lastMPattern.cycle.optimalForEntry) status += " [CYCLE]";
         if(m_lastMPattern.fullSetupConfirmed) status += "\n  >>> FULL SETUP CONFIRMED <<<";
      }
      
      if(m_lastWPattern.isValid)
      {
         if(StringLen(status) > 0) status += "\n";
         status += StringFormat("W Pattern (BUY) [%s]: Score %.1f%%",
                                m_lastWPattern.learning.variantName, m_lastWPattern.totalConfirmationScore);
         status += StringFormat("\n  Conf %.1f%% | AI %.1f%% | WinRate %.1f%%",
                                m_lastWPattern.confidence, m_lastWPattern.aiPrediction,
                                m_lastWPattern.learning.historicalWinRate);
         status += StringFormat("\n  Entry %.5f, SL %.5f, TP %.5f",
                                m_lastWPattern.entryPrice, m_lastWPattern.stopLoss, m_lastWPattern.takeProfit);
         status += "\n  Confirms:";
         if(m_lastWPattern.retracementConfirmed) status += " [RETRACE]";
         if(m_lastWPattern.candleConfirm.hasConfirmation) status += " [" + m_lastWPattern.candleConfirm.patternName + "]";
         if(m_lastWPattern.srZone.atSupportZone) status += " [SUPPORT]";
         if(m_lastWPattern.trend.alignedWithPattern) status += " [TREND]";
         if(m_lastWPattern.cycle.optimalForEntry) status += " [CYCLE]";
         if(m_lastWPattern.fullSetupConfirmed) status += "\n  >>> FULL SETUP CONFIRMED <<<";
      }
      
      if(StringLen(status) == 0)
         status = "No M/W patterns detected";
      
      return status;
   }
   
   double GetWPatternAIPrediction() { return m_lastWPattern.isValid ? m_lastWPattern.aiPrediction : 0; }
   double GetMPatternAIPrediction() { return m_lastMPattern.isValid ? m_lastMPattern.aiPrediction : 0; }
   double GetWPatternSetupScore() { return m_lastWPattern.isValid ? m_lastWPattern.setupScore : 0; }
   double GetMPatternSetupScore() { return m_lastMPattern.isValid ? m_lastMPattern.setupScore : 0; }
   string GetWPatternCandleConfirm() { return m_lastWPattern.candleConfirm.patternName; }
   string GetMPatternCandleConfirm() { return m_lastMPattern.candleConfirm.patternName; }
   
   bool IsWPatternFullSetup() { return m_lastWPattern.isValid && m_lastWPattern.fullSetupConfirmed; }
   bool IsMPatternFullSetup() { return m_lastMPattern.isValid && m_lastMPattern.fullSetupConfirmed; }
   
   bool IsWPatternAtSupport() { return m_lastWPattern.isValid && m_lastWPattern.srZone.atSupportZone; }
   bool IsMPatternAtResistance() { return m_lastMPattern.isValid && m_lastMPattern.srZone.atResistanceZone; }
   
   bool IsWPatternTrendAligned() { return m_lastWPattern.isValid && m_lastWPattern.trend.alignedWithPattern; }
   bool IsMPatternTrendAligned() { return m_lastMPattern.isValid && m_lastMPattern.trend.alignedWithPattern; }
   
   bool IsWPatternCycleOptimal() { return m_lastWPattern.isValid && m_lastWPattern.cycle.optimalForEntry; }
   bool IsMPatternCycleOptimal() { return m_lastMPattern.isValid && m_lastMPattern.cycle.optimalForEntry; }
   
   string GetWPatternVariant() { return m_lastWPattern.learning.variantName; }
   string GetMPatternVariant() { return m_lastMPattern.learning.variantName; }
   
   double GetWPatternWinRate() { return m_lastWPattern.learning.historicalWinRate; }
   double GetMPatternWinRate() { return m_lastMPattern.learning.historicalWinRate; }
   
   void RecordWPatternResult(bool wasWin) { if(m_lastWPattern.isValid) UpdatePatternLearning(false, m_lastWPattern.learning.variant, wasWin); }
   void RecordMPatternResult(bool wasWin) { if(m_lastMPattern.isValid) UpdatePatternLearning(true, m_lastMPattern.learning.variant, wasWin); }
};
