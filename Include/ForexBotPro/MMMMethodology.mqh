//+------------------------------------------------------------------+
//|                                              MMMMethodology.mqh |
//|                     Forex Bot Pro v7.0 - Market Maker Method    |
//|       Progressive Auto-Learning System Based on MMM Theory      |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

enum ENUM_MMM_MOVEMENT_TYPE
{
   MMM_MOVEMENT_SIMPLE,
   MMM_MOVEMENT_HARMONIC_SIMPLE,
   MMM_MOVEMENT_HARMONIC_TREND,
   MMM_MOVEMENT_UNKNOWN
};

enum ENUM_MMM_PAUSE_TYPE
{
   MMM_PAUSE_NONE,
   MMM_PAUSE_RETROCESO,
   MMM_PAUSE_RANGO
};

enum ENUM_MMM_IMPULSE_STRENGTH
{
   MMM_IMPULSE_WEAK,
   MMM_IMPULSE_NORMAL,
   MMM_IMPULSE_STRONG,
   MMM_IMPULSE_VERY_STRONG
};

enum ENUM_MMM_CYCLE_PHASE
{
   MMM_CYCLE_ACCUMULATION,
   MMM_CYCLE_MARKUP,
   MMM_CYCLE_DISTRIBUTION,
   MMM_CYCLE_MARKDOWN
};

enum ENUM_MMM_SESSION
{
   MMM_SESSION_ASIAN,
   MMM_SESSION_LONDON,
   MMM_SESSION_NEW_YORK,
   MMM_SESSION_OVERLAP,
   MMM_SESSION_OFF_HOURS,
   MMM_SESSION_ADAPTIVE
};

struct MMMImpulse
{
   double startPrice;
   double endPrice;
   datetime startTime;
   datetime endTime;
   double magnitude;
   bool isBullish;
   ENUM_MMM_IMPULSE_STRENGTH strength;
};

struct MMMPause
{
   double startPrice;
   double endPrice;
   datetime startTime;
   datetime endTime;
   ENUM_MMM_PAUSE_TYPE type;
   double retracementPercent;
};

struct MMMMovementAnalysis
{
   ENUM_MMM_MOVEMENT_TYPE movementType;
   MMMImpulse impulses[3];
   MMMPause pauses[2];
   int impulseCount;
   int pauseCount;
   bool isHarmonic;
   double harmonicScore;
   double impulseRatio;
   double confidenceScore;
};

struct MMMCycleAnalysis
{
   ENUM_MMM_CYCLE_PHASE currentPhase;
   ENUM_MMM_CYCLE_PHASE previousPhase;
   double phaseProgress;
   double phaseConfidence;
   datetime phaseStartTime;
   double accumulationHigh;
   double accumulationLow;
   double distributionHigh;
   double distributionLow;
   bool cycleTransition;
};

struct MMMIntradayState
{
   ENUM_MMM_SESSION currentSession;
   double sessionHigh;
   double sessionLow;
   double previousSessionHigh;
   double previousSessionLow;
   bool inKillZone;
   double killZoneScore;
   double adrUsed;
   double adrRemaining;
   double adr;
};

struct MMMPatternQuality
{
   bool meetsMMM;
   double riskRewardRatio;
   double slPips;
   double tpPips;
   bool correctSLTP;
   double entryQuality;
   double patternClarity;
   double structureScore;
   double totalScore;
};

struct MMMLearningRecord
{
   datetime entryTime;
   datetime exitTime;
   ENUM_MMM_MOVEMENT_TYPE movementType;
   ENUM_MMM_CYCLE_PHASE cyclePhase;
   ENUM_MMM_SESSION session;
   double entryScore;
   double profitPips;
   bool isWin;
   double riskReward;
   double actualRR;
   string patternVariant;
   double confirmationScore;
};

struct MMMAdaptiveWeights
{
   double movementSimpleWeight;
   double movementHarmonicWeight;
   double movementTrendWeight;
   double cycleAccumulationWeight;
   double cycleMarkupWeight;
   double cycleDistributionWeight;
   double cycleMarkdownWeight;
   double sessionAsianWeight;
   double sessionLondonWeight;
   double sessionNewYorkWeight;
   double sessionOverlapWeight;
   double killZoneBonus;
   double harmonicBonus;
   double structureBonus;
   datetime lastUpdate;
   int totalTrades;
   double overallWinRate;
};

class CMMMMethodology
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   MMMMovementAnalysis m_currentMovement;
   MMMCycleAnalysis m_currentCycle;
   MMMIntradayState m_intradayState;
   MMMAdaptiveWeights m_weights;
   MMMLearningRecord m_learningHistory[];
   int m_learningHistoryCount;
   int m_maxHistoryRecords;
   string m_learningFile;
   int m_gmtOffset;
   double m_defaultSLPips;
   double m_defaultTPPips;
   double m_minRRRatio;
   
   double m_ema5Handle;
   double m_ema13Handle;
   double m_ema50Handle;
   double m_ema200Handle;

public:
   CMMMMethodology()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_learningHistoryCount = 0;
      m_maxHistoryRecords = 500;
      m_learningFile = "ForexBotPro_MMM_Learning.bin";
      m_gmtOffset = 0;
      m_defaultSLPips = 40.0;
      m_defaultTPPips = 120.0;
      m_minRRRatio = 3.0;
      InitializeDefaultWeights();
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES tf, int gmtOffset = 0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_gmtOffset = gmtOffset;
      
      ArrayResize(m_learningHistory, m_maxHistoryRecords);
      LoadLearningData();
      
      m_ema5Handle = iMA(m_symbol, m_timeframe, 5, 0, MODE_EMA, PRICE_CLOSE);
      m_ema13Handle = iMA(m_symbol, m_timeframe, 13, 0, MODE_EMA, PRICE_CLOSE);
      m_ema50Handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   void InitializeDefaultWeights()
   {
      m_weights.movementSimpleWeight = 0.6;
      m_weights.movementHarmonicWeight = 0.8;
      m_weights.movementTrendWeight = 0.9;
      m_weights.cycleAccumulationWeight = 0.7;
      m_weights.cycleMarkupWeight = 0.85;
      m_weights.cycleDistributionWeight = 0.7;
      m_weights.cycleMarkdownWeight = 0.85;
      m_weights.sessionAsianWeight = 0.5;
      m_weights.sessionLondonWeight = 0.9;
      m_weights.sessionNewYorkWeight = 0.85;
      m_weights.sessionOverlapWeight = 1.0;
      m_weights.killZoneBonus = 10.0;
      m_weights.harmonicBonus = 15.0;
      m_weights.structureBonus = 10.0;
      m_weights.lastUpdate = 0;
      m_weights.totalTrades = 0;
      m_weights.overallWinRate = 0.0;
   }
   
   ENUM_MMM_SESSION DetectCurrentSession()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      if(hour < 0) hour += 24;
      
      if(hour >= 0 && hour < 8)
         return MMM_SESSION_ASIAN;
      else if(hour >= 8 && hour < 13)
         return MMM_SESSION_LONDON;
      else if(hour >= 13 && hour < 17)
         return MMM_SESSION_OVERLAP;
      else if(hour >= 17 && hour < 22)
         return MMM_SESSION_NEW_YORK;
      else
         return MMM_SESSION_OFF_HOURS;
   }
   
   bool IsInKillZone()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      if(hour < 0) hour += 24;
      int min = dt.min;
      
      if(hour >= 2 && hour < 5) return true;
      if(hour >= 8 && hour < 11) return true;
      if(hour >= 13 && hour < 16) return true;
      
      return false;
   }
   
   void UpdateIntradayState()
   {
      m_intradayState.currentSession = DetectCurrentSession();
      m_intradayState.inKillZone = IsInKillZone();
      
      if(m_intradayState.inKillZone)
         m_intradayState.killZoneScore = 100.0;
      else if(m_intradayState.currentSession == MMM_SESSION_OVERLAP)
         m_intradayState.killZoneScore = 90.0;
      else if(m_intradayState.currentSession == MMM_SESSION_LONDON)
         m_intradayState.killZoneScore = 85.0;
      else if(m_intradayState.currentSession == MMM_SESSION_NEW_YORK)
         m_intradayState.killZoneScore = 80.0;
      else if(m_intradayState.currentSession == MMM_SESSION_ASIAN)
         m_intradayState.killZoneScore = 50.0;
      else
         m_intradayState.killZoneScore = 30.0;
      
      CalculateADR();
      CalculateSessionHighLow();
   }
   
   void CalculateADR()
   {
      MqlRates daily[];
      ArraySetAsSeries(daily, true);
      int copied = CopyRates(m_symbol, PERIOD_D1, 0, 15, daily);
      if(copied < 14) return;
      
      double sumRange = 0;
      for(int i = 1; i < 15; i++)
         sumRange += daily[i].high - daily[i].low;
      
      m_intradayState.adr = sumRange / 14.0;
      
      double todayRange = daily[0].high - daily[0].low;
      m_intradayState.adrUsed = todayRange;
      m_intradayState.adrRemaining = MathMax(0, m_intradayState.adr - todayRange);
   }
   
   void CalculateSessionHighLow()
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      
      int sessionBars = (hour * 4);
      if(sessionBars < 4) sessionBars = 4;
      
      int copied = CopyRates(m_symbol, PERIOD_M15, 0, sessionBars, rates);
      if(copied < 2) return;
      
      m_intradayState.sessionHigh = rates[0].high;
      m_intradayState.sessionLow = rates[0].low;
      
      for(int i = 1; i < copied; i++)
      {
         if(rates[i].high > m_intradayState.sessionHigh)
            m_intradayState.sessionHigh = rates[i].high;
         if(rates[i].low < m_intradayState.sessionLow)
            m_intradayState.sessionLow = rates[i].low;
      }
   }
   
   MMMMovementAnalysis AnalyzeMovement()
   {
      ZeroMemory(m_currentMovement);
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, 50, rates);
      if(copied < 30) return m_currentMovement;
      
      double swings[10];
      int swingTypes[10];
      datetime swingTimes[10];
      int swingCount = 0;
      
      for(int i = 5; i < copied - 5 && swingCount < 10; i++)
      {
         bool isHigh = true, isLow = true;
         for(int j = i - 5; j <= i + 5; j++)
         {
            if(j == i) continue;
            if(rates[j].high >= rates[i].high) isHigh = false;
            if(rates[j].low <= rates[i].low) isLow = false;
         }
         
         if(isHigh && (swingCount == 0 || swingTypes[swingCount-1] != 1))
         {
            swings[swingCount] = rates[i].high;
            swingTypes[swingCount] = 1;
            swingTimes[swingCount] = rates[i].time;
            swingCount++;
         }
         else if(isLow && (swingCount == 0 || swingTypes[swingCount-1] != -1))
         {
            swings[swingCount] = rates[i].low;
            swingTypes[swingCount] = -1;
            swingTimes[swingCount] = rates[i].time;
            swingCount++;
         }
      }
      
      if(swingCount >= 4)
      {
         m_currentMovement.impulseCount = 0;
         m_currentMovement.pauseCount = 0;
         
         bool firstBullish = (swingTypes[0] == -1);
         
         for(int i = 0; i < swingCount - 1 && m_currentMovement.impulseCount < 3; i++)
         {
            if((firstBullish && swingTypes[i] == -1) || (!firstBullish && swingTypes[i] == 1))
            {
               int idx = m_currentMovement.impulseCount;
               m_currentMovement.impulses[idx].startPrice = swings[i];
               m_currentMovement.impulses[idx].endPrice = swings[i+1];
               m_currentMovement.impulses[idx].startTime = swingTimes[i];
               m_currentMovement.impulses[idx].endTime = swingTimes[i+1];
               m_currentMovement.impulses[idx].magnitude = MathAbs(swings[i+1] - swings[i]);
               m_currentMovement.impulses[idx].isBullish = (swings[i+1] > swings[i]);
               m_currentMovement.impulseCount++;
            }
            else if(m_currentMovement.impulseCount > 0 && m_currentMovement.pauseCount < 2)
            {
               int idx = m_currentMovement.pauseCount;
               m_currentMovement.pauses[idx].startPrice = swings[i];
               m_currentMovement.pauses[idx].endPrice = swings[i+1];
               m_currentMovement.pauses[idx].startTime = swingTimes[i];
               m_currentMovement.pauses[idx].endTime = swingTimes[i+1];
               
               double prevImpulse = m_currentMovement.impulses[m_currentMovement.impulseCount-1].magnitude;
               double pauseSize = MathAbs(swings[i+1] - swings[i]);
               m_currentMovement.pauses[idx].retracementPercent = (prevImpulse > 0) ? (pauseSize / prevImpulse) * 100 : 0;
               
               if(m_currentMovement.pauses[idx].retracementPercent > 50)
                  m_currentMovement.pauses[idx].type = MMM_PAUSE_RETROCESO;
               else
                  m_currentMovement.pauses[idx].type = MMM_PAUSE_RANGO;
               
               m_currentMovement.pauseCount++;
            }
         }
         
         ClassifyMovementType();
      }
      
      return m_currentMovement;
   }
   
   void ClassifyMovementType()
   {
      if(m_currentMovement.impulseCount < 2)
      {
         m_currentMovement.movementType = MMM_MOVEMENT_UNKNOWN;
         m_currentMovement.harmonicScore = 0;
         m_currentMovement.confidenceScore = 0;
         return;
      }
      
      double impulse1 = m_currentMovement.impulses[0].magnitude;
      double impulse2 = m_currentMovement.impulses[1].magnitude;
      m_currentMovement.impulseRatio = (impulse1 > 0) ? impulse2 / impulse1 : 0;
      
      if(m_currentMovement.impulseCount == 2 && m_currentMovement.pauseCount == 1)
      {
         if(m_currentMovement.impulseRatio < 1.0)
         {
            m_currentMovement.movementType = MMM_MOVEMENT_SIMPLE;
            m_currentMovement.isHarmonic = false;
            m_currentMovement.harmonicScore = m_currentMovement.impulseRatio * 60;
         }
         else
         {
            m_currentMovement.movementType = MMM_MOVEMENT_HARMONIC_SIMPLE;
            m_currentMovement.isHarmonic = true;
            m_currentMovement.harmonicScore = MathMin(100, m_currentMovement.impulseRatio * 80);
         }
         m_currentMovement.confidenceScore = 70 + m_currentMovement.harmonicScore * 0.3;
      }
      else if(m_currentMovement.impulseCount >= 3 && m_currentMovement.pauseCount >= 2)
      {
         m_currentMovement.movementType = MMM_MOVEMENT_HARMONIC_TREND;
         
         double pause1 = MathAbs(m_currentMovement.pauses[0].endPrice - m_currentMovement.pauses[0].startPrice);
         double pause2 = MathAbs(m_currentMovement.pauses[1].endPrice - m_currentMovement.pauses[1].startPrice);
         
         double pauseRatio = (pause1 > 0 && pause2 > 0) ? MathMin(pause1, pause2) / MathMax(pause1, pause2) : 0;
         m_currentMovement.isHarmonic = (pauseRatio > 0.6);
         m_currentMovement.harmonicScore = pauseRatio * 100;
         m_currentMovement.confidenceScore = 80 + m_currentMovement.harmonicScore * 0.2;
      }
      else
      {
         m_currentMovement.movementType = MMM_MOVEMENT_UNKNOWN;
         m_currentMovement.harmonicScore = 30;
         m_currentMovement.confidenceScore = 40;
      }
   }
   
   MMMCycleAnalysis AnalyzeCycle()
   {
      ZeroMemory(m_currentCycle);
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, PERIOD_H1, 0, 100, rates);
      if(copied < 50) return m_currentCycle;
      
      double ema20[], ema50[];
      ArraySetAsSeries(ema20, true);
      ArraySetAsSeries(ema50, true);
      
      int h1Ema20 = iMA(m_symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
      int h1Ema50 = iMA(m_symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      CopyBuffer(h1Ema20, 0, 0, 30, ema20);
      CopyBuffer(h1Ema50, 0, 0, 30, ema50);
      
      double current = rates[0].close;
      double high20 = rates[0].high, low20 = rates[0].low;
      for(int i = 0; i < 20; i++)
      {
         if(rates[i].high > high20) high20 = rates[i].high;
         if(rates[i].low < low20) low20 = rates[i].low;
      }
      
      double range20 = high20 - low20;
      double positionInRange = (range20 > 0) ? (current - low20) / range20 : 0.5;
      
      bool emaUpTrend = (ema20[0] > ema50[0]);
      double emaDelta = (ema50[0] > 0) ? (ema20[0] - ema50[0]) / ema50[0] * 100 : 0;
      double emaDeltaPrev = (ema50[5] > 0) ? (ema20[5] - ema50[5]) / ema50[5] * 100 : 0;
      bool emaExpanding = MathAbs(emaDelta) > MathAbs(emaDeltaPrev);
      
      if(!emaUpTrend && !emaExpanding && positionInRange < 0.3)
      {
         m_currentCycle.currentPhase = MMM_CYCLE_ACCUMULATION;
         m_currentCycle.phaseConfidence = 70 + (0.3 - positionInRange) * 100;
         m_currentCycle.accumulationHigh = high20;
         m_currentCycle.accumulationLow = low20;
      }
      else if(emaUpTrend && emaExpanding && positionInRange > 0.5)
      {
         m_currentCycle.currentPhase = MMM_CYCLE_MARKUP;
         m_currentCycle.phaseConfidence = 70 + positionInRange * 30;
      }
      else if(emaUpTrend && !emaExpanding && positionInRange > 0.7)
      {
         m_currentCycle.currentPhase = MMM_CYCLE_DISTRIBUTION;
         m_currentCycle.phaseConfidence = 70 + (positionInRange - 0.7) * 100;
         m_currentCycle.distributionHigh = high20;
         m_currentCycle.distributionLow = low20;
      }
      else if(!emaUpTrend && emaExpanding && positionInRange < 0.5)
      {
         m_currentCycle.currentPhase = MMM_CYCLE_MARKDOWN;
         m_currentCycle.phaseConfidence = 70 + (0.5 - positionInRange) * 60;
      }
      else
      {
         if(positionInRange > 0.5)
            m_currentCycle.currentPhase = (emaUpTrend) ? MMM_CYCLE_MARKUP : MMM_CYCLE_DISTRIBUTION;
         else
            m_currentCycle.currentPhase = (!emaUpTrend) ? MMM_CYCLE_MARKDOWN : MMM_CYCLE_ACCUMULATION;
         m_currentCycle.phaseConfidence = 50;
      }
      
      m_currentCycle.phaseProgress = positionInRange * 100;
      m_currentCycle.phaseStartTime = rates[20].time;
      
      return m_currentCycle;
   }
   
   MMMPatternQuality EvaluatePatternQuality(double entry, double sl, double tp, bool isBuy)
   {
      MMMPatternQuality quality;
      ZeroMemory(quality);
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      double slDistance = MathAbs(entry - sl);
      double tpDistance = MathAbs(tp - entry);
      
      quality.slPips = slDistance / pipValue;
      quality.tpPips = tpDistance / pipValue;
      quality.riskRewardRatio = (quality.slPips > 0) ? quality.tpPips / quality.slPips : 0;
      
      quality.correctSLTP = (quality.slPips >= 30 && quality.slPips <= 60 && 
                            quality.riskRewardRatio >= 2.5);
      
      if(quality.riskRewardRatio >= 3.0)
         quality.entryQuality = 100;
      else if(quality.riskRewardRatio >= 2.5)
         quality.entryQuality = 85;
      else if(quality.riskRewardRatio >= 2.0)
         quality.entryQuality = 70;
      else if(quality.riskRewardRatio >= 1.5)
         quality.entryQuality = 50;
      else
         quality.entryQuality = 30;
      
      quality.patternClarity = m_currentMovement.confidenceScore;
      quality.structureScore = m_currentMovement.harmonicScore;
      
      if(isBuy)
      {
         if(m_currentCycle.currentPhase == MMM_CYCLE_ACCUMULATION ||
            m_currentCycle.currentPhase == MMM_CYCLE_MARKUP)
            quality.meetsMMM = true;
      }
      else
      {
         if(m_currentCycle.currentPhase == MMM_CYCLE_DISTRIBUTION ||
            m_currentCycle.currentPhase == MMM_CYCLE_MARKDOWN)
            quality.meetsMMM = true;
      }
      
      quality.totalScore = (quality.entryQuality * 0.3 +
                           quality.patternClarity * 0.25 +
                           quality.structureScore * 0.25 +
                           (quality.meetsMMM ? 100 : 50) * 0.2);
      
      if(quality.correctSLTP)
         quality.totalScore += 5;
      if(m_intradayState.inKillZone)
         quality.totalScore += m_weights.killZoneBonus;
      if(m_currentMovement.isHarmonic)
         quality.totalScore += m_weights.harmonicBonus;
      
      quality.totalScore = MathMin(100, quality.totalScore);
      
      return quality;
   }
   
   void RecordTradeOutcome(datetime entryTime, datetime exitTime, double profitPips,
                          bool isWin, double entryScore, double actualRR, string variant)
   {
      if(m_learningHistoryCount >= m_maxHistoryRecords)
      {
         for(int i = 0; i < m_maxHistoryRecords - 1; i++)
            m_learningHistory[i] = m_learningHistory[i + 1];
         m_learningHistoryCount = m_maxHistoryRecords - 1;
      }
      
      MMMLearningRecord record;
      record.entryTime = entryTime;
      record.exitTime = exitTime;
      record.movementType = m_currentMovement.movementType;
      record.cyclePhase = m_currentCycle.currentPhase;
      record.session = m_intradayState.currentSession;
      record.entryScore = entryScore;
      record.profitPips = profitPips;
      record.isWin = isWin;
      record.riskReward = m_minRRRatio;
      record.actualRR = actualRR;
      record.patternVariant = variant;
      record.confirmationScore = entryScore;
      
      m_learningHistory[m_learningHistoryCount] = record;
      m_learningHistoryCount++;
      
      UpdateAdaptiveWeights();
      SaveLearningData();
   }
   
   void UpdateAdaptiveWeights()
   {
      if(m_learningHistoryCount < 10) return;
      
      int movementWins[4] = {0, 0, 0, 0};
      int movementTotal[4] = {0, 0, 0, 0};
      int cycleWins[4] = {0, 0, 0, 0};
      int cycleTotal[4] = {0, 0, 0, 0};
      int sessionWins[5] = {0, 0, 0, 0, 0};
      int sessionTotal[5] = {0, 0, 0, 0, 0};
      
      int totalWins = 0;
      
      for(int i = 0; i < m_learningHistoryCount; i++)
      {
         int movIdx = (int)m_learningHistory[i].movementType;
         int cycIdx = (int)m_learningHistory[i].cyclePhase;
         int sesIdx = (int)m_learningHistory[i].session;
         
         if(movIdx >= 0 && movIdx < 4)
         {
            movementTotal[movIdx]++;
            if(m_learningHistory[i].isWin) movementWins[movIdx]++;
         }
         if(cycIdx >= 0 && cycIdx < 4)
         {
            cycleTotal[cycIdx]++;
            if(m_learningHistory[i].isWin) cycleWins[cycIdx]++;
         }
         if(sesIdx >= 0 && sesIdx < 5)
         {
            sessionTotal[sesIdx]++;
            if(m_learningHistory[i].isWin) sessionWins[sesIdx]++;
         }
         
         if(m_learningHistory[i].isWin) totalWins++;
      }
      
      double learningRate = 0.1;
      
      if(movementTotal[0] >= 5)
         m_weights.movementSimpleWeight = m_weights.movementSimpleWeight * (1 - learningRate) +
                                          ((double)movementWins[0] / movementTotal[0]) * learningRate;
      if(movementTotal[1] >= 5)
         m_weights.movementHarmonicWeight = m_weights.movementHarmonicWeight * (1 - learningRate) +
                                            ((double)movementWins[1] / movementTotal[1]) * learningRate;
      if(movementTotal[2] >= 5)
         m_weights.movementTrendWeight = m_weights.movementTrendWeight * (1 - learningRate) +
                                         ((double)movementWins[2] / movementTotal[2]) * learningRate;
      
      if(cycleTotal[0] >= 5)
         m_weights.cycleAccumulationWeight = m_weights.cycleAccumulationWeight * (1 - learningRate) +
                                             ((double)cycleWins[0] / cycleTotal[0]) * learningRate;
      if(cycleTotal[1] >= 5)
         m_weights.cycleMarkupWeight = m_weights.cycleMarkupWeight * (1 - learningRate) +
                                       ((double)cycleWins[1] / cycleTotal[1]) * learningRate;
      if(cycleTotal[2] >= 5)
         m_weights.cycleDistributionWeight = m_weights.cycleDistributionWeight * (1 - learningRate) +
                                             ((double)cycleWins[2] / cycleTotal[2]) * learningRate;
      if(cycleTotal[3] >= 5)
         m_weights.cycleMarkdownWeight = m_weights.cycleMarkdownWeight * (1 - learningRate) +
                                         ((double)cycleWins[3] / cycleTotal[3]) * learningRate;
      
      if(sessionTotal[0] >= 5)
         m_weights.sessionAsianWeight = m_weights.sessionAsianWeight * (1 - learningRate) +
                                        ((double)sessionWins[0] / sessionTotal[0]) * learningRate;
      if(sessionTotal[1] >= 5)
         m_weights.sessionLondonWeight = m_weights.sessionLondonWeight * (1 - learningRate) +
                                         ((double)sessionWins[1] / sessionTotal[1]) * learningRate;
      if(sessionTotal[2] >= 5)
         m_weights.sessionNewYorkWeight = m_weights.sessionNewYorkWeight * (1 - learningRate) +
                                          ((double)sessionWins[2] / sessionTotal[2]) * learningRate;
      if(sessionTotal[3] >= 5)
         m_weights.sessionOverlapWeight = m_weights.sessionOverlapWeight * (1 - learningRate) +
                                          ((double)sessionWins[3] / sessionTotal[3]) * learningRate;
      
      m_weights.totalTrades = m_learningHistoryCount;
      m_weights.overallWinRate = (m_learningHistoryCount > 0) ?
                                 (double)totalWins / m_learningHistoryCount * 100 : 0;
      m_weights.lastUpdate = TimeCurrent();
   }
   
   double GetMMMConfirmationScore(bool isBuy)
   {
      double score = 0;
      
      double movementWeight = 0;
      switch(m_currentMovement.movementType)
      {
         case MMM_MOVEMENT_SIMPLE: movementWeight = m_weights.movementSimpleWeight; break;
         case MMM_MOVEMENT_HARMONIC_SIMPLE: movementWeight = m_weights.movementHarmonicWeight; break;
         case MMM_MOVEMENT_HARMONIC_TREND: movementWeight = m_weights.movementTrendWeight; break;
         default: movementWeight = 0.4; break;
      }
      score += m_currentMovement.confidenceScore * movementWeight * 0.25;
      
      double cycleWeight = 0;
      bool cycleAligned = false;
      if(isBuy)
      {
         if(m_currentCycle.currentPhase == MMM_CYCLE_ACCUMULATION)
         {
            cycleWeight = m_weights.cycleAccumulationWeight;
            cycleAligned = true;
         }
         else if(m_currentCycle.currentPhase == MMM_CYCLE_MARKUP)
         {
            cycleWeight = m_weights.cycleMarkupWeight;
            cycleAligned = true;
         }
      }
      else
      {
         if(m_currentCycle.currentPhase == MMM_CYCLE_DISTRIBUTION)
         {
            cycleWeight = m_weights.cycleDistributionWeight;
            cycleAligned = true;
         }
         else if(m_currentCycle.currentPhase == MMM_CYCLE_MARKDOWN)
         {
            cycleWeight = m_weights.cycleMarkdownWeight;
            cycleAligned = true;
         }
      }
      
      if(cycleAligned)
         score += m_currentCycle.phaseConfidence * cycleWeight * 0.25;
      else
         score += m_currentCycle.phaseConfidence * 0.3 * 0.25;
      
      double sessionWeight = 0;
      switch(m_intradayState.currentSession)
      {
         case MMM_SESSION_ASIAN: sessionWeight = m_weights.sessionAsianWeight; break;
         case MMM_SESSION_LONDON: sessionWeight = m_weights.sessionLondonWeight; break;
         case MMM_SESSION_NEW_YORK: sessionWeight = m_weights.sessionNewYorkWeight; break;
         case MMM_SESSION_OVERLAP: sessionWeight = m_weights.sessionOverlapWeight; break;
         default: sessionWeight = 0.3; break;
      }
      score += m_intradayState.killZoneScore * sessionWeight * 0.25;
      
      double structureScore = (m_currentMovement.harmonicScore + m_currentMovement.impulseRatio * 50) / 2;
      score += structureScore * 0.25;
      
      if(m_intradayState.inKillZone)
         score += m_weights.killZoneBonus;
      if(m_currentMovement.isHarmonic)
         score += m_weights.harmonicBonus;
      
      return MathMin(100, score);
   }
   
   void SaveLearningData()
   {
      string filename = m_learningFile;
      int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      FileWriteInteger(handle, m_learningHistoryCount);
      
      FileWriteDouble(handle, m_weights.movementSimpleWeight);
      FileWriteDouble(handle, m_weights.movementHarmonicWeight);
      FileWriteDouble(handle, m_weights.movementTrendWeight);
      FileWriteDouble(handle, m_weights.cycleAccumulationWeight);
      FileWriteDouble(handle, m_weights.cycleMarkupWeight);
      FileWriteDouble(handle, m_weights.cycleDistributionWeight);
      FileWriteDouble(handle, m_weights.cycleMarkdownWeight);
      FileWriteDouble(handle, m_weights.sessionAsianWeight);
      FileWriteDouble(handle, m_weights.sessionLondonWeight);
      FileWriteDouble(handle, m_weights.sessionNewYorkWeight);
      FileWriteDouble(handle, m_weights.sessionOverlapWeight);
      FileWriteDouble(handle, m_weights.killZoneBonus);
      FileWriteDouble(handle, m_weights.harmonicBonus);
      FileWriteDouble(handle, m_weights.structureBonus);
      FileWriteInteger(handle, m_weights.totalTrades);
      FileWriteDouble(handle, m_weights.overallWinRate);
      
      for(int i = 0; i < m_learningHistoryCount; i++)
      {
         FileWriteLong(handle, (long)m_learningHistory[i].entryTime);
         FileWriteLong(handle, (long)m_learningHistory[i].exitTime);
         FileWriteInteger(handle, (int)m_learningHistory[i].movementType);
         FileWriteInteger(handle, (int)m_learningHistory[i].cyclePhase);
         FileWriteInteger(handle, (int)m_learningHistory[i].session);
         FileWriteDouble(handle, m_learningHistory[i].entryScore);
         FileWriteDouble(handle, m_learningHistory[i].profitPips);
         FileWriteInteger(handle, m_learningHistory[i].isWin ? 1 : 0);
         FileWriteDouble(handle, m_learningHistory[i].actualRR);
      }
      
      FileClose(handle);
   }
   
   void LoadLearningData()
   {
      string filename = m_learningFile;
      int handle = FileOpen(filename, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         Print("MMM: No learning data found, starting fresh");
         return;
      }
      
      m_learningHistoryCount = FileReadInteger(handle);
      if(m_learningHistoryCount > m_maxHistoryRecords)
         m_learningHistoryCount = m_maxHistoryRecords;
      
      m_weights.movementSimpleWeight = FileReadDouble(handle);
      m_weights.movementHarmonicWeight = FileReadDouble(handle);
      m_weights.movementTrendWeight = FileReadDouble(handle);
      m_weights.cycleAccumulationWeight = FileReadDouble(handle);
      m_weights.cycleMarkupWeight = FileReadDouble(handle);
      m_weights.cycleDistributionWeight = FileReadDouble(handle);
      m_weights.cycleMarkdownWeight = FileReadDouble(handle);
      m_weights.sessionAsianWeight = FileReadDouble(handle);
      m_weights.sessionLondonWeight = FileReadDouble(handle);
      m_weights.sessionNewYorkWeight = FileReadDouble(handle);
      m_weights.sessionOverlapWeight = FileReadDouble(handle);
      m_weights.killZoneBonus = FileReadDouble(handle);
      m_weights.harmonicBonus = FileReadDouble(handle);
      m_weights.structureBonus = FileReadDouble(handle);
      m_weights.totalTrades = FileReadInteger(handle);
      m_weights.overallWinRate = FileReadDouble(handle);
      
      for(int i = 0; i < m_learningHistoryCount; i++)
      {
         m_learningHistory[i].entryTime = (datetime)FileReadLong(handle);
         m_learningHistory[i].exitTime = (datetime)FileReadLong(handle);
         m_learningHistory[i].movementType = (ENUM_MMM_MOVEMENT_TYPE)FileReadInteger(handle);
         m_learningHistory[i].cyclePhase = (ENUM_MMM_CYCLE_PHASE)FileReadInteger(handle);
         m_learningHistory[i].session = (ENUM_MMM_SESSION)FileReadInteger(handle);
         m_learningHistory[i].entryScore = FileReadDouble(handle);
         m_learningHistory[i].profitPips = FileReadDouble(handle);
         m_learningHistory[i].isWin = (FileReadInteger(handle) == 1);
         m_learningHistory[i].actualRR = FileReadDouble(handle);
      }
      
      FileClose(handle);
      Print("MMM: Loaded ", m_learningHistoryCount, " learning records, WinRate: ",
            DoubleToString(m_weights.overallWinRate, 1), "%");
   }
   
   MMMMovementAnalysis GetCurrentMovement() { return m_currentMovement; }
   MMMCycleAnalysis GetCurrentCycle() { return m_currentCycle; }
   MMMIntradayState GetIntradayState() { return m_intradayState; }
   MMMAdaptiveWeights GetWeights() { return m_weights; }
   int GetLearningRecordCount() { return m_learningHistoryCount; }
   
   string GetMovementTypeName(ENUM_MMM_MOVEMENT_TYPE type)
   {
      switch(type)
      {
         case MMM_MOVEMENT_SIMPLE: return "Simple";
         case MMM_MOVEMENT_HARMONIC_SIMPLE: return "Harmonic Simple";
         case MMM_MOVEMENT_HARMONIC_TREND: return "Harmonic Trend";
         default: return "Unknown";
      }
   }
   
   string GetCyclePhaseName(ENUM_MMM_CYCLE_PHASE phase)
   {
      switch(phase)
      {
         case MMM_CYCLE_ACCUMULATION: return "Accumulation";
         case MMM_CYCLE_MARKUP: return "Markup";
         case MMM_CYCLE_DISTRIBUTION: return "Distribution";
         case MMM_CYCLE_MARKDOWN: return "Markdown";
         default: return "Unknown";
      }
   }
   
   string GetSessionName(ENUM_MMM_SESSION session)
   {
      switch(session)
      {
         case MMM_SESSION_ASIAN: return "Asian";
         case MMM_SESSION_LONDON: return "London";
         case MMM_SESSION_NEW_YORK: return "New York";
         case MMM_SESSION_OVERLAP: return "London-NYC Overlap";
         case MMM_SESSION_OFF_HOURS: return "Off-Hours";
         default: return "Unknown";
      }
   }
   
   string GetLearningStatus()
   {
      return StringFormat("MMM Learning: %d trades, %.1f%% WinRate | Movement[S:%.0f%% H:%.0f%% T:%.0f%%] | "
                         "Session[A:%.0f%% L:%.0f%% NY:%.0f%% OV:%.0f%%]",
                         m_weights.totalTrades,
                         m_weights.overallWinRate,
                         m_weights.movementSimpleWeight * 100,
                         m_weights.movementHarmonicWeight * 100,
                         m_weights.movementTrendWeight * 100,
                         m_weights.sessionAsianWeight * 100,
                         m_weights.sessionLondonWeight * 100,
                         m_weights.sessionNewYorkWeight * 100,
                         m_weights.sessionOverlapWeight * 100);
   }
};
