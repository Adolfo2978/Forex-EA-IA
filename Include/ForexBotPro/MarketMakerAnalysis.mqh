#property copyright "ForexBotPro"
#property link      ""
#property version   "1.00"

enum ENUM_MM_CYCLE_PHASE
{
   MM_PHASE_UNKNOWN,
   MM_PHASE_ACCUMULATION,
   MM_PHASE_STOP_HUNT,
   MM_PHASE_TRUE_TREND,
   MM_PHASE_DISTRIBUTION
};

enum ENUM_KILL_ZONE
{
   KZ_NONE,
   KZ_ASIAN,
   KZ_LONDON,
   KZ_NEW_YORK,
   KZ_LONDON_NYC_OVERLAP
};

enum ENUM_MM_PATTERN
{
   MM_PATTERN_NONE,
   MM_PATTERN_M_TOP,
   MM_PATTERN_W_BOTTOM,
   MM_PATTERN_HALF_BATMAN,
   MM_PATTERN_RRT,
   MM_PATTERN_SHARK_FIN
};

enum ENUM_DAY_CYCLE
{
   DAY_CYCLE_1,
   DAY_CYCLE_2,
   DAY_CYCLE_3
};

enum ENUM_BEEKAY_LEVEL
{
   BEEKAY_LEVEL_0,
   BEEKAY_LEVEL_1,
   BEEKAY_LEVEL_2,
   BEEKAY_LEVEL_3
};

enum ENUM_EMA_CROSS_TYPE
{
   EMA_CROSS_NONE,
   EMA_CROSS_13_50,
   EMA_CROSS_50_200,
   EMA_CROSS_50_800,
   EMA_CROSS_200_800
};

struct BeeKayLevelState
{
   ENUM_BEEKAY_LEVEL currentLevel;
   ENUM_EMA_CROSS_TYPE lastCrossType;
   bool isBullish;
   double levelStartPrice;
   datetime levelStartTime;
   double adrUtilization;
   bool resetDetected;
   bool mayoPattern;
   bool blueberryPattern;
   double levelConfidence;
   int consecutiveLevels;
   double lastSwingHigh;
   double lastSwingLow;
   bool swingBroken;
};

struct OrderBlockInfo
{
   double priceHigh;
   double priceLow;
   datetime time;
   bool isBullish;
   bool isValid;
   int touches;
};

struct LiquidityPool
{
   double price;
   datetime time;
   bool isHighLiquidity;
   bool wasSwept;
   int stopCount;
};

struct MWPatternInfo
{
   bool detected;
   bool isSecondLeg;
   double peak1Price;
   double peak2Price;
   double valleyPrice;
   double neckline;
   int peak1Index;
   int peak2Index;
   int valleyIndex;
   double confidence;
   double distanceFromExtreme;
};

struct MarketMakerState
{
   ENUM_MM_CYCLE_PHASE intradayPhase;
   ENUM_DAY_CYCLE dayCycle;
   ENUM_KILL_ZONE currentKillZone;
   ENUM_MM_PATTERN detectedPattern;
   
   double adr;
   double adrUsed;
   double adrRemaining;
   
   double todayHigh;
   double todayLow;
   double asianHigh;
   double asianLow;
   
   bool stopHuntDetected;
   bool stopHuntBullish;
   double stopHuntMagnitude;
   
   double orderBlockScore;
   double liquidityScore;
   double patternScore;
   double killZoneScore;
   double cycleScore;
   
   double totalMMScore;
   
   bool isCycle3Entry;
   bool nearDailyHigh;
   bool nearDailyLow;
   MWPatternInfo mPattern;
   MWPatternInfo wPattern;
   
   BeeKayLevelState beeKayLevel;
   double levelCycleCoherence;
};

class CMarketMakerAnalysis
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   int m_ema5Handle;
   int m_ema13Handle;
   int m_ema50Handle;
   int m_ema200Handle;
   
   int m_h1Ema13Handle;
   int m_h1Ema50Handle;
   int m_h1Ema200Handle;
   int m_h1Ema800Handle;
   int m_rsiHandle;
   
   double m_ema5[];
   double m_ema13[];
   double m_ema50[];
   double m_ema200[];
   
   double m_h1Ema13[];
   double m_h1Ema50[];
   double m_h1Ema200[];
   double m_h1Ema800[];
   double m_rsiBuffer[];
   
   OrderBlockInfo m_orderBlocks[10];
   int m_orderBlockCount;
   
   LiquidityPool m_liquidityPools[20];
   int m_liquidityPoolCount;
   
   MarketMakerState m_state;
   
   int m_gmtOffset;
   
   datetime m_lastAsianCalc;
   double m_asianSessionHigh;
   double m_asianSessionLow;
   
   datetime m_cycleStartDate;
   int m_currentDayCycle;
   
   double m_dailyProximityPips;
   double m_mwTolerancePercent;
   
public:
   CMarketMakerAnalysis()
   {
      m_symbol = "";
      m_timeframe = PERIOD_M15;
      m_orderBlockCount = 0;
      m_liquidityPoolCount = 0;
      m_gmtOffset = 0;
      m_lastAsianCalc = 0;
      m_asianSessionHigh = 0;
      m_asianSessionLow = 0;
      m_cycleStartDate = 0;
      m_currentDayCycle = 1;
      m_dailyProximityPips = 50.0;
      m_mwTolerancePercent = 0.015;
      
      m_ema5Handle = INVALID_HANDLE;
      m_ema13Handle = INVALID_HANDLE;
      m_ema50Handle = INVALID_HANDLE;
      m_ema200Handle = INVALID_HANDLE;
      m_h1Ema13Handle = INVALID_HANDLE;
      m_h1Ema50Handle = INVALID_HANDLE;
      m_h1Ema200Handle = INVALID_HANDLE;
      m_h1Ema800Handle = INVALID_HANDLE;
      m_rsiHandle = INVALID_HANDLE;
      
      ArraySetAsSeries(m_ema5, true);
      ArraySetAsSeries(m_ema13, true);
      ArraySetAsSeries(m_ema50, true);
      ArraySetAsSeries(m_ema200, true);
      ArraySetAsSeries(m_h1Ema13, true);
      ArraySetAsSeries(m_h1Ema50, true);
      ArraySetAsSeries(m_h1Ema200, true);
      ArraySetAsSeries(m_h1Ema800, true);
      ArraySetAsSeries(m_rsiBuffer, true);
      
      ZeroMemory(m_state);
   }
   
   ~CMarketMakerAnalysis()
   {
      if(m_ema5Handle != INVALID_HANDLE) IndicatorRelease(m_ema5Handle);
      if(m_ema13Handle != INVALID_HANDLE) IndicatorRelease(m_ema13Handle);
      if(m_ema50Handle != INVALID_HANDLE) IndicatorRelease(m_ema50Handle);
      if(m_ema200Handle != INVALID_HANDLE) IndicatorRelease(m_ema200Handle);
      if(m_h1Ema13Handle != INVALID_HANDLE) IndicatorRelease(m_h1Ema13Handle);
      if(m_h1Ema50Handle != INVALID_HANDLE) IndicatorRelease(m_h1Ema50Handle);
      if(m_h1Ema200Handle != INVALID_HANDLE) IndicatorRelease(m_h1Ema200Handle);
      if(m_h1Ema800Handle != INVALID_HANDLE) IndicatorRelease(m_h1Ema800Handle);
      if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
   }
   
   bool Initialize(string symbol, ENUM_TIMEFRAMES tf, int gmtOffset = 0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_gmtOffset = gmtOffset;
      
      m_ema5Handle = iMA(m_symbol, m_timeframe, 5, 0, MODE_EMA, PRICE_CLOSE);
      m_ema13Handle = iMA(m_symbol, m_timeframe, 13, 0, MODE_EMA, PRICE_CLOSE);
      m_ema50Handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      
      m_h1Ema13Handle = iMA(m_symbol, PERIOD_H1, 13, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Ema50Handle = iMA(m_symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Ema200Handle = iMA(m_symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_h1Ema800Handle = iMA(m_symbol, PERIOD_H1, 800, 0, MODE_EMA, PRICE_CLOSE);
      m_rsiHandle = iRSI(m_symbol, m_timeframe, 13, PRICE_CLOSE);
      
      if(m_ema5Handle == INVALID_HANDLE || m_ema13Handle == INVALID_HANDLE ||
         m_ema50Handle == INVALID_HANDLE || m_ema200Handle == INVALID_HANDLE)
      {
         Print("MarketMakerAnalysis: Failed to create EMA indicators for ", m_symbol);
         return false;
      }
      
      if(m_h1Ema13Handle == INVALID_HANDLE || m_h1Ema50Handle == INVALID_HANDLE ||
         m_h1Ema200Handle == INVALID_HANDLE || m_h1Ema800Handle == INVALID_HANDLE)
      {
         Print("MarketMakerAnalysis: Failed to create H1 EMA indicators for BeeKay levels on ", m_symbol);
      }
      
      return true;
   }
   
   void Analyze()
   {
      UpdateEMAs();
      CalculateADR();
      UpdateTodayHighLow();
      UpdateAsianSession();
      DetectKillZone();
      DetectStopHunt();
      DetectOrderBlocks();
      DetectLiquidityPools();
      UpdateDayCycle();
      CheckDailyProximity();
      DetectEnhancedMWPatterns();
      DetectPatterns();
      DetectIntradayPhase();
      UpdateBeeKayLevels();
      UpdateCycle3EntryStatus();
      CalculateLevelCycleCoherence();
      CalculateScores();
   }
   
   void SetDailyProximityPips(double pips) { m_dailyProximityPips = pips; }
   void SetMWTolerancePercent(double pct) { m_mwTolerancePercent = pct; }
   
   bool IsCycle3EntryAllowed() { return m_state.isCycle3Entry; }
   bool IsNearDailyHigh() { return m_state.nearDailyHigh; }
   bool IsNearDailyLow() { return m_state.nearDailyLow; }
   MWPatternInfo GetMPatternInfo() { return m_state.mPattern; }
   MWPatternInfo GetWPatternInfo() { return m_state.wPattern; }
   int GetCurrentDayCycle() { return m_currentDayCycle; }
   
   MarketMakerState GetState() { return m_state; }
   double GetTotalScore() { return m_state.totalMMScore; }
   ENUM_MM_PATTERN GetPattern() { return m_state.detectedPattern; }
   ENUM_KILL_ZONE GetKillZone() { return m_state.currentKillZone; }
   bool IsStopHuntDetected() { return m_state.stopHuntDetected; }
   
   BeeKayLevelState GetBeeKayLevelState() { return m_state.beeKayLevel; }
   double GetLevelCycleCoherence() { return m_state.levelCycleCoherence; }
   ENUM_BEEKAY_LEVEL GetCurrentBeeKayLevel() { return m_state.beeKayLevel.currentLevel; }
   bool IsBeeKayResetDetected() { return m_state.beeKayLevel.resetDetected; }
   void ClearBeeKayResetFlag() { m_state.beeKayLevel.resetDetected = false; }
   
   double GetBeeKayLevelBoost()
   {
      switch(m_state.beeKayLevel.currentLevel)
      {
         case BEEKAY_LEVEL_1: return 15.0;
         case BEEKAY_LEVEL_2: return 20.0;
         case BEEKAY_LEVEL_3: return -10.0;
         default: return 0.0;
      }
   }
   
   bool IsLevel3ExitZone()
   {
      return (m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_3 && 
              m_state.beeKayLevel.adrUtilization > 70.0);
   }
   
private:
   void UpdateEMAs()
   {
      CopyBuffer(m_ema5Handle, 0, 0, 50, m_ema5);
      CopyBuffer(m_ema13Handle, 0, 0, 50, m_ema13);
      CopyBuffer(m_ema50Handle, 0, 0, 50, m_ema50);
      CopyBuffer(m_ema200Handle, 0, 0, 50, m_ema200);
      
      if(m_h1Ema13Handle != INVALID_HANDLE)
         CopyBuffer(m_h1Ema13Handle, 0, 0, 50, m_h1Ema13);
      if(m_h1Ema50Handle != INVALID_HANDLE)
         CopyBuffer(m_h1Ema50Handle, 0, 0, 50, m_h1Ema50);
      if(m_h1Ema200Handle != INVALID_HANDLE)
         CopyBuffer(m_h1Ema200Handle, 0, 0, 50, m_h1Ema200);
      if(m_h1Ema800Handle != INVALID_HANDLE)
         CopyBuffer(m_h1Ema800Handle, 0, 0, 50, m_h1Ema800);
         
      if(m_rsiHandle != INVALID_HANDLE)
         CopyBuffer(m_rsiHandle, 0, 0, 50, m_rsiBuffer);
   }
   
   void CalculateADR()
   {
      double totalRange = 0;
      int periods = 14;
      
      for(int i = 1; i <= periods; i++)
      {
         double high = iHigh(m_symbol, PERIOD_D1, i);
         double low = iLow(m_symbol, PERIOD_D1, i);
         totalRange += (high - low);
      }
      
      m_state.adr = totalRange / periods;
      
      double todayRange = m_state.todayHigh - m_state.todayLow;
      m_state.adrUsed = todayRange;
      m_state.adrRemaining = MathMax(0, m_state.adr - todayRange);
   }
   
   void UpdateTodayHighLow()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime todayStart = StringToTime(IntegerToString(dt.year) + "." + 
                                          IntegerToString(dt.mon) + "." + 
                                          IntegerToString(dt.day) + " 00:00");
      
      int bars = Bars(m_symbol, m_timeframe, todayStart, TimeCurrent());
      if(bars <= 0) bars = 1;
      
      double highs[], lows[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, bars, highs);
      CopyLow(m_symbol, m_timeframe, 0, bars, lows);
      
      m_state.todayHigh = highs[ArrayMaximum(highs)];
      m_state.todayLow = lows[ArrayMinimum(lows)];
   }
   
   void UpdateAsianSession()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      datetime asianStart = StringToTime(IntegerToString(dt.year) + "." + 
                                          IntegerToString(dt.mon) + "." + 
                                          IntegerToString(dt.day) + " 00:00");
      datetime asianEnd = asianStart + 8 * 3600;
      
      if(m_lastAsianCalc < asianStart)
      {
         int bars = Bars(m_symbol, m_timeframe, asianStart, asianEnd);
         if(bars > 0)
         {
            double highs[], lows[];
            ArraySetAsSeries(highs, true);
            ArraySetAsSeries(lows, true);
            
            int startShift = iBarShift(m_symbol, m_timeframe, asianEnd);
            if(startShift >= 0)
            {
               CopyHigh(m_symbol, m_timeframe, startShift, bars, highs);
               CopyLow(m_symbol, m_timeframe, startShift, bars, lows);
               
               if(ArraySize(highs) > 0 && ArraySize(lows) > 0)
               {
                  m_asianSessionHigh = highs[ArrayMaximum(highs)];
                  m_asianSessionLow = lows[ArrayMinimum(lows)];
                  m_lastAsianCalc = TimeCurrent();
               }
            }
         }
      }
      
      m_state.asianHigh = m_asianSessionHigh;
      m_state.asianLow = m_asianSessionLow;
   }
   
   void DetectKillZone()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      
      if(hour >= 0 && hour < 8)
         m_state.currentKillZone = KZ_ASIAN;
      else if(hour >= 8 && hour < 12)
         m_state.currentKillZone = KZ_LONDON;
      else if(hour >= 12 && hour < 17)
         m_state.currentKillZone = KZ_LONDON_NYC_OVERLAP;
      else if(hour >= 17 && hour < 21)
         m_state.currentKillZone = KZ_NEW_YORK;
      else
         m_state.currentKillZone = KZ_NONE;
   }
   
   void DetectStopHunt()
   {
      m_state.stopHuntDetected = false;
      
      if(m_state.currentKillZone == KZ_ASIAN) return;
      
      double close[], high[], low[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      CopyClose(m_symbol, m_timeframe, 0, 10, close);
      CopyHigh(m_symbol, m_timeframe, 0, 10, high);
      CopyLow(m_symbol, m_timeframe, 0, 10, low);
      
      if(ArraySize(close) < 5) return;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      if(high[0] > m_state.asianHigh && m_state.asianHigh > 0)
      {
         double breakout = (high[0] - m_state.asianHigh) / pipValue;
         
         if(breakout >= 25 && breakout <= 60)
         {
            if(close[0] < high[0] - 10 * pipValue)
            {
               m_state.stopHuntDetected = true;
               m_state.stopHuntBullish = false;
               m_state.stopHuntMagnitude = breakout;
            }
         }
      }
      
      if(low[0] < m_state.asianLow && m_state.asianLow > 0)
      {
         double breakout = (m_state.asianLow - low[0]) / pipValue;
         
         if(breakout >= 25 && breakout <= 60)
         {
            if(close[0] > low[0] + 10 * pipValue)
            {
               m_state.stopHuntDetected = true;
               m_state.stopHuntBullish = true;
               m_state.stopHuntMagnitude = breakout;
            }
         }
      }
      
      for(int i = 0; i < 3; i++)
      {
         double move = MathAbs(close[i] - close[i+1]) / pipValue;
         if(move > 30)
         {
            bool bullishMove = close[i] > close[i+1];
            
            int reversalCount = 0;
            for(int j = 0; j < i; j++)
            {
               if(bullishMove && close[j] < close[j+1]) reversalCount++;
               if(!bullishMove && close[j] > close[j+1]) reversalCount++;
            }
            
            if(reversalCount >= 1)
            {
               m_state.stopHuntDetected = true;
               m_state.stopHuntBullish = !bullishMove;
               m_state.stopHuntMagnitude = move;
               break;
            }
         }
      }
   }
   
   void DetectOrderBlocks()
   {
      double open[], close[], high[], low[];
      datetime time[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(time, true);
      
      CopyOpen(m_symbol, m_timeframe, 0, 50, open);
      CopyClose(m_symbol, m_timeframe, 0, 50, close);
      CopyHigh(m_symbol, m_timeframe, 0, 50, high);
      CopyLow(m_symbol, m_timeframe, 0, 50, low);
      CopyTime(m_symbol, m_timeframe, 0, 50, time);
      
      if(ArraySize(close) < 30) return;
      
      m_orderBlockCount = 0;
      
      for(int i = 5; i < 45 && m_orderBlockCount < 10; i++)
      {
         bool isBullishOB = false;
         bool isBearishOB = false;
         
         if(close[i] < open[i])
         {
            bool followedByBullish = true;
            for(int j = i-1; j >= i-3 && j >= 0; j--)
            {
               if(close[j] <= open[j]) followedByBullish = false;
            }
            
            if(followedByBullish && high[i-1] > high[i])
            {
               isBullishOB = true;
            }
         }
         
         if(close[i] > open[i])
         {
            bool followedByBearish = true;
            for(int j = i-1; j >= i-3 && j >= 0; j--)
            {
               if(close[j] >= open[j]) followedByBearish = false;
            }
            
            if(followedByBearish && low[i-1] < low[i])
            {
               isBearishOB = true;
            }
         }
         
         if(isBullishOB || isBearishOB)
         {
            m_orderBlocks[m_orderBlockCount].priceHigh = high[i];
            m_orderBlocks[m_orderBlockCount].priceLow = low[i];
            m_orderBlocks[m_orderBlockCount].time = time[i];
            m_orderBlocks[m_orderBlockCount].isBullish = isBullishOB;
            m_orderBlocks[m_orderBlockCount].isValid = true;
            m_orderBlocks[m_orderBlockCount].touches = 0;
            m_orderBlockCount++;
         }
      }
   }
   
   void DetectLiquidityPools()
   {
      double high[], low[];
      datetime time[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(time, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, 100, high);
      CopyLow(m_symbol, m_timeframe, 0, 100, low);
      CopyTime(m_symbol, m_timeframe, 0, 100, time);
      
      if(ArraySize(high) < 50) return;
      
      m_liquidityPoolCount = 0;
      
      for(int i = 10; i < 90 && m_liquidityPoolCount < 20; i++)
      {
         int touchesHigh = 0;
         int touchesLow = 0;
         double threshold = 5 * SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10;
         
         for(int j = i - 10; j <= i + 10 && j < ArraySize(high); j++)
         {
            if(j == i || j < 0) continue;
            
            if(MathAbs(high[j] - high[i]) < threshold) touchesHigh++;
            if(MathAbs(low[j] - low[i]) < threshold) touchesLow++;
         }
         
         if(touchesHigh >= 3)
         {
            m_liquidityPools[m_liquidityPoolCount].price = high[i];
            m_liquidityPools[m_liquidityPoolCount].time = time[i];
            m_liquidityPools[m_liquidityPoolCount].isHighLiquidity = true;
            m_liquidityPools[m_liquidityPoolCount].wasSwept = false;
            m_liquidityPools[m_liquidityPoolCount].stopCount = touchesHigh;
            m_liquidityPoolCount++;
         }
         
         if(touchesLow >= 3 && m_liquidityPoolCount < 20)
         {
            m_liquidityPools[m_liquidityPoolCount].price = low[i];
            m_liquidityPools[m_liquidityPoolCount].time = time[i];
            m_liquidityPools[m_liquidityPoolCount].isHighLiquidity = false;
            m_liquidityPools[m_liquidityPoolCount].wasSwept = false;
            m_liquidityPools[m_liquidityPoolCount].stopCount = touchesLow;
            m_liquidityPoolCount++;
         }
      }
   }
   
   void DetectPatterns()
   {
      m_state.detectedPattern = MM_PATTERN_NONE;
      
      if(DetectMPattern())
      {
         m_state.detectedPattern = MM_PATTERN_M_TOP;
         return;
      }
      
      if(DetectWPattern())
      {
         m_state.detectedPattern = MM_PATTERN_W_BOTTOM;
         return;
      }
      
      if(DetectRRT())
      {
         m_state.detectedPattern = MM_PATTERN_RRT;
         return;
      }
      
      if(DetectHalfBatman())
      {
         m_state.detectedPattern = MM_PATTERN_HALF_BATMAN;
         return;
      }
   }
   
   bool DetectMPattern()
   {
      double high[], low[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, 30, high);
      CopyLow(m_symbol, m_timeframe, 0, 30, low);
      CopyClose(m_symbol, m_timeframe, 0, 30, close);
      
      if(ArraySize(high) < 25) return false;
      
      double threshold = 10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10;
      
      int peak1 = -1, peak2 = -1, valley = -1;
      
      for(int i = 5; i < 20; i++)
      {
         if(high[i] > high[i-1] && high[i] > high[i+1] &&
            high[i] > high[i-2] && high[i] > high[i+2])
         {
            if(peak1 < 0)
               peak1 = i;
            else if(peak2 < 0 && MathAbs(high[i] - high[peak1]) < threshold)
            {
               peak2 = i;
               break;
            }
         }
      }
      
      if(peak1 > 0 && peak2 > 0)
      {
         for(int i = peak1 + 1; i < peak2; i++)
         {
            if(low[i] < low[i-1] && low[i] < low[i+1])
            {
               valley = i;
               break;
            }
         }
         
         if(valley > 0)
         {
            double neckline = low[valley];
            if(close[0] < neckline && close[1] > neckline)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   bool DetectWPattern()
   {
      double high[], low[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, 30, high);
      CopyLow(m_symbol, m_timeframe, 0, 30, low);
      CopyClose(m_symbol, m_timeframe, 0, 30, close);
      
      if(ArraySize(low) < 25) return false;
      
      double threshold = 10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10;
      
      int trough1 = -1, trough2 = -1, peak = -1;
      
      for(int i = 5; i < 20; i++)
      {
         if(low[i] < low[i-1] && low[i] < low[i+1] &&
            low[i] < low[i-2] && low[i] < low[i+2])
         {
            if(trough1 < 0)
               trough1 = i;
            else if(trough2 < 0 && MathAbs(low[i] - low[trough1]) < threshold)
            {
               trough2 = i;
               break;
            }
         }
      }
      
      if(trough1 > 0 && trough2 > 0)
      {
         for(int i = trough1 + 1; i < trough2; i++)
         {
            if(high[i] > high[i-1] && high[i] > high[i+1])
            {
               peak = i;
               break;
            }
         }
         
         if(peak > 0)
         {
            double neckline = high[peak];
            if(close[0] > neckline && close[1] < neckline)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   bool DetectRRT()
   {
      double open[], close[], high[], low[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      CopyOpen(m_symbol, m_timeframe, 0, 5, open);
      CopyClose(m_symbol, m_timeframe, 0, 5, close);
      CopyHigh(m_symbol, m_timeframe, 0, 5, high);
      CopyLow(m_symbol, m_timeframe, 0, 5, low);
      
      if(ArraySize(close) < 3) return false;
      
      double body1 = MathAbs(close[1] - open[1]);
      double body2 = MathAbs(close[2] - open[2]);
      double avgBody = (body1 + body2) / 2;
      
      double minBody = 15 * SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10;
      
      if(body1 > minBody && body2 > minBody)
      {
         bool candle1Bullish = close[1] > open[1];
         bool candle2Bullish = close[2] > open[2];
         
         if(candle1Bullish != candle2Bullish)
         {
            double overlap = MathMin(high[1], high[2]) - MathMax(low[1], low[2]);
            if(overlap > 0)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   
   bool DetectHalfBatman()
   {
      if(!m_state.stopHuntDetected) return false;
      
      double close[];
      ArraySetAsSeries(close, true);
      CopyClose(m_symbol, m_timeframe, 0, 10, close);
      
      if(ArraySize(close) < 8) return false;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      double retracement = MathAbs(close[0] - close[3]) / pipValue;
      
      if(retracement < m_state.stopHuntMagnitude * 0.382 && retracement > 10)
      {
         return true;
      }
      
      return false;
   }
   
   void CheckDailyProximity()
   {
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      double distToHigh = (m_state.todayHigh - currentPrice) / pipValue;
      double distToLow = (currentPrice - m_state.todayLow) / pipValue;
      
      m_state.nearDailyHigh = (distToHigh >= 0 && distToHigh <= m_dailyProximityPips);
      m_state.nearDailyLow = (distToLow >= 0 && distToLow <= m_dailyProximityPips);
   }
   
   void DetectEnhancedMWPatterns()
   {
      ZeroMemory(m_state.mPattern);
      ZeroMemory(m_state.wPattern);
      
      double high[], low[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      
      CopyHigh(m_symbol, m_timeframe, 0, 50, high);
      CopyLow(m_symbol, m_timeframe, 0, 50, low);
      CopyClose(m_symbol, m_timeframe, 0, 50, close);
      
      if(ArraySize(high) < 40) return;
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      if(m_state.nearDailyHigh)
         DetectMPatternEnhanced(high, low, close, pipValue);
      
      if(m_state.nearDailyLow)
         DetectWPatternEnhanced(high, low, close, pipValue);
   }
   
   void DetectMPatternEnhanced(double &high[], double &low[], double &close[], double pipValue)
   {
      int peak1 = -1, peak2 = -1, valley = -1;
      double tolerance = m_state.todayHigh * m_mwTolerancePercent;
      
      for(int i = 3; i < 35; i++)
      {
         if(high[i] > high[i-1] && high[i] > high[i+1] &&
            high[i] > high[i-2] && high[i] > high[i+2])
         {
            if(peak1 < 0)
            {
               peak1 = i;
            }
            else if(peak2 < 0 && MathAbs(high[i] - high[peak1]) < tolerance)
            {
               peak2 = i;
               break;
            }
         }
      }
      
      if(peak1 < 0 || peak2 < 0) return;
      
      for(int i = peak1 + 1; i < peak2; i++)
      {
         if(low[i] < low[i-1] && low[i] < low[i+1])
         {
            valley = i;
            break;
         }
      }
      
      if(valley < 0) return;
      
      double distFromHigh = (m_state.todayHigh - MathMax(high[peak1], high[peak2])) / pipValue;
      if(MathAbs(distFromHigh) > m_dailyProximityPips) return;
      
      m_state.mPattern.detected = true;
      m_state.mPattern.peak1Price = high[peak2];
      m_state.mPattern.peak2Price = high[peak1];
      m_state.mPattern.valleyPrice = low[valley];
      m_state.mPattern.neckline = low[valley];
      m_state.mPattern.peak1Index = peak2;
      m_state.mPattern.peak2Index = peak1;
      m_state.mPattern.valleyIndex = valley;
      m_state.mPattern.distanceFromExtreme = MathAbs(distFromHigh);
      
      m_state.mPattern.isSecondLeg = (peak1 <= 5);
      
      double neckBreak = (m_state.mPattern.neckline - close[0]) / pipValue;
      double baseConfidence = 55.0;
      
      if(m_state.mPattern.isSecondLeg)
      {
         baseConfidence = 70.0;
         
         // RSI Confirmation (Precision Improvement)
         if(ArraySize(m_rsiBuffer) > peak2)
         {
            double rsiRight = m_rsiBuffer[peak1]; // Recent peak
            double rsiLeft = m_rsiBuffer[peak2];  // Older peak
            
            // Overbought condition
            if(rsiRight > 65.0) baseConfidence += 5.0;
            if(rsiRight > 70.0) baseConfidence += 5.0;
            
            // Divergence: Price Higher/Equal but RSI Lower
            if(high[peak1] >= high[peak2] && rsiRight < rsiLeft)
            {
               baseConfidence += 15.0;
            }
            // Regular divergence: Price Lower but RSI significantly Lower
            else if(rsiRight < rsiLeft - 5.0)
            {
               baseConfidence += 5.0;
            }
         }
      }
      
      if(neckBreak > 0)
         baseConfidence += MathMin(10.0, neckBreak);
         
      m_state.mPattern.confidence = MathMin(95.0, baseConfidence);
   }
   
   void DetectWPatternEnhanced(double &high[], double &low[], double &close[], double pipValue)
   {
      int trough1 = -1, trough2 = -1, peak = -1;
      double tolerance = m_state.todayLow * m_mwTolerancePercent;
      
      for(int i = 3; i < 35; i++)
      {
         if(low[i] < low[i-1] && low[i] < low[i+1] &&
            low[i] < low[i-2] && low[i] < low[i+2])
         {
            if(trough1 < 0)
            {
               trough1 = i;
            }
            else if(trough2 < 0 && MathAbs(low[i] - low[trough1]) < tolerance)
            {
               trough2 = i;
               break;
            }
         }
      }
      
      if(trough1 < 0 || trough2 < 0) return;
      
      for(int i = trough1 + 1; i < trough2; i++)
      {
         if(high[i] > high[i-1] && high[i] > high[i+1])
         {
            peak = i;
            break;
         }
      }
      
      if(peak < 0) return;
      
      double distFromLow = (MathMin(low[trough1], low[trough2]) - m_state.todayLow) / pipValue;
      if(MathAbs(distFromLow) > m_dailyProximityPips) return;
      
      m_state.wPattern.detected = true;
      m_state.wPattern.peak1Price = low[trough2];
      m_state.wPattern.peak2Price = low[trough1];
      m_state.wPattern.valleyPrice = high[peak];
      m_state.wPattern.neckline = high[peak];
      m_state.wPattern.peak1Index = trough2;
      m_state.wPattern.peak2Index = trough1;
      m_state.wPattern.valleyIndex = peak;
      m_state.wPattern.distanceFromExtreme = MathAbs(distFromLow);
      
      m_state.wPattern.isSecondLeg = (trough1 <= 5);
      
      double neckBreak = (close[0] - m_state.wPattern.neckline) / pipValue;
      double baseConfidence = 55.0;
      
      if(m_state.wPattern.isSecondLeg)
      {
         baseConfidence = 70.0;
         
         // RSI Confirmation (Precision Improvement)
         if(ArraySize(m_rsiBuffer) > trough2)
         {
            double rsiRight = m_rsiBuffer[trough1]; // Recent trough
            double rsiLeft = m_rsiBuffer[trough2];  // Older trough
            
            // Oversold condition
            if(rsiRight < 35.0) baseConfidence += 5.0;
            if(rsiRight < 30.0) baseConfidence += 5.0;
            
            // Divergence: Price Lower/Equal but RSI Higher
            if(low[trough1] <= low[trough2] && rsiRight > rsiLeft)
            {
               baseConfidence += 15.0;
            }
            // Regular divergence
            else if(rsiRight > rsiLeft + 5.0)
            {
               baseConfidence += 5.0;
            }
         }
      }
      
      if(neckBreak > 0)
         baseConfidence += MathMin(10.0, neckBreak);
         
      m_state.wPattern.confidence = MathMin(95.0, baseConfidence);
   }
   
   void UpdateCycle3EntryStatus()
   {
      m_state.isCycle3Entry = false;
      
      if(m_state.dayCycle != DAY_CYCLE_3) return;
      
      if(m_state.currentKillZone == KZ_ASIAN || m_state.currentKillZone == KZ_NONE) return;
      
      bool hasValidMPattern = m_state.mPattern.detected && 
                               m_state.mPattern.isSecondLeg && 
                               m_state.nearDailyHigh &&
                               m_state.mPattern.confidence >= 70.0;
      
      bool hasValidWPattern = m_state.wPattern.detected && 
                               m_state.wPattern.isSecondLeg && 
                               m_state.nearDailyLow &&
                               m_state.wPattern.confidence >= 70.0;
      
      if(hasValidMPattern || hasValidWPattern)
      {
         m_state.isCycle3Entry = true;
      }
   }
   
   void UpdateDayCycle()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      datetime today = StringToTime(IntegerToString(dt.year) + "." + 
                                     IntegerToString(dt.mon) + "." + 
                                     IntegerToString(dt.day));
      
      if(m_cycleStartDate == 0)
      {
         m_cycleStartDate = today;
         m_currentDayCycle = 1;
      }
      else
      {
         int daysDiff = (int)((today - m_cycleStartDate) / 86400);
         m_currentDayCycle = (daysDiff % 3) + 1;
      }
      
      switch(m_currentDayCycle)
      {
         case 1: m_state.dayCycle = DAY_CYCLE_1; break;
         case 2: m_state.dayCycle = DAY_CYCLE_2; break;
         case 3: m_state.dayCycle = DAY_CYCLE_3; break;
         default: m_state.dayCycle = DAY_CYCLE_1; break;
      }
   }
   
   void DetectIntradayPhase()
   {
      if(m_state.currentKillZone == KZ_ASIAN)
      {
         m_state.intradayPhase = MM_PHASE_ACCUMULATION;
      }
      else if(m_state.stopHuntDetected)
      {
         m_state.intradayPhase = MM_PHASE_STOP_HUNT;
      }
      else if(m_state.currentKillZone == KZ_LONDON || 
              m_state.currentKillZone == KZ_LONDON_NYC_OVERLAP)
      {
         if(m_state.detectedPattern != MM_PATTERN_NONE)
            m_state.intradayPhase = MM_PHASE_TRUE_TREND;
         else
            m_state.intradayPhase = MM_PHASE_STOP_HUNT;
      }
      else if(m_state.currentKillZone == KZ_NEW_YORK)
      {
         if(m_state.adrUsed > m_state.adr * 0.8)
            m_state.intradayPhase = MM_PHASE_DISTRIBUTION;
         else
            m_state.intradayPhase = MM_PHASE_TRUE_TREND;
      }
      else
      {
         m_state.intradayPhase = MM_PHASE_UNKNOWN;
      }
   }
   
   void CalculateScores()
   {
      m_state.killZoneScore = CalculateKillZoneScore();
      m_state.patternScore = CalculatePatternScore();
      m_state.orderBlockScore = CalculateOrderBlockScore();
      m_state.liquidityScore = CalculateLiquidityScore();
      m_state.cycleScore = CalculateCycleScore();
      
      m_state.totalMMScore = (m_state.killZoneScore * 0.20 +
                              m_state.patternScore * 0.30 +
                              m_state.orderBlockScore * 0.20 +
                              m_state.liquidityScore * 0.15 +
                              m_state.cycleScore * 0.15);
   }
   
   double CalculateKillZoneScore()
   {
      switch(m_state.currentKillZone)
      {
         case KZ_LONDON_NYC_OVERLAP: return 100.0;
         case KZ_LONDON: return 85.0;
         case KZ_NEW_YORK: return 75.0;
         case KZ_ASIAN: return 30.0;
         default: return 20.0;
      }
   }
   
   double CalculatePatternScore()
   {
      double score = 0;
      
      switch(m_state.detectedPattern)
      {
         case MM_PATTERN_M_TOP:
            score = 90.0;
            if(m_state.mPattern.detected) score = MathMax(score, m_state.mPattern.confidence);
            break;
         case MM_PATTERN_W_BOTTOM:
            score = 90.0;
            if(m_state.wPattern.detected) score = MathMax(score, m_state.wPattern.confidence);
            break;
         case MM_PATTERN_RRT:
            score = 80.0;
            break;
         case MM_PATTERN_HALF_BATMAN:
            score = 70.0;
            break;
         case MM_PATTERN_SHARK_FIN:
            score = 75.0;
            break;
         default:
            score = 30.0;
            break;
      }
      
      if(m_state.stopHuntDetected)
         score += 10.0;
      
      return MathMin(100.0, score);
   }
   
   double CalculateOrderBlockScore()
   {
      if(m_orderBlockCount == 0) return 30.0;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double closestDistance = DBL_MAX;
      bool inOrderBlock = false;
      
      for(int i = 0; i < m_orderBlockCount; i++)
      {
         if(!m_orderBlocks[i].isValid) continue;
         
         if(currentPrice >= m_orderBlocks[i].priceLow && 
            currentPrice <= m_orderBlocks[i].priceHigh)
         {
            inOrderBlock = true;
            break;
         }
         
         double dist = MathMin(MathAbs(currentPrice - m_orderBlocks[i].priceHigh),
                               MathAbs(currentPrice - m_orderBlocks[i].priceLow));
         if(dist < closestDistance)
            closestDistance = dist;
      }
      
      if(inOrderBlock) return 95.0;
      
      double pipDistance = closestDistance / (SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10);
      
      if(pipDistance < 10) return 80.0;
      if(pipDistance < 20) return 60.0;
      if(pipDistance < 30) return 45.0;
      
      return 30.0;
   }
   
   double CalculateLiquidityScore()
   {
      if(m_liquidityPoolCount == 0) return 30.0;
      
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double pipValue = point * 10;
      
      double nearestLiquidityDistance = DBL_MAX;
      int highestStopCount = 0;
      
      for(int i = 0; i < m_liquidityPoolCount; i++)
      {
         double dist = MathAbs(currentPrice - m_liquidityPools[i].price) / pipValue;
         
         if(dist < nearestLiquidityDistance)
         {
            nearestLiquidityDistance = dist;
            highestStopCount = m_liquidityPools[i].stopCount;
         }
      }
      
      double score = 30.0;
      
      if(nearestLiquidityDistance < 15)
         score = 85.0;
      else if(nearestLiquidityDistance < 25)
         score = 70.0;
      else if(nearestLiquidityDistance < 40)
         score = 55.0;
      
      score += MathMin(15.0, highestStopCount * 3.0);
      
      return MathMin(100.0, score);
   }
   
   double CalculateCycleScore()
   {
      double score = 50.0;
      
      switch(m_state.dayCycle)
      {
         case DAY_CYCLE_1:
            if(m_state.intradayPhase == MM_PHASE_TRUE_TREND)
               score = 85.0;
            else
               score = 60.0;
            break;
            
         case DAY_CYCLE_2:
            score = 70.0;
            break;
            
         case DAY_CYCLE_3:
            if(m_state.intradayPhase == MM_PHASE_TRUE_TREND)
               score = 95.0;
            else
               score = 75.0;
            break;
      }
      
      if(m_state.intradayPhase == MM_PHASE_TRUE_TREND && m_state.stopHuntDetected)
         score += 10.0;
      
      return MathMin(100.0, score);
   }
   
public:
   bool IsOptimalEntry()
   {
      if(m_state.totalMMScore < 70.0) return false;
      
      if(m_state.currentKillZone == KZ_ASIAN) return false;
      if(m_state.currentKillZone == KZ_NONE) return false;
      
      if(m_state.isCycle3Entry) return true;
      
      if(m_state.intradayPhase != MM_PHASE_TRUE_TREND) return false;
      
      if(m_state.detectedPattern == MM_PATTERN_NONE) return false;
      
      return true;
   }
   
   bool IsCycle3OptimalEntry()
   {
      if(!m_state.isCycle3Entry) return false;
      if(m_state.totalMMScore < 75.0) return false;
      return true;
   }
   
   ENUM_SIGNAL_TYPE GetMMSignal()
   {
      if(m_state.isCycle3Entry)
      {
         if(m_state.mPattern.detected && m_state.mPattern.isSecondLeg && m_state.nearDailyHigh)
            return SIGNAL_STRONG_SELL;
         
         if(m_state.wPattern.detected && m_state.wPattern.isSecondLeg && m_state.nearDailyLow)
            return SIGNAL_STRONG_BUY;
      }
      
      if(!IsOptimalEntry()) return SIGNAL_NEUTRAL;
      
      if(m_state.detectedPattern == MM_PATTERN_W_BOTTOM ||
         (m_state.stopHuntDetected && m_state.stopHuntBullish))
      {
         return SIGNAL_BUY;
      }
      
      if(m_state.detectedPattern == MM_PATTERN_M_TOP ||
         (m_state.stopHuntDetected && !m_state.stopHuntBullish))
      {
         return SIGNAL_SELL;
      }
      
      return SIGNAL_NEUTRAL;
   }
   
   double GetMWPatternConfidence()
   {
      if(m_state.mPattern.detected && m_state.mPattern.isSecondLeg)
         return m_state.mPattern.confidence;
      if(m_state.wPattern.detected && m_state.wPattern.isSecondLeg)
         return m_state.wPattern.confidence;
      return 0.0;
   }
   
   double GetPatternTargetPrice()
   {
      if(m_state.mPattern.detected && m_state.mPattern.isSecondLeg)
      {
         double height = MathMax(m_state.mPattern.peak1Price, m_state.mPattern.peak2Price) - m_state.mPattern.neckline;
         return m_state.mPattern.neckline - height; // Projected target
      }
      if(m_state.wPattern.detected && m_state.wPattern.isSecondLeg)
      {
         double height = m_state.wPattern.neckline - MathMin(m_state.wPattern.peak1Price, m_state.wPattern.peak2Price);
         return m_state.wPattern.neckline + height; // Projected target
      }
      return 0.0;
   }
   
   double GetEMA5() { return (ArraySize(m_ema5) > 0) ? m_ema5[0] : 0; }
   double GetEMA13() { return (ArraySize(m_ema13) > 0) ? m_ema13[0] : 0; }
   double GetEMA50() { return (ArraySize(m_ema50) > 0) ? m_ema50[0] : 0; }
   double GetEMA200() { return (ArraySize(m_ema200) > 0) ? m_ema200[0] : 0; }
   
   bool IsEMACrossBullish()
   {
      if(ArraySize(m_ema5) < 2 || ArraySize(m_ema13) < 2) return false;
      return (m_ema5[0] > m_ema13[0] && m_ema5[1] <= m_ema13[1]);
   }
   
   bool IsEMACrossBearish()
   {
      if(ArraySize(m_ema5) < 2 || ArraySize(m_ema13) < 2) return false;
      return (m_ema5[0] < m_ema13[0] && m_ema5[1] >= m_ema13[1]);
   }
   
   string GetStatusString()
   {
      string status = "";
      
      status += "KillZone: ";
      switch(m_state.currentKillZone)
      {
         case KZ_ASIAN: status += "Asian"; break;
         case KZ_LONDON: status += "London"; break;
         case KZ_LONDON_NYC_OVERLAP: status += "LDN/NYC"; break;
         case KZ_NEW_YORK: status += "NYC"; break;
         default: status += "None"; break;
      }
      
      status += " | Phase: ";
      switch(m_state.intradayPhase)
      {
         case MM_PHASE_ACCUMULATION: status += "Accum"; break;
         case MM_PHASE_STOP_HUNT: status += "StopHunt"; break;
         case MM_PHASE_TRUE_TREND: status += "TrueTrend"; break;
         case MM_PHASE_DISTRIBUTION: status += "Distrib"; break;
         default: status += "Unknown"; break;
      }
      
      status += " | Day: " + IntegerToString(m_currentDayCycle) + "/3";
      
      status += " | Pattern: ";
      switch(m_state.detectedPattern)
      {
         case MM_PATTERN_M_TOP: status += "M-Top"; break;
         case MM_PATTERN_W_BOTTOM: status += "W-Bottom"; break;
         case MM_PATTERN_RRT: status += "RRT"; break;
         case MM_PATTERN_HALF_BATMAN: status += "HalfBat"; break;
         default: status += "None"; break;
      }
      
      status += " | Score: " + DoubleToString(m_state.totalMMScore, 1) + "%";
      
      if(m_state.stopHuntDetected)
         status += " [STOP HUNT " + DoubleToString(m_state.stopHuntMagnitude, 0) + "p]";
      
      return status;
   }
   
   void GetNeuralInputs(double &inputs[])
   {
      ArrayResize(inputs, 15);
      
      inputs[0] = m_state.killZoneScore / 100.0;
      inputs[1] = m_state.patternScore / 100.0;
      inputs[2] = m_state.orderBlockScore / 100.0;
      inputs[3] = m_state.liquidityScore / 100.0;
      inputs[4] = m_state.cycleScore / 100.0;
      
      inputs[5] = m_state.stopHuntDetected ? 1.0 : 0.0;
      inputs[6] = m_state.stopHuntBullish ? 1.0 : (m_state.stopHuntDetected ? -1.0 : 0.0);
      inputs[7] = MathMin(1.0, m_state.stopHuntMagnitude / 50.0);
      
      inputs[8] = (double)m_state.intradayPhase / 4.0;
      inputs[9] = (double)m_state.dayCycle / 3.0;
      
      inputs[10] = MathMin(1.0, m_state.adrUsed / m_state.adr);
      
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      inputs[11] = (price > GetEMA50()) ? 1.0 : -1.0;
      inputs[12] = (price > GetEMA200()) ? 1.0 : -1.0;
      inputs[13] = (GetEMA50() > GetEMA200()) ? 1.0 : -1.0;
      inputs[14] = IsEMACrossBullish() ? 1.0 : (IsEMACrossBearish() ? -1.0 : 0.0);
   }
   
   void UpdateBeeKayLevels()
   {
      if(ArraySize(m_h1Ema13) < 5 || ArraySize(m_h1Ema50) < 5 ||
         ArraySize(m_h1Ema200) < 5 || ArraySize(m_h1Ema800) < 5)
         return;
      
      bool cross13_50_bull = (m_h1Ema13[1] <= m_h1Ema50[1] && m_h1Ema13[0] > m_h1Ema50[0]);
      bool cross13_50_bear = (m_h1Ema13[1] >= m_h1Ema50[1] && m_h1Ema13[0] < m_h1Ema50[0]);
      bool cross50_200_bull = (m_h1Ema50[1] <= m_h1Ema200[1] && m_h1Ema50[0] > m_h1Ema200[0]);
      bool cross50_200_bear = (m_h1Ema50[1] >= m_h1Ema200[1] && m_h1Ema50[0] < m_h1Ema200[0]);
      bool cross50_800_bull = (m_h1Ema50[1] <= m_h1Ema800[1] && m_h1Ema50[0] > m_h1Ema800[0]);
      bool cross50_800_bear = (m_h1Ema50[1] >= m_h1Ema800[1] && m_h1Ema50[0] < m_h1Ema800[0]);
      bool cross200_800_bull = (m_h1Ema200[1] <= m_h1Ema800[1] && m_h1Ema200[0] > m_h1Ema800[0]);
      bool cross200_800_bear = (m_h1Ema200[1] >= m_h1Ema800[1] && m_h1Ema200[0] < m_h1Ema800[0]);
      
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double prevSwingHigh = m_state.beeKayLevel.lastSwingHigh;
      double prevSwingLow = m_state.beeKayLevel.lastSwingLow;
      
      if(m_state.beeKayLevel.lastSwingHigh == 0)
         m_state.beeKayLevel.lastSwingHigh = m_state.todayHigh;
      if(m_state.beeKayLevel.lastSwingLow == 0 || m_state.beeKayLevel.lastSwingLow > m_state.todayLow)
         m_state.beeKayLevel.lastSwingLow = m_state.todayLow;
      
      bool swingBrokenHigh = (prevSwingHigh > 0 && price > prevSwingHigh);
      bool swingBrokenLow = (prevSwingLow > 0 && price < prevSwingLow);
      
      if(swingBrokenHigh)
         m_state.beeKayLevel.lastSwingHigh = m_state.todayHigh;
      if(swingBrokenLow)
         m_state.beeKayLevel.lastSwingLow = m_state.todayLow;
      
      m_state.beeKayLevel.swingBroken = (m_state.beeKayLevel.isBullish && swingBrokenHigh) ||
                                         (!m_state.beeKayLevel.isBullish && swingBrokenLow);
      
      if(cross13_50_bull || cross13_50_bear)
      {
         if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_0 ||
            (cross13_50_bull != m_state.beeKayLevel.isBullish))
         {
            m_state.beeKayLevel.currentLevel = BEEKAY_LEVEL_1;
            m_state.beeKayLevel.isBullish = cross13_50_bull;
            m_state.beeKayLevel.lastCrossType = EMA_CROSS_13_50;
            m_state.beeKayLevel.levelStartPrice = price;
            m_state.beeKayLevel.levelStartTime = TimeCurrent();
            m_state.beeKayLevel.consecutiveLevels = 1;
            m_state.beeKayLevel.resetDetected = false;
            m_state.beeKayLevel.levelConfidence = 70.0;
         }
      }
      
      if(cross50_200_bull || cross50_200_bear)
      {
         bool sameDirection = (cross50_200_bull == m_state.beeKayLevel.isBullish);
         if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_1 && sameDirection && m_state.beeKayLevel.swingBroken)
         {
            m_state.beeKayLevel.currentLevel = BEEKAY_LEVEL_2;
            m_state.beeKayLevel.lastCrossType = EMA_CROSS_50_200;
            m_state.beeKayLevel.consecutiveLevels = 2;
            m_state.beeKayLevel.levelConfidence = 80.0;
         }
      }
      
      if(cross50_800_bull || cross50_800_bear || cross200_800_bull || cross200_800_bear)
      {
         bool cross800Bull = cross50_800_bull || cross200_800_bull;
         bool cross800Bear = cross50_800_bear || cross200_800_bear;
         bool sameDirection = ((cross800Bull && m_state.beeKayLevel.isBullish) ||
                               (cross800Bear && !m_state.beeKayLevel.isBullish));
         
         if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_2 && sameDirection && m_state.beeKayLevel.swingBroken)
         {
            m_state.beeKayLevel.currentLevel = BEEKAY_LEVEL_3;
            m_state.beeKayLevel.lastCrossType = cross50_800_bull || cross50_800_bear ? EMA_CROSS_50_800 : EMA_CROSS_200_800;
            m_state.beeKayLevel.consecutiveLevels = 3;
            m_state.beeKayLevel.levelConfidence = 60.0;
         }
      }
      
      double emaSpread = MathAbs(m_h1Ema50[0] - m_h1Ema200[0]) / m_h1Ema200[0] * 100;
      bool emasFannedOut = (emaSpread > 0.5);
      
      if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_3 && emasFannedOut)
      {
         m_state.beeKayLevel.levelConfidence = MathMax(40.0, m_state.beeKayLevel.levelConfidence - 10.0);
      }
      
      if(m_state.adr > 0)
         m_state.beeKayLevel.adrUtilization = m_state.adrUsed / m_state.adr * 100.0;
   }
   
   void DetectBeeKayReset(bool tdiMayoPattern, bool tdiBlueberryPattern)
   {
      m_state.beeKayLevel.mayoPattern = tdiMayoPattern;
      m_state.beeKayLevel.blueberryPattern = tdiBlueberryPattern;
      
      if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_3)
      {
         if(tdiMayoPattern || tdiBlueberryPattern)
         {
            bool priceRetested = false;
            double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            
            if(m_state.beeKayLevel.isBullish)
            {
               priceRetested = (price <= m_h1Ema50[0] && price >= m_h1Ema200[0]);
            }
            else
            {
               priceRetested = (price >= m_h1Ema50[0] && price <= m_h1Ema200[0]);
            }
            
            if(priceRetested)
            {
               m_state.beeKayLevel.resetDetected = true;
               m_state.beeKayLevel.currentLevel = BEEKAY_LEVEL_0;
               m_state.beeKayLevel.consecutiveLevels = 0;
               m_state.beeKayLevel.levelConfidence = 75.0;
               m_state.beeKayLevel.lastSwingHigh = 0;
               m_state.beeKayLevel.lastSwingLow = 0;
            }
         }
      }
   }
   
   void CalculateLevelCycleCoherence()
   {
      double coherence = 0.0;
      
      int levelNum = (int)m_state.beeKayLevel.currentLevel;
      int cycleNum = m_currentDayCycle;
      
      if(levelNum == cycleNum)
      {
         coherence = 100.0;
      }
      else if(MathAbs(levelNum - cycleNum) == 1)
      {
         coherence = 75.0;
      }
      else
      {
         coherence = 50.0;
      }
      
      if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_1 && m_currentDayCycle == 1)
      {
         coherence = 100.0;
      }
      else if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_2 && m_currentDayCycle == 2)
      {
         coherence = 100.0;
      }
      else if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_3 && m_currentDayCycle == 3)
      {
         coherence = 100.0;
      }
      
      if(m_state.beeKayLevel.currentLevel == BEEKAY_LEVEL_3)
      {
         coherence = coherence * 0.6;
      }
      
      if(m_state.beeKayLevel.resetDetected)
      {
         coherence = 85.0;
      }
      
      m_state.levelCycleCoherence = coherence;
   }
};
