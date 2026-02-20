//+------------------------------------------------------------------+
//|                                            MultiPairScanner.mqh |
//|                              Forex Bot Pro v7.0 - Multi-Pair    |
//|                              Scanner with Dashboard Panel        |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"
#include "TDI.mqh"
#include "CandlePatterns.mqh"
#include "ChartPatterns.mqh"
#include "SupportResistance.mqh"
#include "NeuralNetwork.mqh"
#include "MarketAlignment.mqh"
#include "MarketMakerAnalysis.mqh"
#include <Trade\Trade.mqh>

#define MAX_PAIRS 28
#define TRAINING_DAYS 90

struct PairAnalysis
{
   string symbol;
   bool active;
   bool hasOpenOrder;
   double iaScore;
   double technicalScore;
   double alignmentScore;
   double combinedScore;
   ENUM_SIGNAL_TYPE signal;
   string tdiStatus;
   string candlePattern;
   string chartPattern;
   string emaStatus;
   string mtfStatus;
   datetime lastUpdate;
   color signalColor;
   double scanProgress;
};

class CMultiPairScanner
{
private:
   string m_symbols[];
   int m_symbolCount;
   PairAnalysis m_analysis[];
   ENUM_TIMEFRAMES m_primaryTF;
   ENUM_TIMEFRAMES m_secondaryTF;
   double m_minConfidence;
   ulong m_magicNumber;
   
   CTDIIndicator m_tdi[];
   CCandlePatternDetector m_candleDetector[];
   CChartPatternDetector m_chartDetector[];
   CSupportResistanceAnalyzer m_srAnalyzer[];
   CNeuralNetwork m_neuralNet[];
   CMarketAlignment m_alignment[];
   CMarketMakerAnalysis m_marketMaker[];
   
   bool m_useMarketMaker;
   double m_mmWeight;
   int m_gmtOffset;
   
   bool m_panelCreated;
   int m_panelX;
   int m_panelY;
   int m_panelWidth;
   int m_rowHeight;
   int m_colWidth;
   
   bool m_isTraining;
   int m_trainProgress;
   int m_currentScanIndex;
   bool m_isScanning;
   int m_scanBatchSize;
   int m_nextScanStart;
   
public:
   CMultiPairScanner()
   {
      m_symbolCount = 0;
      m_primaryTF = PERIOD_M15;
      m_secondaryTF = PERIOD_M30;
      m_minConfidence = 85.0;
      m_magicNumber = 123456;
      m_panelCreated = false;
      m_panelX = 10;          // ✅ POSICIÓN FIJA: 10px desde la izquierda
      m_panelY = 30;
      m_panelWidth = 340;
      m_rowHeight = 20;
      m_colWidth = 30;
      m_isTraining = false;
      m_trainProgress = 0;
      m_currentScanIndex = 0;
      m_isScanning = false;
      m_scanBatchSize = 0;
      m_nextScanStart = 0;
      m_useMarketMaker = true;
      m_mmWeight = 0.25;
      m_gmtOffset = 0;
   }
   
   void SetMarketMakerParams(bool enabled, double weight, int gmtOffset)
   {
      m_useMarketMaker = enabled;
      m_mmWeight = weight;
      m_gmtOffset = gmtOffset;
   }
   
   ~CMultiPairScanner()
   {
      DeletePanel();
   }
   
   void Init(ENUM_TIMEFRAMES primary, ENUM_TIMEFRAMES secondary, double minConf)
   {
      m_primaryTF = primary;
      m_secondaryTF = secondary;
      m_minConfidence = minConf;
   }
   
   void SetMagicNumber(ulong magic) { m_magicNumber = magic; }
   void SetScanBatchSize(int batchSize) { m_scanBatchSize = MathMax(0, batchSize); }
   
   bool AddSymbol(string symbol)
   {
      if(m_symbolCount >= MAX_PAIRS) return false;
      
      if(!SymbolSelect(symbol, true))
      {
         Print("Scanner: Symbol not available: ", symbol);
         return false;
      }
      
      ArrayResize(m_symbols, m_symbolCount + 1);
      ArrayResize(m_analysis, m_symbolCount + 1);
      ArrayResize(m_tdi, m_symbolCount + 1);
      ArrayResize(m_candleDetector, m_symbolCount + 1);
      ArrayResize(m_chartDetector, m_symbolCount + 1);
      ArrayResize(m_srAnalyzer, m_symbolCount + 1);
      ArrayResize(m_neuralNet, m_symbolCount + 1);
      ArrayResize(m_alignment, m_symbolCount + 1);
      ArrayResize(m_marketMaker, m_symbolCount + 1);
      
      m_symbols[m_symbolCount] = symbol;
      
      m_analysis[m_symbolCount].symbol = symbol;
      m_analysis[m_symbolCount].active = true;
      m_analysis[m_symbolCount].hasOpenOrder = false;
      m_analysis[m_symbolCount].iaScore = 0;
      m_analysis[m_symbolCount].technicalScore = 0;
      m_analysis[m_symbolCount].alignmentScore = 0;
      m_analysis[m_symbolCount].combinedScore = 0;
      m_analysis[m_symbolCount].signal = SIGNAL_NEUTRAL;
      m_analysis[m_symbolCount].lastUpdate = 0;
      m_analysis[m_symbolCount].signalColor = clrGray;
      m_analysis[m_symbolCount].scanProgress = 0;
      
      m_tdi[m_symbolCount].Init(symbol, m_primaryTF, 13, 2, 7, 34);
      m_candleDetector[m_symbolCount].Init(symbol, m_primaryTF);
      m_chartDetector[m_symbolCount].Init(symbol, m_primaryTF, 100);
      m_srAnalyzer[m_symbolCount].Init(symbol, m_primaryTF, 100);
      m_neuralNet[m_symbolCount].Init(symbol, m_primaryTF);
      m_alignment[m_symbolCount].Init(symbol, m_primaryTF, m_secondaryTF, 21, 50, 200, 800);
      m_marketMaker[m_symbolCount].Initialize(symbol, m_primaryTF, m_gmtOffset);
      
      m_symbolCount++;
      Print("Scanner: Added symbol ", symbol, " (Total: ", m_symbolCount, ")");
      return true;
   }
   
   void AddDefaultPairs()
   {
      string majors[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD"};
      string crosses[] = {"EURGBP", "EURJPY", "GBPJPY", "AUDJPY", "CADJPY", "CHFJPY"};
      string minors[] = {"EURAUD", "EURNZD", "EURCAD", "GBPAUD", "GBPNZD", "GBPCAD"};
      
      for(int i = 0; i < ArraySize(majors); i++)
      {
         if(!AddSymbol(majors[i]))
            AddSymbol(majors[i] + "m");
      }
      
      for(int i = 0; i < ArraySize(crosses); i++)
      {
         if(!AddSymbol(crosses[i]))
            AddSymbol(crosses[i] + "m");
      }
      
      for(int i = 0; i < ArraySize(minors); i++)
      {
         if(!AddSymbol(minors[i]))
            AddSymbol(minors[i] + "m");
      }
   }
   
   void ScanAll()
   {
      m_isScanning = true;
      UpdateOpenOrders();

      if(m_symbolCount <= 0)
      {
         m_isScanning = false;
         return;
      }

      int start = 0;
      int end = m_symbolCount;
      if(m_scanBatchSize > 0 && m_scanBatchSize < m_symbolCount)
      {
         start = m_nextScanStart;
         if(start < 0 || start >= m_symbolCount)
            start = 0;
         end = MathMin(start + m_scanBatchSize, m_symbolCount);
      }

      for(int i = start; i < end; i++)
      {
         m_currentScanIndex = i;
         m_analysis[i].scanProgress = 0;

         UpdateScanProgress(i, 10);
         ScanSymbol(i);
         UpdateScanProgress(i, 100);
      }

      if(m_scanBatchSize > 0 && m_scanBatchSize < m_symbolCount)
      {
         m_nextScanStart = end;
         if(m_nextScanStart >= m_symbolCount)
            m_nextScanStart = 0;
      }
      else
      {
         m_nextScanStart = 0;
      }

      UpdatePanel();

      m_isScanning = false;
      m_currentScanIndex = -1;
   }

   void UpdateScanProgress(int index, double progress)
   {
      if(index >= 0 && index < m_symbolCount)
      {
         m_analysis[index].scanProgress = progress;
      }
   }
   
   void UpdateOpenOrders()
   {
      for(int i = 0; i < m_symbolCount; i++)
      {
         m_analysis[i].hasOpenOrder = false;
      }
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber || m_magicNumber == 0)
            {
               string posSymbol = PositionGetString(POSITION_SYMBOL);
               for(int j = 0; j < m_symbolCount; j++)
               {
                  if(m_symbols[j] == posSymbol)
                  {
                     m_analysis[j].hasOpenOrder = true;
                     break;
                  }
               }
            }
         }
      }
   }
   
   void ScanSymbol(int index)
   {
      if(index < 0 || index >= m_symbolCount) return;
      
      string symbol = m_symbols[index];
      UpdateScanProgress(index, 20);
      
      double iaScore = m_neuralNet[index].GetIAScore();
      ENUM_SIGNAL_TYPE nnSignal = m_neuralNet[index].GetSignalDirection();
      UpdateScanProgress(index, 35);
      
      TDIResult tdiResult = m_tdi[index].Calculate(100);
      UpdateScanProgress(index, 50);
      
      CandlePatternResult candleResult = m_candleDetector[index].DetectPattern(10);
      ChartPatternResult chartResult = m_chartDetector[index].DetectAll();
      BreakoutResult breakout = m_srAnalyzer[index].CheckBreakout();
      UpdateScanProgress(index, 70);
      
      AlignmentResult emaResult = m_alignment[index].GetEMAAlignment();
      UpdateScanProgress(index, 85);
      
      double technicalScore = 50.0;
      int signals = 0;
      
      if(tdiResult.signal == SIGNAL_STRONG_BUY || tdiResult.signal == SIGNAL_STRONG_SELL)
      {
         technicalScore += 25;
         signals++;
      }
      else if(tdiResult.signal == SIGNAL_BUY || tdiResult.signal == SIGNAL_SELL)
      {
         technicalScore += 15;
         signals++;
      }
      
      if(candleResult.pattern != PATTERN_NONE)
      {
         technicalScore += (candleResult.confidence - 50) * 0.3;
         signals++;
      }
      
      if(chartResult.pattern != CHART_PATTERN_NONE)
      {
         technicalScore += (chartResult.confidence - 50) * 0.4;
         signals++;
      }
      
      if(breakout.detected)
      {
         technicalScore += 15;
         signals++;
      }
      
      if(signals > 2)
         technicalScore += 10;
      
      if(m_useMarketMaker)
      {
         m_marketMaker[index].Analyze();
         double mmScore = m_marketMaker[index].GetTotalScore();
         
         if(m_marketMaker[index].IsStopHuntDetected())
         {
            technicalScore += 15;
            signals++;
         }
         
         if(m_marketMaker[index].GetPattern() != MM_PATTERN_NONE)
         {
            technicalScore += 10;
            signals++;
         }
         
         technicalScore = technicalScore * (1.0 - m_mmWeight) + mmScore * m_mmWeight;
      }
      
      technicalScore = MathMax(0, MathMin(100, technicalScore));
      
      ENUM_SIGNAL_TYPE techSignal = SIGNAL_NEUTRAL;
      int buySignals = 0;
      int sellSignals = 0;
      
      if(tdiResult.signal == SIGNAL_BUY || tdiResult.signal == SIGNAL_STRONG_BUY)
         buySignals++;
      else if(tdiResult.signal == SIGNAL_SELL || tdiResult.signal == SIGNAL_STRONG_SELL)
         sellSignals++;
      
      if(tdiResult.sharkFinBullish)
         buySignals++;
      else if(tdiResult.sharkFinBearish)
         sellSignals++;
      
      if(candleResult.signal == SIGNAL_BUY || candleResult.signal == SIGNAL_STRONG_BUY)
         buySignals++;
      else if(candleResult.signal == SIGNAL_SELL || candleResult.signal == SIGNAL_STRONG_SELL)
         sellSignals++;
      
      if(chartResult.signal == SIGNAL_BUY || chartResult.signal == SIGNAL_STRONG_BUY)
         buySignals++;
      else if(chartResult.signal == SIGNAL_SELL || chartResult.signal == SIGNAL_STRONG_SELL)
         sellSignals++;
      
      if(m_useMarketMaker)
      {
         ENUM_SIGNAL_TYPE mmSignal = m_marketMaker[index].GetMMSignal();
         if(mmSignal == SIGNAL_BUY)
            buySignals += 2;
         else if(mmSignal == SIGNAL_SELL)
            sellSignals += 2;
      }
      
      if(buySignals >= 2 && buySignals > sellSignals)
         techSignal = buySignals >= 4 ? SIGNAL_STRONG_BUY : (buySignals >= 3 ? SIGNAL_BUY : SIGNAL_WEAK_BUY);
      else if(sellSignals >= 2 && sellSignals > buySignals)
         techSignal = sellSignals >= 4 ? SIGNAL_STRONG_SELL : (sellSignals >= 3 ? SIGNAL_SELL : SIGNAL_WEAK_SELL);
      
      if(techSignal == SIGNAL_NEUTRAL && nnSignal != SIGNAL_NEUTRAL)
      {
         if(nnSignal == SIGNAL_BUY || nnSignal == SIGNAL_STRONG_BUY)
            techSignal = SIGNAL_WEAK_BUY;
         else if(nnSignal == SIGNAL_SELL || nnSignal == SIGNAL_STRONG_SELL)
            techSignal = SIGNAL_WEAK_SELL;
      }
      
      bool isBuy = (techSignal == SIGNAL_BUY || techSignal == SIGNAL_STRONG_BUY ||
                    techSignal == SIGNAL_WEAK_BUY || techSignal == SIGNAL_MODERATE_BUY);
      double alignmentScore = m_alignment[index].GetAlignmentScore(isBuy);
      
      double combinedScore = (iaScore * 0.35) + (technicalScore * 0.35) + (alignmentScore * 0.30);
      
      m_analysis[index].iaScore = iaScore;
      m_analysis[index].technicalScore = technicalScore;
      m_analysis[index].alignmentScore = alignmentScore;
      m_analysis[index].combinedScore = combinedScore;
      m_analysis[index].signal = techSignal;
      m_analysis[index].lastUpdate = TimeCurrent();
      
      switch(tdiResult.signal)
      {
         case SIGNAL_STRONG_BUY: m_analysis[index].tdiStatus = "BUY++"; break;
         case SIGNAL_BUY: m_analysis[index].tdiStatus = "BUY"; break;
         case SIGNAL_STRONG_SELL: m_analysis[index].tdiStatus = "SELL--"; break;
         case SIGNAL_SELL: m_analysis[index].tdiStatus = "SELL"; break;
         default: m_analysis[index].tdiStatus = "---"; break;
      }
      
      m_analysis[index].candlePattern = candleResult.pattern != PATTERN_NONE ? 
                                        candleResult.name : "---";
      m_analysis[index].chartPattern = chartResult.pattern != CHART_PATTERN_NONE ? 
                                       chartResult.name : "---";
      
      switch(emaResult.direction)
      {
         case TREND_BULLISH: m_analysis[index].emaStatus = "BULL"; break;
         case TREND_BEARISH: m_analysis[index].emaStatus = "BEAR"; break;
         default: m_analysis[index].emaStatus = "FLAT"; break;
      }
      
      m_analysis[index].mtfStatus = m_alignment[index].CheckMTFAlignment() ? "OK" : "NO";
      
      if(m_analysis[index].hasOpenOrder)
      {
         m_analysis[index].signalColor = clrDodgerBlue;
      }
      else if(combinedScore >= m_minConfidence)
      {
         if(techSignal == SIGNAL_BUY || techSignal == SIGNAL_STRONG_BUY)
            m_analysis[index].signalColor = clrLime;
         else if(techSignal == SIGNAL_SELL || techSignal == SIGNAL_STRONG_SELL)
            m_analysis[index].signalColor = clrRed;
         else
            m_analysis[index].signalColor = clrYellow;
      }
      else
      {
         m_analysis[index].signalColor = clrGray;
      }
      
      UpdateScanProgress(index, 100);
   }
   
   void CreatePanel()
   {
      DeletePanel();
      int visibleRows = MathMin(m_symbolCount, 15);
      int panelPadding = 12;
      int headerHeight = m_rowHeight + 6;
      int headerRowHeight = m_rowHeight + 4;
      int contentWidth = m_panelWidth - panelPadding * 2;
      int symbolWidth = MathMax(110, MathMin(160, contentWidth / 2));
      int valueWidth = MathMax(40, (contentWidth - symbolWidth) / 3);
      m_colWidth = valueWidth;
      int totalWidth = m_panelWidth;
      int totalHeight = headerHeight + headerRowHeight + visibleRows * m_rowHeight + 30;
      
      long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      long maxPanelX = chartWidth - totalWidth - 10;
      long maxPanelY = chartHeight - totalHeight - 10;
      m_panelX = (int)MathMax(10, MathMin((long)m_panelX, maxPanelX));
      m_panelY = (int)MathMax(30, MathMin((long)m_panelY, maxPanelY));
      
      ObjectCreate(0, "FBP_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_XDISTANCE, m_panelX - 5);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_YDISTANCE, m_panelY - 5);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_XSIZE, totalWidth);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_YSIZE, totalHeight);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_BGCOLOR, C'18,22,28');
      ObjectSetInteger(0, "FBP_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_COLOR, C'65,105,225');
      ObjectSetInteger(0, "FBP_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "FBP_BG", OBJPROP_BACK, true);
      
      if(ObjectFind(0, "FBP_Header") < 0)
         ObjectCreate(0, "FBP_Header", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_XDISTANCE, m_panelX - 3);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_YDISTANCE, m_panelY - 3);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_XSIZE, totalWidth - 4);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_YSIZE, headerHeight);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_BGCOLOR, C'25,42,86');
      ObjectSetInteger(0, "FBP_Header", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_COLOR, C'65,105,225');
      ObjectSetInteger(0, "FBP_Header", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "FBP_Header", OBJPROP_BACK, true);
      
      CreateLabel("FBP_Title", m_panelX + panelPadding, m_panelY + 3, 
                  "MULTI-PAIR SCANNER", C'255,255,255', 10);
      
      if(ObjectFind(0, "FBP_ColsBG") < 0)
         ObjectCreate(0, "FBP_ColsBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_XDISTANCE, m_panelX - 3);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_YDISTANCE, m_panelY + headerHeight);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_XSIZE, totalWidth - 4);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_YSIZE, headerRowHeight);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_BGCOLOR, C'30,38,48');
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_COLOR, C'65,105,225');
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "FBP_ColsBG", OBJPROP_BACK, true);
      
      string headers[] = {"SYMBOL", "IA%", "TECH%", "TOTAL%"};
      int headerX[] = {m_panelX + panelPadding,
                       m_panelX + panelPadding + symbolWidth,
                       m_panelX + panelPadding + symbolWidth + valueWidth,
                       m_panelX + panelPadding + symbolWidth + valueWidth * 2};
      for(int i = 0; i < ArraySize(headers); i++)
      {
         CreateLabel("FBP_H" + IntegerToString(i), 
                     headerX[i], m_panelY + headerHeight + 3,
                     headers[i], C'150,170,190', 9);
      }
      
      m_panelCreated = true;
      UpdatePanel();
   }
   
   void UpdatePanel()
   {
      if(!m_panelCreated) CreatePanel();
      
      int visibleRows = MathMin(m_symbolCount, 15);
      int panelPadding = 12;
      int headerHeight = m_rowHeight + 6;
      int headerRowHeight = m_rowHeight + 4;
      int contentWidth = m_panelWidth - panelPadding * 2;
      int symbolWidth = MathMax(110, MathMin(160, contentWidth / 2));
      int valueWidth = MathMax(40, (contentWidth - symbolWidth) / 3);
      int startY = m_panelY + headerHeight + headerRowHeight + 4;
      
      for(int i = 0; i < visibleRows; i++)
      {
         int y = startY + i * m_rowHeight;
         string prefix = "FBP_R" + IntegerToString(i) + "_";
         
         color rowColor = m_analysis[i].signalColor;
         color bgColor = m_analysis[i].hasOpenOrder ? C'25,42,86' : C'30,38,48';
         
         int rowWidth = m_panelWidth - 10;
         CreateRowBackground(prefix + "BG", m_panelX - 3, y - 2, 
                            rowWidth, m_rowHeight - 2, bgColor);
         
         int x0 = m_panelX + panelPadding;
         CreateLabel(prefix + "0", x0, y, m_analysis[i].symbol, rowColor, 9);
         CreateLabel(prefix + "1", x0 + symbolWidth, y, 
                     DoubleToString(m_analysis[i].iaScore, 0), 
                     GetScoreColor(m_analysis[i].iaScore), 9);
         CreateLabel(prefix + "2", x0 + symbolWidth + valueWidth, y, 
                     DoubleToString(m_analysis[i].technicalScore, 0), 
                     GetScoreColor(m_analysis[i].technicalScore), 9);
         CreateLabel(prefix + "3", x0 + symbolWidth + valueWidth * 2, y, 
                     DoubleToString(m_analysis[i].combinedScore, 0), 
                     GetCombinedColor(m_analysis[i].combinedScore), 9);
      }
      
      int btnW = 120;
      int btnH = 24;
      int btnX = m_panelX + m_panelWidth - btnW - 10;
      int btnY = m_panelY - btnH - 6;
      string btnText = m_isTraining ? "TRAINING..." : "TRAIN IA";
      CreateButton("FBP_FloatTrainBtn", btnX, btnY, btnW, btnH, 
                   btnText, C'255,255,255', C'25,42,86');
      
      ChartRedraw(0);
   }
   
   void DeletePanel()
   {
      ObjectsDeleteAll(0, "FBP_");
      m_panelCreated = false;
   }
   
   bool HandleChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == "FBP_TrainBtn" || sparam == "FBP_FloatTrainBtn")
         {
            Print("Training button clicked - Starting 90-day NN training...");
            StartTraining();
            return true;
         }
         else if(sparam == "FBP_ScanBtn")
         {
            Print("Scan button clicked - Starting full scan...");
            ScanAll();
            return true;
         }
      }
      return false;
   }
   
   void StartTraining()
   {
      if(m_isTraining)
      {
         Print("Training already in progress...");
         return;
      }
      
      m_isTraining = true;
      m_trainProgress = 0;
      UpdatePanel();
      
      Print("=== STARTING NATIVE MQL5 NEURAL NETWORK TRAINING ===");
      Print("Period: ", TRAINING_DAYS, " days");
      Print("Pairs: ", m_symbolCount);
      Print("No Python required - training directly in MQL5!");
      
      // Collect training data from all pairs
      datetime endTime = TimeCurrent();
      datetime startTime = endTime - TRAINING_DAYS * 24 * 60 * 60;
      
      // Estimate total samples needed
      int estimatedSamplesPerPair = TRAINING_DAYS * 96;  // M15 = 96 bars per day
      int maxSamples = m_symbolCount * estimatedSamplesPerPair;
      
      double allFeatures[][42];  // NN_INPUT_SIZE = 42
      int allLabels[];
      ArrayResize(allFeatures, maxSamples);
      ArrayResize(allLabels, maxSamples);
      
      int totalSamples = 0;
      
      for(int pairIdx = 0; pairIdx < m_symbolCount; pairIdx++)
      {
         string symbol = m_symbols[pairIdx];
         Print("Extracting features: ", symbol, " (", pairIdx + 1, "/", m_symbolCount, ")");
         
         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         int copied = CopyRates(symbol, m_primaryTF, startTime, endTime, rates);
         
         if(copied < 100)
         {
            Print("WARNING: Not enough data for ", symbol, " (", copied, " bars)");
            continue;
         }
         
         int lookAhead = 5;
         int startBar = 60;  // Need 60 bars for feature calculation
         
         for(int i = lookAhead; i < copied - startBar; i++)
         {
            // Calculate label based on future price movement
            double futureChange = (rates[i - lookAhead].close - rates[i].close) / rates[i].close * 100;
            
            int label;
            if(futureChange > 0.05) label = 0;       // BUY (price went up)
            else if(futureChange < -0.05) label = 1; // SELL (price went down)
            else label = 2;                          // NEUTRAL
            
            // Extract close prices
            double close[];
            ArrayResize(close, 60);
            for(int j = 0; j < 60; j++)
               close[j] = rates[i + j].close;
            
            // Calculate returns
            double returns[];
            ArrayResize(returns, 20);
            for(int j = 0; j < 20; j++)
               returns[j] = close[j+1] != 0 ? (close[j] - close[j+1]) / close[j+1] : 0;
            
            // Calculate statistics
            double meanReturn = 0;
            for(int j = 0; j < 20; j++) meanReturn += returns[j];
            meanReturn /= 20;
            
            double stdReturn = 0;
            for(int j = 0; j < 20; j++) stdReturn += MathPow(returns[j] - meanReturn, 2);
            stdReturn = MathSqrt(stdReturn / 20);
            
            double minReturn = returns[ArrayMinimum(returns)];
            double maxReturn = returns[ArrayMaximum(returns)];
            
            // Calculate EMAs
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
            
            // Calculate ATR (14-period)
            double atr = 0;
            for(int k = 0; k < 14 && (i + k + 1) < copied; k++)
            {
               double tr = MathMax(rates[i + k].high - rates[i + k].low,
                          MathMax(MathAbs(rates[i + k].high - rates[i + k + 1].close),
                                 MathAbs(rates[i + k].low - rates[i + k + 1].close)));
               atr += tr;
            }
            atr /= 14;
            
            // Normalize features
            allFeatures[totalSamples][0] = NormalizeFeature(meanReturn, -0.005, 0.005);
            allFeatures[totalSamples][1] = NormalizeFeature(stdReturn, 0, 0.01);
            allFeatures[totalSamples][2] = NormalizeFeature(minReturn, -0.02, 0);
            allFeatures[totalSamples][3] = NormalizeFeature(maxReturn, 0, 0.02);
            allFeatures[totalSamples][4] = NormalizeFeature(current != 0 ? (current - ema5) / current : 0, -0.01, 0.01);
            allFeatures[totalSamples][5] = NormalizeFeature(current != 0 ? (current - ema10) / current : 0, -0.02, 0.02);
            allFeatures[totalSamples][6] = NormalizeFeature(current != 0 ? (current - ema20) / current : 0, -0.03, 0.03);
            allFeatures[totalSamples][7] = NormalizeFeature(ema10 != 0 ? (ema5 - ema10) / ema10 : 0, -0.01, 0.01);
            allFeatures[totalSamples][8] = NormalizeFeature(ema20 != 0 ? (ema10 - ema20) / ema20 : 0, -0.02, 0.02);
            allFeatures[totalSamples][9] = NormalizeFeature(current != 0 ? std20 / current : 0, 0, 0.05);
            allFeatures[totalSamples][10] = NormalizeFeature(current != 0 ? atr / current : 0, 0, 0.03);
            allFeatures[totalSamples][11] = NormalizeFeature(momentum5, -0.02, 0.02);
            allFeatures[totalSamples][12] = NormalizeFeature(momentum10, -0.04, 0.04);
            allFeatures[totalSamples][13] = NormalizeFeature(current != 0 ? (rates[i].high - rates[i].low) / current : 0, 0, 0.02);
            
            double hl_range = rates[i].high - rates[i].low;
            allFeatures[totalSamples][14] = hl_range != 0 ? (rates[i].close - rates[i].low) / hl_range : 0.5;
            
            int posReturns = 0, negReturns = 0;
            for(int j = 0; j < 20; j++)
            {
               if(returns[j] > 0) posReturns++;
               else if(returns[j] < 0) negReturns++;
            }
            allFeatures[totalSamples][15] = posReturns / 20.0;
            allFeatures[totalSamples][16] = negReturns / 20.0;
            allFeatures[totalSamples][17] = NormalizeFeature(returns[0], -0.01, 0.01);
            allFeatures[totalSamples][18] = NormalizeFeature(returns[1], -0.01, 0.01);
            allFeatures[totalSamples][19] = NormalizeFeature(returns[2], -0.01, 0.01);
            
            // MTF features 20-41 (14 MTF + 8 MMM features, initialized to neutral)
            for(int f = 20; f < 42; f++)
               allFeatures[totalSamples][f] = 0.0;
            
            allLabels[totalSamples] = label;
            totalSamples++;
            
            // Check array bounds
            if(totalSamples >= maxSamples - 1)
            {
               maxSamples += 10000;
               ArrayResize(allFeatures, maxSamples);
               ArrayResize(allLabels, maxSamples);
            }
         }
         
         m_trainProgress = (int)((pairIdx + 1) * 50.0 / m_symbolCount);
         UpdatePanel();
      }
      
      // Trim arrays
      ArrayResize(allFeatures, totalSamples);
      ArrayResize(allLabels, totalSamples);
      
      Print("Total training samples: ", totalSamples);
      
      // Count label distribution
      int buyCount = 0, sellCount = 0, neutralCount = 0;
      for(int i = 0; i < totalSamples; i++)
      {
         if(allLabels[i] == 0) buyCount++;
         else if(allLabels[i] == 1) sellCount++;
         else neutralCount++;
      }
      Print("Label distribution - BUY: ", buyCount, ", SELL: ", sellCount, ", NEUTRAL: ", neutralCount);
      
      if(totalSamples < 100)
      {
         Print("ERROR: Not enough training samples");
         m_isTraining = false;
         Alert("Training failed: Not enough data");
         return;
      }
      
      // Train the neural network
      Print("Starting backpropagation training...");
      m_trainProgress = 50;
      UpdatePanel();
      
      CNeuralNetwork trainNN;
      trainNN.Init(m_symbols[0], m_primaryTF);
      
      double accuracy = trainNN.Train(allFeatures, allLabels, totalSamples, 50, 0.001, 32);
      
      m_trainProgress = 100;
      m_isTraining = false;
      
      Print("=== NATIVE MQL5 TRAINING COMPLETE ===");
      Print("Final accuracy: ", DoubleToString(accuracy, 1), "%");
      Print("Weights saved to: ForexBotPro_NN_Weights.bin");
      Print("Reload EA to use new weights, or they will be loaded on next restart");
      
      string msg = "Training Complete!\nAccuracy: " + DoubleToString(accuracy, 1) + "%\nNo Python required!";
      Alert(msg);
      
      UpdatePanel();
   }
   
   double NormalizeFeature(double value, double minVal, double maxVal)
   {
      if(!MathIsValidNumber(value)) return 0;
      if(maxVal == minVal) return 0;
      double normalized = (value - minVal) / (maxVal - minVal);
      return MathMax(-1, MathMin(1, 2 * normalized - 1));
   }
   
   int GetSymbolCount() { return m_symbolCount; }
   bool IsTraining() { return m_isTraining; }
   int GetTrainProgress() { return m_trainProgress; }
   
   PairAnalysis GetAnalysis(int index)
   {
      PairAnalysis empty;
      if(index < 0 || index >= m_symbolCount) return empty;
      return m_analysis[index];
   }
   
   void AnalyzeSymbol(string symbol)
   {
      int idx = FindSymbolIndex(symbol);
      if(idx < 0)
      {
         if(AddSymbol(symbol))
            idx = FindSymbolIndex(symbol);
      }
      
      if(idx >= 0)
      {
         ScanSymbol(idx);
      }
   }
   
   PairAnalysis GetAnalysisBySymbol(string symbol)
   {
      PairAnalysis empty;
      int idx = FindSymbolIndex(symbol);
      if(idx >= 0)
         return m_analysis[idx];
      return empty;
   }
   
   int FindSymbolIndex(string symbol)
   {
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_symbols[i] == symbol)
            return i;
      }
      return -1;
   }
   
   PairAnalysis GetBestSignal()
   {
      PairAnalysis best;
      best.combinedScore = 0;
      best.signal = SIGNAL_NEUTRAL;
      
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_analysis[i].combinedScore >= m_minConfidence &&
            m_analysis[i].signal != SIGNAL_NEUTRAL &&
            !m_analysis[i].hasOpenOrder)
         {
            if(m_analysis[i].combinedScore > best.combinedScore)
               best = m_analysis[i];
         }
      }
      
      return best;
   }
   
   void GetSignalsAboveThreshold(PairAnalysis &results[], int &count)
   {
      count = 0;
      ArrayResize(results, 0);
      
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_analysis[i].combinedScore >= m_minConfidence &&
            m_analysis[i].signal != SIGNAL_NEUTRAL)
         {
            ArrayResize(results, count + 1);
            results[count] = m_analysis[i];
            count++;
         }
      }
   }
   
   int GetActiveOrderCount()
   {
      int count = 0;
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_analysis[i].hasOpenOrder)
            count++;
      }
      return count;
   }
   
   bool ApplyTemplate(string symbol, string templateName)
   {
      long chartId = ChartOpen(symbol, m_primaryTF);
      if(chartId == 0)
      {
         Print("Scanner: Failed to open chart for ", symbol);
         return false;
      }
      
      if(!ChartApplyTemplate(chartId, templateName))
      {
         Print("Scanner: Failed to apply template ", templateName, " to ", symbol);
         return false;
      }
      
      Print("Scanner: Applied template ", templateName, " to ", symbol);
      return true;
   }
   
   void OpenChartsForSignals(string templateName = "")
   {
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_analysis[i].combinedScore >= m_minConfidence &&
            m_analysis[i].signal != SIGNAL_NEUTRAL)
         {
            long chartId = ChartOpen(m_analysis[i].symbol, m_primaryTF);
            if(chartId > 0 && templateName != "")
            {
               ChartApplyTemplate(chartId, templateName);
            }
         }
      }
   }
   
private:
   void CreateLabel(string name, int x, int y, string text, color clr, int fontSize)
   {
      if(ObjectFind(0, name) >= 0)
      {
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      }
      else
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
         ObjectSetString(0, name, OBJPROP_TEXT, text);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
   }
   
   void CreateButton(string name, int x, int y, int width, int height, 
                     string text, color textColor, color bgColor)
   {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'65,105,225');
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   
   void CreateRowBackground(string name, int x, int y, int width, int height, color bgColor)
   {
      if(ObjectFind(0, name) >= 0)
      {
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      }
      else
      {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
         ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
         ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, name, OBJPROP_COLOR, bgColor);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
      }
   }
   
   void CreateProgressBar(string name, int x, int y, int width, int height, double progress)
   {
      string bgName = name + "_BG";
      string fgName = name + "_FG";
      
      if(ObjectFind(0, bgName) < 0)
      {
         ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, bgName, OBJPROP_XSIZE, width);
         ObjectSetInteger(0, bgName, OBJPROP_YSIZE, height);
         ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'40,40,50');
         ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDarkGray);
         ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
      
      int fillWidth = (int)(width * progress / 100.0);
      color fillColor = progress >= 100 ? clrLime : 
                        (progress >= 50 ? clrYellow : clrOrange);
      
      if(ObjectFind(0, fgName) >= 0)
      {
         ObjectSetInteger(0, fgName, OBJPROP_XSIZE, MathMax(1, fillWidth));
         ObjectSetInteger(0, fgName, OBJPROP_BGCOLOR, fillColor);
         ObjectSetInteger(0, fgName, OBJPROP_COLOR, fillColor);
      }
      else
      {
         ObjectCreate(0, fgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, fgName, OBJPROP_XDISTANCE, x + 1);
         ObjectSetInteger(0, fgName, OBJPROP_YDISTANCE, y + 1);
         ObjectSetInteger(0, fgName, OBJPROP_XSIZE, MathMax(1, fillWidth - 2));
         ObjectSetInteger(0, fgName, OBJPROP_YSIZE, height - 2);
         ObjectSetInteger(0, fgName, OBJPROP_BGCOLOR, fillColor);
         ObjectSetInteger(0, fgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, fgName, OBJPROP_COLOR, fillColor);
         ObjectSetInteger(0, fgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
   }
   
   color GetScoreColor(double score)
   {
      if(score >= 80) return clrLime;
      if(score >= 60) return clrYellow;
      if(score >= 40) return clrOrange;
      return clrRed;
   }
   
   color GetCombinedColor(double score)
   {
      if(score >= 90) return clrLime;
      if(score >= 85) return clrGreen;
      if(score >= 70) return clrYellow;
      return clrGray;
   }
   
   string GetSignalText(ENUM_SIGNAL_TYPE signal)
   {
      switch(signal)
      {
         case SIGNAL_STRONG_BUY: return "BUY++";
         case SIGNAL_BUY: return "BUY";
         case SIGNAL_MODERATE_BUY: return "BUY+";
         case SIGNAL_WEAK_BUY: return "buy";
         case SIGNAL_STRONG_SELL: return "SELL--";
         case SIGNAL_SELL: return "SELL";
         case SIGNAL_MODERATE_SELL: return "SELL-";
         case SIGNAL_WEAK_SELL: return "sell";
         default: return "---";
      }
   }
};
