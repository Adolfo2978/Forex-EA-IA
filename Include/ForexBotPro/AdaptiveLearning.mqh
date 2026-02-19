//+------------------------------------------------------------------+
//|                                           AdaptiveLearning.mqh  |
//|                              Forex Bot Pro v7.0 - Auto Learning  |
//|                              Sistema de Aprendizaje Adaptativo   |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

#define MAX_REFERENCE_PATTERNS 100
#define WINS_PER_SNAPSHOT 5
#define MAX_TRADE_HISTORY 500

struct TradeFeatureSnapshot
{
   string symbol;
   datetime entryTime;
   datetime exitTime;
   ENUM_SIGNAL_TYPE signal;
   double entryPrice;
   double exitPrice;
   double profitPips;
   bool isWin;
   
   double iaScore;
   double technicalScore;
   double alignmentScore;
   double combinedScore;
   
   double tdiRSI;
   double tdiSignal;
   string tdiStatus;
   
   double ema21;
   double ema50;
   double ema200;
   string emaAlignment;
   
   string candlePattern;
   string chartPattern;
   
   bool mtfAligned;
   string trendDirection;
   
   double spreadPips;
   double volatility;
};

struct ReferencePattern
{
   int patternId;
   int tradeCount;
   double winRate;
   datetime lastUpdate;
   
   double avgIAScore;
   double avgTechnicalScore;
   double avgAlignmentScore;
   double avgCombinedScore;
   
   double minIAScore;
   double maxIAScore;
   double minTechnicalScore;
   double maxTechnicalScore;
   double minAlignmentScore;
   double maxAlignmentScore;
   
   double avgTDI_RSI;
   double avgTDI_Signal;
   
   string preferredEMAAlignment;
   string preferredTrend;
   bool requiresMTF;
   
   ENUM_SIGNAL_TYPE signalType;
   string symbol;
   
   double successConfidence;
};

class CAdaptiveLearning
{
private:
   TradeFeatureSnapshot m_tradeHistory[];
   int m_historyCount;
   
   ReferencePattern m_referencePatterns[];
   int m_patternCount;
   
   int m_consecutiveWins;
   int m_totalWins;
   int m_totalLosses;
   
   TradeFeatureSnapshot m_recentWins[];
   int m_recentWinsCount;
   
   double m_adaptiveBias[];
   int m_biasSize;
   
   string m_dataPath;
   bool m_autoSaveEnabled;
   
public:
   CAdaptiveLearning()
   {
      m_historyCount = 0;
      m_patternCount = 0;
      m_consecutiveWins = 0;
      m_totalWins = 0;
      m_totalLosses = 0;
      m_recentWinsCount = 0;
      m_biasSize = 16;
      m_dataPath = "ForexBotPro_";
      m_autoSaveEnabled = true;
      
      ArrayResize(m_adaptiveBias, m_biasSize);
      ArrayInitialize(m_adaptiveBias, 0.0);
      
      ArrayResize(m_recentWins, WINS_PER_SNAPSHOT);
   }
   
   void Init()
   {
      LoadTradeHistory();
      LoadReferencePatterns();
      LoadAdaptiveBias();
      
      Print("=== Adaptive Learning Initialized ===");
      Print("Trade History: ", m_historyCount, " trades");
      Print("Reference Patterns: ", m_patternCount);
      Print("Total Wins: ", m_totalWins, " | Losses: ", m_totalLosses);
      Print("Win Rate: ", m_totalWins + m_totalLosses > 0 ? 
            DoubleToString(m_totalWins * 100.0 / (m_totalWins + m_totalLosses), 1) : "0", "%");
   }
   
   void RecordTradeOutcome(TradeFeatureSnapshot &snapshot)
   {
      if(m_historyCount >= MAX_TRADE_HISTORY)
      {
         for(int i = 0; i < MAX_TRADE_HISTORY - 1; i++)
            m_tradeHistory[i] = m_tradeHistory[i + 1];
         m_historyCount--;
      }
      
      ArrayResize(m_tradeHistory, m_historyCount + 1);
      m_tradeHistory[m_historyCount] = snapshot;
      m_historyCount++;
      
      if(snapshot.isWin)
      {
         m_totalWins++;
         m_consecutiveWins++;
         
         if(m_recentWinsCount < WINS_PER_SNAPSHOT)
         {
            m_recentWins[m_recentWinsCount] = snapshot;
            m_recentWinsCount++;
         }
         else
         {
            for(int i = 0; i < WINS_PER_SNAPSHOT - 1; i++)
               m_recentWins[i] = m_recentWins[i + 1];
            m_recentWins[WINS_PER_SNAPSHOT - 1] = snapshot;
         }
         
         if(m_consecutiveWins >= WINS_PER_SNAPSHOT)
         {
            CreateReferencePattern();
            UpdateAdaptiveBias(true);
            m_consecutiveWins = 0;
         }
      }
      else
      {
         m_totalLosses++;
         m_consecutiveWins = 0;
         UpdateAdaptiveBias(false);
      }
      
      if(m_autoSaveEnabled)
      {
         SaveTradeHistory();
         if(m_patternCount > 0)
            SaveReferencePatterns();
      }
      
      Print("Trade recorded: ", snapshot.symbol, " | ", 
            snapshot.isWin ? "WIN" : "LOSS", " | ",
            DoubleToString(snapshot.profitPips, 1), " pips | ",
            "Score: ", DoubleToString(snapshot.combinedScore, 1), "%");
   }
   
   void CreateReferencePattern()
   {
      if(m_recentWinsCount < WINS_PER_SNAPSHOT) return;
      
      ReferencePattern pattern;
      pattern.patternId = m_patternCount + 1;
      pattern.tradeCount = WINS_PER_SNAPSHOT;
      pattern.winRate = 100.0;
      pattern.lastUpdate = TimeCurrent();
      
      double sumIA = 0, sumTech = 0, sumAlign = 0, sumCombined = 0;
      double sumTDI_RSI = 0, sumTDI_Signal = 0;
      double minIA = 100, maxIA = 0, minTech = 100, maxTech = 0;
      double minAlign = 100, maxAlign = 0;
      
      int buyCount = 0, sellCount = 0;
      int mtfCount = 0;
      
      for(int i = 0; i < WINS_PER_SNAPSHOT; i++)
      {
         sumIA += m_recentWins[i].iaScore;
         sumTech += m_recentWins[i].technicalScore;
         sumAlign += m_recentWins[i].alignmentScore;
         sumCombined += m_recentWins[i].combinedScore;
         sumTDI_RSI += m_recentWins[i].tdiRSI;
         sumTDI_Signal += m_recentWins[i].tdiSignal;
         
         if(m_recentWins[i].iaScore < minIA) minIA = m_recentWins[i].iaScore;
         if(m_recentWins[i].iaScore > maxIA) maxIA = m_recentWins[i].iaScore;
         if(m_recentWins[i].technicalScore < minTech) minTech = m_recentWins[i].technicalScore;
         if(m_recentWins[i].technicalScore > maxTech) maxTech = m_recentWins[i].technicalScore;
         if(m_recentWins[i].alignmentScore < minAlign) minAlign = m_recentWins[i].alignmentScore;
         if(m_recentWins[i].alignmentScore > maxAlign) maxAlign = m_recentWins[i].alignmentScore;
         
         if(m_recentWins[i].signal == SIGNAL_BUY || m_recentWins[i].signal == SIGNAL_STRONG_BUY)
            buyCount++;
         else
            sellCount++;
         
         if(m_recentWins[i].mtfAligned)
            mtfCount++;
      }
      
      pattern.avgIAScore = sumIA / WINS_PER_SNAPSHOT;
      pattern.avgTechnicalScore = sumTech / WINS_PER_SNAPSHOT;
      pattern.avgAlignmentScore = sumAlign / WINS_PER_SNAPSHOT;
      pattern.avgCombinedScore = sumCombined / WINS_PER_SNAPSHOT;
      pattern.avgTDI_RSI = sumTDI_RSI / WINS_PER_SNAPSHOT;
      pattern.avgTDI_Signal = sumTDI_Signal / WINS_PER_SNAPSHOT;
      
      pattern.minIAScore = minIA;
      pattern.maxIAScore = maxIA;
      pattern.minTechnicalScore = minTech;
      pattern.maxTechnicalScore = maxTech;
      pattern.minAlignmentScore = minAlign;
      pattern.maxAlignmentScore = maxAlign;
      
      pattern.signalType = buyCount > sellCount ? SIGNAL_BUY : SIGNAL_SELL;
      pattern.symbol = m_recentWins[WINS_PER_SNAPSHOT - 1].symbol;
      pattern.preferredEMAAlignment = m_recentWins[WINS_PER_SNAPSHOT - 1].emaAlignment;
      pattern.preferredTrend = m_recentWins[WINS_PER_SNAPSHOT - 1].trendDirection;
      pattern.requiresMTF = (mtfCount >= 3);
      
      pattern.successConfidence = pattern.avgCombinedScore;
      
      if(m_patternCount >= MAX_REFERENCE_PATTERNS)
      {
         int worstIdx = FindWeakestPattern();
         m_referencePatterns[worstIdx] = pattern;
      }
      else
      {
         ArrayResize(m_referencePatterns, m_patternCount + 1);
         m_referencePatterns[m_patternCount] = pattern;
         m_patternCount++;
      }
      
      Print("=== NEW REFERENCE PATTERN CREATED ===");
      Print("Pattern #", pattern.patternId);
      Print("Avg Scores - IA: ", DoubleToString(pattern.avgIAScore, 1), 
            " | Tech: ", DoubleToString(pattern.avgTechnicalScore, 1),
            " | Align: ", DoubleToString(pattern.avgAlignmentScore, 1));
      Print("Combined: ", DoubleToString(pattern.avgCombinedScore, 1), "%");
      Print("Signal Type: ", pattern.signalType == SIGNAL_BUY ? "BUY" : "SELL");
      Print("Total Patterns: ", m_patternCount);
      
      SaveReferencePatterns();
   }
   
   double GetPatternSimilarity(double iaScore, double techScore, double alignScore,
                                ENUM_SIGNAL_TYPE signal, string emaAlign, bool mtfAligned)
   {
      if(m_patternCount == 0) return 0;
      
      double bestSimilarity = 0;
      
      for(int i = 0; i < m_patternCount; i++)
      {
         double similarity = CalculateSimilarity(m_referencePatterns[i], 
                                                  iaScore, techScore, alignScore,
                                                  signal, emaAlign, mtfAligned);
         if(similarity > bestSimilarity)
            bestSimilarity = similarity;
      }
      
      return bestSimilarity;
   }
   
   double GetConfidenceBoost(double iaScore, double techScore, double alignScore,
                              ENUM_SIGNAL_TYPE signal, string emaAlign, bool mtfAligned)
   {
      double similarity = GetPatternSimilarity(iaScore, techScore, alignScore,
                                                signal, emaAlign, mtfAligned);
      
      if(similarity >= 90) return 5.0;
      if(similarity >= 80) return 3.0;
      if(similarity >= 70) return 1.5;
      if(similarity >= 60) return 0.5;
      
      return 0;
   }
   
   void UpdateAdaptiveBias(bool wasWin)
   {
      if(m_historyCount == 0) return;
      
      TradeFeatureSnapshot lastTrade = m_tradeHistory[m_historyCount - 1];
      double learningRate = 0.01;
      double direction = wasWin ? 1.0 : -1.0;
      
      double features[16];
      NormalizeFeatures(lastTrade, features);
      
      for(int i = 0; i < m_biasSize; i++)
      {
         m_adaptiveBias[i] += learningRate * direction * features[i];
         m_adaptiveBias[i] = MathMax(-0.5, MathMin(0.5, m_adaptiveBias[i]));
      }
      
      SaveAdaptiveBias();
   }
   
   double ApplyAdaptiveBias(double baseScore)
   {
      double biasSum = 0;
      for(int i = 0; i < m_biasSize; i++)
         biasSum += m_adaptiveBias[i];
      
      double avgBias = biasSum / m_biasSize;
      double adjustedScore = baseScore + (avgBias * 10);
      
      return MathMax(0, MathMin(100, adjustedScore));
   }
   
   int GetTotalWins() { return m_totalWins; }
   int GetTotalLosses() { return m_totalLosses; }
   int GetPatternCount() { return m_patternCount; }
   int GetHistoryCount() { return m_historyCount; }
   
   double GetOverallWinRate()
   {
      int total = m_totalWins + m_totalLosses;
      if(total == 0) return 0;
      return m_totalWins * 100.0 / total;
   }
   
   ReferencePattern GetBestMatchingPattern(double iaScore, double techScore, double alignScore,
                                            ENUM_SIGNAL_TYPE signal)
   {
      ReferencePattern best;
      best.patternId = 0;
      best.successConfidence = 0;
      
      double bestSim = 0;
      
      for(int i = 0; i < m_patternCount; i++)
      {
         double sim = CalculateSimilarity(m_referencePatterns[i], 
                                          iaScore, techScore, alignScore,
                                          signal, "", true);
         if(sim > bestSim)
         {
            bestSim = sim;
            best = m_referencePatterns[i];
         }
      }
      
      return best;
   }
   
   void ExportLearningData()
   {
      int handle = FileOpen(m_dataPath + "Learning_Export.csv", FILE_WRITE|FILE_CSV);
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Cannot export learning data");
         return;
      }
      
      FileWrite(handle, "Symbol,EntryTime,Signal,IAScore,TechScore,AlignScore,CombinedScore,TDI_RSI,EMA_Align,MTF,ProfitPips,IsWin");
      
      for(int i = 0; i < m_historyCount; i++)
      {
         FileWrite(handle,
                   m_tradeHistory[i].symbol,
                   TimeToString(m_tradeHistory[i].entryTime),
                   EnumToString(m_tradeHistory[i].signal),
                   DoubleToString(m_tradeHistory[i].iaScore, 2),
                   DoubleToString(m_tradeHistory[i].technicalScore, 2),
                   DoubleToString(m_tradeHistory[i].alignmentScore, 2),
                   DoubleToString(m_tradeHistory[i].combinedScore, 2),
                   DoubleToString(m_tradeHistory[i].tdiRSI, 2),
                   m_tradeHistory[i].emaAlignment,
                   m_tradeHistory[i].mtfAligned ? "YES" : "NO",
                   DoubleToString(m_tradeHistory[i].profitPips, 2),
                   m_tradeHistory[i].isWin ? "1" : "0");
      }
      
      FileClose(handle);
      Print("Learning data exported: ", m_historyCount, " trades");
   }
   
private:
   double CalculateSimilarity(ReferencePattern &pattern, double iaScore, double techScore,
                               double alignScore, ENUM_SIGNAL_TYPE signal, 
                               string emaAlign, bool mtfAligned)
   {
      double similarity = 0;
      double weight = 0;
      
      if(iaScore >= pattern.minIAScore && iaScore <= pattern.maxIAScore)
      {
         double iaDiff = MathAbs(iaScore - pattern.avgIAScore);
         double iaRange = pattern.maxIAScore - pattern.minIAScore + 1;
         similarity += (1.0 - iaDiff / iaRange) * 25;
      }
      else
      {
         double iaDist = MathMin(MathAbs(iaScore - pattern.minIAScore), 
                                  MathAbs(iaScore - pattern.maxIAScore));
         similarity += MathMax(0, 25 - iaDist);
      }
      weight += 25;
      
      if(techScore >= pattern.minTechnicalScore && techScore <= pattern.maxTechnicalScore)
      {
         double techDiff = MathAbs(techScore - pattern.avgTechnicalScore);
         double techRange = pattern.maxTechnicalScore - pattern.minTechnicalScore + 1;
         similarity += (1.0 - techDiff / techRange) * 25;
      }
      else
      {
         double techDist = MathMin(MathAbs(techScore - pattern.minTechnicalScore), 
                                    MathAbs(techScore - pattern.maxTechnicalScore));
         similarity += MathMax(0, 25 - techDist);
      }
      weight += 25;
      
      if(alignScore >= pattern.minAlignmentScore && alignScore <= pattern.maxAlignmentScore)
      {
         double alignDiff = MathAbs(alignScore - pattern.avgAlignmentScore);
         double alignRange = pattern.maxAlignmentScore - pattern.minAlignmentScore + 1;
         similarity += (1.0 - alignDiff / alignRange) * 20;
      }
      else
      {
         double alignDist = MathMin(MathAbs(alignScore - pattern.minAlignmentScore), 
                                     MathAbs(alignScore - pattern.maxAlignmentScore));
         similarity += MathMax(0, 20 - alignDist);
      }
      weight += 20;
      
      bool signalMatch = false;
      if((pattern.signalType == SIGNAL_BUY || pattern.signalType == SIGNAL_STRONG_BUY) &&
         (signal == SIGNAL_BUY || signal == SIGNAL_STRONG_BUY))
         signalMatch = true;
      else if((pattern.signalType == SIGNAL_SELL || pattern.signalType == SIGNAL_STRONG_SELL) &&
              (signal == SIGNAL_SELL || signal == SIGNAL_STRONG_SELL))
         signalMatch = true;
      
      if(signalMatch)
         similarity += 15;
      weight += 15;
      
      if(pattern.requiresMTF == mtfAligned)
         similarity += 10;
      else if(!pattern.requiresMTF)
         similarity += 5;
      weight += 10;
      
      if(emaAlign != "" && pattern.preferredEMAAlignment != "")
      {
         if(emaAlign == pattern.preferredEMAAlignment)
            similarity += 5;
      }
      weight += 5;
      
      return (similarity / weight) * 100;
   }
   
   void NormalizeFeatures(TradeFeatureSnapshot &snapshot, double &features[])
   {
      features[0] = snapshot.iaScore / 100.0;
      features[1] = snapshot.technicalScore / 100.0;
      features[2] = snapshot.alignmentScore / 100.0;
      features[3] = snapshot.combinedScore / 100.0;
      features[4] = snapshot.tdiRSI / 100.0;
      features[5] = snapshot.tdiSignal / 100.0;
      features[6] = snapshot.ema21 > 0 ? 1.0 : 0.0;
      features[7] = snapshot.ema50 > 0 ? 1.0 : 0.0;
      features[8] = snapshot.ema200 > 0 ? 1.0 : 0.0;
      features[9] = snapshot.mtfAligned ? 1.0 : 0.0;
      features[10] = (snapshot.signal == SIGNAL_BUY || snapshot.signal == SIGNAL_STRONG_BUY) ? 1.0 : 0.0;
      features[11] = snapshot.emaAlignment == "BULL" ? 1.0 : (snapshot.emaAlignment == "BEAR" ? -1.0 : 0.0);
      features[12] = snapshot.candlePattern != "---" ? 1.0 : 0.0;
      features[13] = snapshot.chartPattern != "---" ? 1.0 : 0.0;
      features[14] = snapshot.volatility;
      features[15] = snapshot.spreadPips / 3.0;
   }
   
   int FindWeakestPattern()
   {
      int worstIdx = 0;
      double worstScore = m_referencePatterns[0].successConfidence;
      
      for(int i = 1; i < m_patternCount; i++)
      {
         if(m_referencePatterns[i].successConfidence < worstScore)
         {
            worstScore = m_referencePatterns[i].successConfidence;
            worstIdx = i;
         }
      }
      
      return worstIdx;
   }
   
   void SaveTradeHistory()
   {
      int handle = FileOpen(m_dataPath + "TradeHistory.bin", FILE_WRITE|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      FileWriteInteger(handle, m_historyCount);
      FileWriteInteger(handle, m_totalWins);
      FileWriteInteger(handle, m_totalLosses);
      
      for(int i = 0; i < m_historyCount; i++)
      {
         FileWriteString(handle, m_tradeHistory[i].symbol, 16);
         FileWriteLong(handle, m_tradeHistory[i].entryTime);
         FileWriteLong(handle, m_tradeHistory[i].exitTime);
         FileWriteInteger(handle, (int)m_tradeHistory[i].signal);
         FileWriteDouble(handle, m_tradeHistory[i].entryPrice);
         FileWriteDouble(handle, m_tradeHistory[i].exitPrice);
         FileWriteDouble(handle, m_tradeHistory[i].profitPips);
         FileWriteInteger(handle, m_tradeHistory[i].isWin ? 1 : 0);
         FileWriteDouble(handle, m_tradeHistory[i].iaScore);
         FileWriteDouble(handle, m_tradeHistory[i].technicalScore);
         FileWriteDouble(handle, m_tradeHistory[i].alignmentScore);
         FileWriteDouble(handle, m_tradeHistory[i].combinedScore);
         FileWriteDouble(handle, m_tradeHistory[i].tdiRSI);
         FileWriteDouble(handle, m_tradeHistory[i].tdiSignal);
         FileWriteInteger(handle, m_tradeHistory[i].mtfAligned ? 1 : 0);
      }
      
      FileClose(handle);
   }
   
   void LoadTradeHistory()
   {
      int handle = FileOpen(m_dataPath + "TradeHistory.bin", FILE_READ|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      m_historyCount = FileReadInteger(handle);
      m_totalWins = FileReadInteger(handle);
      m_totalLosses = FileReadInteger(handle);
      
      ArrayResize(m_tradeHistory, m_historyCount);
      
      for(int i = 0; i < m_historyCount; i++)
      {
         m_tradeHistory[i].symbol = FileReadString(handle, 16);
         m_tradeHistory[i].entryTime = (datetime)FileReadLong(handle);
         m_tradeHistory[i].exitTime = (datetime)FileReadLong(handle);
         m_tradeHistory[i].signal = (ENUM_SIGNAL_TYPE)FileReadInteger(handle);
         m_tradeHistory[i].entryPrice = FileReadDouble(handle);
         m_tradeHistory[i].exitPrice = FileReadDouble(handle);
         m_tradeHistory[i].profitPips = FileReadDouble(handle);
         m_tradeHistory[i].isWin = FileReadInteger(handle) == 1;
         m_tradeHistory[i].iaScore = FileReadDouble(handle);
         m_tradeHistory[i].technicalScore = FileReadDouble(handle);
         m_tradeHistory[i].alignmentScore = FileReadDouble(handle);
         m_tradeHistory[i].combinedScore = FileReadDouble(handle);
         m_tradeHistory[i].tdiRSI = FileReadDouble(handle);
         m_tradeHistory[i].tdiSignal = FileReadDouble(handle);
         m_tradeHistory[i].mtfAligned = FileReadInteger(handle) == 1;
      }
      
      FileClose(handle);
      Print("Loaded trade history: ", m_historyCount, " trades");
   }
   
   void SaveReferencePatterns()
   {
      int handle = FileOpen(m_dataPath + "ReferencePatterns.bin", FILE_WRITE|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      FileWriteInteger(handle, m_patternCount);
      
      for(int i = 0; i < m_patternCount; i++)
      {
         FileWriteInteger(handle, m_referencePatterns[i].patternId);
         FileWriteInteger(handle, m_referencePatterns[i].tradeCount);
         FileWriteDouble(handle, m_referencePatterns[i].winRate);
         FileWriteLong(handle, m_referencePatterns[i].lastUpdate);
         FileWriteDouble(handle, m_referencePatterns[i].avgIAScore);
         FileWriteDouble(handle, m_referencePatterns[i].avgTechnicalScore);
         FileWriteDouble(handle, m_referencePatterns[i].avgAlignmentScore);
         FileWriteDouble(handle, m_referencePatterns[i].avgCombinedScore);
         FileWriteDouble(handle, m_referencePatterns[i].minIAScore);
         FileWriteDouble(handle, m_referencePatterns[i].maxIAScore);
         FileWriteDouble(handle, m_referencePatterns[i].minTechnicalScore);
         FileWriteDouble(handle, m_referencePatterns[i].maxTechnicalScore);
         FileWriteDouble(handle, m_referencePatterns[i].minAlignmentScore);
         FileWriteDouble(handle, m_referencePatterns[i].maxAlignmentScore);
         FileWriteDouble(handle, m_referencePatterns[i].avgTDI_RSI);
         FileWriteDouble(handle, m_referencePatterns[i].avgTDI_Signal);
         FileWriteInteger(handle, (int)m_referencePatterns[i].signalType);
         FileWriteString(handle, m_referencePatterns[i].symbol, 16);
         FileWriteString(handle, m_referencePatterns[i].preferredEMAAlignment, 8);
         FileWriteString(handle, m_referencePatterns[i].preferredTrend, 8);
         FileWriteInteger(handle, m_referencePatterns[i].requiresMTF ? 1 : 0);
         FileWriteDouble(handle, m_referencePatterns[i].successConfidence);
      }
      
      FileClose(handle);
   }
   
   void LoadReferencePatterns()
   {
      int handle = FileOpen(m_dataPath + "ReferencePatterns.bin", FILE_READ|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      m_patternCount = FileReadInteger(handle);
      ArrayResize(m_referencePatterns, m_patternCount);
      
      for(int i = 0; i < m_patternCount; i++)
      {
         m_referencePatterns[i].patternId = FileReadInteger(handle);
         m_referencePatterns[i].tradeCount = FileReadInteger(handle);
         m_referencePatterns[i].winRate = FileReadDouble(handle);
         m_referencePatterns[i].lastUpdate = (datetime)FileReadLong(handle);
         m_referencePatterns[i].avgIAScore = FileReadDouble(handle);
         m_referencePatterns[i].avgTechnicalScore = FileReadDouble(handle);
         m_referencePatterns[i].avgAlignmentScore = FileReadDouble(handle);
         m_referencePatterns[i].avgCombinedScore = FileReadDouble(handle);
         m_referencePatterns[i].minIAScore = FileReadDouble(handle);
         m_referencePatterns[i].maxIAScore = FileReadDouble(handle);
         m_referencePatterns[i].minTechnicalScore = FileReadDouble(handle);
         m_referencePatterns[i].maxTechnicalScore = FileReadDouble(handle);
         m_referencePatterns[i].minAlignmentScore = FileReadDouble(handle);
         m_referencePatterns[i].maxAlignmentScore = FileReadDouble(handle);
         m_referencePatterns[i].avgTDI_RSI = FileReadDouble(handle);
         m_referencePatterns[i].avgTDI_Signal = FileReadDouble(handle);
         m_referencePatterns[i].signalType = (ENUM_SIGNAL_TYPE)FileReadInteger(handle);
         m_referencePatterns[i].symbol = FileReadString(handle, 16);
         m_referencePatterns[i].preferredEMAAlignment = FileReadString(handle, 8);
         m_referencePatterns[i].preferredTrend = FileReadString(handle, 8);
         m_referencePatterns[i].requiresMTF = FileReadInteger(handle) == 1;
         m_referencePatterns[i].successConfidence = FileReadDouble(handle);
      }
      
      FileClose(handle);
      Print("Loaded reference patterns: ", m_patternCount);
   }
   
   void SaveAdaptiveBias()
   {
      int handle = FileOpen(m_dataPath + "AdaptiveBias.bin", FILE_WRITE|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      FileWriteInteger(handle, m_biasSize);
      for(int i = 0; i < m_biasSize; i++)
         FileWriteDouble(handle, m_adaptiveBias[i]);
      
      FileClose(handle);
   }
   
   void LoadAdaptiveBias()
   {
      int handle = FileOpen(m_dataPath + "AdaptiveBias.bin", FILE_READ|FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      int size = FileReadInteger(handle);
      if(size == m_biasSize)
      {
         for(int i = 0; i < m_biasSize; i++)
            m_adaptiveBias[i] = FileReadDouble(handle);
      }
      
      FileClose(handle);
      Print("Loaded adaptive bias values");
   }
};
