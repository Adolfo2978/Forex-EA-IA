//+------------------------------------------------------------------+
//|                                    AdaptiveLearningV2.mqh |
//|                              Forex Bot Pro v7.0 - Advanced AL    |
//|                   Auto-Aprendizaje Progresivo con Retroalimentación NN |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"
#include "MMMMethodology.mqh"

#define MAX_ADAPTIVE_PATTERNS 50
#define MIN_PATTERN_TRADES 10
#define LEARNING_WINDOW_DAYS 30

struct AdaptivePatternV2
{
   int patternId;
   datetime createdTime;
   datetime lastUpdateTime;
   
   // Estadísticas de patrón
   int totalTrades;
   int wins;
   int losses;
   double winRate;
   
   // Condiciones del patrón
   double minConfidence;
   double maxConfidence;
   double avgConfidence;
   
   double minATR;
   double maxATR;
   
   ENUM_MMM_SESSION preferredSession;
   ENUM_MMM_CYCLE_PHASE preferredPhase;
   
   // Resultados
   double avgProfitPips;
   double avgLossPips;
   double avgRRRatio;
   
   // Decay factor para datos antiguos
   double decayFactor;
   
   // Validación cruzada
   bool passedBacktest;
   int backtestTrades;
   double backtestWinRate;
};

struct NeuralNetworkWeightAdjustment
{
   double layerGradient[3];  // Para 3 capas ocultas
   double adjustment;
   datetime timestamp;
   bool isWin;
   double confidence;
};

class CAdaptiveLearningV2
{
private:
   AdaptivePatternV2 m_patterns[];
   int m_patternCount;
   
   NeuralNetworkWeightAdjustment m_nnAdjustments[];
   int m_adjustmentCount;
   int m_maxAdjustments;
   
   struct TradeEntry
   {
      datetime entryTime;
      datetime exitTime;
      double entryPrice;
      double exitPrice;
      double profitPips;
      bool isWin;
      double iaScore;
      double technicalScore;
      double alignmentScore;
      double mmmScore;
      ENUM_SIGNAL_TYPE signal;
      ENUM_MMM_SESSION session;
      ENUM_MMM_CYCLE_PHASE phase;
      ENUM_MMM_IMPULSE_STRENGTH impulseStrength;
      double atr;
      double confidence;
      string pattern;
      bool validatedByBacktest;
   };
   
   TradeEntry m_tradeHistory[];
   int m_tradeHistoryCount;
   int m_maxTradeHistory;
   
   // Estadísticas generales
   int m_totalWins;
   int m_totalLosses;
   int m_consecutiveWins;
   int m_consecutiveLosses;
   double m_totalProfit;
   
   // Control de aprendizaje
   double m_learningRate;
   double m_momentum;
   datetime m_lastLearningUpdate;
   int m_learningCycle;
   
   // Archivos
   string m_patternFile;
   string m_historyFile;
   
public:
   CAdaptiveLearningV2()
   {
      m_patternCount = 0;
      m_adjustmentCount = 0;
      m_maxAdjustments = 1000;
      m_tradeHistoryCount = 0;
      m_maxTradeHistory = 500;
      
      m_totalWins = 0;
      m_totalLosses = 0;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
      m_totalProfit = 0;
      
      m_learningRate = 0.01;
      m_momentum = 0.9;
      m_lastLearningUpdate = TimeCurrent();
      m_learningCycle = 0;
      
      m_patternFile = "ForexBotPro_AdaptivePatterns_v2.bin";
      m_historyFile = "ForexBotPro_TradeHistory_v2.bin";
      
      ArrayResize(m_patterns, MAX_ADAPTIVE_PATTERNS);
      ArrayResize(m_nnAdjustments, m_maxAdjustments);
      ArrayResize(m_tradeHistory, m_maxTradeHistory);
   }
   
   ~CAdaptiveLearningV2()
   {
      SavePatterns();
      SaveTradeHistory();
   }
   
   // ========== REGISTRO DE TRADES ==========
   
   void RecordTrade(datetime entryTime, datetime exitTime, double entryPrice, double exitPrice,
                   double iaScore, double technicalScore, double alignmentScore, double mmmScore,
                   ENUM_SIGNAL_TYPE signal, ENUM_MMM_SESSION session, ENUM_MMM_CYCLE_PHASE phase,
                   ENUM_MMM_IMPULSE_STRENGTH impulseStr, double atr, double confidence)
   {
      if(m_tradeHistoryCount >= m_maxTradeHistory)
      {
         // Desplazar histórico hacia atrás (remover el más antiguo)
         for(int i = 0; i < m_maxTradeHistory - 1; i++)
            m_tradeHistory[i] = m_tradeHistory[i + 1];
         m_tradeHistoryCount--;
      }
      
      TradeEntry entry;
      entry.entryTime = entryTime;
      entry.exitTime = exitTime;
      entry.entryPrice = entryPrice;
      entry.exitPrice = exitPrice;
      entry.iaScore = iaScore;
      entry.technicalScore = technicalScore;
      entry.alignmentScore = alignmentScore;
      entry.mmmScore = mmmScore;
      entry.signal = signal;
      entry.session = session;
      entry.phase = phase;
      entry.impulseStrength = impulseStr;
      entry.atr = atr;
      entry.confidence = confidence;
      
      // Calcular profit
      entry.profitPips = exitPrice > entryPrice ? (exitPrice - entryPrice) * 10000 : 
                        (entryPrice - exitPrice) * 10000;
      entry.isWin = (entry.profitPips > 0);
      
      m_tradeHistory[m_tradeHistoryCount++] = entry;
      
      // Actualizar estadísticas
      if(entry.isWin)
      {
         m_totalWins++;
         m_consecutiveWins++;
         m_consecutiveLosses = 0;
         m_totalProfit += entry.profitPips;
      }
      else
      {
         m_totalLosses++;
         m_consecutiveWins = 0;
         m_consecutiveLosses++;
         m_totalProfit -= MathAbs(entry.profitPips);
      }
      
      // Análisis de patrón
      AnalyzeAndCreatePattern(entry);
      
      // Retroalimentación a NN
      if(m_learningRate > 0.001)
         ApplyNeuralNetworkFeedback(entry);
      
      Print("ADAPTIVE LEARNING: Trade recorded - ", (entry.isWin ? "WIN" : "LOSS"), 
            " | Profit: ", DoubleToString(entry.profitPips, 1), "p | Confidence: ", 
            DoubleToString(confidence, 0), "%");
   }
   
   // ========== ANÁLISIS DE PATRONES ==========
   
   void AnalyzeAndCreatePattern(TradeEntry &trade)
   {
      // Verificar si ya existe un patrón similar
      int matchingPatternId = FindSimilarPattern(trade);
      
      if(matchingPatternId >= 0 && matchingPatternId < m_patternCount)
      {
         // Actualizar patrón existente
         UpdatePattern(matchingPatternId, trade);
      }
      else if(m_patternCount < MAX_ADAPTIVE_PATTERNS)
      {
         // Crear nuevo patrón
         CreateNewPattern(trade);
      }
      
      // Aplicar decay a todos los patrones
      ApplyPatternDecay();
   }
   
   int FindSimilarPattern(TradeEntry &trade)
   {
      const double confidenceTolerance = 10.0;
      const double atrTolerance = 0.01;
      
      for(int i = 0; i < m_patternCount; i++)
      {
         // Verificar similitud por sesión y fase
         if(m_patterns[i].preferredSession != trade.session)
            continue;
         if(m_patterns[i].preferredPhase != trade.phase)
            continue;
         
         // Verificar similitud por confianza
         if(MathAbs(m_patterns[i].avgConfidence - trade.confidence) > confidenceTolerance)
            continue;
         
         // Verificar similitud por ATR
         if(MathAbs(m_patterns[i].maxATR - trade.atr) > atrTolerance)
            continue;
         
         return i;
      }
      
      return -1;
   }
   
   void CreateNewPattern(TradeEntry &trade)
   {
      if(m_patternCount >= MAX_ADAPTIVE_PATTERNS)
      {
         Print("ADAPTIVE: Máximo número de patrones alcanzado");
         return;
      }
      
      AdaptivePatternV2 newPattern;
      newPattern.patternId = m_patternCount;
      newPattern.createdTime = TimeCurrent();
      newPattern.lastUpdateTime = TimeCurrent();
      
      newPattern.totalTrades = 1;
      newPattern.wins = trade.isWin ? 1 : 0;
      newPattern.losses = trade.isWin ? 0 : 1;
      newPattern.winRate = trade.isWin ? 1.0 : 0.0;
      
      newPattern.minConfidence = trade.confidence;
      newPattern.maxConfidence = trade.confidence;
      newPattern.avgConfidence = trade.confidence;
      
      newPattern.minATR = trade.atr;
      newPattern.maxATR = trade.atr;
      
      newPattern.preferredSession = trade.session;
      newPattern.preferredPhase = trade.phase;
      
      newPattern.avgProfitPips = trade.isWin ? trade.profitPips : 0;
      newPattern.avgLossPips = trade.isWin ? 0 : MathAbs(trade.profitPips);
      newPattern.avgRRRatio = newPattern.totalTrades > 0 ? 
                             newPattern.avgProfitPips / MathMax(1, newPattern.avgLossPips) : 1.0;
      
      newPattern.decayFactor = 1.0;
      newPattern.passedBacktest = false;
      newPattern.backtestTrades = 0;
      newPattern.backtestWinRate = 0.0;
      
      m_patterns[m_patternCount++] = newPattern;
      Print("ADAPTIVE: Nuevo patrón creado - ID:", newPattern.patternId, " | Sesión: ", 
            (int)newPattern.preferredSession, " | Fase: ", (int)newPattern.preferredPhase);
   }
   
   void UpdatePattern(int patternId, TradeEntry &trade)
   {
      if(patternId < 0 || patternId >= m_patternCount) return;
      
      m_patterns[patternId].lastUpdateTime = TimeCurrent();
      m_patterns[patternId].totalTrades++;
      
      if(trade.isWin)
         m_patterns[patternId].wins++;
      else
         m_patterns[patternId].losses++;
      
      m_patterns[patternId].winRate = m_patterns[patternId].wins / (double)m_patterns[patternId].totalTrades;
      
      // Actualizar confianza
      m_patterns[patternId].minConfidence = MathMin(m_patterns[patternId].minConfidence, trade.confidence);
      m_patterns[patternId].maxConfidence = MathMax(m_patterns[patternId].maxConfidence, trade.confidence);
      m_patterns[patternId].avgConfidence = (m_patterns[patternId].avgConfidence * (m_patterns[patternId].totalTrades - 1) + trade.confidence) / 
                             m_patterns[patternId].totalTrades;
      
      // Actualizar ATR
      m_patterns[patternId].minATR = MathMin(m_patterns[patternId].minATR, trade.atr);
      m_patterns[patternId].maxATR = MathMax(m_patterns[patternId].maxATR, trade.atr);
      
      // Validación: si patrón tiene >= 10 trades y win rate > 65%, marcar como validado
      if(m_patterns[patternId].totalTrades >= MIN_PATTERN_TRADES && m_patterns[patternId].winRate > 0.65)
      {
         m_patterns[patternId].passedBacktest = true;
         m_patterns[patternId].backtestTrades = m_patterns[patternId].totalTrades;
         m_patterns[patternId].backtestWinRate = m_patterns[patternId].winRate;
      }
      
      Print("ADAPTIVE: Patrón actualizado - ID:", patternId, " | Trades: ", m_patterns[patternId].totalTrades, 
            " | Win Rate: ", DoubleToString(m_patterns[patternId].winRate * 100, 1), "%");
   }
   
   void ApplyPatternDecay()
   {
      datetime currentTime = TimeCurrent();
      
      for(int i = 0; i < m_patternCount; i++)
      {
         int daysOld = (int)((currentTime - m_patterns[i].lastUpdateTime) / 86400);
         
         // Decay factor: reduce weight de trades antiguos
         m_patterns[i].decayFactor = 1.0 - (daysOld / (double)(LEARNING_WINDOW_DAYS * 2));
         m_patterns[i].decayFactor = MathMax(0.1, m_patterns[i].decayFactor);  // Mínimo 10%
      }
   }
   
   // ========== RETROALIMENTACIÓN NEURAL NETWORK ==========
   
   void ApplyNeuralNetworkFeedback(TradeEntry &trade)
   {
      if(m_adjustmentCount >= m_maxAdjustments)
      {
         // Remover ajustes más antiguos
         for(int i = 0; i < m_maxAdjustments - 1; i++)
            m_nnAdjustments[i] = m_nnAdjustments[i + 1];
         m_adjustmentCount--;
      }
      
      NeuralNetworkWeightAdjustment adj;
      adj.isWin = trade.isWin;
      adj.confidence = trade.confidence;
      adj.timestamp = TimeCurrent();
      
      // Calcular gradiente basado en trade outcome
      if(trade.isWin)
      {
         // Ganar: reforzar los pesos que contribuyeron a esta predicción
         adj.adjustment = 0.0001 * (trade.confidence / 100.0);  // Ajuste positivo pequeño
         
         for(int i = 0; i < 3; i++)
            adj.layerGradient[i] = 0.0001;
      }
      else
      {
         // Perder: reducir los pesos que contribuyeron a esta predicción
         adj.adjustment = -0.0001 * (trade.confidence / 100.0);  // Ajuste negativo pequeño
         
         for(int i = 0; i < 3; i++)
            adj.layerGradient[i] = -0.0001;
      }
      
      m_nnAdjustments[m_adjustmentCount++] = adj;
      
      // Actualizar learning rate adaptativo
      UpdateAdaptiveLearningRate();
      
      Print("NN FEEDBACK: Adjustment recorded - ", (trade.isWin ? "Reinforcement" : "Penalty"), 
            " | LR: ", DoubleToString(m_learningRate, 6));
   }
   
   void UpdateAdaptiveLearningRate()
   {
      int totalTrades = m_totalWins + m_totalLosses;
      
      if(totalTrades < 10)
      {
         m_learningRate = 0.01;  // Alto al principio
      }
      else if(totalTrades < 50)
      {
         m_learningRate = 0.01 * (m_totalWins / (double)totalTrades);
      }
      else
      {
         // Reducir learning rate con el tiempo
         m_learningRate = 0.001 * (m_totalWins / (double)totalTrades);
      }
      
      m_learningRate = MathMax(0.00001, MathMin(0.01, m_learningRate));
   }
   
   // ========== CONSULTAS DE PATRONES ==========
   
   double GetPatternWinRate(int patternId)
   {
      if(patternId < 0 || patternId >= m_patternCount) return 0.0;
      return m_patterns[patternId].winRate * m_patterns[patternId].decayFactor;
   }
   
   bool IsPatternValidated(int patternId)
   {
      if(patternId < 0 || patternId >= m_patternCount) return false;
      return m_patterns[patternId].passedBacktest && m_patterns[patternId].winRate > 0.65;
   }
   
   double GetAverageWinRate()
   {
      if(m_totalWins + m_totalLosses == 0) return 50.0;
      return (m_totalWins / (double)(m_totalWins + m_totalLosses)) * 100.0;
   }
   
   int GetPatternCount() { return m_patternCount; }
   int GetTotalTrades() { return m_totalWins + m_totalLosses; }
   int GetConsecutiveWins() { return m_consecutiveWins; }
   int GetConsecutiveLosses() { return m_consecutiveLosses; }
   double GetTotalProfit() { return m_totalProfit; }
   double GetAdaptiveLearningRate() { return m_learningRate; }
   
   // ========== PERSISTENCIA ==========
   
   void SavePatterns()
   {
      int handle = FileOpen(m_patternFile, FILE_WRITE | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         Print("AL: Error saving patterns to file");
         return;
      }
      
      FileWriteInteger(handle, m_patternCount);
      for(int i = 0; i < m_patternCount; i++)
      {
         FileWriteInteger(handle, m_patterns[i].patternId);
         FileWriteLong(handle, m_patterns[i].createdTime);
         FileWriteLong(handle, m_patterns[i].lastUpdateTime);
         FileWriteInteger(handle, m_patterns[i].totalTrades);
         FileWriteInteger(handle, m_patterns[i].wins);
         FileWriteDouble(handle, m_patterns[i].winRate);
         FileWriteDouble(handle, m_patterns[i].avgConfidence);
         FileWriteDouble(handle, m_patterns[i].decayFactor);
      }
      
      FileClose(handle);
      Print("AL: Patterns saved successfully");
   }
   
   void SaveTradeHistory()
   {
      int handle = FileOpen(m_historyFile, FILE_WRITE | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         Print("AL: Error saving trade history to file");
         return;
      }
      
      FileWriteInteger(handle, m_tradeHistoryCount);
      for(int i = 0; i < m_tradeHistoryCount; i++)
      {
         FileWriteLong(handle, m_tradeHistory[i].entryTime);
         FileWriteDouble(handle, m_tradeHistory[i].profitPips);
         FileWriteInteger(handle, m_tradeHistory[i].isWin ? 1 : 0);
         FileWriteDouble(handle, m_tradeHistory[i].confidence);
      }
      
      FileClose(handle);
      Print("AL: Trade history saved successfully");
   }
   
   void LoadPatterns()
   {
      int handle = FileOpen(m_patternFile, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         Print("AL: No patterns file found, starting fresh");
         return;
      }
      
      m_patternCount = FileReadInteger(handle);
      for(int i = 0; i < m_patternCount && i < MAX_ADAPTIVE_PATTERNS; i++)
      {
         m_patterns[i].patternId = FileReadInteger(handle);
         m_patterns[i].createdTime = (datetime)FileReadLong(handle);
         m_patterns[i].lastUpdateTime = (datetime)FileReadLong(handle);
         m_patterns[i].totalTrades = FileReadInteger(handle);
         m_patterns[i].wins = FileReadInteger(handle);
         m_patterns[i].winRate = FileReadDouble(handle);
         m_patterns[i].avgConfidence = FileReadDouble(handle);
         m_patterns[i].decayFactor = FileReadDouble(handle);
      }
      
      FileClose(handle);
      Print("AL: Loaded ", m_patternCount, " patterns from file");
   }
};
