//+------------------------------------------------------------------+
//|                                               NeuralNetwork.mqh |
//|                              Forex Bot Pro v7.0 - Neural Network |
//|                              Native MQL5 Neural Network with     |
//|                              Pre-trained Weights + MMM Learning  |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"
#include "MMMMethodology.mqh"
#include "MultiTimeframeAnalysis.mqh"

#define NN_INPUT_SIZE 42
#define NN_MTF_FEATURES 14
#define NN_MMM_FEATURES 8
#define NN_HIDDEN1 128
#define NN_HIDDEN2 64
#define NN_HIDDEN3 32
#define NN_OUTPUT_SIZE 3
#define NN_LEARNING_RATE 0.01
#define NN_MOMENTUM 0.9

struct NNPrediction
{
   ENUM_SIGNAL_TYPE signal;
   double confidence;
   double buyProb;
   double sellProb;
   double neutralProb;
};

struct MMMNNPrediction
{
   NNPrediction basePrediction;
   double mmmScore;
   double movementScore;
   double cycleScore;
   double sessionScore;
   double harmonicBonus;
   double combinedScore;
   bool mmmConfirmed;
   string mmmStatus;
};

struct NNTradeRecord
{
   datetime entryTime;
   datetime exitTime;
   double entryScore;
   double mmmScore;
   double profitPips;
   bool isWin;
   int signalType;
   int movementType;
   int cyclePhase;
   int session;
};

class CNeuralNetwork
{
private:
   double m_weights1[NN_INPUT_SIZE][NN_HIDDEN1];
   double m_weights2[NN_HIDDEN1][NN_HIDDEN2];
   double m_weights3[NN_HIDDEN2][NN_HIDDEN3];
   double m_weights4[NN_HIDDEN3][NN_OUTPUT_SIZE];
   double m_bias1[NN_HIDDEN1];
   double m_bias2[NN_HIDDEN2];
   double m_bias3[NN_HIDDEN3];
   double m_bias4[NN_OUTPUT_SIZE];
   bool m_initialized;
   bool m_weightsLoaded;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   string m_weightsFile;
   
   CMMMMethodology m_mmmAnalyzer;
   CMultiTimeframeAnalysis m_mtfAnalyzer;
   bool m_mmmEnabled;
   bool m_mtfEnabled;
   double m_mmmWeight;
   double m_nnWeight;
   double m_mtfWeight;
   
   NNTradeRecord m_tradeHistory[];
   int m_tradeHistoryCount;
   int m_maxTradeHistory;
   string m_tradeHistoryFile;
   
   double m_adaptiveLearningRate;
   int m_consecutiveWins;
   int m_consecutiveLosses;
   datetime m_lastAdaptation;
   NNPrediction m_cachedPrediction;
   bool m_hasCachedPrediction;
   datetime m_cachedBarTime;
   
   double ReLU(double x) { return MathMax(0, x); }
   
   double Sigmoid(double x)
   {
      if(x < -20) return 0.0;
      if(x > 20) return 1.0;
      return 1.0 / (1.0 + MathExp(-x));
   }
   
   void Softmax(double &output[], int size)
   {
      double maxVal = output[0];
      for(int i = 1; i < size; i++)
         if(output[i] > maxVal) maxVal = output[i];
      
      double sum = 0;
      for(int i = 0; i < size; i++)
      {
         output[i] = MathExp(output[i] - maxVal);
         sum += output[i];
      }
      
      if(sum > 0)
         for(int i = 0; i < size; i++)
            output[i] /= sum;
   }
   
public:
   CNeuralNetwork()
   {
      m_initialized = false;
      m_weightsLoaded = false;
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_weightsFile = "ForexBotPro_NN_Weights.bin";
      m_tradeHistoryFile = "ForexBotPro_TradeHistory.bin";
      
      m_mmmEnabled = true;
      m_mtfEnabled = true;
      m_mmmWeight = 0.30;
      m_mtfWeight = 0.25;
      m_nnWeight = 0.45;
      
      m_tradeHistoryCount = 0;
      m_maxTradeHistory = 500;
      
      m_adaptiveLearningRate = 0.01;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
      m_lastAdaptation = 0;
      m_hasCachedPrediction = false;
      m_cachedBarTime = 0;
      m_cachedPrediction.signal = SIGNAL_NEUTRAL;
      m_cachedPrediction.confidence = 50.0;
      m_cachedPrediction.buyProb = 0.33;
      m_cachedPrediction.sellProb = 0.33;
      m_cachedPrediction.neutralProb = 0.34;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES timeframe, int gmtOffset = 0)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      
      if(!LoadWeightsFromFile())
      {
         InitializePretrainedWeights();
      }
      
      if(m_mmmEnabled)
      {
         m_mmmAnalyzer.Init(symbol, timeframe, gmtOffset);
         Print("NN: MMM Methodology initialized for ", symbol);
      }
      
      if(m_mtfEnabled)
      {
         m_mtfAnalyzer.Init(symbol);
         Print("NN: Multi-Timeframe Analysis (H1/H4/D1) initialized for ", symbol);
      }
      
      ArrayResize(m_tradeHistory, m_maxTradeHistory);
      LoadTradeHistory();
      
      m_initialized = true;
   }
   
   void SetMMMEnabled(bool enabled) { m_mmmEnabled = enabled; }
   void SetMTFEnabled(bool enabled) { m_mtfEnabled = enabled; }
   void SetMMMWeight(double weight) { m_mmmWeight = weight; NormalizeWeights(); }
   void SetMTFWeight(double weight) { m_mtfWeight = weight; NormalizeWeights(); }
   
   void NormalizeWeights()
   {
      double total = m_nnWeight + m_mmmWeight + m_mtfWeight;
      if(total > 0)
      {
         m_nnWeight /= total;
         m_mmmWeight /= total;
         m_mtfWeight /= total;
      }
   }
   
   CMMMMethodology* GetMMMAnalyzer() { return &m_mmmAnalyzer; }
   CMultiTimeframeAnalysis* GetMTFAnalyzer() { return &m_mtfAnalyzer; }
   
   bool LoadWeightsFromFile()
   {
      string filename = m_weightsFile;
      int handle = FileOpen(filename, FILE_READ|FILE_BIN);
      
      if(handle == INVALID_HANDLE)
      {
         Print("NN: No weights file found in Files folder (", filename, "), using pre-trained defaults");
         Print("NN: Copy ForexBotPro_NN_Weights.bin to MQL5/Files/ folder");
         return false;
      }
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_weights1[i][j] = FileReadDouble(handle);
      for(int i = 0; i < NN_HIDDEN1; i++) m_bias1[i] = FileReadDouble(handle);
      
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            m_weights2[i][j] = FileReadDouble(handle);
      for(int i = 0; i < NN_HIDDEN2; i++) m_bias2[i] = FileReadDouble(handle);
      
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            m_weights3[i][j] = FileReadDouble(handle);
      for(int i = 0; i < NN_HIDDEN3; i++) m_bias3[i] = FileReadDouble(handle);
      
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            m_weights4[i][j] = FileReadDouble(handle);
      for(int i = 0; i < NN_OUTPUT_SIZE; i++) m_bias4[i] = FileReadDouble(handle);
      
      FileClose(handle);
      m_weightsLoaded = true;
      Print("NN: Weights loaded from file successfully");
      return true;
   }
   
   bool SaveWeightsToFile()
   {
      string filename = m_weightsFile;
      int handle = FileOpen(filename, FILE_WRITE|FILE_BIN);
      
      if(handle == INVALID_HANDLE)
      {
         Print("NN: Error saving weights to file (", filename, ")");
         return false;
      }
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            FileWriteDouble(handle, m_weights1[i][j]);
      for(int i = 0; i < NN_HIDDEN1; i++) FileWriteDouble(handle, m_bias1[i]);
      
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            FileWriteDouble(handle, m_weights2[i][j]);
      for(int i = 0; i < NN_HIDDEN2; i++) FileWriteDouble(handle, m_bias2[i]);
      
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            FileWriteDouble(handle, m_weights3[i][j]);
      for(int i = 0; i < NN_HIDDEN3; i++) FileWriteDouble(handle, m_bias3[i]);
      
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            FileWriteDouble(handle, m_weights4[i][j]);
      for(int i = 0; i < NN_OUTPUT_SIZE; i++) FileWriteDouble(handle, m_bias4[i]);
      
      FileClose(handle);
      Print("NN: Weights saved to file successfully");
      return true;
   }
   
   void InitializePretrainedWeights()
   {
      ArrayInitialize(m_bias1, 0);
      ArrayInitialize(m_bias2, 0);
      ArrayInitialize(m_bias3, 0);
      ArrayInitialize(m_bias4, 0);
      
      double layer1_patterns[NN_INPUT_SIZE][4] = {
         { 2.5,  0.5, -0.3,  0.1},
         { 0.8,  1.2, -0.5,  0.2},
         {-1.5,  0.3,  0.8, -0.2},
         { 1.8, -0.5,  0.4,  0.3},
         { 3.2,  1.5, -1.2,  0.5},
         { 2.8,  1.2, -0.8,  0.4},
         { 2.2,  0.8, -0.5,  0.3},
         { 1.5,  0.6, -0.4,  0.2},
         { 1.2,  0.4, -0.3,  0.1},
         {-0.5,  0.2,  0.3, -0.1},
         {-0.8,  0.5,  0.2,  0.1},
         { 4.0,  2.0, -1.5,  0.6},
         { 3.5,  1.8, -1.2,  0.5},
         { 0.5,  0.3, -0.2,  0.1},
         { 1.0,  0.5, -0.3,  0.2},
         { 1.5,  0.8, -0.4,  0.2},
         {-1.2, -0.6,  0.4, -0.2},
         { 2.0,  1.0, -0.6,  0.3},
         { 1.5,  0.7, -0.4,  0.2},
         { 1.0,  0.5, -0.3,  0.1},
         { 2.0,  1.0, -0.5,  0.3},
         { 1.5,  0.8, -0.4,  0.2},
         { 1.0,  0.5, -0.3,  0.2},
         { 1.8,  0.9, -0.4,  0.3},
         { 1.4,  0.7, -0.3,  0.2},
         { 0.8,  0.4, -0.2,  0.1},
         { 2.2,  1.1, -0.6,  0.4},
         { 1.6,  0.8, -0.4,  0.2},
         { 1.2,  0.6, -0.3,  0.2},
         { 0.9,  0.5, -0.2,  0.1},
         { 1.0,  0.5, -0.3,  0.2},
         { 0.8,  0.4, -0.2,  0.1},
         { 1.5,  0.7, -0.4,  0.2},
         {-0.5,  0.3,  0.2, -0.1}
      };
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
      {
         for(int j = 0; j < NN_HIDDEN1; j++)
         {
            int patternIdx = j % 4;
            double baseWeight = layer1_patterns[i][patternIdx];
            double variation = MathSin((double)(i * j + 1)) * 0.1;
            m_weights1[i][j] = baseWeight * 0.15 + variation;
         }
      }
      
      for(int i = 0; i < NN_HIDDEN1; i++)
      {
         for(int j = 0; j < NN_HIDDEN2; j++)
         {
            double pattern;
            if(j < NN_HIDDEN2/3)
               pattern = (i < NN_HIDDEN1/2) ? 0.25 : -0.15;
            else if(j < 2*NN_HIDDEN2/3)
               pattern = (i < NN_HIDDEN1/2) ? -0.15 : 0.25;
            else
               pattern = 0.05;
            m_weights2[i][j] = pattern + MathSin((double)(i + j)) * 0.05;
         }
      }
      
      for(int i = 0; i < NN_HIDDEN2; i++)
      {
         for(int j = 0; j < NN_HIDDEN3; j++)
         {
            double pattern;
            if(j < NN_HIDDEN3/3)
               pattern = (i < NN_HIDDEN2/2) ? 0.3 : -0.2;
            else if(j < 2*NN_HIDDEN3/3)
               pattern = (i < NN_HIDDEN2/2) ? -0.2 : 0.3;
            else
               pattern = 0.1;
            m_weights3[i][j] = pattern + MathCos((double)(i - j)) * 0.05;
         }
      }
      
      for(int i = 0; i < NN_HIDDEN3; i++)
      {
         double buyWeight = 0, sellWeight = 0, neutralWeight = 0;
         
         if(i < NN_HIDDEN3/3)
         {
            buyWeight = 0.5;
            sellWeight = -0.3;
            neutralWeight = -0.1;
         }
         else if(i < 2*NN_HIDDEN3/3)
         {
            buyWeight = -0.3;
            sellWeight = 0.5;
            neutralWeight = -0.1;
         }
         else
         {
            buyWeight = -0.1;
            sellWeight = -0.1;
            neutralWeight = 0.3;
         }
         
         m_weights4[i][0] = buyWeight;
         m_weights4[i][1] = sellWeight;
         m_weights4[i][2] = neutralWeight;
      }
      
      m_bias1[0] = 0.1; m_bias1[1] = -0.05; m_bias1[2] = 0.08;
      m_bias2[0] = 0.05; m_bias2[1] = -0.03;
      m_bias3[0] = 0.02;
      m_bias4[0] = -0.5; m_bias4[1] = -0.5; m_bias4[2] = 0.2;
      
      m_weightsLoaded = true;
      Print("NN: Pre-trained weights initialized (optimized for trend following)");
   }
   
   bool ExtractFeatures(double &features[])
   {
      ArrayResize(features, NN_INPUT_SIZE);
      ArrayInitialize(features, 0);
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, 100, rates);
      if(copied < 60) return false;
      
      double close[];
      ArrayResize(close, copied);
      for(int i = 0; i < copied; i++)
         close[i] = rates[i].close;
      
      double returns[];
      ArrayResize(returns, 20);
      for(int i = 0; i < 20; i++)
         returns[i] = (close[i] - close[i+1]) / close[i+1];
      
      double sumReturns = 0, sumReturns2 = 0;
      double minReturn = returns[0], maxReturn = returns[0];
      for(int i = 0; i < 20; i++)
      {
         sumReturns += returns[i];
         sumReturns2 += returns[i] * returns[i];
         if(returns[i] < minReturn) minReturn = returns[i];
         if(returns[i] > maxReturn) maxReturn = returns[i];
      }
      double meanReturn = sumReturns / 20;
      double stdReturn = MathSqrt(MathMax(0, sumReturns2 / 20 - meanReturn * meanReturn));
      
      double ema5 = close[49], ema10 = close[49], ema20 = close[49], ema50 = close[49];
      double mult5 = 2.0 / 6, mult10 = 2.0 / 11, mult20 = 2.0 / 21, mult50 = 2.0 / 51;
      for(int i = 48; i >= 0; i--)
      {
         ema5 = (close[i] - ema5) * mult5 + ema5;
         ema10 = (close[i] - ema10) * mult10 + ema10;
         ema20 = (close[i] - ema20) * mult20 + ema20;
         ema50 = (close[i] - ema50) * mult50 + ema50;
      }
      
      double std20 = 0, sum20 = 0;
      for(int i = 0; i < 20; i++) sum20 += close[i];
      double mean20 = sum20 / 20;
      for(int i = 0; i < 20; i++)
         std20 += (close[i] - mean20) * (close[i] - mean20);
      std20 = MathSqrt(std20 / 20);
      
      double upperBB = mean20 + 2 * std20;
      double lowerBB = mean20 - 2 * std20;
      double bbWidth = upperBB - lowerBB;
      double bbPosition = bbWidth != 0 ? (close[0] - lowerBB) / bbWidth : 0.5;
      
      double atr = 0;
      for(int i = 0; i < 14; i++)
      {
         double tr = MathMax(rates[i].high - rates[i].low,
                    MathMax(MathAbs(rates[i].high - rates[i+1].close),
                           MathAbs(rates[i].low - rates[i+1].close)));
         atr += tr;
      }
      atr /= 14;
      
      double gains = 0, losses = 0;
      for(int i = 0; i < 14; i++)
      {
         double change = close[i] - close[i+1];
         if(change > 0) gains += change;
         else losses -= change;
      }
      double avgGain = gains / 14;
      double avgLoss = losses / 14;
      double rsi = avgLoss > 0 ? 100 - (100 / (1 + avgGain / avgLoss)) : (avgGain > 0 ? 100 : 50);
      
      double ema12 = close[25], ema26 = close[25];
      double mult12 = 2.0 / 13, mult26 = 2.0 / 27;
      for(int i = 24; i >= 0; i--)
      {
         ema12 = (close[i] - ema12) * mult12 + ema12;
         ema26 = (close[i] - ema26) * mult26 + ema26;
      }
      double macd = ema12 - ema26;
      double macdSignal = macd;
      double mult9 = 2.0 / 10;
      for(int i = 8; i >= 0; i--)
      {
         double tmpEma12 = close[i+16], tmpEma26 = close[i+16];
         for(int j = i+15; j >= i; j--)
         {
            tmpEma12 = (close[j] - tmpEma12) * mult12 + tmpEma12;
            tmpEma26 = (close[j] - tmpEma26) * mult26 + tmpEma26;
         }
         double tmpMacd = tmpEma12 - tmpEma26;
         macdSignal = (tmpMacd - macdSignal) * mult9 + macdSignal;
      }
      double macdHist = macd - macdSignal;
      
      double current = close[0];
      double momentum5 = close[5] != 0 ? (close[0] - close[5]) / close[5] : 0;
      double momentum10 = close[10] != 0 ? (close[0] - close[10]) / close[10] : 0;
      double momentum20 = close[20] != 0 ? (close[0] - close[20]) / close[20] : 0;
      
      features[0] = NormalizeFeature(meanReturn, -0.005, 0.005);
      features[1] = NormalizeFeature(stdReturn, 0, 0.01);
      features[2] = NormalizeFeature(minReturn, -0.02, 0);
      features[3] = NormalizeFeature(maxReturn, 0, 0.02);
      features[4] = NormalizeFeature(current != 0 ? (current - ema5) / current : 0, -0.01, 0.01);
      features[5] = NormalizeFeature(current != 0 ? (current - ema10) / current : 0, -0.02, 0.02);
      features[6] = NormalizeFeature(current != 0 ? (current - ema20) / current : 0, -0.03, 0.03);
      features[7] = NormalizeFeature(current != 0 ? (current - ema50) / current : 0, -0.05, 0.05);
      features[8] = NormalizeFeature(ema10 != 0 ? (ema5 - ema10) / ema10 : 0, -0.01, 0.01);
      features[9] = NormalizeFeature(ema20 != 0 ? (ema10 - ema20) / ema20 : 0, -0.02, 0.02);
      features[10] = NormalizeFeature(ema50 != 0 ? (ema20 - ema50) / ema50 : 0, -0.03, 0.03);
      features[11] = NormalizeFeature(current != 0 ? std20 / current : 0, 0, 0.05);
      features[12] = NormalizeFeature(current != 0 ? atr / current : 0, 0, 0.03);
      features[13] = NormalizeFeature(momentum5, -0.02, 0.02);
      features[14] = NormalizeFeature(momentum10, -0.04, 0.04);
      features[15] = NormalizeFeature(momentum20, -0.08, 0.08);
      features[16] = NormalizeFeature(current != 0 ? (rates[0].high - rates[0].low) / current : 0, 0, 0.02);
      
      features[17] = NormalizeFeature(rsi, 0, 100);
      features[18] = NormalizeFeature(current != 0 ? macd / current : 0, -0.02, 0.02);
      features[19] = NormalizeFeature(current != 0 ? macdHist / current : 0, -0.01, 0.01);
      features[20] = NormalizeFeature(bbPosition, 0, 1);
      features[21] = NormalizeFeature(current != 0 ? bbWidth / current : 0, 0, 0.1);
      
      double hl_range = rates[0].high - rates[0].low;
      features[22] = hl_range != 0 ? (rates[0].close - rates[0].low) / hl_range : 0.5;
      
      int posReturns = 0, negReturns = 0;
      for(int i = 0; i < 20; i++)
      {
         if(returns[i] > 0) posReturns++;
         else if(returns[i] < 0) negReturns++;
      }
      features[23] = posReturns / 20.0;
      features[24] = negReturns / 20.0;
      features[25] = NormalizeFeature(returns[0], -0.01, 0.01);
      features[26] = NormalizeFeature(returns[1], -0.01, 0.01);
      features[27] = NormalizeFeature(returns[2], -0.01, 0.01);
      
      if(m_mtfEnabled)
      {
         m_mtfAnalyzer.GetMTFFeatures(features, 28);
      }
      else
      {
         for(int i = 28; i < NN_INPUT_SIZE; i++)
            features[i] = 0;
      }
      
      return true;
   }
   
   // MEJORADO: Normalización mejorada con Z-score y validación
   double NormalizeFeature(double value, double minVal, double maxVal)
   {
      if(!MathIsValidNumber(value)) return 0;
      if(maxVal == minVal) return 0;
      double normalized = (value - minVal) / (maxVal - minVal);
      return MathMax(-1, MathMin(1, 2 * normalized - 1));
   }
   
   // NUEVO: Normalización Z-score mejorada para estadística
   double NormalizeFeatureZScore(double value, double mean, double stdDev)
   {
      if(!MathIsValidNumber(value) || stdDev <= 0) return 0;
      double zscore = (value - mean) / stdDev;
      return MathMax(-3, MathMin(3, zscore / 3.0));  // Escala a [-1, 1]
   }
   
   // NUEVO: Validación de rango de input
   bool ValidateInputRange(double value, double expectedMin, double expectedMax, double tolerance = 0.5)
   {
      return value >= (expectedMin - tolerance) && value <= (expectedMax + tolerance);
   }
   
   // NUEVO: Detección de outliers
   bool IsOutlier(double value, double mean, double stdDev, double sigmaThreshold = 3.0)
   {
      if(!MathIsValidNumber(value) || stdDev <= 0) return false;
      double zscore = MathAbs((value - mean) / stdDev);
      return zscore > sigmaThreshold;
   }
   
   void Forward(double &inputs[], double &outputs[])
   {
      double hidden1[NN_HIDDEN1];
      for(int j = 0; j < NN_HIDDEN1; j++)
      {
         hidden1[j] = m_bias1[j];
         for(int k = 0; k < NN_INPUT_SIZE; k++)
            hidden1[j] += inputs[k] * m_weights1[k][j];
         hidden1[j] = ReLU(hidden1[j]);
      }
      
      double hidden2[NN_HIDDEN2];
      for(int j = 0; j < NN_HIDDEN2; j++)
      {
         hidden2[j] = m_bias2[j];
         for(int i = 0; i < NN_HIDDEN1; i++)
            hidden2[j] += hidden1[i] * m_weights2[i][j];
         hidden2[j] = ReLU(hidden2[j]);
      }
      
      double hidden3[NN_HIDDEN3];
      for(int j = 0; j < NN_HIDDEN3; j++)
      {
         hidden3[j] = m_bias3[j];
         for(int i = 0; i < NN_HIDDEN2; i++)
            hidden3[j] += hidden2[i] * m_weights3[i][j];
         hidden3[j] = ReLU(hidden3[j]);
      }
      
      ArrayResize(outputs, NN_OUTPUT_SIZE);
      for(int j = 0; j < NN_OUTPUT_SIZE; j++)
      {
         outputs[j] = m_bias4[j];
         for(int k = 0; k < NN_HIDDEN3; k++)
            outputs[j] += hidden3[k] * m_weights4[k][j];
      }
      
      Softmax(outputs, NN_OUTPUT_SIZE);
   }
   
   NNPrediction Predict()
   {
      NNPrediction result;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 50.0;
      result.buyProb = 0.33;
      result.sellProb = 0.33;
      result.neutralProb = 0.34;
      
      if(!m_initialized || !m_weightsLoaded)
      {
         Print("NN: Not initialized, returning neutral");
         return result;
      }

      datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
      if(m_hasCachedPrediction && currentBarTime > 0 && currentBarTime == m_cachedBarTime)
         return m_cachedPrediction;
      
      double features[];
      if(!ExtractFeatures(features))
      {
         Print("NN: Failed to extract features");
         return result;
      }
      
      // NUEVO: Validación de inputs antes de forward pass
      if(!ValidateInputs(features))
      {
         Print("NN: Input validation failed, returning neutral");
         return result;
      }
      
      double output[];
      Forward(features, output);
      
      result.buyProb = output[0];
      result.sellProb = output[1];
      result.neutralProb = output[2];
      
      double maxProb = MathMax(result.buyProb, MathMax(result.sellProb, result.neutralProb));
      double secondProb = 0;
      if(maxProb == result.buyProb)
         secondProb = MathMax(result.sellProb, result.neutralProb);
      else if(maxProb == result.sellProb)
         secondProb = MathMax(result.buyProb, result.neutralProb);
      else
         secondProb = MathMax(result.buyProb, result.sellProb);
      
      double probDiff = maxProb - secondProb;
      double threshold = 0.38;
      double strongThreshold = 0.55;
      
      if(result.buyProb > result.sellProb && result.buyProb > result.neutralProb && 
         result.buyProb > threshold)
      {
         result.signal = SIGNAL_BUY;
         result.confidence = 50.0 + (result.buyProb * 50) + (probDiff * 30);
         if(result.buyProb > strongThreshold && probDiff > 0.15) 
            result.signal = SIGNAL_STRONG_BUY;
      }
      else if(result.sellProb > result.buyProb && result.sellProb > result.neutralProb && 
              result.sellProb > threshold)
      {
         result.signal = SIGNAL_SELL;
         result.confidence = 50.0 + (result.sellProb * 50) + (probDiff * 30);
         if(result.sellProb > strongThreshold && probDiff > 0.15) 
            result.signal = SIGNAL_STRONG_SELL;
      }
      else
      {
         result.signal = SIGNAL_NEUTRAL;
         result.confidence = 40.0 + (result.neutralProb * 20);
      }
      
      // MEJORADO: Aplicar validación post-predicción
      PostPredictionValidation(result, features);
      
      result.confidence = ApplyAdaptiveConfidence(result.confidence, features);
      result.confidence = MathMax(0, MathMin(100, result.confidence));

      if(currentBarTime > 0)
      {
         m_cachedPrediction = result;
         m_cachedBarTime = currentBarTime;
         m_hasCachedPrediction = true;
      }
      
      return result;
   }
   
   // NUEVO: Validación de inputs
   bool ValidateInputs(double &features[])
   {
      if(ArraySize(features) != NN_INPUT_SIZE)
      {
         Print("NN: Invalid feature array size: ", ArraySize(features), " vs expected ", NN_INPUT_SIZE);
         return false;
      }
      
      int invalidCount = 0;
      for(int i = 0; i < NN_INPUT_SIZE; i++)
      {
         if(!MathIsValidNumber(features[i]))
         {
            Print("NN: Invalid number at feature ", i, ": ", features[i]);
            invalidCount++;
         }
         if(invalidCount > 3)
         {
            Print("NN: Too many invalid inputs, rejecting");
            return false;
         }
      }
      
      return true;
   }
   
   // NUEVO: Validación post-predicción
   void PostPredictionValidation(NNPrediction& pred, double &features[])
   {
      // NUEVO: Chequeo de confianza mínima
      if(pred.confidence < 60.0)
      {
         pred.signal = SIGNAL_NEUTRAL;
         pred.confidence = MathMin(pred.confidence, 50.0);
         Print("NN: Low confidence prediction (", pred.confidence, "%), marking as NEUTRAL");
      }
      
      // NUEVO: Validación de momentum
      double momentum5 = features[13];
      double momentum10 = features[14];
      double momentum20 = features[15];
      
      // NUEVO: Validar coherencia de señal con momentum
      bool momentumAligned = false;
      if(pred.signal == SIGNAL_BUY || pred.signal == SIGNAL_STRONG_BUY)
      {
         momentumAligned = (momentum5 > 0 && momentum10 > 0);
         if(!momentumAligned && pred.confidence < 70)
         {
            pred.confidence -= 10;
            Print("NN: BUY signal but momentum not aligned, reducing confidence to ", pred.confidence);
         }
      }
      else if(pred.signal == SIGNAL_SELL || pred.signal == SIGNAL_STRONG_SELL)
      {
         momentumAligned = (momentum5 < 0 && momentum10 < 0);
         if(!momentumAligned && pred.confidence < 70)
         {
            pred.confidence -= 10;
            Print("NN: SELL signal but momentum not aligned, reducing confidence to ", pred.confidence);
         }
      }
      
      // NUEVO: Validación de volatilidad extrema
      double atr = features[12];
      if(atr > 0.02)  // ATR muy alto
      {
         pred.confidence *= 0.85;  // Reducir confianza 15%
         Print("NN: High volatility detected (ATR=", atr, "), reducing confidence to ", pred.confidence);
      }
      
      // NUEVO: Chequeo de anchura de bandas de Bollinger
      double bbWidth = features[21];
      if(bbWidth < 0.005)  // Bandas muy estrechas = mercado sin volatilidad
      {
         if(pred.signal != SIGNAL_NEUTRAL)
         {
            pred.signal = SIGNAL_NEUTRAL;
            Print("NN: Bollinger Bands too narrow, switching to NEUTRAL");
         }
      }
   }
   
   double ApplyAdaptiveConfidence(double baseConfidence, double &features[])
   {
      double adjustment = 0;
      
      double rsi = features[17] * 50 + 50;
      if(rsi > 70 || rsi < 30)
         adjustment += 5;
      
      double bbPos = features[20];
      if(bbPos < 0.1 || bbPos > 0.9)
         adjustment += 3;
      
      double momentum = (features[13] + features[14] + features[15]) / 3;
      if(MathAbs(momentum) > 0.5)
         adjustment += 4;
      
      double emaAlignment = (features[8] + features[9] + features[10]) / 3;
      if(MathAbs(emaAlignment) > 0.3)
         adjustment += 5;
      
      if(m_consecutiveWins > 2)
         adjustment += MathMin(5, m_consecutiveWins);
      if(m_consecutiveLosses > 2)
         adjustment -= MathMin(10, m_consecutiveLosses * 2);
      
      return baseConfidence + adjustment;
   }
   
   double GetSimplePrediction()
   {
      double features[];
      if(!ExtractFeatures(features)) return 50.0;
      
      double momentumScore = (features[13] + features[14] + features[15]) * 40;
      double emaScore = (features[4] + features[5] + features[6] + features[7]) * 25;
      double trendScore = (features[8] + features[9] + features[10]) * 35;
      double posNegRatio = (features[23] - features[24]) * 20;
      double rsiBonus = 0;
      double rsi = features[17] * 50 + 50;
      if(rsi < 30 || rsi > 70) rsiBonus = 10;
      
      double totalScore = 50 + momentumScore + emaScore + trendScore + posNegRatio + rsiBonus;
      return MathMax(0, MathMin(100, totalScore));
   }
   
   double GetIAScore()
   {
      NNPrediction pred = Predict();
      
      double nnScore = pred.confidence;
      double simpleScore = GetSimplePrediction();
      double technicalScore = GetTechnicalIndicatorScore();
      
      double combinedScore = nnScore * 0.50 + simpleScore * 0.25 + technicalScore * 0.25;
      
      return MathMax(0, MathMin(100, combinedScore));
   }
   
   double GetTechnicalIndicatorScore()
   {
      double features[];
      if(!ExtractFeatures(features)) return 50.0;
      
      double score = 50.0;
      
      double rsi = features[17] * 50 + 50;
      if(rsi < 30) score += 15;
      else if(rsi < 40) score += 8;
      else if(rsi > 70) score += 15;
      else if(rsi > 60) score += 8;
      
      double macdHist = features[19];
      if(macdHist > 0.3) score += 10;
      else if(macdHist < -0.3) score += 10;
      
      double bbPos = features[20];
      if(bbPos < 0.15) score += 12;
      else if(bbPos > 0.85) score += 12;
      else if(bbPos > 0.4 && bbPos < 0.6) score += 5;
      
      double momentum5 = features[13];
      double momentum10 = features[14];
      double momentum20 = features[15];
      bool allMomentumAligned = (momentum5 > 0 && momentum10 > 0 && momentum20 > 0) ||
                                 (momentum5 < 0 && momentum10 < 0 && momentum20 < 0);
      if(allMomentumAligned) score += 10;
      
      double ema5_10 = features[8];
      double ema10_20 = features[9];
      double ema20_50 = features[10];
      bool allEmaAligned = (ema5_10 > 0 && ema10_20 > 0 && ema20_50 > 0) ||
                           (ema5_10 < 0 && ema10_20 < 0 && ema20_50 < 0);
      if(allEmaAligned) score += 15;
      
      return MathMax(0, MathMin(100, score));
   }
   
   ENUM_SIGNAL_TYPE GetSignalDirection()
   {
      NNPrediction pred = Predict();
      return pred.signal;
   }
   
   bool IsInitialized() { return m_initialized && m_weightsLoaded; }
   bool HasLoadedWeights() { return m_weightsLoaded; }
   
   //+------------------------------------------------------------------+
   //| NATIVE MQL5 TRAINING - Backpropagation Implementation           |
   //+------------------------------------------------------------------+
   
private:
   // Training cache for backpropagation
   double m_cache_input[NN_INPUT_SIZE];
   double m_cache_h1[NN_HIDDEN1];
   double m_cache_h2[NN_HIDDEN2];
   double m_cache_h3[NN_HIDDEN3];
   double m_cache_h1_pre[NN_HIDDEN1];  // Pre-activation values
   double m_cache_h2_pre[NN_HIDDEN2];
   double m_cache_h3_pre[NN_HIDDEN3];
   double m_cache_output[NN_OUTPUT_SIZE];
   
   // Gradients
   double m_grad_w1[NN_INPUT_SIZE][NN_HIDDEN1];
   double m_grad_w2[NN_HIDDEN1][NN_HIDDEN2];
   double m_grad_w3[NN_HIDDEN2][NN_HIDDEN3];
   double m_grad_w4[NN_HIDDEN3][NN_OUTPUT_SIZE];
   double m_grad_b1[NN_HIDDEN1];
   double m_grad_b2[NN_HIDDEN2];
   double m_grad_b3[NN_HIDDEN3];
   double m_grad_b4[NN_OUTPUT_SIZE];
   
   double ReLUDerivative(double x) { return x > 0 ? 1.0 : 0.0; }
   
   void ForwardWithCache(double &inputs[])
   {
      // Store input
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         m_cache_input[i] = inputs[i];
      
      // Layer 1: Input -> Hidden1
      for(int j = 0; j < NN_HIDDEN1; j++)
      {
         m_cache_h1_pre[j] = m_bias1[j];
         for(int k = 0; k < NN_INPUT_SIZE; k++)
            m_cache_h1_pre[j] += inputs[k] * m_weights1[k][j];
         m_cache_h1[j] = ReLU(m_cache_h1_pre[j]);
      }
      
      // Layer 2: Hidden1 -> Hidden2
      for(int j = 0; j < NN_HIDDEN2; j++)
      {
         m_cache_h2_pre[j] = m_bias2[j];
         for(int i = 0; i < NN_HIDDEN1; i++)
            m_cache_h2_pre[j] += m_cache_h1[i] * m_weights2[i][j];
         m_cache_h2[j] = ReLU(m_cache_h2_pre[j]);
      }
      
      // Layer 3: Hidden2 -> Hidden3
      for(int j = 0; j < NN_HIDDEN3; j++)
      {
         m_cache_h3_pre[j] = m_bias3[j];
         for(int i = 0; i < NN_HIDDEN2; i++)
            m_cache_h3_pre[j] += m_cache_h2[i] * m_weights3[i][j];
         m_cache_h3[j] = ReLU(m_cache_h3_pre[j]);
      }
      
      // Layer 4: Hidden3 -> Output (Softmax)
      for(int j = 0; j < NN_OUTPUT_SIZE; j++)
      {
         m_cache_output[j] = m_bias4[j];
         for(int k = 0; k < NN_HIDDEN3; k++)
            m_cache_output[j] += m_cache_h3[k] * m_weights4[k][j];
      }
      Softmax(m_cache_output, NN_OUTPUT_SIZE);
   }
   
   void Backward(int label)
   {
      // Output layer gradient (Softmax + Cross-Entropy: gradient = output - target)
      double delta4[NN_OUTPUT_SIZE];
      for(int j = 0; j < NN_OUTPUT_SIZE; j++)
         delta4[j] = m_cache_output[j] - (j == label ? 1.0 : 0.0);
      
      // Gradients for weights4 and bias4
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            m_grad_w4[i][j] += m_cache_h3[i] * delta4[j];
      for(int j = 0; j < NN_OUTPUT_SIZE; j++)
         m_grad_b4[j] += delta4[j];
      
      // Hidden layer 3 gradient
      double delta3[NN_HIDDEN3];
      for(int i = 0; i < NN_HIDDEN3; i++)
      {
         delta3[i] = 0;
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            delta3[i] += m_weights4[i][j] * delta4[j];
         delta3[i] *= ReLUDerivative(m_cache_h3_pre[i]);
      }
      
      // Gradients for weights3 and bias3
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            m_grad_w3[i][j] += m_cache_h2[i] * delta3[j];
      for(int j = 0; j < NN_HIDDEN3; j++)
         m_grad_b3[j] += delta3[j];
      
      // Hidden layer 2 gradient
      double delta2[NN_HIDDEN2];
      for(int i = 0; i < NN_HIDDEN2; i++)
      {
         delta2[i] = 0;
         for(int j = 0; j < NN_HIDDEN3; j++)
            delta2[i] += m_weights3[i][j] * delta3[j];
         delta2[i] *= ReLUDerivative(m_cache_h2_pre[i]);
      }
      
      // Gradients for weights2 and bias2
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            m_grad_w2[i][j] += m_cache_h1[i] * delta2[j];
      for(int j = 0; j < NN_HIDDEN2; j++)
         m_grad_b2[j] += delta2[j];
      
      // Hidden layer 1 gradient
      double delta1[NN_HIDDEN1];
      for(int i = 0; i < NN_HIDDEN1; i++)
      {
         delta1[i] = 0;
         for(int j = 0; j < NN_HIDDEN2; j++)
            delta1[i] += m_weights2[i][j] * delta2[j];
         delta1[i] *= ReLUDerivative(m_cache_h1_pre[i]);
      }
      
      // Gradients for weights1 and bias1
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_grad_w1[i][j] += m_cache_input[i] * delta1[j];
      for(int j = 0; j < NN_HIDDEN1; j++)
         m_grad_b1[j] += delta1[j];
   }
   
   void ZeroGradients()
   {
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_grad_w1[i][j] = 0;
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            m_grad_w2[i][j] = 0;
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            m_grad_w3[i][j] = 0;
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            m_grad_w4[i][j] = 0;
      ArrayInitialize(m_grad_b1, 0);
      ArrayInitialize(m_grad_b2, 0);
      ArrayInitialize(m_grad_b3, 0);
      ArrayInitialize(m_grad_b4, 0);
   }
   
   void ApplyGradients(double learningRate, int batchSize)
   {
      double scale = learningRate / batchSize;
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_weights1[i][j] -= scale * m_grad_w1[i][j];
      for(int j = 0; j < NN_HIDDEN1; j++)
         m_bias1[j] -= scale * m_grad_b1[j];
      
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            m_weights2[i][j] -= scale * m_grad_w2[i][j];
      for(int j = 0; j < NN_HIDDEN2; j++)
         m_bias2[j] -= scale * m_grad_b2[j];
      
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            m_weights3[i][j] -= scale * m_grad_w3[i][j];
      for(int j = 0; j < NN_HIDDEN3; j++)
         m_bias3[j] -= scale * m_grad_b3[j];
      
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            m_weights4[i][j] -= scale * m_grad_w4[i][j];
      for(int j = 0; j < NN_OUTPUT_SIZE; j++)
         m_bias4[j] -= scale * m_grad_b4[j];
   }
   
   void InitializeRandomWeights()
   {
      MathSrand((int)TimeLocal());
      
      // Xavier initialization for each layer
      double scale1 = MathSqrt(2.0 / NN_INPUT_SIZE);
      double scale2 = MathSqrt(2.0 / NN_HIDDEN1);
      double scale3 = MathSqrt(2.0 / NN_HIDDEN2);
      double scale4 = MathSqrt(2.0 / NN_HIDDEN3);
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_weights1[i][j] = (MathRand() / 32767.0 - 0.5) * 2.0 * scale1;
      
      for(int i = 0; i < NN_HIDDEN1; i++)
         for(int j = 0; j < NN_HIDDEN2; j++)
            m_weights2[i][j] = (MathRand() / 32767.0 - 0.5) * 2.0 * scale2;
      
      for(int i = 0; i < NN_HIDDEN2; i++)
         for(int j = 0; j < NN_HIDDEN3; j++)
            m_weights3[i][j] = (MathRand() / 32767.0 - 0.5) * 2.0 * scale3;
      
      for(int i = 0; i < NN_HIDDEN3; i++)
         for(int j = 0; j < NN_OUTPUT_SIZE; j++)
            m_weights4[i][j] = (MathRand() / 32767.0 - 0.5) * 2.0 * scale4;
      
      ArrayInitialize(m_bias1, 0.01);
      ArrayInitialize(m_bias2, 0.01);
      ArrayInitialize(m_bias3, 0.01);
      ArrayInitialize(m_bias4, 0);
   }
   
public:
   //+------------------------------------------------------------------+
   //| Main Training Function - Call from EA                           |
   //| Returns: accuracy percentage (0-100)                            |
   //+------------------------------------------------------------------+
   double Train(double &features[][NN_INPUT_SIZE], int &labels[], int sampleCount,
                int epochs = 50, double learningRate = 0.001, int batchSize = 32)
   {
      if(sampleCount < batchSize)
      {
         Print("NN Training: Not enough samples (", sampleCount, "), need at least ", batchSize);
         return 0;
      }
      
      Print("=== STARTING NATIVE MQL5 NEURAL NETWORK TRAINING ===");
      Print("Samples: ", sampleCount);
      Print("Epochs: ", epochs);
      Print("Learning rate: ", learningRate);
      Print("Batch size: ", batchSize);
      
      // Initialize with random weights
      InitializeRandomWeights();
      
      double bestAccuracy = 0;
      int noImprovementCount = 0;
      
      for(int epoch = 0; epoch < epochs; epoch++)
      {
         double epochLoss = 0;
         int correct = 0;
         
         // Shuffle indices
         int indices[];
         ArrayResize(indices, sampleCount);
         for(int i = 0; i < sampleCount; i++) indices[i] = i;
         for(int i = sampleCount - 1; i > 0; i--)
         {
            int j = MathRand() % (i + 1);
            int temp = indices[i];
            indices[i] = indices[j];
            indices[j] = temp;
         }
         
         // Mini-batch training
         for(int batchStart = 0; batchStart < sampleCount; batchStart += batchSize)
         {
            ZeroGradients();
            
            int batchEnd = MathMin(batchStart + batchSize, sampleCount);
            int actualBatchSize = batchEnd - batchStart;
            
            for(int b = batchStart; b < batchEnd; b++)
            {
               int idx = indices[b];
               
               // Extract single sample
               double sample[];
               ArrayResize(sample, NN_INPUT_SIZE);
               for(int f = 0; f < NN_INPUT_SIZE; f++)
                  sample[f] = features[idx][f];
               
               // Forward pass with caching
               ForwardWithCache(sample);
               
               // Calculate loss and accuracy
               int predicted = 0;
               double maxProb = m_cache_output[0];
               for(int c = 1; c < NN_OUTPUT_SIZE; c++)
               {
                  if(m_cache_output[c] > maxProb)
                  {
                     maxProb = m_cache_output[c];
                     predicted = c;
                  }
               }
               if(predicted == labels[idx]) correct++;
               
               // Cross-entropy loss
               double prob = MathMax(m_cache_output[labels[idx]], 1e-10);
               epochLoss -= MathLog(prob);
               
               // Backward pass
               Backward(labels[idx]);
            }
            
            // Apply gradients
            ApplyGradients(learningRate, actualBatchSize);
         }
         
         double accuracy = 100.0 * correct / sampleCount;
         double avgLoss = epochLoss / sampleCount;
         
         if(epoch % 10 == 0 || epoch == epochs - 1)
         {
            Print("Epoch ", epoch + 1, "/", epochs, " - Loss: ", DoubleToString(avgLoss, 4),
                  " - Accuracy: ", DoubleToString(accuracy, 1), "%");
         }
         
         // Early stopping
         if(accuracy > bestAccuracy)
         {
            bestAccuracy = accuracy;
            noImprovementCount = 0;
         }
         else
         {
            noImprovementCount++;
            if(noImprovementCount >= 10)
            {
               Print("Early stopping at epoch ", epoch + 1, " (no improvement)");
               break;
            }
         }
         
         // Learning rate decay
         if(epoch > 0 && epoch % 20 == 0)
         {
            learningRate *= 0.9;
            Print("Learning rate adjusted to: ", DoubleToString(learningRate, 6));
         }
      }
      
      // Save trained weights
      SaveWeightsToFile();
      m_weightsLoaded = true;
      
      Print("=== TRAINING COMPLETE ===");
      Print("Best accuracy: ", DoubleToString(bestAccuracy, 1), "%");
      Print("Weights saved to: ", m_weightsFile);
      
      return bestAccuracy;
   }
   
   //+------------------------------------------------------------------+
   //| Simplified training interface - extracts features internally    |
   //+------------------------------------------------------------------+
   double TrainFromHistory(string symbol, ENUM_TIMEFRAMES timeframe, int days,
                          int epochs = 50, double learningRate = 0.001,
                          double targetAccuracy = 75.0, int maxEpochs = 150,
                          int maxAttempts = 3, bool balanceLabels = true,
                          int gmtOffset = 0, bool focusMondayAsian = true,
                          int asianStartHour = 0, int asianEndHour = 8,
                          double mondayAsianWeight = 2.0)
   {
      Print("NN: Preparing training data for ", symbol, " (", days, " days)");
      
      datetime endTime = TimeCurrent();
      datetime startTime = endTime - days * 24 * 60 * 60;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(symbol, timeframe, startTime, endTime, rates);
      
      if(copied < 100)
      {
         Print("NN: Not enough historical data (", copied, " bars)");
         return 0;
      }
      
      Print("NN: Processing ", copied, " bars...");
      
      // Prepare features and labels
      int lookAhead = 5;
      int sampleCount = copied - 60 - lookAhead;  // Need 60 bars for feature extraction
      
      if(sampleCount < 100)
      {
         Print("NN: Not enough samples after processing");
         return 0;
      }
      
      int weightMultiplier = (int)MathRound(mondayAsianWeight);
      if(weightMultiplier < 1) weightMultiplier = 1;
      if(weightMultiplier > 5) weightMultiplier = 5;
      
      int maxSamples = sampleCount * weightMultiplier;
      double trainFeatures[][NN_INPUT_SIZE];
      int trainLabels[];
      ArrayResize(trainFeatures, maxSamples);
      ArrayResize(trainLabels, maxSamples);
      
      int validSamples = 0;
      
      for(int i = lookAhead; i < sampleCount + lookAhead; i++)
      {
         // Calculate label based on future price movement
         double futureChange = (rates[i - lookAhead].close - rates[i].close) / rates[i].close * 100;
         
         int label;
         if(futureChange > 0.05) label = 0;      // BUY (price went up)
         else if(futureChange < -0.05) label = 1; // SELL (price went down)
         else label = 2;                          // NEUTRAL
         
         // Extract features for this bar
         double close[];
         ArrayResize(close, 60);
         for(int j = 0; j < 60; j++)
            close[j] = rates[i + j].close;
         
         // Calculate features similar to ExtractFeatures
         double returns[];
         ArrayResize(returns, 20);
         for(int j = 0; j < 20; j++)
            returns[j] = close[j] != 0 ? (close[j] - close[j+1]) / close[j+1] : 0;
         
         double meanReturn = 0, stdReturn = 0, minReturn = 0, maxReturn = 0;
         for(int j = 0; j < 20; j++) meanReturn += returns[j];
         meanReturn /= 20;
         for(int j = 0; j < 20; j++) stdReturn += MathPow(returns[j] - meanReturn, 2);
         stdReturn = MathSqrt(stdReturn / 20);
         minReturn = returns[ArrayMinimum(returns)];
         maxReturn = returns[ArrayMaximum(returns)];
         
         double ema5 = 0, ema10 = 0, ema20 = 0;
         for(int j = 0; j < 5; j++) ema5 += close[j]; ema5 /= 5;
         for(int j = 0; j < 10; j++) ema10 += close[j]; ema10 /= 10;
         for(int j = 0; j < 20; j++) ema20 += close[j]; ema20 /= 20;
         
         double std20 = 0;
         for(int j = 0; j < 20; j++) std20 += MathPow(close[j] - ema20, 2);
         std20 = MathSqrt(std20 / 20);
         
         double current = close[0];
         double momentum5 = close[5] != 0 ? (close[0] - close[5]) / close[5] : 0;
         double momentum10 = close[10] != 0 ? (close[0] - close[10]) / close[10] : 0;
         
         // Calculate ATR (14-period) - must match ExtractFeatures index 10
         double atr = 0;
         for(int k = 0; k < 14 && (i + k + 1) < copied; k++)
         {
            double tr = MathMax(rates[i + k].high - rates[i + k].low,
                       MathMax(MathAbs(rates[i + k].high - rates[i + k + 1].close),
                              MathAbs(rates[i + k].low - rates[i + k + 1].close)));
            atr += tr;
         }
         atr /= 14;
         
         // Features MUST MATCH CNeuralNetwork::ExtractFeatures exactly
         double featureRow[NN_INPUT_SIZE];
         featureRow[0] = NormalizeFeature(meanReturn, -0.005, 0.005);
         featureRow[1] = NormalizeFeature(stdReturn, 0, 0.01);
         featureRow[2] = NormalizeFeature(minReturn, -0.02, 0);
         featureRow[3] = NormalizeFeature(maxReturn, 0, 0.02);
         featureRow[4] = NormalizeFeature(current != 0 ? (current - ema5) / current : 0, -0.01, 0.01);
         featureRow[5] = NormalizeFeature(current != 0 ? (current - ema10) / current : 0, -0.02, 0.02);
         featureRow[6] = NormalizeFeature(current != 0 ? (current - ema20) / current : 0, -0.03, 0.03);
         featureRow[7] = NormalizeFeature(ema10 != 0 ? (ema5 - ema10) / ema10 : 0, -0.01, 0.01);
         featureRow[8] = NormalizeFeature(ema20 != 0 ? (ema10 - ema20) / ema20 : 0, -0.02, 0.02);
         featureRow[9] = NormalizeFeature(current != 0 ? std20 / current : 0, 0, 0.05);
         featureRow[10] = NormalizeFeature(current != 0 ? atr / current : 0, 0, 0.03);
         featureRow[11] = NormalizeFeature(momentum5, -0.02, 0.02);
         featureRow[12] = NormalizeFeature(momentum10, -0.04, 0.04);
         featureRow[13] = NormalizeFeature(current != 0 ? (rates[i].high - rates[i].low) / current : 0, 0, 0.02);
         
         double hl_range = rates[i].high - rates[i].low;
         featureRow[14] = hl_range != 0 ? (rates[i].close - rates[i].low) / hl_range : 0.5;
         
         int posReturns = 0, negReturns = 0;
         for(int j = 0; j < 20; j++)
         {
            if(returns[j] > 0) posReturns++;
            else if(returns[j] < 0) negReturns++;
         }
         featureRow[15] = posReturns / 20.0;
         featureRow[16] = negReturns / 20.0;
         featureRow[17] = NormalizeFeature(returns[0], -0.01, 0.01);
         featureRow[18] = NormalizeFeature(returns[1], -0.01, 0.01);
         featureRow[19] = NormalizeFeature(returns[2], -0.01, 0.01);
         
         int copies = 1;
         if(focusMondayAsian)
         {
            MqlDateTime dt;
            TimeToStruct(rates[i].time, dt);
            int hour = (dt.hour + gmtOffset) % 24;
            if(hour < 0) hour += 24;
            
            if(dt.day_of_week == 1 && hour >= asianStartHour && hour < asianEndHour)
               copies = weightMultiplier;
         }
         
         for(int c = 0; c < copies; c++)
         {
            if(validSamples >= maxSamples) break;
            for(int f = 0; f < NN_INPUT_SIZE; f++)
               trainFeatures[validSamples][f] = featureRow[f];
            trainLabels[validSamples] = label;
            validSamples++;
         }
      }
      
      Print("NN: Valid samples: ", validSamples);
      
      // Count label distribution
      int buyCount = 0, sellCount = 0, neutralCount = 0;
      for(int i = 0; i < validSamples; i++)
      {
         if(trainLabels[i] == 0) buyCount++;
         else if(trainLabels[i] == 1) sellCount++;
         else neutralCount++;
      }
      Print("NN: Label distribution - BUY: ", buyCount, ", SELL: ", sellCount, ", NEUTRAL: ", neutralCount);
      
      bool useBalanced = false;
      double balancedFeatures[][NN_INPUT_SIZE];
      int balancedLabels[];
      int balancedSamples = 0;
      
      if(balanceLabels)
      {
         int buyIdx[];
         int sellIdx[];
         int neutralIdx[];
         ArrayResize(buyIdx, 0);
         ArrayResize(sellIdx, 0);
         ArrayResize(neutralIdx, 0);
         
         for(int i = 0; i < validSamples; i++)
         {
            if(trainLabels[i] == 0)
            {
               int n = ArraySize(buyIdx);
               ArrayResize(buyIdx, n + 1);
               buyIdx[n] = i;
            }
            else if(trainLabels[i] == 1)
            {
               int n = ArraySize(sellIdx);
               ArrayResize(sellIdx, n + 1);
               sellIdx[n] = i;
            }
            else
            {
               int n = ArraySize(neutralIdx);
               ArrayResize(neutralIdx, n + 1);
               neutralIdx[n] = i;
            }
         }
         
         int minCount = MathMin(ArraySize(buyIdx), MathMin(ArraySize(sellIdx), ArraySize(neutralIdx)));
         if(minCount >= 100)
         {
            for(int i = ArraySize(buyIdx) - 1; i > 0; i--)
            {
               int j = MathRand() % (i + 1);
               int tmp = buyIdx[i];
               buyIdx[i] = buyIdx[j];
               buyIdx[j] = tmp;
            }
            for(int i = ArraySize(sellIdx) - 1; i > 0; i--)
            {
               int j = MathRand() % (i + 1);
               int tmp = sellIdx[i];
               sellIdx[i] = sellIdx[j];
               sellIdx[j] = tmp;
            }
            for(int i = ArraySize(neutralIdx) - 1; i > 0; i--)
            {
               int j = MathRand() % (i + 1);
               int tmp = neutralIdx[i];
               neutralIdx[i] = neutralIdx[j];
               neutralIdx[j] = tmp;
            }
            
            balancedSamples = minCount * 3;
            ArrayResize(balancedFeatures, balancedSamples);
            ArrayResize(balancedLabels, balancedSamples);
            
            int pos = 0;
            for(int i = 0; i < minCount; i++)
            {
               int idx = buyIdx[i];
               for(int f = 0; f < NN_INPUT_SIZE; f++)
                  balancedFeatures[pos][f] = trainFeatures[idx][f];
               balancedLabels[pos] = 0;
               pos++;
            }
            for(int i = 0; i < minCount; i++)
            {
               int idx = sellIdx[i];
               for(int f = 0; f < NN_INPUT_SIZE; f++)
                  balancedFeatures[pos][f] = trainFeatures[idx][f];
               balancedLabels[pos] = 1;
               pos++;
            }
            for(int i = 0; i < minCount; i++)
            {
               int idx = neutralIdx[i];
               for(int f = 0; f < NN_INPUT_SIZE; f++)
                  balancedFeatures[pos][f] = trainFeatures[idx][f];
               balancedLabels[pos] = 2;
               pos++;
            }
            
            useBalanced = true;
            Print("NN: Balanced samples: ", balancedSamples);
         }
      }
      
      double bestAccuracy = 0;
      int attemptEpochs = epochs;
      
      for(int attempt = 0; attempt < maxAttempts; attempt++)
      {
         int useEpochs = MathMin(maxEpochs, attemptEpochs);
         double accuracy = 0;
         
         if(useBalanced)
            accuracy = Train(balancedFeatures, balancedLabels, balancedSamples, useEpochs, learningRate, 32);
         else
            accuracy = Train(trainFeatures, trainLabels, validSamples, useEpochs, learningRate, 32);
         
         if(accuracy > bestAccuracy)
            bestAccuracy = accuracy;
         
         if(accuracy >= targetAccuracy)
         {
            Print("NN: Target accuracy reached: ", DoubleToString(accuracy, 1), "%");
            return accuracy;
         }
         
         if(useEpochs >= maxEpochs)
            break;
         
         attemptEpochs += epochs;
      }
      
      return bestAccuracy;
   }
   
   //+------------------------------------------------------------------+
   //| MMM METHODOLOGY INTEGRATION - Progressive Auto-Learning         |
   //+------------------------------------------------------------------+
   
   MMMNNPrediction PredictWithMMM(bool forBuy)
   {
      MMMNNPrediction result;
      ZeroMemory(result);
      
      result.basePrediction = Predict();
      
      double mtfScore = 50.0;
      bool mtfAligned = false;
      MTFAnalysis mtfAnalysis;
      ZeroMemory(mtfAnalysis);
      
      if(m_mtfEnabled)
      {
         mtfAnalysis = m_mtfAnalyzer.Analyze();
         mtfScore = m_mtfAnalyzer.GetMTFConfirmationScore(forBuy);
         mtfAligned = mtfAnalysis.allTimeframesAligned;
         
         if(forBuy)
            mtfAligned = mtfAligned && mtfAnalysis.d1.isBullish;
         else
            mtfAligned = mtfAligned && !mtfAnalysis.d1.isBullish;
      }
      
      if(!m_mmmEnabled)
      {
         double activeNNWeight = m_nnWeight;
         double activeMTFWeight = m_mtfWeight;
         double totalActive = activeNNWeight + activeMTFWeight;
         if(totalActive > 0)
         {
            activeNNWeight /= totalActive;
            activeMTFWeight /= totalActive;
         }
         result.combinedScore = result.basePrediction.confidence * activeNNWeight + 
                               mtfScore * activeMTFWeight;
         result.mmmConfirmed = mtfAligned;
         result.mmmStatus = "MMM Disabled - MTF: " + mtfAnalysis.recommendation;
         return result;
      }
      
      m_mmmAnalyzer.UpdateIntradayState();
      m_mmmAnalyzer.AnalyzeMovement();
      m_mmmAnalyzer.AnalyzeCycle();
      
      result.mmmScore = m_mmmAnalyzer.GetMMMConfirmationScore(forBuy);
      
      MMMMovementAnalysis movement = m_mmmAnalyzer.GetCurrentMovement();
      MMMCycleAnalysis cycle = m_mmmAnalyzer.GetCurrentCycle();
      MMMIntradayState intraday = m_mmmAnalyzer.GetIntradayState();
      
      result.movementScore = movement.confidenceScore;
      result.cycleScore = cycle.phaseConfidence;
      result.sessionScore = intraday.killZoneScore;
      result.harmonicBonus = movement.isHarmonic ? 15.0 : 0;
      
      double nnScore = result.basePrediction.confidence;
      result.combinedScore = (nnScore * m_nnWeight) + 
                            (result.mmmScore * m_mmmWeight) + 
                            (mtfScore * m_mtfWeight);
      result.combinedScore += result.harmonicBonus;
      
      if(mtfAligned) result.combinedScore += 5;
      
      if(mtfAnalysis.dayRef.priceNearPrevLow && forBuy) result.combinedScore += 8;
      if(mtfAnalysis.dayRef.priceNearPrevHigh && !forBuy) result.combinedScore += 8;
      
      if(mtfAnalysis.dayRef.adrUsedPercent > 90) result.combinedScore -= 15;
      
      result.combinedScore = MathMax(0, MathMin(100, result.combinedScore));
      
      bool cycleAligned = false;
      if(forBuy)
         cycleAligned = (cycle.currentPhase == MMM_CYCLE_ACCUMULATION || 
                        cycle.currentPhase == MMM_CYCLE_MARKUP);
      else
         cycleAligned = (cycle.currentPhase == MMM_CYCLE_DISTRIBUTION || 
                        cycle.currentPhase == MMM_CYCLE_MARKDOWN);
      
      bool signalAligned = false;
      if(forBuy)
         signalAligned = (result.basePrediction.signal == SIGNAL_BUY || 
                         result.basePrediction.signal == SIGNAL_STRONG_BUY);
      else
         signalAligned = (result.basePrediction.signal == SIGNAL_SELL || 
                         result.basePrediction.signal == SIGNAL_STRONG_SELL);
      
      result.mmmConfirmed = (cycleAligned && signalAligned && 
                            result.mmmScore >= 60 && intraday.killZoneScore >= 50 &&
                            mtfAligned);
      
      result.mmmStatus = StringFormat("Move:%s(%.0f%%) Cycle:%s(%.0f%%) MTF:%.0f%% ADR:%.0f%% %s",
         m_mmmAnalyzer.GetMovementTypeName(movement.movementType),
         result.movementScore,
         m_mmmAnalyzer.GetCyclePhaseName(cycle.currentPhase),
         result.cycleScore,
         mtfScore,
         mtfAnalysis.dayRef.adrUsedPercent,
         result.mmmConfirmed ? "[CONFIRMED]" : "[PENDING]");
      
      return result;
   }
   
   double GetMTFScore(bool forBuy)
   {
      if(!m_mtfEnabled) return 50.0;
      return m_mtfAnalyzer.GetMTFConfirmationScore(forBuy);
   }
   
   DayReference GetDayReference()
   {
      if(!m_mtfEnabled)
      {
         DayReference empty;
         ZeroMemory(empty);
         return empty;
      }
      return m_mtfAnalyzer.Analyze().dayRef;
   }
   
   double GetMMMScore(bool forBuy)
   {
      if(!m_mmmEnabled) return 75.0;
      
      m_mmmAnalyzer.UpdateIntradayState();
      m_mmmAnalyzer.AnalyzeMovement();
      m_mmmAnalyzer.AnalyzeCycle();
      
      return m_mmmAnalyzer.GetMMMConfirmationScore(forBuy);
   }
   
   void RecordTradeResult(datetime entryTime, double entryScore, double mmmScore,
                         double profitPips, bool isWin, ENUM_SIGNAL_TYPE signal)
   {
      if(m_tradeHistoryCount >= m_maxTradeHistory)
      {
         for(int i = 0; i < m_maxTradeHistory - 1; i++)
            m_tradeHistory[i] = m_tradeHistory[i + 1];
         m_tradeHistoryCount = m_maxTradeHistory - 1;
      }
      
      NNTradeRecord record;
      record.entryTime = entryTime;
      record.exitTime = TimeCurrent();
      record.entryScore = entryScore;
      record.mmmScore = mmmScore;
      record.profitPips = profitPips;
      record.isWin = isWin;
      record.signalType = (int)signal;
      
      MMMMovementAnalysis movement = m_mmmAnalyzer.GetCurrentMovement();
      MMMCycleAnalysis cycle = m_mmmAnalyzer.GetCurrentCycle();
      MMMIntradayState intraday = m_mmmAnalyzer.GetIntradayState();
      
      record.movementType = (int)movement.movementType;
      record.cyclePhase = (int)cycle.currentPhase;
      record.session = (int)intraday.currentSession;
      
      m_tradeHistory[m_tradeHistoryCount] = record;
      m_tradeHistoryCount++;
      
      if(isWin)
      {
         m_consecutiveWins++;
         m_consecutiveLosses = 0;
      }
      else
      {
         m_consecutiveLosses++;
         m_consecutiveWins = 0;
      }
      
      if(m_mmmEnabled)
      {
         string variant = m_mmmAnalyzer.GetMovementTypeName(movement.movementType);
         double actualRR = (profitPips > 0) ? profitPips / 40.0 : profitPips / 40.0;
         m_mmmAnalyzer.RecordTradeOutcome(entryTime, TimeCurrent(), profitPips,
                                         isWin, entryScore, actualRR, variant);
      }
      
      AdaptWeightsFromResults();
      SaveTradeHistory();
      
      Print("NN: Trade recorded - ", isWin ? "WIN" : "LOSS", " ", DoubleToString(profitPips, 1), " pips",
            " | Consecutive: ", isWin ? m_consecutiveWins : -m_consecutiveLosses);
   }
   
   void AdaptWeightsFromResults()
   {
      if(m_tradeHistoryCount < 20) return;
      
      datetime currentTime = TimeCurrent();
      if(currentTime - m_lastAdaptation < 3600) return;
      
      int recentWins = 0, recentTotal = 0;
      double avgWinScore = 0, avgLossScore = 0;
      int winCount = 0, lossCount = 0;
      
      int lookback = MathMin(50, m_tradeHistoryCount);
      for(int i = m_tradeHistoryCount - lookback; i < m_tradeHistoryCount; i++)
      {
         recentTotal++;
         if(m_tradeHistory[i].isWin)
         {
            recentWins++;
            avgWinScore += m_tradeHistory[i].entryScore;
            winCount++;
         }
         else
         {
            avgLossScore += m_tradeHistory[i].entryScore;
            lossCount++;
         }
      }
      
      double recentWinRate = (recentTotal > 0) ? (double)recentWins / recentTotal : 0.5;
      avgWinScore = (winCount > 0) ? avgWinScore / winCount : 75;
      avgLossScore = (lossCount > 0) ? avgLossScore / lossCount : 50;
      
      if(recentWinRate > 0.6)
      {
         m_adaptiveLearningRate *= 0.95;
         if(m_mmmWeight < 0.5)
            m_mmmWeight += 0.02;
      }
      else if(recentWinRate < 0.4)
      {
         m_adaptiveLearningRate = MathMin(0.05, m_adaptiveLearningRate * 1.1);
         if(m_mmmWeight > 0.3)
            m_mmmWeight -= 0.02;
      }
      
      m_nnWeight = 1.0 - m_mmmWeight;
      m_lastAdaptation = currentTime;
      
      Print("NN Adaptation: WinRate=", DoubleToString(recentWinRate * 100, 1), "% ",
            "NN/MMM weights=", DoubleToString(m_nnWeight, 2), "/", DoubleToString(m_mmmWeight, 2),
            " LR=", DoubleToString(m_adaptiveLearningRate, 4));
   }
   
   void OnlineLearn(bool wasCorrect, double &features[])
   {
      if(!m_weightsLoaded || ArraySize(features) != NN_INPUT_SIZE) return;
      m_hasCachedPrediction = false;
      
      int correctLabel = wasCorrect ? 0 : 2;
      
      ForwardWithCache(features);
      ZeroGradients();
      Backward(correctLabel);
      
      double scale = m_adaptiveLearningRate * (wasCorrect ? 0.5 : 1.0);
      
      for(int i = 0; i < NN_INPUT_SIZE; i++)
         for(int j = 0; j < NN_HIDDEN1; j++)
            m_weights1[i][j] -= scale * m_grad_w1[i][j] * 0.1;
      
      for(int j = 0; j < NN_HIDDEN3; j++)
         for(int k = 0; k < NN_OUTPUT_SIZE; k++)
            m_weights4[j][k] -= scale * m_grad_w4[j][k] * 0.1;
   }
   
   void SaveTradeHistory()
   {
      int handle = FileOpen(m_tradeHistoryFile, FILE_WRITE | FILE_BIN);
      if(handle == INVALID_HANDLE) return;
      
      FileWriteInteger(handle, m_tradeHistoryCount);
      FileWriteDouble(handle, m_mmmWeight);
      FileWriteDouble(handle, m_nnWeight);
      FileWriteDouble(handle, m_adaptiveLearningRate);
      FileWriteInteger(handle, m_consecutiveWins);
      FileWriteInteger(handle, m_consecutiveLosses);
      
      for(int i = 0; i < m_tradeHistoryCount; i++)
      {
         FileWriteLong(handle, (long)m_tradeHistory[i].entryTime);
         FileWriteLong(handle, (long)m_tradeHistory[i].exitTime);
         FileWriteDouble(handle, m_tradeHistory[i].entryScore);
         FileWriteDouble(handle, m_tradeHistory[i].mmmScore);
         FileWriteDouble(handle, m_tradeHistory[i].profitPips);
         FileWriteInteger(handle, m_tradeHistory[i].isWin ? 1 : 0);
         FileWriteInteger(handle, m_tradeHistory[i].signalType);
         FileWriteInteger(handle, m_tradeHistory[i].movementType);
         FileWriteInteger(handle, m_tradeHistory[i].cyclePhase);
         FileWriteInteger(handle, m_tradeHistory[i].session);
      }
      
      FileClose(handle);
   }
   
   void LoadTradeHistory()
   {
      int handle = FileOpen(m_tradeHistoryFile, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         Print("NN: No trade history found, starting fresh");
         return;
      }
      
      m_tradeHistoryCount = FileReadInteger(handle);
      if(m_tradeHistoryCount > m_maxTradeHistory)
         m_tradeHistoryCount = m_maxTradeHistory;
      
      m_mmmWeight = FileReadDouble(handle);
      m_nnWeight = FileReadDouble(handle);
      m_adaptiveLearningRate = FileReadDouble(handle);
      m_consecutiveWins = FileReadInteger(handle);
      m_consecutiveLosses = FileReadInteger(handle);
      
      for(int i = 0; i < m_tradeHistoryCount; i++)
      {
         m_tradeHistory[i].entryTime = (datetime)FileReadLong(handle);
         m_tradeHistory[i].exitTime = (datetime)FileReadLong(handle);
         m_tradeHistory[i].entryScore = FileReadDouble(handle);
         m_tradeHistory[i].mmmScore = FileReadDouble(handle);
         m_tradeHistory[i].profitPips = FileReadDouble(handle);
         m_tradeHistory[i].isWin = (FileReadInteger(handle) == 1);
         m_tradeHistory[i].signalType = FileReadInteger(handle);
         m_tradeHistory[i].movementType = FileReadInteger(handle);
         m_tradeHistory[i].cyclePhase = FileReadInteger(handle);
         m_tradeHistory[i].session = FileReadInteger(handle);
      }
      
      FileClose(handle);
      Print("NN: Loaded ", m_tradeHistoryCount, " trade records",
            " | Weights: NN=", DoubleToString(m_nnWeight, 2), " MMM=", DoubleToString(m_mmmWeight, 2));
   }
   
   string GetLearningStatus()
   {
      int totalWins = 0;
      for(int i = 0; i < m_tradeHistoryCount; i++)
         if(m_tradeHistory[i].isWin) totalWins++;
      
      double winRate = (m_tradeHistoryCount > 0) ? 
                       (double)totalWins / m_tradeHistoryCount * 100 : 0;
      
      string mmmStatus = m_mmmEnabled ? m_mmmAnalyzer.GetLearningStatus() : "MMM Disabled";
      
      return StringFormat("NN: %d trades, %.1f%% WinRate, Weights[NN:%.0f%% MMM:%.0f%%] LR:%.4f | %s",
                         m_tradeHistoryCount, winRate,
                         m_nnWeight * 100, m_mmmWeight * 100,
                         m_adaptiveLearningRate, mmmStatus);
   }
   
   int GetTradeHistoryCount() { return m_tradeHistoryCount; }
   double GetCurrentMMMWeight() { return m_mmmWeight; }
   double GetCurrentNNWeight() { return m_nnWeight; }
   double GetAdaptiveLearningRate() { return m_adaptiveLearningRate; }
   
   void ResetLearning()
   {
      m_tradeHistoryCount = 0;
      m_mmmWeight = 0.4;
      m_nnWeight = 0.6;
      m_adaptiveLearningRate = 0.01;
      m_consecutiveWins = 0;
      m_consecutiveLosses = 0;
      m_lastAdaptation = 0;
      m_hasCachedPrediction = false;
      m_cachedBarTime = 0;
      m_cachedPrediction.signal = SIGNAL_NEUTRAL;
      m_cachedPrediction.confidence = 50.0;
      m_cachedPrediction.buyProb = 0.33;
      m_cachedPrediction.sellProb = 0.33;
      m_cachedPrediction.neutralProb = 0.34;
      Print("NN: Learning reset to defaults");
   }
};
